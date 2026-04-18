defmodule Example.UserController do
  use PhoenixSpectral.Controller, formats: [:json]

  alias Example.Types.{User, UserId, UserInput, Error}

  @type read_headers :: %{}
  @type write_headers :: %{required(:"x-api-key") => String.t()}

  # In-memory store for demo purposes
  {:ok, dt, _} = DateTime.from_iso8601("2024-01-15T09:00:00Z")

  @users %{
    "1" => %User{
      id: 1,
      name: "Andreas",
      email: "andreas@example.com",
      password_hash: "hashed_secret_1",
      created_at: dt
    },
    "2" => %User{
      id: 2,
      name: "Hasse",
      email: "hasse@example.com",
      password_hash: "hashed_secret_2",
      created_at: dt
    }
  }

  spectral summary: "List users", description: "Returns all users"
  @spec index(Plug.Conn.t(), %{}, %{}, read_headers(), nil) :: {200, %{}, [User.t()]}
  def index(_conn, _path_args, %{}, _headers, _body) do
    {200, %{}, Map.values(@users)}
  end

  spectral summary: "Get user", description: "Returns a user by ID"
  @spec show(Plug.Conn.t(), %{id: UserId.t()}, %{}, read_headers(), nil) ::
          {200, %{}, User.t()} | {404, %{}, Error.t()}
  def show(_conn, %{id: id}, %{}, _headers, _body) do
    case Map.get(@users, id) do
      nil -> {404, %{}, %Error{message: "User #{id} not found"}}
      user -> {200, %{}, user}
    end
  end

  spectral summary: "Create user", description: "Creates a new user"
  @spec create(Plug.Conn.t(), %{}, %{}, write_headers(), UserInput.t()) ::
          {201, %{}, User.t()} | {422, %{}, Error.t()}
  def create(_conn, _path_args, %{}, _headers, body) do
    new_user = %User{
      id: 3,
      name: body.name,
      email: body.email,
      # password_hash is set server-side — it is never received from or sent to the client
      password_hash: "hashed_#{body.name}",
      created_at: DateTime.utc_now()
    }

    {201, %{}, new_user}
  end

  spectral summary: "Update user", description: "Updates an existing user by ID"
  @spec update(Plug.Conn.t(), %{id: UserId.t()}, %{}, write_headers(), UserInput.t()) ::
          {200, %{}, User.t()} | {404, %{}, Error.t()} | {422, %{}, Error.t()}
  def update(_conn, %{id: id}, %{}, _headers, body) do
    case Map.get(@users, id) do
      nil ->
        {404, %{}, %Error{message: "User #{id} not found"}}

      %User{} = user ->
        updated = %User{user | name: body.name, email: body.email}
        {200, %{}, updated}
    end
  end

  spectral summary: "Delete user", description: "Deletes a user by ID"
  @spec delete(Plug.Conn.t(), %{id: UserId.t()}, %{}, write_headers(), nil) ::
          {204, %{}, nil}
  def delete(_conn, _path_args, %{}, _headers, _body) do
    {204, %{}, nil}
  end
end
