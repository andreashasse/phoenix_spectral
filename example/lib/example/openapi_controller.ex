defmodule Example.OpenAPIController do
  use PhoenixSpectral.OpenAPIController,
    router: Example.Router,
    title: "Example API",
    version: "1.0.0",
    summary: "A simple user management API",
    description: "Demonstrates PhoenixSpectral with full OpenAPI 3.0 spec generation from typespecs.",
    terms_of_service: "https://example.com/terms",
    contact: %{name: "Example Support", url: "https://example.com/support", email: "support@example.com"},
    license: %{name: "MIT", url: "https://opensource.org/licenses/MIT"},
    servers: [
      %{url: "http://localhost:4000", description: "Local development"},
      %{url: "https://api.example.com", description: "Production"}
    ]
end
