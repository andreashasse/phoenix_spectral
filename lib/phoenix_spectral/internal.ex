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
    :sp_simple_type,
    Record.extract(:sp_simple_type, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecordp(
    :literal_map_field,
    Record.extract(:literal_map_field, from_lib: "spectra/include/spectra_internal.hrl")
  )

  @content_type_header "content-type"
  @json_content_type "application/json"

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

  def pop_content_type(headers_type, type_info) do
    case Enum.split_with(map_fields(headers_type, type_info), &content_type_field?/1) do
      {[], header_fields} ->
        {nil, header_fields}

      {[content_type_field], header_fields} ->
        {content_type(content_type_field), header_fields}

      {[_, _ | _] = content_type_fields, _header_fields} ->
        raise ArgumentError,
              "PhoenixSpectral: a response headers map declares #{length(content_type_fields)} " <>
                "content-type entries; it may declare at most one media type"
    end
  end

  def json_content_type?(content_type) do
    media_type = media_type(content_type)
    media_type == @json_content_type or String.ends_with?(media_type, "+json")
  end

  def binary_body_type?(sp_simple_type(type: :binary), _type_info), do: true

  def binary_body_type?(sp_literal(value: nil), _type_info), do: true

  def binary_body_type?(sp_remote_type(mfargs: {String, :t, []}), _type_info), do: true

  def binary_body_type?(sp_user_type_ref(type_name: name), type_info) do
    {:ok, resolved} = Spectral.TypeInfo.find_type(type_info, name, 0)
    binary_body_type?(resolved, type_info)
  end

  def binary_body_type?(sp_remote_type(mfargs: {mod, name, args}), _type_info) do
    Code.ensure_loaded(mod)

    if function_exported?(mod, :__spectra_type_info__, 0) do
      remote_type_info = mod.__spectra_type_info__()
      {:ok, resolved} = Spectral.TypeInfo.find_type(remote_type_info, name, length(args))
      binary_body_type?(resolved, remote_type_info)
    else
      false
    end
  end

  def binary_body_type?(_type, _type_info), do: false

  defp media_type(content_type) do
    content_type
    |> String.split(";", parts: 2)
    |> hd()
    |> String.trim()
    |> String.downcase()
  end

  defp content_type_field?(literal_map_field(binary_name: binary_name)) do
    String.downcase(binary_name) == @content_type_header
  end

  defp content_type_field?(_other_map_field), do: false

  defp content_type(literal_map_field(val_type: sp_literal(binary_value: declared))) do
    if String.contains?(declared, "/") do
      declared
    else
      raise_invalid_content_type(declared)
    end
  end

  defp content_type(literal_map_field(val_type: val_type)) do
    raise_invalid_content_type(val_type)
  end

  defp raise_invalid_content_type(declared) do
    raise ArgumentError,
          "PhoenixSpectral: the \"content-type\" entry of a response headers map declares the " <>
            "response media type and must be a literal atom, e.g. " <>
            ~s(%{"content-type": :"application/pdf"}, got: #{inspect(declared)})
  end
end
