import Config

config :example, Example.Endpoint,
  secret_key_base: String.duplicate("a", 64),
  adapter: Bandit.PhoenixAdapter,
  server: false,
  render_errors: [formats: [json: Example.ErrorJSON], root_layout: false]
