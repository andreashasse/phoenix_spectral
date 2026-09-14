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

  @spec download_capitalized(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{optional(:"Content-Type") => :"application/pdf"}, binary()}
  def download_capitalized(_conn, _path_args, %{}, _headers, _body) do
    {200, %{}, "%PDF-1.7\n"}
  end

  @spec download_problem_json(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{optional(:"content-type") => :"application/problem+json"}, TestError.t()}
  def download_problem_json(_conn, _path_args, %{}, _headers, _body) do
    {200, %{}, %TestError{message: "Not found"}}
  end

  @spec download_json_with_charset(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{optional(:"content-type") => :"application/json; charset=utf-8"}, TestUser.t()}
  def download_json_with_charset(_conn, _path_args, %{}, _headers, _body) do
    {200, %{}, %TestUser{id: 1, name: "Alice", email: "alice@example.com"}}
  end

  @spec download_two_content_types(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200,
           %{
             required(:"content-type") => :"application/pdf",
             required(:"Content-Type") => :"application/xml"
           }, binary()}
  def download_two_content_types(_conn, _path_args, %{}, _headers, _body) do
    {200, %{"content-type": :"application/pdf", "Content-Type": :"application/xml"}, "bytes"}
  end

  @spec download_integer_content_type(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{required(:"content-type") => 42}, binary()}
  def download_integer_content_type(_conn, _path_args, %{}, _headers, _body) do
    {200, %{"content-type": 42}, "bytes"}
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

  @type empty :: nil

  @spec download_alias_empty(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {204, %{optional(:"content-type") => :"application/pdf"}, empty()}
  def download_alias_empty(_conn, _path_args, %{}, _headers, _body) do
    {204, %{}, nil}
  end

  @spec download_alias_empty_json(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {204, %{}, empty()}
  def download_alias_empty_json(_conn, _path_args, %{}, _headers, _body) do
    {204, %{}, nil}
  end

  @spec download_dynamic_content_type(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{"content-type": String.t()}, binary()}
  def download_dynamic_content_type(_conn, _path_args, %{}, _headers, _body) do
    {200, %{"content-type": "application/pdf"}, "bytes"}
  end

  @type tagged(t) :: %{required(:"x-total-count") => t}
  @type payload(t) :: t

  @spec download_parameterized_headers(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, tagged(integer()), TestUser.t()}
  def download_parameterized_headers(_conn, _path_args, %{}, _headers, _body) do
    {200, %{"x-total-count": 3}, %TestUser{id: 1, name: "Alice", email: "alice@example.com"}}
  end

  @spec download_parameterized_body(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{optional(:"content-type") => :"application/pdf"}, payload(binary())}
  def download_parameterized_body(_conn, _path_args, %{}, _headers, _body) do
    {200, %{}, "%PDF-1.7\n"}
  end

  @spec download_missing_content_type(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{required(:"content-type") => :"application/pdf"}, binary()}
  def download_missing_content_type(_conn, _path_args, %{}, _headers, _body) do
    {200, %{}, "%PDF-1.7\n"}
  end

  @spec download_wrong_content_type(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{required(:"content-type") => :"application/pdf"}, binary()}
  def download_wrong_content_type(_conn, _path_args, %{}, _headers, _body) do
    {200, %{"content-type": :"application/xml"}, "%PDF-1.7\n"}
  end

  @spec download_capitalized_returned(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{required(:"Content-Type") => :"application/pdf"}, binary()}
  def download_capitalized_returned(_conn, _path_args, %{}, _headers, _body) do
    {200, %{"Content-Type": :"application/pdf"}, "%PDF-1.7\n"}
  end

  @spec download_empty_with_body(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{optional(:"content-type") => :"application/pdf"}, nil}
  def download_empty_with_body(_conn, _path_args, %{}, _headers, _body) do
    {200, %{}, "%PDF-1.7\n"}
  end

  @spec download_not_binary(Plug.Conn.t(), %{}, %{}, %{}, nil) ::
          {200, %{optional(:"content-type") => :"application/pdf"}, TestUser.t()}
  def download_not_binary(_conn, _path_args, %{}, _headers, _body) do
    {200, %{}, %TestUser{id: 1, name: "Alice", email: "alice@example.com"}}
  end
end
