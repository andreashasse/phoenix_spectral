defmodule PhoenixSpectral.WebhookTest do
  use ExUnit.Case

  import Plug.Test

  @metadata %{title: "Test API", version: "1.0.0"}

  defmodule TestWebhookOpenAPIController do
    use PhoenixSpectral.OpenAPIController,
      router: TestRouter,
      title: "Test API",
      version: "1.0.0",
      webhooks: [
        %{
          name: "userCreated",
          method: :post,
          module: TestUser,
          payload: {:type, :t, 0},
          responses: [{200, "Acknowledged"}]
        }
      ]
  end

  defp generate(webhooks) do
    {:ok, json} = PhoenixSpectral.generate_openapi(TestRouter, @metadata, webhooks: webhooks)
    Jason.decode!(json)
  end

  describe "generate_openapi/3 with :webhooks" do
    test "emits a webhook at the top level" do
      spec =
        generate([
          %{
            name: "userCreated",
            method: :post,
            module: TestUser,
            payload: {:type, :t, 0},
            responses: [{200, "Acknowledged"}],
            doc: %{summary: "Sent when a user is created"}
          }
        ])

      assert %{
               "webhooks" => %{
                 "userCreated" => %{
                   "post" => %{
                     "summary" => "Sent when a user is created",
                     "requestBody" => %{
                       "content" => %{"application/json" => %{"schema" => %{"$ref" => ref}}}
                     },
                     "responses" => %{"200" => %{"description" => "Acknowledged"}}
                   }
                 }
               }
             } = spec

      # t/0 components are named after the module, not the spectral title.
      assert ref == "#/components/schemas/TestUser"
    end

    test "a response can use a status code range" do
      spec =
        generate([
          %{
            name: "userCreated",
            method: :post,
            module: TestUser,
            payload: {:type, :t, 0},
            responses: [{"2XX", "Acknowledged"}]
          }
        ])

      assert %{"2XX" => %{"description" => "Acknowledged"}} =
               spec["webhooks"]["userCreated"]["post"]["responses"]
    end

    test "responses and doc are optional" do
      spec =
        generate([
          %{name: "userCreated", method: :post, module: TestUser, payload: {:type, :t, 0}}
        ])

      operation = spec["webhooks"]["userCreated"]["post"]

      assert Map.has_key?(operation, "requestBody")
      refute Map.has_key?(operation, "responses")
    end

    test "several methods can share one event name" do
      spec =
        generate([
          %{name: "userChanged", method: :post, module: TestUser, payload: {:type, :t, 0}},
          %{name: "userChanged", method: :delete, module: TestUser, payload: {:type, :t, 0}}
        ])

      assert ["delete", "post"] == spec["webhooks"]["userChanged"] |> Map.keys() |> Enum.sort()
    end

    test "the router's endpoints are still generated alongside webhooks" do
      spec =
        generate([
          %{name: "userCreated", method: :post, module: TestUser, payload: {:type, :t, 0}}
        ])

      assert Map.has_key?(spec["paths"], "/users/{id}")
    end

    test "omits the webhooks key when the list is empty" do
      refute Map.has_key?(generate([]), "webhooks")
    end

    test "crashes on a malformed webhook entry rather than emitting a broken spec" do
      assert_raise FunctionClauseError, fn ->
        generate([%{method: :post, module: TestUser, payload: {:type, :t, 0}}])
      end
    end

    test "raises on an unknown key in a webhook entry" do
      assert_raise ArgumentError, ~r/respones/, fn ->
        generate([
          %{
            name: "userCreated",
            method: :post,
            module: TestUser,
            payload: {:type, :t, 0},
            respones: [{200, "Acknowledged"}]
          }
        ])
      end
    end

    test "nil_fields: :null keeps the schema name of a payload type used nowhere else" do
      spec =
        generate([
          %{
            name: "paymentDone",
            method: :post,
            module: TestWebhookEvents,
            payload: {:type, :payment_done, 0},
            nil_fields: :null
          }
        ])

      assert %{"$ref" => "#/components/schemas/PaymentDone0"} =
               spec["webhooks"]["paymentDone"]["post"]["requestBody"]["content"][
                 "application/json"
               ]["schema"]

      assert %{
               "required" => required,
               "properties" => %{"note" => %{"type" => ["string", "null"]}}
             } = spec["components"]["schemas"]["PaymentDone0"]

      assert Enum.sort(required) == ["id", "note"]
      refute Map.has_key?(spec["components"]["schemas"], "PaymentDone0Nullable")
    end

    test "nil_fields: :null gives a payload type the router also uses its own schema" do
      spec =
        generate([
          %{
            name: "userCreated",
            method: :post,
            module: TestUser,
            payload: {:type, :t, 0},
            nil_fields: :null
          }
        ])

      schemas = spec["components"]["schemas"]

      assert %{"$ref" => "#/components/schemas/TestUserNullable"} =
               spec["webhooks"]["userCreated"]["post"]["requestBody"]["content"][
                 "application/json"
               ]["schema"]

      assert Enum.sort(schemas["TestUserNullable"]["required"]) == ["email", "id", "name"]
      refute Map.has_key?(schemas["TestUser"], "required")
    end

    test "nil_fields: :null on a payload alias names the schema after the alias" do
      spec =
        generate([
          %{
            name: "userCreated",
            method: :post,
            module: TestWebhookEvents,
            payload: {:type, :user_created, 0},
            nil_fields: :null
          }
        ])

      assert %{"$ref" => "#/components/schemas/UserCreated0"} =
               spec["webhooks"]["userCreated"]["post"]["requestBody"]["content"][
                 "application/json"
               ]["schema"]

      schemas = spec["components"]["schemas"]
      assert Enum.sort(schemas["UserCreated0"]["required"]) == ["email", "id", "name"]
      refute Map.has_key?(schemas, "TestUserNullable")
    end

    test "raises on a nil_fields value other than :null" do
      assert_raise ArgumentError, ~r/must be null, got: omit/, fn ->
        generate([
          %{
            name: "userCreated",
            method: :post,
            module: TestUser,
            payload: {:type, :t, 0},
            nil_fields: :omit
          }
        ])
      end
    end

    test "coexists with encode options, in either order" do
      webhooks = [
        %{name: "userCreated", method: :post, module: TestUser, payload: {:type, :t, 0}}
      ]

      for opts <- [[:pre_encoded, webhooks: webhooks], [{:webhooks, webhooks}, :pre_encoded]] do
        {:ok, spec} = PhoenixSpectral.generate_openapi(TestRouter, @metadata, opts)

        assert is_map(spec)
        assert Map.has_key?(spec, "webhooks")
      end
    end

    test "raises on an unrecognized option instead of silently dropping it" do
      assert_raise ArgumentError, ~r/webhook/, fn ->
        PhoenixSpectral.generate_openapi(TestRouter, @metadata,
          webhook: [
            %{name: "userCreated", method: :post, module: TestUser, payload: {:type, :t, 0}}
          ]
        )
      end
    end

    test "still accepts a bare encode-option list" do
      {:ok, spec} = PhoenixSpectral.generate_openapi(TestRouter, @metadata, [:pre_encoded])

      assert is_map(spec)
      refute Map.has_key?(spec, "webhooks")
    end
  end

  describe "webhook :headers" do
    defp headers_webhook(headers) do
      %{
        name: "userCreated",
        method: :post,
        module: TestWebhookEvents,
        payload: {:type, :user_created, 0},
        headers: headers
      }
    end

    test "each map field becomes a header parameter, required when the key is required" do
      spec = generate([headers_webhook({:type, :webhook_headers, 0})])

      parameters = spec["webhooks"]["userCreated"]["post"]["parameters"]

      assert Enum.sort_by(parameters, & &1["name"]) == [
               %{
                 "name" => "x-event-id",
                 "in" => "header",
                 "required" => false,
                 "schema" => %{"type" => "integer", "minimum" => 0}
               },
               %{
                 "name" => "x-signature",
                 "in" => "header",
                 "required" => true,
                 "schema" => %{"type" => "string"}
               }
             ]
    end

    test "an entry without :headers has no parameters" do
      spec =
        generate([
          %{
            name: "userCreated",
            method: :post,
            module: TestWebhookEvents,
            payload: {:type, :user_created, 0}
          }
        ])

      refute Map.has_key?(spec["webhooks"]["userCreated"]["post"], "parameters")
    end

    test "a :headers type aliased from another module resolves that module's local types" do
      spec = generate([headers_webhook({:type, :shared_headers, 0})])

      parameters = spec["webhooks"]["userCreated"]["post"]["parameters"]

      assert Enum.sort_by(parameters, & &1["name"]) == [
               %{
                 "name" => "x-count",
                 "in" => "header",
                 "required" => false,
                 "schema" => %{"type" => "integer", "minimum" => 1}
               },
               %{
                 "name" => "x-signature",
                 "in" => "header",
                 "required" => true,
                 "schema" => %{"type" => "string"}
               }
             ]
    end

    test "crashes when the :headers type is not a map type" do
      assert_raise FunctionClauseError, fn ->
        generate([headers_webhook({:type, :not_a_map, 0})])
      end
    end

    test "names the module and type when the :headers type does not exist" do
      assert_raise ArgumentError, ~r/:no_such_type\/0 not found in TestWebhookEvents/, fn ->
        generate([headers_webhook({:type, :no_such_type, 0})])
      end
    end

    test "names the module and type when the :payload type does not exist" do
      assert_raise ArgumentError, ~r/:no_such_type\/0 not found in TestUser/, fn ->
        generate([
          %{
            name: "userCreated",
            method: :post,
            module: TestUser,
            payload: {:type, :no_such_type, 0}
          }
        ])
      end
    end
  end

  describe "per-webhook security" do
    @security_metadata %{
      title: "Test API",
      version: "1.0.0",
      security_schemes: %{
        "bearer_auth" => %{type: "http", scheme: "bearer"},
        "webhook_signature" => %{type: "apiKey", in: "header", name: "x-signature"}
      },
      security: [%{"bearer_auth" => []}]
    }

    defp generate_with_security(webhooks) do
      {:ok, json} =
        PhoenixSpectral.generate_openapi(TestRouter, @security_metadata, webhooks: webhooks)

      Jason.decode!(json)
    end

    test "a webhook declares its own auth while the API keeps the global default" do
      spec =
        generate_with_security([
          %{
            name: "userCreated",
            method: :post,
            module: TestUser,
            payload: {:type, :t, 0},
            doc: %{security: [%{"webhook_signature" => []}]}
          }
        ])

      assert spec["security"] == [%{"bearer_auth" => []}]

      assert spec["webhooks"]["userCreated"]["post"]["security"] == [
               %{"webhook_signature" => []}
             ]
    end

    test "an empty list opts a webhook out of the global requirement" do
      spec =
        generate_with_security([
          %{
            name: "userCreated",
            method: :post,
            module: TestUser,
            payload: {:type, :t, 0},
            doc: %{security: []}
          }
        ])

      assert spec["webhooks"]["userCreated"]["post"]["security"] == []
    end

    test "a webhook without its own security inherits the global default" do
      spec =
        generate_with_security([
          %{name: "userCreated", method: :post, module: TestUser, payload: {:type, :t, 0}}
        ])

      refute Map.has_key?(spec["webhooks"]["userCreated"]["post"], "security")
      assert spec["security"] == [%{"bearer_auth" => []}]
    end
  end

  describe "OpenAPIController :webhooks option" do
    test "serves webhooks declared on the controller" do
      conn = TestWebhookOpenAPIController.show(conn(:get, "/openapi"), %{})

      assert conn.status == 200

      assert %{
               "webhooks" => %{
                 "userCreated" => %{
                   "post" => %{
                     "responses" => %{"200" => %{"description" => "Acknowledged"}}
                   }
                 }
               }
             } = Jason.decode!(conn.resp_body)
    end
  end
end
