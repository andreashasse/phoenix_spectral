defmodule PhoenixSpectral do
  @moduledoc """
  Generates OpenAPI 3.1 specifications from Phoenix router and typed controllers.

  Controllers that `use PhoenixSpectral.Controller` and define typespecs on their
  action functions become the single source of truth for OpenAPI documentation.

  The schema for each request and response is derived from your types by `Spectral`.
  Schema details — descriptions, examples, string constraints, field aliases, custom
  codecs — are declared on the types via Spectral's `spectral/1` macro; see the
  [Spectral docs](https://hexdocs.pm/spectral).

  ## Usage

      {:ok, spec} = PhoenixSpectral.generate_openapi(MyAppWeb.Router, %{title: "My API", version: "1.0.0"})
  """

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
    :sp_tuple,
    Record.extract(:sp_tuple, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecordp(
    :literal_map_field,
    Record.extract(:literal_map_field, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecordp(
    :sp_union,
    Record.extract(:sp_union, from_lib: "spectra/include/spectra_internal.hrl")
  )

  @doc """
  Generates an OpenAPI 3.1 specification from a Phoenix router module.

  Introspects all routes in the router, extracts type information from
  controllers, and builds an OpenAPI spec.

  ## Parameters

  - `router` - A Phoenix router module
  - `metadata` - Map with API metadata. Required keys:
    - `:title` — API title
    - `:version` — API version string

    Optional keys:
    - `:summary` — short one-line summary of the API (appears in `info.summary`)
    - `:description` — longer description of the API (appears in `info.description`)
    - `:terms_of_service` — URL string for terms of service
    - `:contact` — map with `:name`, `:url`, and/or `:email`
    - `:license` — map with `:name` and optional `:url` or `:identifier`
    - `:servers` — list of server maps, each with `:url` and optional `:description`

  ## Returns

  - `{:ok, iodata}` - Complete OpenAPI 3.1 specification as JSON iodata
  - `{:error, errors}` - List of errors if generation fails

  ## Parameter descriptions via typed type aliases

  To add a description to a path or header parameter, define a named type alias
  for the parameter's type and annotate it with `spectral description: "..."`:

      spectral description: "The user's unique identifier"
      @type user_id :: String.t()

      @spec show(%{id: user_id()}, %{}, nil) :: {200, %{}, User.t()}
      def show(%{id: id}, _headers, _body), do: ...

  PhoenixSpectral reads the type's metadata when building the spec and adds the
  `description` field to the parameter object in the OpenAPI output.
  """
  @spec generate_openapi(module(), map()) :: {:ok, iodata()} | {:error, list()}
  def generate_openapi(router, metadata) do
    generate_openapi(router, metadata, [])
  end

  @spec generate_openapi(module(), map(), [:pre_encoded]) ::
          {:ok, iodata() | map()} | {:error, list()}
  def generate_openapi(router, metadata, options) do
    generate_openapi(router, metadata, [], options)
  end

  @doc """
  Generates an OpenAPI 3.1 specification from a Phoenix router and a list of webhooks.

  Webhooks describe requests your API *sends out*, rather than requests it
  receives, so they have no route in the router and are declared explicitly here.
  They are emitted under the spec's top-level
  [`webhooks`](https://spec.openapis.org/oas/v3.1.0#oasWebhooks) key, keyed by
  event name, and their payload types share `components/schemas` with the routes.

  The direction is inverted relative to a route: the payload is what your API
  *sends*, and the responses describe what the consumer is expected to *return*.

  ## Webhook entries

  Each entry is a map:

  - `:name` — event name the webhook is keyed by (required, e.g. `"userCreated"`)
  - `:method` — HTTP method your API uses when calling the consumer (required, usually `:post`)
  - `:module` — module owning the payload type (required)
  - `:payload` — the payload type reference (required, e.g. `{:type, :t, 0}`)
  - `:responses` — list of `{status_code, description}` tuples (optional, defaults to none)
  - `:doc` — operation documentation map, as for `Spectral.OpenAPI.endpoint/3` (optional)

  A malformed entry raises rather than producing a broken spec.

  ## Example

      PhoenixSpectral.generate_openapi(MyAppWeb.Router, metadata, [
        %{
          name: "userCreated",
          method: :post,
          module: MyApp.Events,
          payload: {:type, :user_created, 0},
          responses: [{200, "Acknowledged"}],
          doc: %{summary: "Sent when a user is created"}
        }
      ], [])
  """
  @spec generate_openapi(module(), map(), [map()], [:pre_encoded]) ::
          {:ok, iodata() | map()} | {:error, list()}
  def generate_openapi(router, metadata, webhooks, options)
      when is_list(webhooks) and is_list(options) do
    endpoints =
      router
      |> Phoenix.Router.routes()
      |> Enum.filter(&api_route?/1)
      |> Enum.map(&route_to_endpoint/1)

    :spectra_openapi.to_openapi(
      metadata,
      endpoints,
      Enum.map(webhooks, &to_webhook/1),
      options
    )
  end

  defp to_webhook(%{name: name, method: method, module: module, payload: payload} = webhook) do
    Spectral.OpenAPI.webhook(name, method, Map.get(webhook, :doc, %{}))
    |> Spectral.OpenAPI.with_request_body(module, payload)
    |> add_webhook_responses(Map.get(webhook, :responses, []))
  end

  defp add_webhook_responses(webhook, responses) do
    Enum.reduce(responses, webhook, fn {status, description}, acc ->
      Spectral.OpenAPI.add_response(acc, Spectral.OpenAPI.response(status, description))
    end)
  end

  defp api_route?(%{plug: plug}) do
    Code.ensure_loaded(plug)
    function_exported?(plug, :__spectra_type_info__, 0)
  end

  defp route_to_endpoint(%{verb: verb, path: path, plug: controller, plug_opts: action}) do
    {path_args_type, query_params_type, headers_type, body_type, return_type} =
      extract_handler_type(controller, action)

    Spectral.OpenAPI.endpoint(verb, phoenix_path_to_openapi_path(path), controller, action, 5)
    |> maybe_add_request_body(verb, controller, body_type)
    |> add_header_parameters(controller, headers_type)
    |> add_query_parameters(controller, query_params_type)
    |> add_path_parameters(controller, path_args_type)
    |> add_responses(controller, extract_responses(return_type))
  end

  defp maybe_add_request_body(endpoint, verb, controller, body_type) do
    if http_method_supports_body?(verb) do
      Spectral.OpenAPI.with_request_body(endpoint, controller, body_type)
    else
      endpoint
    end
  end

  defp add_responses(endpoint, controller, responses) do
    Enum.reduce(responses, endpoint, fn {status, headers_type, body_type}, ep ->
      Spectral.OpenAPI.response(status, status_code_description(status))
      |> Spectral.OpenAPI.response_with_body(controller, body_type)
      |> add_response_headers(controller, headers_type)
      |> then(&Spectral.OpenAPI.add_response(ep, &1))
    end)
  end

  defp add_response_headers(response, controller, headers_type) do
    type_info = controller.__spectra_type_info__()
    fields = PhoenixSpectral.Internal.map_fields(headers_type, type_info)

    Enum.reduce(fields, response, fn field, acc ->
      literal_map_field(kind: kind, binary_name: binary_name, val_type: val_type) = field

      Spectral.OpenAPI.response_with_header(acc, binary_name, controller, %{
        required: kind == :exact,
        schema: val_type
      })
    end)
  end

  defp extract_handler_type(controller, action) do
    type_info = controller.__spectra_type_info__()

    {:ok,
     [
       sp_function_spec(
         args: [_conn_type, path_args, query_params, headers, body],
         return: return_type
       )
       | _
     ]} = Spectral.TypeInfo.find_function(type_info, action, 5)

    {path_args, query_params, headers, body, return_type}
  end

  defp extract_responses(sp_union(types: types)) do
    Enum.flat_map(types, &extract_single_response/1)
  end

  defp extract_responses(other) do
    extract_single_response(other)
  end

  defp extract_single_response(sp_tuple(fields: [status_type, headers_type, body_type])) do
    sp_literal(value: status) = status_type
    [{status, headers_type, body_type}]
  end

  defp add_header_parameters(endpoint, controller, headers_type) do
    type_info = controller.__spectra_type_info__()
    fields = PhoenixSpectral.Internal.map_fields(headers_type, type_info)

    Enum.reduce(fields, endpoint, fn field, ep ->
      literal_map_field(kind: kind, binary_name: binary_name, val_type: val_type) = field

      param_spec = %{
        name: binary_name,
        in: :header,
        required: kind == :exact,
        schema: val_type
      }

      Spectral.OpenAPI.with_parameter(ep, controller, param_spec)
    end)
  end

  defp add_query_parameters(endpoint, controller, query_params_type) do
    type_info = controller.__spectra_type_info__()
    fields = PhoenixSpectral.Internal.map_fields(query_params_type, type_info)

    Enum.reduce(fields, endpoint, fn field, ep ->
      literal_map_field(kind: kind, binary_name: binary_name, val_type: val_type) = field

      param_spec = %{
        name: binary_name,
        in: :query,
        required: kind == :exact,
        schema: val_type
      }

      Spectral.OpenAPI.with_parameter(ep, controller, param_spec)
    end)
  end

  @path_param_regex ~r/:([a-zA-Z_][a-zA-Z0-9_]*)/

  defp phoenix_path_to_openapi_path(path) do
    Regex.replace(@path_param_regex, path, "{\\1}")
  end

  defp add_path_parameters(endpoint, controller, path_args_type) do
    type_info = controller.__spectra_type_info__()
    fields = PhoenixSpectral.Internal.map_fields(path_args_type, type_info)

    Enum.reduce(fields, endpoint, fn field, ep ->
      literal_map_field(binary_name: binary_name, val_type: val_type) = field

      param_spec = %{
        name: binary_name,
        in: :path,
        required: true,
        schema: val_type
      }

      Spectral.OpenAPI.with_parameter(ep, controller, param_spec)
    end)
  end

  defp http_method_supports_body?(:post), do: true
  defp http_method_supports_body?(:put), do: true
  defp http_method_supports_body?(:patch), do: true
  defp http_method_supports_body?(_), do: false

  defp status_code_description(200), do: "OK"
  defp status_code_description(201), do: "Created"
  defp status_code_description(204), do: "No Content"
  defp status_code_description(400), do: "Bad Request"
  defp status_code_description(401), do: "Unauthorized"
  defp status_code_description(403), do: "Forbidden"
  defp status_code_description(404), do: "Not Found"
  defp status_code_description(409), do: "Conflict"
  defp status_code_description(422), do: "Unprocessable Entity"
  defp status_code_description(500), do: "Internal Server Error"
  defp status_code_description(code), do: "Response #{code}"
end
