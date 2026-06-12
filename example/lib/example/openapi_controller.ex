defmodule Example.OpenAPIController do
  use PhoenixSpectral.OpenAPIController,
    router: Example.Router,
    title: "Example API",
    version: "1.0.0",
    summary: "A simple user management API",
    description:
      "Demonstrates PhoenixSpectral with full OpenAPI 3.0 spec generation from typespecs.",
    terms_of_service: "https://example.com/terms",
    contact: %{
      name: "Example Support",
      url: "https://example.com/support",
      email: "support@example.com"
    },
    license: %{name: "MIT", url: "https://opensource.org/licenses/MIT"},
    servers: [
      %{url: "http://localhost:4000", description: "Local development"},
      %{url: "https://api.example.com", description: "Production"}
    ],
    security_schemes: %{
      "api_key" => %{
        type: "apiKey",
        in: "header",
        name: "x-api-key",
        description: "API key required for write endpoints. Click Authorize to set it."
      },
      "bearer_auth" => %{
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT",
        description:
          "Bearer token required for write endpoints. Paste only the token — " <>
            "Swagger UI adds the \"Bearer \" prefix when it sends the Authorization header."
      }
    },
    # A single requirement object listing both schemes means *both* are required,
    # matching the write endpoints (Bearer via Example.BearerAuth + x-api-key via
    # the controller typespec). NOTE: only global security is supported today, so this
    # applies to every operation including the open reads — per-endpoint security is a
    # future enhancement.
    security: [%{"api_key" => [], "bearer_auth" => []}]
end
