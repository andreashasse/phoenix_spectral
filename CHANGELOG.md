# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
