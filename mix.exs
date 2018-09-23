defmodule SimpleCache.MixProject do
  use Mix.Project

  def project do
    [
      app: :simple_cache,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [flags: [:error_handling, :race_conditions, :underspecs]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {SimpleCache.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:propcheck, "~> 1.1", only: :test},
      {:excoveralls, "~> 0.10", only: :test},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end
end
