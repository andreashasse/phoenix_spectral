defmodule PhoenixSpectral.OpenAPIControllerTest do
  use ExUnit.Case

  import Plug.Test

  defmodule TestOpenAPIController do
    use PhoenixSpectral.OpenAPIController,
      router: TestRouter,
      title: "Test API",
      version: "1.0.0"
  end

  defmodule TestOpenAPIControllerCustomUrl do
    use PhoenixSpectral.OpenAPIController,
      router: TestRouter,
      title: "Test API",
      version: "1.0.0",
      openapi_url: "/api/openapi"
  end

  defmodule TestOpenAPIControllerCached do
    use PhoenixSpectral.OpenAPIController,
      router: TestRouter,
      title: "Test API",
      version: "1.0.0",
      cache: true
  end

  defmodule TestOpenAPIControllerRichMetadata do
    use PhoenixSpectral.OpenAPIController,
      router: TestRouter,
      title: "Rich API",
      version: "2.0.0",
      summary: "A short summary",
      description: "A longer description",
      terms_of_service: "https://example.com/terms",
      contact: %{name: "Support", url: "https://example.com", email: "support@example.com"},
      license: %{name: "MIT", url: "https://opensource.org/licenses/MIT"},
      servers: [
        %{url: "https://api.example.com", description: "Production"},
        %{url: "http://localhost:4000", description: "Local"}
      ]
  end

  describe "show/2" do
    test "returns 200 with application/json content type" do
      conn = conn(:get, "/openapi") |> TestOpenAPIController.show(%{})

      assert conn.status == 200
      assert {"content-type", "application/json; charset=utf-8"} in conn.resp_headers
    end

    test "response body contains the configured title and version" do
      conn = conn(:get, "/openapi") |> TestOpenAPIController.show(%{})

      body = Jason.decode!(conn.resp_body)
      assert body["info"]["title"] == "Test API"
      assert body["info"]["version"] == "1.0.0"
    end

    test "response body includes routes from the configured router" do
      conn = conn(:get, "/openapi") |> TestOpenAPIController.show(%{})

      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body["paths"], "/users")
    end
  end

  describe "show/2 with cache: true" do
    @cache_key {PhoenixSpectral.OpenAPIController, TestOpenAPIControllerCached}

    setup do
      on_exit(fn -> :persistent_term.erase(@cache_key) end)
      :ok
    end

    test "populates persistent_term on first call" do
      assert :persistent_term.get(@cache_key, nil) == nil

      conn(:get, "/openapi") |> TestOpenAPIControllerCached.show(%{})

      assert :persistent_term.get(@cache_key, nil) != nil
    end

    test "stores the encoded JSON that matches the response body" do
      conn = conn(:get, "/openapi") |> TestOpenAPIControllerCached.show(%{})

      assert :persistent_term.get(@cache_key) == conn.resp_body
    end

    test "returns the cached JSON on subsequent calls" do
      conn(:get, "/openapi") |> TestOpenAPIControllerCached.show(%{})
      cached = :persistent_term.get(@cache_key)

      conn = conn(:get, "/openapi") |> TestOpenAPIControllerCached.show(%{})

      assert conn.resp_body == cached
    end

    test "cached response is a valid OpenAPI spec" do
      conn(:get, "/openapi") |> TestOpenAPIControllerCached.show(%{})

      body = Jason.decode!(:persistent_term.get(@cache_key))
      assert body["info"]["title"] == "Test API"
    end
  end

  describe "show/2 with cache: false (default)" do
    @no_cache_key {PhoenixSpectral.OpenAPIController, TestOpenAPIController}

    test "does not populate persistent_term" do
      conn(:get, "/openapi") |> TestOpenAPIController.show(%{})

      assert :persistent_term.get(@no_cache_key, nil) == nil
    end
  end

  describe "show/2 with rich metadata" do
    test "summary is included in info" do
      conn = conn(:get, "/openapi") |> TestOpenAPIControllerRichMetadata.show(%{})

      body = Jason.decode!(conn.resp_body)
      assert body["info"]["summary"] == "A short summary"
    end

    test "description is included in info" do
      conn = conn(:get, "/openapi") |> TestOpenAPIControllerRichMetadata.show(%{})

      body = Jason.decode!(conn.resp_body)
      assert body["info"]["description"] == "A longer description"
    end

    test "terms_of_service is included in info" do
      conn = conn(:get, "/openapi") |> TestOpenAPIControllerRichMetadata.show(%{})

      body = Jason.decode!(conn.resp_body)
      assert body["info"]["termsOfService"] == "https://example.com/terms"
    end

    test "contact is included in info" do
      conn = conn(:get, "/openapi") |> TestOpenAPIControllerRichMetadata.show(%{})

      body = Jason.decode!(conn.resp_body)
      assert body["info"]["contact"]["name"] == "Support"
      assert body["info"]["contact"]["email"] == "support@example.com"
    end

    test "license is included in info" do
      conn = conn(:get, "/openapi") |> TestOpenAPIControllerRichMetadata.show(%{})

      body = Jason.decode!(conn.resp_body)
      assert body["info"]["license"]["name"] == "MIT"
    end

    test "servers list is included at top level" do
      conn = conn(:get, "/openapi") |> TestOpenAPIControllerRichMetadata.show(%{})

      body = Jason.decode!(conn.resp_body)
      assert length(body["servers"]) == 2
      assert hd(body["servers"])["url"] == "https://api.example.com"
    end

    test "minimal metadata produces no extra info keys" do
      conn = conn(:get, "/openapi") |> TestOpenAPIController.show(%{})

      body = Jason.decode!(conn.resp_body)
      refute Map.has_key?(body["info"], "summary")
      refute Map.has_key?(body["info"], "description")
      refute Map.has_key?(body, "servers")
    end
  end

  describe "swagger/2" do
    test "returns 200 with text/html content type" do
      conn = conn(:get, "/swagger") |> TestOpenAPIController.swagger(%{})

      assert conn.status == 200
      assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    end

    test "falls back to /openapi when the controller has no :show route in the router" do
      conn = conn(:get, "/swagger") |> TestOpenAPIController.swagger(%{})

      assert conn.resp_body =~ ~s(url: "/openapi")
    end

    test "auto-detects the openapi_url from the router's :show route" do
      conn = conn(:get, "/swagger") |> TestOpenAPIRouterController.swagger(%{})

      assert conn.resp_body =~ ~s(url: "/openapi")
    end

    test "auto-detected url includes scope prefix" do
      conn = conn(:get, "/swagger") |> TestScopedOpenAPIRouterController.swagger(%{})

      assert conn.resp_body =~ ~s(url: "/api/openapi")
    end

    test "explicit openapi_url overrides auto-detection" do
      conn = conn(:get, "/swagger") |> TestOpenAPIControllerCustomUrl.swagger(%{})

      assert conn.resp_body =~ ~s(url: "/api/openapi")
    end
  end
end
