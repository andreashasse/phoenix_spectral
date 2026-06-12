defmodule ExampleTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Phoenix.ConnTest

  @endpoint Example.Endpoint

  # Valid Bearer token accepted by Example.BearerAuth (demo value).
  @bearer "Bearer let-me-in"

  # Both credentials the write endpoints require: a valid Bearer token (checked by
  # the router's bearer_auth pipeline) and the x-api-key header (validated from the
  # controller typespec).
  defp authed(conn) do
    conn
    |> put_req_header("authorization", @bearer)
    |> put_req_header("x-api-key", "secret")
    |> put_req_header("content-type", "application/json")
  end

  describe "GET /users" do
    test "returns 200" do
      conn = get(build_conn(), "/users")
      assert conn.status == 200
    end
  end

  describe "GET /users/:id" do
    test "returns 200 for an existing user" do
      conn = get(build_conn(), "/users/user:1")
      assert conn.status == 200
    end

    test "returns 404 for a non-existent user" do
      conn = get(build_conn(), "/users/user:99")
      assert conn.status == 404
    end

    test "omits password_hash from the response body" do
      conn = get(build_conn(), "/users/user:1")
      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      refute Map.has_key?(body, "password_hash")
    end
  end

  describe "POST /users" do
    test "returns 400 without x-api-key header (Bearer present)" do
      conn =
        build_conn()
        |> put_req_header("authorization", @bearer)
        |> put_req_header("content-type", "application/json")
        |> post("/users", Jason.encode!(%{name: "Test", email: "test@example.com"}))

      assert conn.status == 400
    end

    test "returns 201 with both credentials and full body" do
      conn =
        build_conn()
        |> authed()
        |> post("/users", Jason.encode!(%{name: "Test", email: "test@example.com"}))

      assert conn.status == 201
    end

    test "returns 201 when email is absent (email is optional)" do
      conn =
        build_conn()
        |> authed()
        |> post("/users", Jason.encode!(%{name: "NoEmail"}))

      assert conn.status == 201
    end
  end

  describe "Bearer auth on write endpoints" do
    test "returns 401 when the Authorization header is missing" do
      conn =
        build_conn()
        |> put_req_header("x-api-key", "secret")
        |> put_req_header("content-type", "application/json")
        |> post("/users", Jason.encode!(%{name: "Test"}))

      assert conn.status == 401
    end

    test "returns 401 for a non-Bearer scheme" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Basic abc123")
        |> put_req_header("x-api-key", "secret")
        |> put_req_header("content-type", "application/json")
        |> post("/users", Jason.encode!(%{name: "Test"}))

      assert conn.status == 401
    end

    test "returns 401 for a Bearer token that does not verify" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer nope")
        |> put_req_header("x-api-key", "secret")
        |> put_req_header("content-type", "application/json")
        |> post("/users", Jason.encode!(%{name: "Test"}))

      assert conn.status == 401
    end

    test "reads are not affected by the Bearer pipeline" do
      conn = get(build_conn(), "/users")
      assert conn.status == 200
    end
  end

  describe "GET /openapi" do
    test "returns 200" do
      conn = get(build_conn(), "/openapi")
      assert conn.status == 200
    end

    test "advertises both the x-api-key and Bearer schemes for Swagger UI Authorize" do
      spec =
        build_conn()
        |> get("/openapi")
        |> Map.fetch!(:resp_body)
        |> Jason.decode!()

      schemes = spec["components"]["securitySchemes"]

      assert schemes["api_key"]["type"] == "apiKey"
      assert schemes["api_key"]["in"] == "header"
      assert schemes["api_key"]["name"] == "x-api-key"

      assert schemes["bearer_auth"]["type"] == "http"
      assert schemes["bearer_auth"]["scheme"] == "bearer"

      assert spec["security"] == [%{"api_key" => [], "bearer_auth" => []}]
    end
  end
end
