defmodule TestRemoteTypes do
  use Spectral

  @type request_headers :: %{required(:"x-request-id") => String.t()}
end
