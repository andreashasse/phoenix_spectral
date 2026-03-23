defmodule PhoenixSpectralTest do
  use ExUnit.Case

  defp generate_spec do
    {:ok, json} =
      PhoenixSpectral.generate_openapi(TestRouter, %{title: "Test API", version: "1.0.0"})

    Jason.decode!(json)
  end

  defp generate_header_spec do
    {:ok, json} =
      PhoenixSpectral.generate_openapi(TestHeaderRouter, %{title: "Test API", version: "1.0.0"})

    Jason.decode!(json)
  end

  defp generate_query_spec do
    {:ok, json} =
      PhoenixSpectral.generate_openapi(TestQueryRouter, %{title: "Test API", version: "1.0.0"})

    Jason.decode!(json)
  end

  describe "generate_openapi/2" do
    test "generates a valid OpenAPI spec" do
      spec = generate_spec()
      assert spec["info"]["title"] == "Test API"
      assert spec["info"]["version"] == "1.0.0"
    end

    test "contains correct paths with OpenAPI format params" do
      spec = generate_spec()
      assert Map.has_key?(spec["paths"], "/users")
      assert Map.has_key?(spec["paths"], "/users/{id}")
      refute Map.has_key?(spec["paths"], "/users/:id")
    end

    test "contains correct HTTP methods" do
      spec = generate_spec()

      assert Map.has_key?(spec["paths"]["/users"], "get")
      assert Map.has_key?(spec["paths"]["/users"], "post")

      assert Map.has_key?(spec["paths"]["/users/{id}"], "get")
      assert Map.has_key?(spec["paths"]["/users/{id}"], "put")
      assert Map.has_key?(spec["paths"]["/users/{id}"], "delete")
    end

    test "spectral annotations on actions appear as summary and description in spec" do
      spec = generate_spec()
      show_op = spec["paths"]["/users/{id}"]["get"]
      assert show_op["summary"] == "Get user"
      assert show_op["description"] == "Returns a user by ID"
    end

    test "actions without spectral annotations have no summary in spec" do
      spec = generate_spec()
      index_op = spec["paths"]["/users"]["get"]
      refute Map.has_key?(index_op, "summary")
    end

    test "union return types produce multiple response entries" do
      spec = generate_spec()

      # show action has {200, ...} | {404, ...} return type
      show_responses = spec["paths"]["/users/{id}"]["get"]["responses"]
      assert Map.has_key?(show_responses, "200")
      assert Map.has_key?(show_responses, "404")
    end

    test "single return type produces single response entry" do
      spec = generate_spec()

      # delete action has {204, ...} return type
      delete_responses = spec["paths"]["/users/{id}"]["delete"]["responses"]
      assert Map.has_key?(delete_responses, "204")
      assert map_size(delete_responses) == 1
    end

    test "required header appears as required header parameter in spec" do
      spec = generate_header_spec()

      params = spec["paths"]["/items/{id}"]["get"]["parameters"]
      header_param = Enum.find(params, &(&1["in"] == "header" && &1["name"] == "x-user-id"))
      assert header_param != nil
      assert header_param["required"] == true
    end

    test "optional header appears as non-required header parameter in spec" do
      spec = generate_header_spec()

      params = spec["paths"]["/items"]["get"]["parameters"]
      header_param = Enum.find(params, &(&1["in"] == "header" && &1["name"] == "x-trace-id"))
      assert header_param != nil
      assert header_param["required"] == false
    end

    test "required response header appears in response spec" do
      spec = generate_header_spec()

      headers = spec["paths"]["/items/count"]["get"]["responses"]["200"]["headers"]
      assert headers != nil
      assert Map.has_key?(headers, "x-count")
      assert headers["x-count"]["required"] == true
    end

    test "response with no declared headers has no headers in spec" do
      spec = generate_header_spec()

      response = spec["paths"]["/items/{id}"]["get"]["responses"]["200"]
      assert response["headers"] == nil or response["headers"] == %{}
    end

    test "path parameter using a typed alias with spectral description gets description in spec" do
      spec = generate_spec()

      params = spec["paths"]["/users/{id}"]["get"]["parameters"]
      id_param = Enum.find(params, &(&1["name"] == "id"))
      assert id_param["description"] == "The user's unique identifier"
    end

    test "header parameter from a remote type appears in spec" do
      spec = generate_header_spec()

      params = spec["paths"]["/items/ping"]["get"]["parameters"]
      header_param = Enum.find(params, &(&1["name"] == "x-request-id"))
      assert header_param != nil
      assert header_param["required"] == true
      assert header_param["in"] == "header"
    end

    test "path parameter with plain type has no description in spec" do
      spec = generate_spec()

      # update uses %{id: String.t()} directly, not a named type
      params = spec["paths"]["/users/{id}"]["put"]["parameters"]
      id_param = Enum.find(params, &(&1["name"] == "id"))
      refute Map.has_key?(id_param, "description")
    end
  end

  describe "generate_openapi/3 with pre_encoded option and rich metadata" do
    test "summary is included in info" do
      {:ok, spec} =
        PhoenixSpectral.generate_openapi(
          TestRouter,
          %{
            title: "Test API",
            version: "1.0.0",
            summary: "A short summary"
          },
          [:pre_encoded]
        )

      assert spec["info"]["summary"] == "A short summary"
    end

    test "description is included in info" do
      {:ok, spec} =
        PhoenixSpectral.generate_openapi(
          TestRouter,
          %{
            title: "Test API",
            version: "1.0.0",
            description: "A longer description"
          },
          [:pre_encoded]
        )

      assert spec["info"]["description"] == "A longer description"
    end

    test "terms_of_service is included in info" do
      {:ok, spec} =
        PhoenixSpectral.generate_openapi(
          TestRouter,
          %{
            title: "Test API",
            version: "1.0.0",
            terms_of_service: "https://example.com/terms"
          },
          [:pre_encoded]
        )

      assert spec["info"]["termsOfService"] == "https://example.com/terms"
    end

    test "contact is included in info" do
      {:ok, spec} =
        PhoenixSpectral.generate_openapi(
          TestRouter,
          %{
            title: "Test API",
            version: "1.0.0",
            contact: %{name: "Support", url: "https://example.com", email: "support@example.com"}
          },
          [:pre_encoded]
        )

      assert spec["info"]["contact"]["name"] == "Support"
      assert spec["info"]["contact"]["email"] == "support@example.com"
    end

    test "license is included in info" do
      {:ok, spec} =
        PhoenixSpectral.generate_openapi(
          TestRouter,
          %{
            title: "Test API",
            version: "1.0.0",
            license: %{name: "MIT", url: "https://opensource.org/licenses/MIT"}
          },
          [:pre_encoded]
        )

      assert spec["info"]["license"]["name"] == "MIT"
    end

    test "servers list is included at top level" do
      {:ok, spec} =
        PhoenixSpectral.generate_openapi(
          TestRouter,
          %{
            title: "Test API",
            version: "1.0.0",
            servers: [
              %{url: "https://api.example.com", description: "Production"},
              %{url: "http://localhost:4000", description: "Local"}
            ]
          },
          [:pre_encoded]
        )

      assert length(spec["servers"]) == 2
      assert hd(spec["servers"])["url"] == "https://api.example.com"
      assert hd(spec["servers"])["description"] == "Production"
    end

    test "minimal metadata without optional fields produces no extra info keys" do
      {:ok, spec} =
        PhoenixSpectral.generate_openapi(TestRouter, %{title: "Test API", version: "1.0.0"}, [
          :pre_encoded
        ])

      refute Map.has_key?(spec["info"], "summary")
      refute Map.has_key?(spec["info"], "description")
      refute Map.has_key?(spec, "servers")
    end
  end

  describe "generate_openapi/2 with conn actions" do
    defp generate_conn_spec do
      {:ok, json} =
        PhoenixSpectral.generate_openapi(TestConnRouter, %{title: "Test API", version: "1.0.0"})

      Jason.decode!(json)
    end

    test "generates paths for conn actions" do
      spec = generate_conn_spec()
      assert Map.has_key?(spec["paths"], "/users/{id}")
      assert Map.has_key?(spec["paths"], "/download")
    end

    test "path parameters are extracted from the typed args (skipping conn)" do
      spec = generate_conn_spec()
      params = spec["paths"]["/users/{id}"]["get"]["parameters"]
      id_param = Enum.find(params, &(&1["in"] == "path" && &1["name"] == "id"))
      assert id_param != nil
      assert id_param["required"] == true
    end

    test "response schema is extracted from the typed return (skipping conn)" do
      spec = generate_conn_spec()
      responses = spec["paths"]["/users/{id}"]["get"]["responses"]
      assert Map.has_key?(responses, "200")
    end
  end

  describe "generate_openapi/2 with query parameters" do
    test "required query param appears as required in:query parameter" do
      spec = generate_query_spec()

      params = spec["paths"]["/users/search"]["get"]["parameters"]
      q_param = Enum.find(params, &(&1["in"] == "query" && &1["name"] == "q"))
      assert q_param != nil
      assert q_param["required"] == true
    end

    test "optional query params appear as non-required in:query parameters" do
      spec = generate_query_spec()

      params = spec["paths"]["/users"]["get"]["parameters"]
      page_param = Enum.find(params, &(&1["in"] == "query" && &1["name"] == "page"))
      per_page_param = Enum.find(params, &(&1["in"] == "query" && &1["name"] == "per_page"))
      assert page_param != nil
      assert page_param["required"] == false
      assert per_page_param != nil
      assert per_page_param["required"] == false
    end

    test "query param with spectral description gets description in spec" do
      spec = generate_query_spec()

      params = spec["paths"]["/users/search"]["get"]["parameters"]
      q_param = Enum.find(params, &(&1["in"] == "query" && &1["name"] == "q"))
      assert q_param["description"] == "Search query string"
    end

    test "query param with plain type has no description in spec" do
      spec = generate_query_spec()

      params = spec["paths"]["/users"]["get"]["parameters"]
      page_param = Enum.find(params, &(&1["in"] == "query" && &1["name"] == "page"))
      refute Map.has_key?(page_param, "description")
    end

    test "action with no query params has no in:query parameters" do
      spec = generate_spec()

      # index action on TestUserController uses %{} for query params
      params = spec["paths"]["/users"]["get"]["parameters"] || []
      query_params = Enum.filter(params, &(&1["in"] == "query"))
      assert query_params == []
    end
  end
end
