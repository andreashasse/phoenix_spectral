defmodule TestContentTypeRouter do
  @moduledoc false
  use Phoenix.Router

  get("/documents/:id/pdf", TestContentTypeController, :download_pdf)
  get("/documents/xml", TestContentTypeController, :download_xml)
  get("/documents/stream", TestContentTypeController, :stream_xml)
  get("/documents/json", TestContentTypeController, :download_json)
end

defmodule TestInvalidContentTypeRouter do
  @moduledoc false
  use Phoenix.Router

  get("/documents/dynamic", TestContentTypeController, :download_dynamic_content_type)
end
