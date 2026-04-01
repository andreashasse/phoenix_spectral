# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PhoenixSpectral integrates Spectral (Elixir type-driven validation/OpenAPI generation) with Phoenix. Controller typespecs become the single source of truth for OpenAPI docs and request/response validation. Analogous to how `elli_openapi` integrates `spectra` with Elli.

## Commands

```bash
mix compile          # Build
mix test             # Run all tests
mix test test/phoenix_spectral_test.exs           # Run specific test file
mix test test/phoenix_spectral_test.exs:92        # Run specific test by line
mix format            # Format code
mix format --check-formatted  # Check formatting
make ci               # Full CI: compile, test, credo, dialyzer, format check
```

Run `make ci` before every commit and when done with a task.

## Architecture

Two modules form the core:

### `PhoenixSpectral` (lib/phoenix_spectral.ex) — OpenAPI generation
Takes a Phoenix router + metadata, produces an OpenAPI spec. Pipeline:
1. `Phoenix.Router.routes(router)` → list of `%{verb, path, plug, plug_opts}`
2. Filter to controllers with `__spectra_type_info__/0` (i.e., those using Spectral)
3. For each route, extract the function spec from the controller's type info
4. Parse return types (single tuple or union) into response specs
5. Build endpoints via `Spectral.OpenAPI` builder API
6. `Spectral.OpenAPI.endpoints_to_openapi/2` produces the final spec

### `PhoenixSpectral.Controller` (lib/phoenix_spectral/controller.ex) — Runtime plug
`use PhoenixSpectral.Controller` implies `use Phoenix.Controller` + `use Spectral`. Overrides `action/2` to:
- Call handlers as `action(conn, path_args, query_params, headers, body)` instead of Phoenix's `action(conn, params)`
- Encode struct response bodies via `Spectral.encode`
- Return 400 on validation failure, raise on non-struct response bodies

## Key Conventions

- **Crash on bad code, error on bad user input.** Never silently swallow unexpected inputs with defensive catch-all clauses that return defaults or empty results. If a controller has a malformed typespec, let it crash with a clear match error rather than generating a broken spec. Only return `{:error, ...}` tuples for expected failures from user input.
- Controller actions use `(conn, path_args, query_params, headers, body)` and return `{status_code, headers, body}`
- Use `conn` only for out-of-band context (`conn.assigns`, `conn.remote_ip`, etc.). Do not read `conn.path_params`, `conn.query_params`, `conn.req_headers`, or `conn.body_params` — use the decoded and validated arguments instead.
- Union return types (e.g., `{200, map(), User.t()} | {404, map(), Error.t()}`) produce multiple OpenAPI response entries
- Response bodies must be Spectral-typed structs (not plain maps)
- `Code.ensure_loaded/1` must be called before `function_exported?/3` checks on controller modules

## Working with Spectra Types

Use `Spectral.TypeInfo` to access type info — never destructure the `type_info` record tuple directly:
```elixir
type_info = controller.__spectra_type_info__()
{:ok, func_specs} = Spectral.TypeInfo.find_function(type_info, :action_name, 5)
```

Individual sp_type records are defined via `Record.defrecordp` in `PhoenixSpectral` (sourced from `deps/spectra/include/spectra_internal.hrl`). Use record syntax for pattern matching:
```elixir
sp_union(types: types)                          # not {:sp_union, types, _meta}
sp_tuple(fields: [status, headers, body])       # not {:sp_tuple, [...], _meta}
sp_literal(value: 200)                          # not {:sp_literal, 200, _, _}
sp_user_type_ref(type_name: name)               # not {:sp_user_type_ref, name, _, _}
sp_simple_type(type: :binary)                   # construction and matching
```

All records use `Record.extract` from the `.hrl` file directly.

## Test Support

Test support modules live in `test/support/` and are compiled via `elixirc_paths(:test)` in mix.exs. They must be separate files (not inline in test files) because `__spectra_type_info__/0` requires beam files on disk.
