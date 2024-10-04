defmodule EDTF.MixProject do
  use Mix.Project

  @version "1.0.0"
  @url "https://github.com/nulib/authoritex"

  def project do
    [
      app: :edtf,
      version: @version,
      elixir: "~> 1.15",
      deps: deps(),
      name: "EDTF",
      package: package(),
      source_url: @url,
      homepage: @url,
      docs: [
        main: "readme",
        extras: ["README.md"]
      ],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.circle": :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        docs: :docs,
        "hex.publish": :docs,
        vcr: :test,
        "vcr.delete": :test,
        "vcr.check": :test,
        "vcr.show": :test
      ],
      test_coverage: [tool: ExCoveralls],
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :text], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: [:dev, :test], runtime: false},
      {:inflex, "~> 2.1"}
    ]
  end

  defp elixirc_paths(:docs), do: ["lib", "test/support"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE.md"],
      maintainers: ["Brendan Quinn", "Karen Shaw", "Michael B. Klein"],
      licenses: ["MIT"],
      links: %{GitHub: @url},
      exclude_patterns: [".DS_Store"]
    ]
  end
end
