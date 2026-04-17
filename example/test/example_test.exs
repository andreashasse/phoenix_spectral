defmodule ExampleTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Phoenix.ConnTest

  @endpoint Example.Endpoint

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
    test "returns 400 without x-api-key header" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post("/users", Jason.encode!(%{name: "Test", email: "test@example.com"}))

      assert conn.status == 400
    end

    test "returns 201 with x-api-key header and full body" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-api-key", "secret")
        |> post("/users", Jason.encode!(%{name: "Test", email: "test@example.com"}))

      assert conn.status == 201
    end

    test "returns 201 when email is absent (email is optional)" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-api-key", "secret")
        |> post("/users", Jason.encode!(%{name: "NoEmail"}))

      assert conn.status == 201
    end
  end

  describe "GET /openapi" do
    test "returns 200" do
      conn = get(build_conn(), "/openapi")
      assert conn.status == 200
    end
  end
end
