defmodule PhoenixSpectral.Internal do
  @moduledoc false

  require Record

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
end
