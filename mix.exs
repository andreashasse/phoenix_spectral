defmodule PhoenixSpectral.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_spectral,
      version: "0.6.0",
      elixir: ">= 1.18.0",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description:
        "FastAPI for Elixir/Phoenix — controller typespecs as the single source of truth for OpenAPI 3.1 generation and request/response validation.",
      package: package(),
      source_url: "https://github.com/andreashasse/phoenix_spectral",
      docs: [
        main: "readme",
        extras: ["README.md", "AGENTS.md", "CHANGELOG.md"]
      ]
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      files: ~w(lib .formatter.exs mix.exs README.md AGENTS.md CHANGELOG.md),
      links: %{
        "GitHub" => "https://github.com/andreashasse/phoenix_spectral",
        "Spectral" => "https://hexdocs.pm/spectral"
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:spectral, "~> 0.13.0"},
      {:spectra, "~> 0.13.2"},
      {:jason, "~> 1.0", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
