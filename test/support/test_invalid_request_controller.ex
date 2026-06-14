defmodule TestInvalidRequestController do
  @moduledoc false
  # Exercises the `:on_invalid_request` MFA form.
  use PhoenixSpectral.Controller,
    formats: [:json],
    on_invalid_request: {__MODULE__, :render_invalid}

  @spec create(Plug.Conn.t(), %{}, %{}, %{}, TestUserInput.t()) ::
          {201, %{}, TestUser.t()}
  def create(_conn, _path_args, %{}, _headers, body) do
    {201, %{}, %TestUser{id: 2, name: body.name, email: body.email}}
  end

  @doc false
  def render_invalid(conn, errors) do
    fields =
      Enum.map(errors, fn %Spectral.Error{location: location} ->
        Enum.map(location, &to_string/1)
      end)

    body = Phoenix.json_library().encode!(%{code: "validation_failed", fields: fields})

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(422, body)
  end
end

defmodule TestInvalidRequestFunController do
  @moduledoc false
  # Exercises the `:on_invalid_request` captured-function form.
  use PhoenixSpectral.Controller,
    formats: [:json],
    on_invalid_request: &__MODULE__.render_invalid/2

  @spec create(Plug.Conn.t(), %{}, %{}, %{}, TestUserInput.t()) ::
          {201, %{}, TestUser.t()}
  def create(_conn, _path_args, %{}, _headers, body) do
    {201, %{}, %TestUser{id: 2, name: body.name, email: body.email}}
  end

  @doc false
  def render_invalid(conn, _errors) do
    body = Phoenix.json_library().encode!(%{code: "nope"})

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(418, body)
  end
end
