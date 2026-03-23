defmodule TestHeaderController do
  @moduledoc false
  use PhoenixSpectral.Controller, formats: [:json]

  @type required_headers :: %{required(:"x-user-id") => String.t()}
  @type optional_headers :: %{optional(:"x-trace-id") => String.t()}

  @spec show(Plug.Conn.t(), %{id: String.t()}, %{}, required_headers(), nil) ::
          {200, %{}, TestUser.t()}
  def show(_conn, %{id: _id}, %{}, headers, _body) do
    {200, %{}, %TestUser{id: 1, name: headers[:"x-user-id"], email: "test@example.com"}}
  end

  @spec index(Plug.Conn.t(), %{}, %{}, optional_headers(), nil) :: {200, %{}, [TestUser.t()]}
  def index(_conn, _path_args, %{}, _headers, _body) do
    {200, %{}, [%TestUser{id: 1, name: "Alice", email: "alice@example.com"}]}
  end

  @type count_response_headers :: %{required(:"x-count") => integer()}

  @spec list_with_count(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, count_response_headers(), [TestUser.t()]}
  def list_with_count(_conn, _path_args, %{}, _headers, _body) do
    users = [%TestUser{id: 1, name: "Alice", email: "alice@example.com"}]
    {200, %{:"x-count" => length(users)}, users}
  end

  @spec list_with_string_count(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, count_response_headers(), [TestUser.t()]}
  def list_with_string_count(_conn, _path_args, %{}, _headers, _body) do
    # Returns a string for an integer-typed header — this is bad code and should crash.
    {200, %{:"x-count" => "not-an-integer"}, []}
  end

  @spec ping(Plug.Conn.t(), %{}, %{}, TestRemoteTypes.request_headers(), nil) ::
          {200, %{}, TestUser.t()}
  def ping(_conn, _path_args, %{}, headers, _body) do
    {200, %{}, %TestUser{id: 1, name: headers[:"x-request-id"], email: "test@example.com"}}
  end

  @spec search(Plug.Conn.t(), %{id: String.t()}, %{}, %{}, nil) ::
          {200, count_response_headers(), TestUser.t()} | {404, %{}, TestError.t()}
  def search(_conn, %{id: id}, %{}, _headers, _body) do
    case id do
      "1" ->
        {200, %{:"x-count" => 1}, %TestUser{id: 1, name: "Alice", email: "alice@example.com"}}

      _ ->
        {404, %{}, %TestError{message: "Not found"}}
    end
  end
end
