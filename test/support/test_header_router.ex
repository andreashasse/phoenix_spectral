defmodule TestHeaderRouter do
  use Phoenix.Router

  get("/items", TestHeaderController, :index)
  get("/items/:id", TestHeaderController, :show)
  get("/items/count", TestHeaderController, :list_with_count)
  get("/items/ping", TestHeaderController, :ping)
end
