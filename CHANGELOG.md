# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] - 2026-09-14

### Added

- Non-JSON response content types. A `content-type` entry in a response headers map, with the media type as a literal atom (e.g. `{200, %{"content-type": :"application/pdf"}, binary()}`), is now the declaration of that response's media type: the OpenAPI spec emits the body under it instead of `application/json` rather than listing it in the response's `headers` object, the response's `content-type` is set from it, and at runtime a non-JSON body is sent verbatim rather than JSON-encoded (it must be a `binary()`). The entry is validated like the response headers around it — a `required` declaration the action omits raises, as does a returned value that does not match the declared media type — while `optional(:"content-type")` lets the action leave it out and take the media type from the typespec alone. The declaration applies per response, so other statuses in the same union stay JSON, and it also documents actions that return `conn` directly for streaming or file sends.

### Fixed

- A response whose declared body type is `nil` now raises when the action returns a body anyway, instead of sending those bytes under a spec that documents no content for the response. The JSON path already rejected the mismatch; the raw path did not.
- A type alias that resolves to `nil` (`@type empty :: nil`) is now treated as a `nil` body type wherever a bare `nil` already was: the OpenAPI response carries no `content` instead of a `"null"` enum, and the runtime sends an empty body instead of encoding `"null"` or — under a declared non-JSON media type — raising for a body that is not a binary.
- A parameterized type alias (`@type tagged(t) :: %{...}`) used as a response headers map or a response body now resolves. Both resolution sites looked the alias up at arity 0 and crashed with a `MatchError`; type references are now resolved in one place, at the arity the reference carries, with the reference's arguments substituted for the alias's variables.

### Changed

- Depends on `spectral ~> 0.14.0` and `spectra ~> 0.14.0`, up from the 0.13 line, and accepts every later 0.14.x release of both.
- **Breaking:** a `content-type` entry in a response headers map is now a media type declaration, not a header. Declaring one whose value is not a literal atom media type — e.g. `%{"content-type": String.t()}`, which 0.6.x documented as a response header and then overwrote with `application/json` at runtime — now raises, in the generator and on dispatch. Drop the entry, or make it a literal atom (`%{"content-type": :"application/pdf"}`). Header names are matched case-insensitively, so `Content-Type` is affected too.

## [0.6.1] - 2026-06-17

### Changed

- Documentation now surfaces Spectral's type features directly: a "Going further with Spectral" reference table in the README (string/length/pattern constraints, field aliases, `only`, struct defaults, enums, built-in and custom codecs), hexdocs links throughout, and "powered by Spectral" pointers in the module docs. The example app gained a `type_parameters` string-constraint demonstration with a test.

## [0.6.0] - 2026-06-14

### Added

- `:on_invalid_request` option on `use PhoenixSpectral.Controller` — a 2-arity function or `{module, function}` tuple, called with `(conn, [%Spectral.Error{}])` when request validation fails, returning a `Plug.Conn`. Lets applications render validation failures into their own error envelope and status code instead of the built-in `400`.

### Changed

- The default `400 Bad Request` body now enriches each `details` entry with a human-readable `message` (e.g. `"no_match at currency"`) and `got` (the offending request value, when available), alongside the existing `type` and `location`.

## [0.5.2] - 2026-06-12

### Added

- OpenAPI security schemes via two new `PhoenixSpectral.OpenAPIController` options: `:security_schemes` (a map of named Security Scheme Objects, emitted under `components.securitySchemes`) and `:security` (a list of Security Requirement Objects applied as the global default to every operation). Declaring `:security_schemes` is what makes Swagger UI render the **Authorize** button.

## [0.5.1] - 2026-06-09

### Added

- Support for Elixir 1.20.

## [0.5.0] - 2026-05-03

### Added

- Built-in codecs (`Spectral.Codec.Date`, `Spectral.Codec.DateTime`, `Spectral.Codec.MapSet`, `Spectral.Codec.String`) are now automatically registered at application startup. Explicit `config :spectra, :codecs, ...` configuration is no longer required for these codecs — though explicit config still takes precedence if present.

### Changed

- Bumped `spectral` requirement to `~> 0.12.0`. **Users with custom `Spectral.Codec` implementations must update their callbacks** to the new 6-argument signatures: the separate `params` argument has been removed — use `:spectra_type.parameters(target_type)` in your callback to read `type_parameters` instead. The `module` argument is renamed `caller_type_info` and `sp_type` is renamed `target_type`. See the [spectral 0.12.0 changelog](https://github.com/andreashasse/spectral) for details.

## [0.4.0] - 2026-04-18

### Added

- Documented and demonstrated support for struct defaults: JSON fields absent from a request body are filled from the struct's `defstruct` defaults. Fields whose default is `nil` are required on input only when their type does not allow `nil`.
- Documented and demonstrated field filtering via Spectral's `only:` option: fields outside the list are dropped on encode and filled from defaults on decode, making it straightforward to hide sensitive fields (e.g. `password_hash`) from responses.
- Example app tests migrated to Elixir `Phoenix.ConnTest` so the full request/response flow is exercised by `mix test` instead of external `curl` scripts.

### Changed

- Bumped `spectral` requirement to `~> 0.11.0`. **Users with custom `Spectral.Codec` implementations must update their callbacks** to the new arities (`encode/7`, `decode/7`, `schema/6` with the new `_config` parameter); see the updated example codec in `example/lib/example/types.ex`.

### Fixed

- Module docstrings now correctly state that PhoenixSpectral emits OpenAPI 3.1 (previously said 3.0).

## [0.3.3] - 2026-04-02

### Changed

- Bumped `spectral` requirement to `~> 0.9.2`, picking up spectra 0.9.3 which fixes codec `type_parameters` handling for string types.

### Fixed

- README `update` action example corrected to use the right argument names.

## [0.3.2] - 2026-04-01

### Added

- `OpenAPIController` now auto-detects the OpenAPI spec URL from the router, so `:openapi_url` no longer needs to be set explicitly in the common case. Set it explicitly only when serving the spec at a non-standard path.

### Changed

- Type info and action types are now resolved once per request dispatch instead of once per decode step, reducing redundant BEAM metadata lookups.

### Fixed

- Format check in CI pinned to Elixir 1.19 to avoid spurious failures from formatter behaviour differences between 1.18 and 1.19.

## [0.3.1] - 2026-03-25

### Changed

- Upgraded `spectral` dependency to `~> 0.9.0` (and `spectra` transitively). No API changes required in PhoenixSpectral itself.
- Example app `UserId` codec updated to the 6-argument `Spectral.Codec` callbacks introduced in spectral 0.9.0 (`_sp_type` inserted before `params` in `encode/6`, `decode/6`, and `schema/5`).

### Fixed

- Corrected stale `/4` arity references in controller error messages to `/5` (the correct arity since the `conn` argument was added in 0.3.0).

## [0.3.0] - 2026-03-23

### Added

- `conn` is now passed as the first argument to every controller action, giving direct access to `conn.assigns` (auth context from upstream plugs), `conn.remote_ip`, `conn.host`, `conn.method`, and other connection data.
- Actions may return a `Plug.Conn` directly instead of `{status, headers, body}`, enabling `send_file/3`, `send_chunked/2`, and other raw response mechanisms. Schema validation is intentionally bypassed in that case.

### Fixed

- Requests without a body (e.g. GET) no longer return 400 when the endpoint is configured with `Plug.Parsers` `pass: ["*/*"]`, which sets `body_params` to `%{}` rather than leaving it unfetched.

### Changed

- **Breaking:** Controller action signature changed from `(path_args, query_params, headers, body)` to `(conn, path_args, query_params, headers, body)`. All existing actions must add `conn` (or `_conn`) as the first argument and include `Plug.Conn.t()` in their `@spec`.

## [0.2.0] - 2026-03-22

### Added

- Query parameters are now passed as the second argument to controller actions. Declare them in the typespec as a map and they are extracted from `conn.query_params`, validated against the typespec, and decoded accordingly.
- OpenAPI spec generation emits query parameter fields as `in: query` parameters with correct required/optional annotations.

### Changed

- **Breaking:** Controller action arity changed from 3-arity `(path_args, headers, body)` to 4-arity `(path_args, query_params, headers, body)`. Existing actions must add a `query_params` argument and update their typespecs accordingly.

## [0.1.1] - 2026-03-22

### Changed

- README and CHANGELOG are now published to hexdocs.pm

## [0.1.0] - 2026-03-21

### Added

- OpenAPI 3.1 spec generation from Phoenix router and typed controllers
- Request decoding and validation via Spectral — invalid requests return `400` with structured error details
- Response encoding via Spectral — encoding failures return `500` and are logged
- Union return types (e.g. `{200, %{}, User.t()} | {404, %{}, Error.t()}`) produce multiple OpenAPI response entries
- Typed request and response headers: declare and validate headers in action typespecs
- Path parameter decoding from binary strings to typed values
- Parameter descriptions via named type aliases annotated with `spectral`
- `PhoenixSpectral.OpenAPIController` for serving the OpenAPI JSON spec and a Swagger UI page
- Optional caching of the generated spec via `:persistent_term`
- Support for remote types in OpenAPI schema generation
