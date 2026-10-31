defmodule TestSharedTypes do
  @moduledoc false
  use Spectral

  @type signature :: String.t()
  @type count :: pos_integer()

  @type headers :: %{required(:"x-signature") => signature(), optional(:"x-count") => count()}
  @type query :: %{required(:limit) => count()}
  @type path_args :: %{id: count()}
  @type response_headers :: %{required(:"x-count") => count()}
end
