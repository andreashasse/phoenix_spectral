# PhoenixSpectral

PhoenixSpectral integrates [Spectral](https://github.com/andreashasse/spectral) with Phoenix, making controller typespecs the single source of truth for OpenAPI 3.1 spec generation and request/response validation. Define your types once — PhoenixSpectral derives the API docs and enforces them at runtime.

## Installation

Add `phoenix_spectral` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_spectral, "~> 0.2.0"}
  ]
end
```

## Usage

### Step 1: Define typed structs with Spectral

[Spectral](https://github.com/andreashasse/spectral) is an Elixir library that validates, decodes, and encodes data according to your `@type` definitions. Add `use Spectral` to a module and your types become the schema — PhoenixSpectral reads them to validate requests, decode inputs, encode responses, and generate the OpenAPI spec.

```elixir
defmodule MyApp.User do
  use Spectral

  defstruct [:id, :name, :email]

  spectral(title: "User", description: "A user resource")
  @type t :: %__MODULE__{
    id: integer(),
    name: String.t(),
    email: String.t()
  }
end

defmodule MyApp.Error do
  use Spectral

  defstruct [:message]

  spectral(title: "Error")
  @type t :: %__MODULE__{message: String.t()}
end
```

### Step 2: Create a typed controller

`use PhoenixSpectral.Controller` replaces the standard Phoenix `action(conn, params)` convention with a 3-arity `action(path_args, headers, body)` convention:

- **`path_args`** — map of path parameters declared in the router (e.g. `%{id: 42}`), decoded from strings to the types declared in the spec
- **`headers`** — map of request headers, decoded from binary strings to typed values; required keys use atom syntax (`key: type`), optional keys use arrow syntax (`optional(key) => type`)
- **`body`** — decoded and validated request body, or `nil` for requests without a body

Actions return `{status_code, response_headers, response_body}`. Union return types produce multiple OpenAPI response entries.

Use the `spectral/1` macro to annotate actions with OpenAPI metadata such as `summary` and `description`:

```elixir
defmodule MyAppWeb.UserController do
  use PhoenixSpectral.Controller, formats: [:json]

  spectral(summary: "Get user", description: "Returns a user by ID")
  @spec show(%{id: integer()}, %{}, nil) ::
          {200, %{}, MyApp.User.t()}
          | {404, %{}, MyApp.Error.t()}
  def show(%{id: id}, _headers, nil) do
    case MyApp.Users.get(id) do
      {:ok, user} -> {200, %{}, user}
      :not_found -> {404, %{}, %MyApp.Error{message: "User not found"}}
    end
  end

  spectral(summary: "Create user")
  @spec create(%{}, %{}, MyApp.User.t()) :: {201, %{}, MyApp.User.t()}
  def create(_path_args, _headers, body) do
    {201, %{}, MyApp.Users.insert!(body)}
  end
end
```

#### Parameter descriptions

To add a description to a path or header parameter in the OpenAPI output, define a named type alias and annotate it with `spectral`:

```elixir
spectral(description: "The user's unique identifier")
@type user_id :: integer()

@spec show(%{id: user_id()}, %{}, nil) ::
        {200, %{}, MyApp.User.t()}
        | {404, %{}, MyApp.Error.t()}
def show(%{id: id}, _headers, nil), do: ...
```

#### Typed response headers

Response headers are declared in the return type map:

```elixir
@spec show(%{id: integer()}, %{}, nil) ::
        {200, %{"x-request-id": String.t()}, MyApp.User.t()}
def show(%{id: id}, _headers, nil) do
  {200, %{"x-request-id": "abc123"}, MyApp.Users.get!(id)}
end
```

### Step 3: Serve the OpenAPI spec

```elixir
defmodule MyAppWeb.OpenAPIController do
  use PhoenixSpectral.OpenAPIController,
    router: MyAppWeb.Router,
    title: "My API",
    version: "1.0.0"
end
```

Add routes in your router:

```elixir
scope "/api" do
  get "/users/:id", MyAppWeb.UserController, :show
  post "/users", MyAppWeb.UserController, :create
  get "/openapi", MyAppWeb.OpenAPIController, :show
  get "/swagger", MyAppWeb.OpenAPIController, :swagger
end
```

`GET /openapi` returns the OpenAPI JSON spec. `GET /swagger` serves a Swagger UI page.

#### OpenAPIController options

| Option | Required | Description |
|--------|----------|-------------|
| `:router` | yes | Your Phoenix router module |
| `:title` | yes | API title |
| `:version` | yes | API version string |
| `:summary` | no | Short one-line summary |
| `:description` | no | Longer description |
| `:terms_of_service` | no | URL to terms of service |
| `:contact` | no | Map with `:name`, `:url`, `:email` |
| `:license` | no | Map with `:name` and optional `:url`, `:identifier` |
| `:servers` | no | List of maps with `:url` and optional `:description` |
| `:openapi_url` | no | URL path for the JSON spec, used by Swagger UI (default: `"/openapi"`) |
| `:cache` | no | Cache the generated JSON in `:persistent_term` (default: `false`) |

## Request/Response Behavior

- **Invalid requests** (type mismatch, missing required fields) return `400 Bad Request` with a JSON error body listing the validation errors
- **Response encoding failures** return `500 Internal Server Error` and log the error
- **Malformed typespecs** raise at runtime — the fail-fast approach surfaces bugs during development rather than silently producing broken specs
- Only routes whose controllers `use PhoenixSpectral.Controller` appear in the generated OpenAPI spec; standard Phoenix controllers are ignored

## Design

- **Typespecs are the single source of truth** — no separate schema definitions; `@spec` drives both docs and validation
- **3-arity action convention** — `(path_args, headers, body)` → `{status, headers, body}`; union return types produce multiple OpenAPI response entries
- **Crash on bad code, error on bad user input** — malformed typespecs raise; invalid requests return 400, encoding failures return 500
- **Automatic encoding/decoding** — Spectral handles struct serialization
- **Optional caching** — via `persistent_term` for production performance
