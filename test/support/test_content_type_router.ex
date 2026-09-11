defmodule TestContentTypeRouter do
  @moduledoc false
  use Phoenix.Router

  get("/documents/:id/pdf", TestContentTypeController, :download_pdf)
  get("/documents/xml", TestContentTypeController, :download_xml)
  get("/documents/stream", TestContentTypeController, :stream_xml)
  get("/documents/json", TestContentTypeController, :download_json)
  get("/documents/capitalized", TestContentTypeController, :download_capitalized)
  get("/documents/problem", TestContentTypeController, :download_problem_json)
  get("/documents/json-charset", TestContentTypeController, :download_json_with_charset)
end

defmodule TestNonBinaryBodyRouter do
  @moduledoc false
  use Phoenix.Router

  get("/documents/not-binary", TestContentTypeController, :download_not_binary)
end

defmodule TestInvalidContentTypeRouter do
  @moduledoc false
  use Phoenix.Router

  get("/documents/dynamic", TestContentTypeController, :download_dynamic_content_type)
end
