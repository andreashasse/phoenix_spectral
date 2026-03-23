defmodule TestUserController do
  @moduledoc false
  use PhoenixSpectral.Controller, formats: [:json]

  spectral(description: "The user's unique identifier")
  @type test_user_id :: String.t()

  @spec index(Plug.Conn.t(), %{}, %{}, %{}, nil) :: {200, %{}, [TestUser.t()]}
  def index(_conn, _path_args, %{}, _headers, _body) do
    {200, %{}, [%TestUser{id: 1, name: "Alice", email: "alice@example.com"}]}
  end

  spectral(summary: "Get user", description: "Returns a user by ID")

  @spec show(Plug.Conn.t(), %{id: test_user_id()}, %{}, %{}, nil) ::
          {200, %{}, TestUser.t()} | {404, %{}, TestError.t()}
  def show(_conn, %{id: id}, %{}, _headers, _body) do
    case id do
      "1" -> {200, %{}, %TestUser{id: 1, name: "Alice", email: "alice@example.com"}}
      _ -> {404, %{}, %TestError{message: "User not found"}}
    end
  end

  @spec create(Plug.Conn.t(), %{}, %{}, %{}, TestUserInput.t()) ::
          {201, %{}, TestUser.t()} | {422, %{}, TestError.t()}
  def create(_conn, _path_args, %{}, _headers, body) do
    {201, %{}, %TestUser{id: 2, name: body.name, email: body.email}}
  end

  @spec update(Plug.Conn.t(), %{id: String.t()}, %{}, %{}, TestUserInput.t()) ::
          {200, %{}, TestUser.t()} | {422, %{}, TestError.t()}
  def update(_conn, %{id: _id}, %{}, _headers, body) do
    {200, %{}, %TestUser{id: 1, name: body.name, email: body.email}}
  end

  @spec delete(Plug.Conn.t(), %{id: String.t()}, %{}, %{}, nil) :: {204, %{}, nil}
  def delete(_conn, %{id: _id}, %{}, _headers, _body) do
    {204, %{}, nil}
  end

  @spec show_by_integer_id(Plug.Conn.t(), %{id: integer()}, %{}, %{}, nil) ::
          {200, %{}, TestUser.t()}
  def show_by_integer_id(_conn, %{id: id}, %{}, _headers, _body) do
    {200, %{}, %TestUser{id: id, name: "Alice", email: "alice@example.com"}}
  end
end
