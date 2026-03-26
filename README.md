# PhoenixSpectral

PhoenixSpectral integrates [Spectral](https://github.com/andreashasse/spectral) with Phoenix, making controller typespecs the single source of truth for OpenAPI 3.1 spec generation and request/response validation. Define your types once — PhoenixSpectral derives the API docs and enforces them at runtime.

## Installation

Add `phoenix_spectral` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_spectral, "~> 0.3.1"}
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

`use PhoenixSpectral.Controller` replaces the standard Phoenix `action(conn, params)` convention with `action(conn, path_args, query_params, headers, body)`:

- **`conn`** — the Plug connection, for out-of-band context (`conn.assigns`, `conn.remote_ip`, etc.)
- **`path_args`** — map of path parameters declared in the router (e.g. `%{id: 42}`), decoded from strings to the types declared in the spec
- **`query_params`** — map of query string parameters, decoded to typed values; required keys use atom syntax (`key: type`), optional keys use arrow syntax (`optional(key) => type`)
- **`headers`** — map of request headers, decoded from binary strings to typed values; required keys use atom syntax (`key: type`), optional keys use arrow syntax (`optional(key) => type`)
- **`body`** — decoded and validated request body, or `nil` for requests without a body

> **Note:** Use `conn` only for context that isn't already captured in the typed arguments — primarily `conn.assigns` (auth data from upstream plugs), `conn.remote_ip`, `conn.host`, or `conn.method`. Do not read `conn.path_params`, `conn.query_params`, `conn.req_headers`, or `conn.body_params` directly; use the decoded and validated arguments instead.

Actions return `{status_code, response_headers, response_body}`. Union return types produce multiple OpenAPI response entries.

Use the `spectral/1` macro to annotate actions with OpenAPI metadata such as `summary` and `description`:

```elixir
defmodule MyAppWeb.UserController do
  use PhoenixSpectral.Controller, formats: [:json]  # opts forwarded to use Phoenix.Controller

  spectral(summary: "Get user", description: "Returns a user by ID")
  @spec show(Plug.Conn.t(), %{id: integer()}, %{}, %{}, nil) ::
          {200, %{}, MyApp.User.t()}
          | {404, %{}, MyApp.Error.t()}
  def show(_conn, %{id: id}, _query, _headers, _body) do
    case MyApp.Users.get(id) do
      {:ok, user} -> {200, %{}, user}
      :not_found -> {404, %{}, %MyApp.Error{message: "User not found"}}
    end
  end

  spectral(summary: "Create user")
  @spec create(Plug.Conn.t(), %{}, %{}, %{}, MyApp.User.t()) :: {201, %{}, MyApp.User.t()}
  def create(_conn, _path_args, _query, _headers, body) do
    {201, %{}, MyApp.Users.insert!(body)}
  end
end
```

#### Parameter descriptions

To add a description to a path or header parameter in the OpenAPI output, define a named type alias and annotate it with `spectral`:

```elixir
spectral(description: "The user's unique identifier")
@type user_id :: integer()

@spec show(Plug.Conn.t(), %{id: user_id()}, %{}, %{}, nil) ::
        {200, %{}, MyApp.User.t()}
        | {404, %{}, MyApp.Error.t()}
def show(_conn, %{id: id}, _query, _headers, _body), do: ...
```

#### Typed response headers

Response headers are declared in the return type map:

```elixir
@spec show(Plug.Conn.t(), %{id: integer()}, %{}, %{}, nil) ::
        {200, %{"x-request-id": String.t()}, MyApp.User.t()}
def show(_conn, %{id: id}, _query, _headers, _body) do
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
| `:openapi_url` | no | URL path for the JSON spec, used by Swagger UI. Defaults to the path of this controller's `:show` route as declared in the router (scope prefixes included). Set explicitly to use a different path. |
| `:cache` | no | Cache the generated JSON in `:persistent_term` (default: `false`) |

## Streaming and raw responses

An action can return a `Plug.Conn` directly instead of `{status, headers, body}`. This enables `send_file/3`, `send_chunked/2`, and any other conn-based response mechanism:

```elixir
@spec download(Plug.Conn.t(), %{id: String.t()}, %{}, %{}, nil) :: {200, %{}, nil}
def download(conn, %{id: id}, _query, _headers, _body) do
  path = MyApp.Files.path_for(id)
  conn
  |> put_resp_content_type("application/octet-stream")
  |> send_file(200, path)
end
```

**When a conn is returned, PhoenixSpectral passes it through without schema validation.** The typespec still documents the endpoint for the OpenAPI spec, but the actual response is your responsibility.

## Request/Response Behavior

- **Invalid requests** (type mismatch, missing required fields) return `400 Bad Request` with a JSON error body listing the validation errors
- **Response encoding failures** return `500 Internal Server Error` and log the error
- **Missing or malformed typespecs** raise at runtime — actions without `@spec` crash on dispatch; malformed specs crash on spec generation
- Only routes whose controllers `use PhoenixSpectral.Controller` appear in the generated OpenAPI spec; standard Phoenix controllers are ignored

## Example

The [`example/`](https://github.com/andreashasse/phoenix_spectral/tree/main/example) directory contains a complete runnable Phoenix app demonstrating a CRUD user API with path parameters, typed request headers, union return types, and an OpenAPI/Swagger UI endpoint. To run it:

```bash
cd example
mix deps.get
make integration-test   # starts server, runs curl checks, stops server
```

## Design

- **Typespecs are the single source of truth** — no separate schema definitions; `@spec` drives both docs and validation
- **Action convention** — `(conn, path_args, query_params, headers, body)` → `{status, headers, body}`; union return types produce multiple OpenAPI response entries
- **Crash on bad code, error on bad user input** — malformed typespecs raise; invalid requests return 400, encoding failures return 500
- **Automatic encoding/decoding** — Spectral handles struct serialization
- **Optional caching** — via `persistent_term` for production performance
