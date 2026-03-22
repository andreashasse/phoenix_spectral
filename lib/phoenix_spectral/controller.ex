defmodule PhoenixSpectral.Controller do
  @moduledoc """
  A Phoenix controller module that validates requests and responses using typespecs.

  When you `use PhoenixSpectral.Controller`, your controller actions use a 4-arity
  convention `(path_args, query_params, headers, body)` instead of the standard Phoenix
  `(conn, params)`. Request data is decoded and validated against your typespecs,
  and responses are encoded automatically.

  ## Usage

      defmodule MyAppWeb.UserController do
        use PhoenixSpectral.Controller

        @spec show(%{id: String.t()}, %{}, %{}, nil) :: {200, %{}, User.t()}
        def show(path_args, _query_params, _headers, _body) do
          user = Repo.get!(User, path_args.id)
          {200, %{}, user}
        end

        @spec create(%{}, %{}, %{}, UserInput.t()) :: {201, %{}, User.t()} | {422, %{}, Error.t()}
        def create(_path_args, _query_params, _headers, body) do
          case Repo.insert(body) do
            {:ok, user} -> {201, %{}, user}
            {:error, changeset} -> {422, %{}, format_errors(changeset)}
          end
        end
      end

  ## How It Works

  1. Extracts path params, query params, headers, and body from `conn`
  2. Decodes and validates them against the action's typespec via `Spectral.decode`
  3. Calls your handler as `action(path_args, query_params, headers, decoded_body)`
  4. Encodes the `{status, headers, body}` response via `Spectral.encode`
  5. Sends the response on `conn`
  6. On validation failure, returns a 400 response
  """

  require Logger
  # Records extracted from deps/spectra/include/spectra_internal.hrl.
  require Record

  Record.defrecordp(
    :sp_function_spec,
    Record.extract(:sp_function_spec, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecordp(
    :sp_literal,
    Record.extract(:sp_literal, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecordp(
    :sp_map,
    Record.extract(:sp_map, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecordp(
    :sp_tuple,
    Record.extract(:sp_tuple, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecordp(
    :sp_union,
    Record.extract(:sp_union, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecordp(
    :sp_user_type_ref,
    Record.extract(:sp_user_type_ref, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecordp(
    :literal_map_field,
    Record.extract(:literal_map_field, from_lib: "spectra/include/spectra_internal.hrl")
  )

  defmacro __using__(opts) do
    quote do
      use Phoenix.Controller, unquote(opts)
      use Spectral

      @before_compile PhoenixSpectral.Controller
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      defoverridable action: 2

      def action(conn, _opts) do
        action_name = Phoenix.Controller.action_name(conn)
        PhoenixSpectral.Controller.dispatch(conn, __MODULE__, action_name)
      end
    end
  end

  def dispatch(conn, controller, action) do
    with {:ok, path_args} <- decode_path_args(conn, controller, action),
         {:ok, query_params} <- decode_query_params(conn, controller, action),
         {:ok, headers} <- decode_request_headers(conn, controller, action),
         {:ok, body} <- decode_request_body(conn, controller, action) do
      case apply(controller, action, [path_args, query_params, headers, body]) do
        {status, response_headers, response_body} when is_integer(status) ->
          send_typed_response(conn, controller, action, status, response_headers, response_body)

        other ->
          raise "PhoenixSpectral action #{inspect(controller)}.#{action}/4 must return " <>
                  "{status, headers, body}, got: #{inspect(other)}"
      end
    else
      {:error, errors} ->
        body =
          Phoenix.json_library().encode!(%{error: "Bad Request", details: format_errors(errors)})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, body)
    end
  end

  defp decode_request_body(conn, controller, action) do
    {_path_args_type, _query_params_type, _headers_type, body_type} =
      lookup_action_types(controller, action)

    type_info = controller.__spectra_type_info__()

    raw_body =
      case conn.body_params do
        %Plug.Conn.Unfetched{} -> nil
        params -> params
      end

    Spectral.decode(raw_body, type_info, body_type, :json, [:pre_decoded])
  end

  defp lookup_action_types(controller, action) do
    type_info = controller.__spectra_type_info__()

    {:ok,
     [
       sp_function_spec(args: [path_args_type, query_params_type, headers_type, body_type]) | _
     ]} = Spectral.TypeInfo.find_function(type_info, action, 4)

    {path_args_type, query_params_type, headers_type, body_type}
  end

  defp decode_path_args(conn, controller, action) do
    {path_args_type, _query_params_type, _headers_type, _body_type} =
      lookup_action_types(controller, action)

    type_info = controller.__spectra_type_info__()
    fields = PhoenixSpectral.map_fields(path_args_type, type_info)
    raw_path_params = conn.path_params

    Enum.reduce_while(fields, {:ok, %{}}, fn field, {:ok, acc} ->
      literal_map_field(name: name, binary_name: binary_name, val_type: val_type) = field

      case Map.fetch(raw_path_params, binary_name) do
        {:ok, raw_value} ->
          decode_value(raw_value, name, type_info, val_type, acc)

        :error ->
          raise "PhoenixSpectral: path param #{inspect(binary_name)} declared in typespec for " <>
                  "#{inspect(controller)}.#{action}/4 is not present in conn.path_params. " <>
                  "Does the router path match the typespec?"
      end
    end)
  end

  defp decode_query_params(conn, controller, action) do
    {_path_args_type, query_params_type, _headers_type, _body_type} =
      lookup_action_types(controller, action)

    type_info = controller.__spectra_type_info__()
    fields = PhoenixSpectral.map_fields(query_params_type, type_info)

    raw_query_params =
      case conn.query_params do
        %Plug.Conn.Unfetched{} ->
          %{query_params: params} = Plug.Conn.fetch_query_params(conn)
          params

        params ->
          params
      end

    Enum.reduce_while(fields, {:ok, %{}}, fn field, {:ok, acc} ->
      literal_map_field(kind: kind, name: name, binary_name: binary_name, val_type: val_type) =
        field

      case Map.fetch(raw_query_params, binary_name) do
        {:ok, raw_value} ->
          decode_value(raw_value, name, type_info, val_type, acc)

        :error when kind == :exact ->
          {:halt, {:error, [%Spectral.Error{type: :missing_data, location: [name]}]}}

        :error ->
          {:cont, {:ok, acc}}
      end
    end)
  end

  defp decode_request_headers(conn, controller, action) do
    {_path_args_type, _query_params_type, headers_type, _body_type} =
      lookup_action_types(controller, action)

    type_info = controller.__spectra_type_info__()
    fields = PhoenixSpectral.map_fields(headers_type, type_info)
    raw_headers = conn.req_headers

    Enum.reduce_while(fields, {:ok, %{}}, fn field, {:ok, acc} ->
      literal_map_field(kind: kind, name: name, binary_name: binary_name, val_type: val_type) =
        field

      case List.keyfind(raw_headers, binary_name, 0) do
        {_key, raw_value} ->
          decode_value(raw_value, name, type_info, val_type, acc)

        nil when kind == :exact ->
          {:halt, {:error, [%Spectral.Error{type: :missing_data, location: [name]}]}}

        nil ->
          {:cont, {:ok, acc}}
      end
    end)
  end

  defp decode_value(raw_value, name, type_info, val_type, acc) do
    case Spectral.decode(raw_value, type_info, val_type, :binary_string) do
      {:ok, decoded} -> {:cont, {:ok, Map.put(acc, name, decoded)}}
      {:error, errors} -> {:halt, {:error, errors}}
    end
  end

  defp send_typed_response(conn, controller, action, status, response_headers, response_body) do
    type_info = controller.__spectra_type_info__()
    conn = encode_response_headers(conn, type_info, action, status, response_headers)
    body_type = lookup_response_body_type(type_info, action, status)

    case encode_response_body(type_info, body_type, response_body) do
      {:ok, encoded} ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(status, encoded)

      {:error, errors} ->
        Logger.error(
          "PhoenixSpectral: response encoding failed for #{inspect(controller)}.#{action}/4: #{inspect(errors)}"
        )

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          500,
          ~s({"error":"Internal Server Error","message":"Response encoding failed"})
        )
    end
  end

  defp find_return_tuple(type_info, action, status) do
    {:ok, [sp_function_spec(return: return_type) | _]} =
      Spectral.TypeInfo.find_function(type_info, action, 4)

    tuples =
      case return_type do
        sp_union(types: types) -> types
        sp_tuple() = t -> [t]
      end

    Enum.find(tuples, fn sp_tuple(fields: [sp_literal(value: s), _, _]) -> s == status end)
  end

  defp lookup_response_body_type(type_info, action, status) do
    sp_tuple(fields: [_status_type, _headers_type, body_type]) =
      find_return_tuple(type_info, action, status)

    body_type
  end

  defp lookup_response_headers_type(type_info, action, status) do
    sp_tuple(fields: [_status_type, headers_type, _body_type]) =
      find_return_tuple(type_info, action, status)

    headers_type
  end

  defp encode_response_body(_type_info, sp_literal(value: nil), nil), do: {:ok, ""}

  defp encode_response_body(type_info, body_type, body) do
    case Spectral.encode(body, type_info, body_type, :json, [:pre_encoded]) do
      {:ok, term} -> {:ok, Phoenix.json_library().encode!(term)}
      {:error, _} = err -> err
    end
  end

  defp encode_response_headers(conn, type_info, action, status, response_headers) do
    headers_type = lookup_response_headers_type(type_info, action, status)
    fields = PhoenixSpectral.map_fields(headers_type, type_info)

    Enum.reduce(fields, conn, fn field, acc ->
      literal_map_field(kind: kind, name: name, binary_name: binary_name, val_type: val_type) =
        field

      case Map.fetch(response_headers, name) do
        {:ok, value} ->
          {:ok, encoded} = Spectral.encode(value, type_info, val_type, :binary_string)
          Plug.Conn.put_resp_header(acc, binary_name, encoded)

        :error when kind == :exact ->
          raise "PhoenixSpectral: required response header #{inspect(binary_name)} declared in " <>
                  "typespec for #{action}/4 is missing from the response"

        :error ->
          acc
      end
    end)
  end

  defp format_errors(errors) when is_list(errors) do
    Enum.map(errors, fn %Spectral.Error{location: location, type: type} ->
      %{
        type: type,
        location: Enum.map(location, &to_string/1)
      }
    end)
  end
end
