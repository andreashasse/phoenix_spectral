defmodule TestOpenAPIRouterController do
  @moduledoc false
  use PhoenixSpectral.OpenAPIController,
    router: TestOpenAPIRouter,
    title: "Test API",
    version: "1.0.0"
end

defmodule TestScopedOpenAPIRouterController do
  @moduledoc false
  use PhoenixSpectral.OpenAPIController,
    router: TestScopedOpenAPIRouter,
    title: "Test API",
    version: "1.0.0"
end

defmodule TestOpenAPIRouter do
  @moduledoc false
  use Phoenix.Router

  get("/openapi", TestOpenAPIRouterController, :show)
  get("/swagger", TestOpenAPIRouterController, :swagger)
end

defmodule TestScopedOpenAPIRouter do
  @moduledoc false
  use Phoenix.Router

  scope "/api" do
    get("/openapi", TestScopedOpenAPIRouterController, :show)
    get("/swagger", TestScopedOpenAPIRouterController, :swagger)
  end
end
