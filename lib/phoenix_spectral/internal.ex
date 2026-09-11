defmodule PhoenixSpectral.Internal do
  @moduledoc false

  require Record

  Record.defrecordp(
    :sp_literal,
    Record.extract(:sp_literal, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecordp(
    :sp_map,
    Record.extract(:sp_map, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecordp(
    :sp_user_type_ref,
    Record.extract(:sp_user_type_ref, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecordp(
    :sp_remote_type,
    Record.extract(:sp_remote_type, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecordp(
    :literal_map_field,
    Record.extract(:literal_map_field, from_lib: "spectra/include/spectra_internal.hrl")
  )

  @content_type_header "content-type"

  def map_fields(sp_user_type_ref(type_name: name), type_info) do
    {:ok, resolved} = Spectral.TypeInfo.find_type(type_info, name, 0)
    map_fields(resolved, type_info)
  end

  def map_fields(sp_remote_type(mfargs: {mod, name, args}), _type_info) do
    remote_type_info = mod.__spectra_type_info__()
    {:ok, resolved} = Spectral.TypeInfo.find_type(remote_type_info, name, length(args))
    map_fields(resolved, remote_type_info)
  end

  def map_fields(sp_map(fields: fields), _type_info), do: fields

  @doc """
  Splits a response headers type into its declared media type and its remaining
  header fields.

  A `content-type` entry in a response headers map is a declaration of the
  response's media type, not a header whose value the action supplies, so it is
  taken out of the header fields. Returns `{nil, fields}` when the map declares
  no content type.
  """
  def pop_content_type(headers_type, type_info) do
    case Enum.split_with(map_fields(headers_type, type_info), &content_type_field?/1) do
      {[], header_fields} -> {nil, header_fields}
      {[content_type_field], header_fields} -> {content_type(content_type_field), header_fields}
    end
  end

  defp content_type_field?(literal_map_field(binary_name: binary_name)) do
    String.downcase(binary_name) == @content_type_header
  end

  defp content_type_field?(_other_map_field), do: false

  defp content_type(literal_map_field(val_type: sp_literal(binary_value: content_type))) do
    content_type
  end

  defp content_type(literal_map_field(val_type: val_type)) do
    raise ArgumentError,
          "PhoenixSpectral: the \"content-type\" entry of a response headers map declares the " <>
            "response media type and must be a literal atom, e.g. " <>
            ~s(%{"content-type": :"application/pdf"}, got: #{inspect(val_type)})
  end
end
