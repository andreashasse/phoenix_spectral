defmodule TestConnController do
  @moduledoc false
  use PhoenixSpectral.Controller, formats: [:json]

  @spec show_with_assigns(Plug.Conn.t(), %{id: String.t()}, %{}, %{}, nil) ::
          {200, %{}, TestUser.t()}
  def show_with_assigns(conn, %{id: id}, _query, _headers, _body) do
    current_user = conn.assigns[:current_user] || "unknown"

    {200, %{},
     %TestUser{
       id: String.to_integer(id),
       name: current_user,
       email: "#{current_user}@example.com"
     }}
  end

  # The typespec declares the API contract for OpenAPI generation.
  # The implementation returns conn directly, demonstrating the raw-response
  # escape hatch — schema validation is intentionally bypassed.
  @spec download(Plug.Conn.t(), %{}, %{}, %{}, nil) :: {200, %{}, nil}
  def download(conn, _path_args, _query, _headers, _body) do
    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, "file content")
  end
end
