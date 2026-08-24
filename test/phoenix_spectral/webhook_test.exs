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

    test "webhook payload types land in components/schemas" do
      spec =
        generate([
          %{name: "userCreated", method: :post, module: TestUser, payload: {:type, :t, 0}}
        ])

      assert Map.has_key?(spec["components"]["schemas"], "TestUser")
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

      assert map_size(spec["paths"]) > 0
    end

    test "omits the webhooks key when the list is empty" do
      refute Map.has_key?(generate([]), "webhooks")
    end

    test "crashes on a malformed webhook entry rather than emitting a broken spec" do
      assert_raise FunctionClauseError, fn ->
        generate([%{method: :post, module: TestUser, payload: {:type, :t, 0}}])
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
      # spectra reads options with proplists:get_value/3, which ignores unknown
      # keys - so a typo would silently drop every webhook without this check.
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
