defmodule TestQueryRouter do
  @moduledoc false
  use Phoenix.Router

  get("/users", TestQueryController, :index)
  get("/users/search", TestQueryController, :search)
  get("/users/:id/shared", TestQueryController, :shared)
end
