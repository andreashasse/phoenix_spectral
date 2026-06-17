# AGENTS.md

Guidance for AI agents building or modifying APIs with **PhoenixSpectral**. (Human contributors: see [CLAUDE.md](CLAUDE.md) for repo workflow.)

## The one thing to internalize

PhoenixSpectral is a **thin Phoenix adapter over [Spectral](https://hexdocs.pm/spectral)**. It adds almost no validation or schema features of its own — it reads your controller `@spec`s and delegates decoding, validation, encoding, and JSON-schema generation to Spectral.

**Consequence:** if you only read PhoenixSpectral's docs, you will write more controller code than you need and miss validation that Spectral does declaratively. Before hand-rolling anything, read the [Spectral docs](https://hexdocs.pm/spectral) — the request/response shaping power lives there, configured on your *types* with the `spectral/1` macro.

## Reach for a Spectral type feature before writing controller code

When you're about to do any of these in an action, stop — Spectral does it on the type instead:

| You're tempted to… | Use instead (on the type) | Spectral docs |
|---|---|---|
| Check a string's length / format in the controller | `spectral type_parameters: %{min_length:, max_length:, pattern:, format:}` on a `String.t()` type | [String constraints](https://hexdocs.pm/spectral/readme.html#string-and-binary-constraints) |
| Read `conn.body_params` / `conn.query_params` and validate by hand | the typed `body` / `query_params` arguments — already decoded and validated against the `@spec` | README "Step 2" |
| Map `camelCase` JSON to `snake_case` fields manually | `spectral field_aliases: %{first_name: "firstName"}` | [Field Aliases](https://hexdocs.pm/spectral/readme.html#field-aliases) |
| Strip secret fields (`password_hash`) before responding | `spectral only: [:id, :name, ...]` | [`only`](https://hexdocs.pm/spectral/readme.html#field-filtering-with-only) |
| Make a body field optional / give it a default | struct `defstruct` default + a nullable type | [Struct defaults](https://hexdocs.pm/spectral/readme.html#struct-defaults) |
| Parse an enum from a path/query param | an atom-union type (`:: :a \| :b`) | [Data Serialization API](https://hexdocs.pm/spectral/readme.html#data-serialization-api) |
| Format `DateTime`/`Date`/`MapSet` | the built-in codecs (automatic) | [Built-in Codecs](https://hexdocs.pm/spectral/readme.html#built-in-codecs) |
| Encode/decode a domain type (prefixed IDs, money) | a custom codec via `use Spectral.Codec` | [Custom Codecs](https://hexdocs.pm/spectral/readme.html#custom-codecs) |

Anything you declare on the type also flows automatically into the generated OpenAPI 3.1 spec — you do not write schema separately.

## Conventions specific to PhoenixSpectral

- Actions take `(conn, path_args, query_params, headers, body)` and return `{status, headers, body}` (or a `Plug.Conn` for streaming/raw responses).
- Use `conn` only for out-of-band context (`conn.assigns`, `conn.remote_ip`). Do **not** read `conn.path_params`, `conn.query_params`, `conn.req_headers`, or `conn.body_params`.
- Response bodies must be Spectral-typed structs, not plain maps.
- Union return types (e.g. `{200, %{}, User.t()} | {404, %{}, Error.t()}`) produce multiple OpenAPI responses.
- See the runnable [`example/`](example/) app for working uses of `only`, a custom codec, optional fields, examples, and `type_parameters` string constraints.

## If you maintain a downstream project

A dependency's `AGENTS.md` is **not** auto-read by an agent working in your repo. If you want agents in *your* project to use Spectral's full feature set, copy the table above (or a link to it) into your own project's `AGENTS.md` / `CLAUDE.md`.
