defmodule TestContentTypeController do
  @moduledoc false
  use PhoenixSpectral.Controller, formats: [:json]

  @type pdf_headers :: %{
          required(:"content-type") => :"application/pdf",
          required(:"content-disposition") => String.t()
        }

  @type xml_headers :: %{optional(:"content-type") => :"application/xml"}

  @spec download_pdf(Plug.Conn.t(), %{id: String.t()}, %{}, %{}, nil) ::
          {200, pdf_headers(), binary()} | {404, %{}, TestError.t()}
  def download_pdf(_conn, %{id: id}, %{}, _headers, _body) do
    case id do
      "1" ->
        {200,
         %{
           "content-type": :"application/pdf",
           "content-disposition": ~s(attachment; filename="1.pdf")
         }, <<"%PDF-1.7\n", 0xFF, 0xD8>>}

      _ ->
        {404, %{}, %TestError{message: "Not found"}}
    end
  end

  @spec download_xml(Plug.Conn.t(), %{}, %{}, %{}, nil) :: {200, xml_headers(), binary()}
  def download_xml(_conn, _path_args, %{}, _headers, _body) do
    {200, %{}, "<signature/>"}
  end

  @spec stream_xml(Plug.Conn.t(), %{}, %{}, %{}, nil) :: {200, xml_headers(), binary()}
  def stream_xml(conn, _path_args, %{}, _headers, _body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/xml", nil)
    |> Plug.Conn.send_resp(200, "<streamed/>")
  end

  @spec download_json(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{optional(:"content-type") => :"application/json"}, TestUser.t()}
  def download_json(_conn, _path_args, %{}, _headers, _body) do
    {200, %{}, %TestUser{id: 1, name: "Alice", email: "alice@example.com"}}
  end

  @spec download_json_mixed_case(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{optional(:"content-type") => :"Application/JSON"}, TestUser.t()}
  def download_json_mixed_case(_conn, _path_args, %{}, _headers, _body) do
    {200, %{}, %TestUser{id: 1, name: "Alice", email: "alice@example.com"}}
  end

  @spec download_empty(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {204, %{optional(:"content-type") => :"application/pdf"}, nil}
  def download_empty(_conn, _path_args, %{}, _headers, _body) do
    {204, %{}, nil}
  end

  @spec download_dynamic_content_type(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{"content-type": String.t()}, binary()}
  def download_dynamic_content_type(_conn, _path_args, %{}, _headers, _body) do
    {200, %{"content-type": "application/pdf"}, "bytes"}
  end

  @spec download_not_binary(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{optional(:"content-type") => :"application/pdf"}, TestUser.t()}
  def download_not_binary(_conn, _path_args, %{}, _headers, _body) do
    {200, %{}, %TestUser{id: 1, name: "Alice", email: "alice@example.com"}}
  end
end
