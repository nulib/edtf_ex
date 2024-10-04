defmodule EDTF.MixProject do
  use Mix.Project

  def project do
    [
      app: :edtf,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:inflex, "~> 2.1"}
    ]
  end
end
