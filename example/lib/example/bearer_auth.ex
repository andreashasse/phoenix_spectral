defmodule Example.BearerAuth do
  @moduledoc """
  Demonstrates runtime handling of an `Authorization: Bearer <token>` header.

  The OpenAPI `http`/`bearer` security scheme (declared in `Example.OpenAPIController`)
  only tells Swagger UI to send the header — Swagger UI adds the `"Bearer "` prefix
  for you, so the user pastes just the token. Stripping that prefix and verifying the
  token is the application's job, and that is what this plug does.

  This is the plug pattern: auth lives outside the controller typespec and the result
  is stashed in `conn.assigns`. Contrast it with the `x-api-key` header, which is
  declared in `Example.UserController`'s `write_headers` typespec and validated by
  PhoenixSpectral itself.
  """
  import Plug.Conn

  # Demo only. A real app verifies a signed token (e.g. a JWT) instead of comparing
  # against a constant.
  @valid_token "let-me-in"

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> verify(conn, token)
      _ -> unauthorized(conn, "missing or malformed Authorization header")
    end
  end

  defp verify(conn, @valid_token), do: assign(conn, :authenticated, true)
  defp verify(conn, _token), do: unauthorized(conn, "invalid token")

  defp unauthorized(conn, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{message: message}))
    |> halt()
  end
end
