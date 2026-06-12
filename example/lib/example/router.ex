defmodule Example.Router do
  use Phoenix.Router

  # Verifies the `Authorization: Bearer <token>` header (see Example.BearerAuth).
  pipeline :bearer_auth do
    plug(Example.BearerAuth)
  end

  get("/openapi", Example.OpenAPIController, :show)
  get("/swagger", Example.OpenAPIController, :swagger)

  # Reads are open.
  get("/users", Example.UserController, :index)
  get("/users/:id", Example.UserController, :show)

  # Writes require a valid Bearer token (this pipeline) AND an x-api-key header
  # (validated from Example.UserController's write_headers typespec).
  scope "/" do
    pipe_through(:bearer_auth)

    post("/users", Example.UserController, :create)
    put("/users/:id", Example.UserController, :update)
    delete("/users/:id", Example.UserController, :delete)
  end
end
