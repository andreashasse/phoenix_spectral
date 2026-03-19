defmodule Example.Application do
  use Application

  @impl true
  def start(_type, _args) do
    Application.put_env(:spectra, :codecs, %{
      {DateTime, {:type, :t, 0}} => Spectral.Codec.DateTime
    })

    children = [
      Example.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Example.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
