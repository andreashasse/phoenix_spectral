defmodule TestUserController do
  @moduledoc false
  use PhoenixSpectral.Controller, formats: [:json]

  spectral(description: "The user's unique identifier")
  @type test_user_id :: String.t()

  @spec index(%{}, %{}, %{}, nil) :: {200, %{}, [TestUser.t()]}
  def index(_path_args, %{}, _headers, _body) do
    {200, %{}, [%TestUser{id: 1, name: "Alice", email: "alice@example.com"}]}
  end

  spectral(summary: "Get user", description: "Returns a user by ID")

  @spec show(%{id: test_user_id()}, %{}, %{}, nil) ::
          {200, %{}, TestUser.t()} | {404, %{}, TestError.t()}
  def show(%{id: id}, %{}, _headers, _body) do
    case id do
      "1" -> {200, %{}, %TestUser{id: 1, name: "Alice", email: "alice@example.com"}}
      _ -> {404, %{}, %TestError{message: "User not found"}}
    end
  end

  @spec create(%{}, %{}, %{}, TestUserInput.t()) ::
          {201, %{}, TestUser.t()} | {422, %{}, TestError.t()}
  def create(_path_args, %{}, _headers, body) do
    {201, %{}, %TestUser{id: 2, name: body.name, email: body.email}}
  end

  @spec update(%{id: String.t()}, %{}, %{}, TestUserInput.t()) ::
          {200, %{}, TestUser.t()} | {422, %{}, TestError.t()}
  def update(%{id: _id}, %{}, _headers, body) do
    {200, %{}, %TestUser{id: 1, name: body.name, email: body.email}}
  end

  @spec delete(%{id: String.t()}, %{}, %{}, nil) :: {204, %{}, nil}
  def delete(%{id: _id}, %{}, _headers, _body) do
    {204, %{}, nil}
  end

  @spec show_by_integer_id(%{id: integer()}, %{}, %{}, nil) :: {200, %{}, TestUser.t()}
  def show_by_integer_id(%{id: id}, %{}, _headers, _body) do
    {200, %{}, %TestUser{id: id, name: "Alice", email: "alice@example.com"}}
  end
end
