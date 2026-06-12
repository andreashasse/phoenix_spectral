defmodule Example.MixProject do
  use Mix.Project

  def project do
    [
      app: :example,
      version: "0.1.0",
      elixir: ">= 1.18.0",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Example.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix_spectral, path: ".."},
      # Mirror phoenix_spectral's override so the example resolves the same
      # unreleased spectra (security-scheme support, PR #181). Drop once released.
      {:spectra,
       github: "andreashasse/spectra", branch: "add-security-schemes", override: true},
      {:bandit, "~> 1.0"},
      {:jason, "~> 1.0"}
    ]
  end
end
