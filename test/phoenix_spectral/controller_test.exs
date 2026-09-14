defmodule PhoenixSpectral.ControllerTest do
  use ExUnit.Case

  import Plug.Test

  defp call(controller, action, method, path, body_params, path_params, query_params, req_headers) do
    conn(method, path, body_params)
    |> Map.put(:path_params, path_params)
    |> Map.put(:query_params, query_params)
    |> Map.put(:req_headers, req_headers)
    |> Phoenix.Controller.put_format("json")
    |> Plug.Conn.put_private(:phoenix_action, action)
    |> controller.action([])
  end

  defp dispatch(
         method,
         path,
         body_params,
         path_params \\ %{},
         query_params \\ %{},
         req_headers \\ []
       ) do
    call(
      TestUserController,
      action_from_path(method, path),
      method,
      path,
      body_params,
      path_params,
      query_params,
      req_headers
    )
  end

  defp dispatch_header(action, path_params, req_headers) do
    call(TestHeaderController, action, :get, "/", nil, path_params, %{}, req_headers)
  end

  defp action_from_path(:post, "/users"), do: :create
  defp action_from_path(:put, "/users/:id"), do: :update

  describe "PhoenixSpectral.Controller with invalid request body" do
    test "returns 400 when a required field (name) is absent from the body" do
      conn = dispatch(:post, "/users", %{})

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Bad Request"
      assert [%{"type" => "type_mismatch", "location" => []}] = body["details"]
    end

    test "returns 400 when a required field is absent but other fields are present" do
      conn = dispatch(:post, "/users", %{"email" => "bob@example.com"})

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Bad Request"
      assert [%{"type" => "missing_data", "location" => ["name"]}] = body["details"]
    end

    test "returns 400 with field-level detail when a field has the wrong type" do
      conn = dispatch(:post, "/users", %{"name" => 123, "email" => "test@example.com"})

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Bad Request"
      assert [%{"type" => "type_mismatch", "location" => ["name"]}] = body["details"]
    end

    test "returns 400 with details when the body has multiple invalid fields" do
      conn = dispatch(:post, "/users", %{"name" => 123, "email" => 456})

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Bad Request"
      assert is_list(body["details"])
      assert body["details"] != []
      assert Enum.all?(body["details"], &is_map_key(&1, "type"))
      assert Enum.all?(body["details"], &is_map_key(&1, "location"))
    end
  end

  describe "PhoenixSpectral.Controller with valid request body" do
    test "returns 201 on valid create" do
      conn = dispatch(:post, "/users", %{"name" => "Alice", "email" => "alice@example.com"})

      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert body["name"] == "Alice"
      assert body["email"] == "alice@example.com"
    end
  end

  describe "PhoenixSpectral.Controller with request headers" do
    test "returns 400 when a required header is missing" do
      conn = dispatch_header(:show, %{"id" => "1"}, [])

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Bad Request"
      assert [%{"type" => "missing_data", "location" => ["x-user-id"]}] = body["details"]
    end

    test "returns 200 when the required header is present" do
      conn = dispatch_header(:show, %{"id" => "1"}, [{"x-user-id", "alice"}])

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["name"] == "alice"
    end

    test "returns 200 when an optional header is absent" do
      conn = dispatch_header(:index, %{}, [])

      assert conn.status == 200
    end

    test "returns 200 when an optional header is present" do
      conn = dispatch_header(:index, %{}, [{"x-trace-id", "abc123"}])

      assert conn.status == 200
    end
  end

  describe "PhoenixSpectral.Controller with remote type headers" do
    test "returns 400 when a required remote-type header is missing" do
      conn = dispatch_header(:ping, %{}, [])

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert [%{"type" => "missing_data", "location" => ["x-request-id"]}] = body["details"]
    end

    test "returns 200 when a required remote-type header is present" do
      conn = dispatch_header(:ping, %{}, [{"x-request-id", "req-123"}])

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["name"] == "req-123"
    end
  end

  describe "PhoenixSpectral.Controller with typed response headers" do
    defp dispatch_header_action(action, path_params \\ %{}) do
      conn(:get, "/", nil)
      |> Map.put(:path_params, path_params)
      |> Map.put(:query_params, %{})
      |> Map.put(:req_headers, [])
      |> Phoenix.Controller.put_format("json")
      |> Plug.Conn.put_private(:phoenix_action, action)
      |> TestHeaderController.action([])
    end

    test "single return code: encodes integer response header to string" do
      conn = dispatch_header_action(:list_with_count)

      assert conn.status == 200
      # The action returns %{:"x-count" => 1} (integer), typed as integer().
      # The response header must be a binary string, so it should be encoded as "1".
      assert Plug.Conn.get_resp_header(conn, "x-count") == ["1"]
    end

    test "single return code: raises when response header value has wrong type" do
      assert_raise MatchError, fn ->
        dispatch_header_action(:list_with_string_count)
      end
    end

    test "union return codes: encodes typed response header for matching status" do
      conn = dispatch_header_action(:search, %{"id" => "1"})

      assert conn.status == 200
      assert Plug.Conn.get_resp_header(conn, "x-count") == ["1"]
    end

    test "union return codes: uses correct (empty) headers type for the other status" do
      conn = dispatch_header_action(:search, %{"id" => "unknown"})

      assert conn.status == 404
      assert Plug.Conn.get_resp_header(conn, "x-count") == []
    end
  end

  describe "PhoenixSpectral.Controller with integer path arg type" do
    defp dispatch_integer_id(raw_id) do
      conn =
        conn(:get, "/", nil)
        |> Map.put(:path_params, %{"id" => raw_id})
        |> Map.put(:query_params, %{})
        |> Map.put(:req_headers, [])
        |> Phoenix.Controller.put_format("json")

      conn
      |> Plug.Conn.put_private(:phoenix_action, :show_by_integer_id)
      |> TestUserController.action([])
    end

    test "coerces a numeric string path param to integer" do
      conn = dispatch_integer_id("42")

      assert conn.status == 200
      # The action passes id through to TestUser.id unchanged, so reading the
      # response body tells us what type the action actually received.
      body = Jason.decode!(conn.resp_body)
      assert body["id"] == 42
    end

    test "returns 400 when the path param cannot be coerced to integer" do
      conn = dispatch_integer_id("not-a-number")

      assert conn.status == 400
    end
  end

  describe "PhoenixSpectral.Controller with path args" do
    test "path args are decoded and passed as atom-keyed map" do
      conn =
        dispatch(:put, "/users/:id", %{"name" => "Bob", "email" => "bob@example.com"}, %{
          "id" => "1"
        })

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["name"] == "Bob"
    end
  end

  describe "PhoenixSpectral.Controller with conn access" do
    defp dispatch_conn(action, path_params, assigns \\ %{}) do
      conn(:get, "/", nil)
      |> Map.put(:path_params, path_params)
      |> Map.put(:query_params, %{})
      |> Map.put(:req_headers, [])
      |> Map.update!(:assigns, &Map.merge(&1, assigns))
      |> Phoenix.Controller.put_format("json")
      |> Plug.Conn.put_private(:phoenix_action, action)
      |> TestConnController.action([])
    end

    test "conn is passed as first arg and conn.assigns is accessible" do
      conn = dispatch_conn(:show_with_assigns, %{"id" => "5"}, %{current_user: "alice"})

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["name"] == "alice"
      assert body["id"] == 5
    end

    test "conn.assigns defaults when assign is absent" do
      conn = dispatch_conn(:show_with_assigns, %{"id" => "7"})

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["name"] == "unknown"
    end

    test "returning conn directly bypasses typed response and passes conn through" do
      conn = dispatch_conn(:download, %{})

      assert conn.status == 200
      assert conn.resp_body == "file content"
      assert {"content-type", "text/plain; charset=utf-8"} in conn.resp_headers
    end
  end

  describe "PhoenixSpectral.Controller with struct defaults" do
    test "decoding succeeds with missing optional fields (struct defaults)" do
      conn = dispatch(:post, "/users", %{"name" => "Charlie"})

      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert body["name"] == "Charlie"
      assert body["email"] == nil
      assert body["id"] == 2
    end

    test "response with all fields populated" do
      conn = dispatch(:post, "/users", %{"name" => "Dana", "email" => "dana@example.com"})

      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert body["name"] == "Dana"
      assert body["email"] == "dana@example.com"
      assert body["id"] == 2
    end
  end

  describe "PhoenixSpectral.Controller with field filtering (only:)" do
    defp dispatch_public(action, path_params) do
      call(TestUserController, action, :get, "/", nil, path_params, %{}, [])
    end

    test "response excludes filtered-out fields (password_hash)" do
      conn = dispatch_public(:show_public, %{"id" => "1"})

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["id"] == 1
      assert body["name"] == "Alice"
      assert body["email"] == "alice@example.com"
      # password_hash should not be present due to only: [:id, :name, :email]
      assert !Map.has_key?(body, "password_hash")
    end

    test "response for non-existent user still excludes filtered fields" do
      conn = dispatch_public(:show_public, %{"id" => "999"})

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["message"] == "User not found"
      # Error response doesn't have password_hash
      assert !Map.has_key?(body, "password_hash")
    end
  end

  describe "PhoenixSpectral.Controller with query params" do
    defp dispatch_query(action, query_params) do
      call(TestQueryController, action, :get, "/", nil, %{}, query_params, [])
    end

    test "optional query params absent: action receives empty map" do
      conn = dispatch_query(:index, %{})

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      # page defaults to 1 when absent
      assert hd(body)["id"] == 1
    end

    test "optional query params present: decoded and passed as atom-keyed map" do
      conn = dispatch_query(:index, %{"page" => "3"})

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert hd(body)["id"] == 3
    end

    test "returns 400 when a required query param is missing" do
      conn = dispatch_query(:search, %{})

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Bad Request"
      assert [%{"type" => "missing_data", "location" => ["q"]}] = body["details"]
    end

    test "required query param present: decoded and passed as atom-keyed map" do
      conn = dispatch_query(:search, %{"q" => "alice"})

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert hd(body)["name"] == "alice"
    end

    test "returns 400 when a query param has wrong type" do
      conn = dispatch_query(:index, %{"page" => "not-a-number"})

      assert conn.status == 400
    end
  end

  describe "PhoenixSpectral.Controller invalid request body detail enrichment" do
    test "each detail carries a human-readable message" do
      conn = dispatch(:post, "/users", %{"name" => 123, "email" => "test@example.com"})

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)

      assert [%{"type" => "type_mismatch", "location" => ["name"], "message" => message}] =
               body["details"]

      assert message == "type_mismatch at name"
    end

    test "detail surfaces the offending value as got" do
      conn = dispatch(:post, "/users", %{"name" => 123, "email" => "test@example.com"})

      body = Jason.decode!(conn.resp_body)
      assert [%{"got" => 123}] = body["details"]
    end

    test "a missing required header omits got (no value context) but carries a message" do
      conn = dispatch_header(:show, %{"id" => "1"}, [])

      body = Jason.decode!(conn.resp_body)
      assert [detail] = body["details"]
      assert detail["type"] == "missing_data"
      assert detail["message"] == "missing_data at x-user-id"
      refute Map.has_key?(detail, "got")
    end
  end

  describe "PhoenixSpectral.Controller with :on_invalid_request renderer" do
    test "MFA renderer controls the error envelope and status code" do
      conn =
        call(TestInvalidRequestController, :create, :post, "/", %{"name" => 123}, %{}, %{}, [])

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["code"] == "validation_failed"
      assert body["fields"] == [["name"]]
    end

    test "MFA renderer is bypassed on a valid request" do
      conn =
        call(
          TestInvalidRequestController,
          :create,
          :post,
          "/",
          %{"name" => "Alice", "email" => "a@example.com"},
          %{},
          %{},
          []
        )

      assert conn.status == 201
    end

    test "captured-function renderer is invoked" do
      conn =
        call(TestInvalidRequestFunController, :create, :post, "/", %{"name" => 123}, %{}, %{}, [])

      assert conn.status == 418
      assert Jason.decode!(conn.resp_body)["code"] == "nope"
    end
  end

  describe "PhoenixSpectral.Controller with a declared response content type" do
    defp dispatch_content_type(action, path_params \\ %{}) do
      call(TestContentTypeController, action, :get, "/", nil, path_params, %{}, [])
    end

    test "a declared non-JSON content type sends the body bytes verbatim" do
      conn = dispatch_content_type(:download_pdf, %{"id" => "1"})

      assert conn.status == 200
      assert conn.resp_body == <<"%PDF-1.7\n", 0xFF, 0xD8>>
      assert {"content-type", "application/pdf"} in conn.resp_headers
    end

    test "other declared response headers are still set from the returned map" do
      conn = dispatch_content_type(:download_pdf, %{"id" => "1"})

      assert {"content-disposition", ~s(attachment; filename="1.pdf")} in conn.resp_headers
    end

    test "a response in the same union without a declared content type stays JSON" do
      conn = dispatch_content_type(:download_pdf, %{"id" => "2"})

      assert conn.status == 404
      assert {"content-type", "application/json; charset=utf-8"} in conn.resp_headers
      assert Jason.decode!(conn.resp_body)["message"] == "Not found"
    end

    test "the content type is taken from the typespec, not from the returned headers map" do
      conn = dispatch_content_type(:download_xml)

      assert conn.status == 200
      assert conn.resp_body == "<signature/>"
      assert {"content-type", "application/xml"} in conn.resp_headers
    end

    test "an action returning conn keeps the content type it set itself" do
      conn = dispatch_content_type(:stream_xml)

      assert conn.status == 200
      assert conn.resp_body == "<streamed/>"
      assert {"content-type", "application/xml"} in conn.resp_headers
    end

    test "a declared application/json content type still encodes the body as JSON" do
      conn = dispatch_content_type(:download_json)

      assert conn.status == 200
      assert {"content-type", "application/json; charset=utf-8"} in conn.resp_headers
      assert Jason.decode!(conn.resp_body)["name"] == "Alice"
    end

    test "media type casing does not change how the body is encoded" do
      conn = dispatch_content_type(:download_json_mixed_case)

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["name"] == "Alice"
    end

    test "a nil body type sends an empty body" do
      conn = dispatch_content_type(:download_empty)

      assert conn.status == 204
      assert conn.resp_body == ""
      assert {"content-type", "application/pdf"} in conn.resp_headers
    end

    test "the content-type entry is matched whatever its casing" do
      conn = dispatch_content_type(:download_capitalized)

      assert conn.status == 200
      assert conn.resp_body == "%PDF-1.7\n"
      assert {"content-type", "application/pdf"} in conn.resp_headers
    end

    test "a +json media type is encoded as JSON under its own content type" do
      conn = dispatch_content_type(:download_problem_json)

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["message"] == "Not found"
      assert {"content-type", "application/problem+json; charset=utf-8"} in conn.resp_headers
    end

    test "a media type carrying parameters keeps them and still encodes JSON" do
      conn = dispatch_content_type(:download_json_with_charset)

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["name"] == "Alice"
      assert {"content-type", "application/json; charset=utf-8"} in conn.resp_headers
    end

    test "more than one content-type entry raises" do
      assert_raise ArgumentError, ~r/at most one media type/, fn ->
        dispatch_content_type(:download_two_content_types)
      end
    end

    test "a content-type entry that is not an atom raises" do
      assert_raise ArgumentError, ~r/must be a literal atom/, fn ->
        dispatch_content_type(:download_integer_content_type)
      end
    end

    test "a parameterized headers alias resolves to the type its argument supplies" do
      conn = dispatch_content_type(:download_parameterized_headers)

      assert conn.status == 200
      assert Plug.Conn.get_resp_header(conn, "x-total-count") == ["3"]
    end

    test "a required content-type entry missing from the returned map raises" do
      assert_raise RuntimeError, ~r/required response header "content-type"/, fn ->
        dispatch_content_type(:download_missing_content_type)
      end
    end

    test "a returned content-type that does not match the declared media type raises" do
      assert_raise MatchError, fn ->
        dispatch_content_type(:download_wrong_content_type)
      end
    end

    test "a returned content-type entry is validated but not sent under its declared casing" do
      conn = dispatch_content_type(:download_capitalized_returned)

      assert conn.status == 200
      assert conn.resp_body == "%PDF-1.7\n"
      assert {"content-type", "application/pdf"} in conn.resp_headers
      assert Plug.Conn.get_resp_header(conn, "Content-Type") == []
    end

    test "a body returned under a nil body type raises" do
      assert_raise RuntimeError, ~r/declared body type is nil must return nil/, fn ->
        dispatch_content_type(:download_empty_with_body)
      end
    end

    test "a non-binary body under a non-JSON content type raises" do
      assert_raise RuntimeError, ~r/must return a binary body/, fn ->
        dispatch_content_type(:download_not_binary)
      end
    end
  end
end
