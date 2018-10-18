defmodule SimplerCache.MixProject do
  use Mix.Project

  def project do
    [
      app: :simpler_cache,
      version: "0.1.5",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        ignore_warnings: "dialyzer.ignore-warnings",
        flags: [:error_handling, :race_conditions, :underspecs]
      ],
      # Docs
      name: "Simpler Cache",
      source_url: "https://github.com/IRog/simpler_cache",
      homepage_url: "https://github.com/IRog/simpler_cache",
      docs: [
        # The main page in the docs
        main: "SimplerCache",
        # logo: "path/to/logo.png",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {SimplerCache.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:propcheck, "~> 1.1.3", only: :test},
      {:propcheck, git: "https://github.com/IRog/propcheck.git"},
      {:excoveralls, "~> 0.10", only: :test},
      {:dialyxir, "~> 1.0.0-rc.3", only: :dev, runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "A simple cache with ttl based on ets and timers. Tested with property model testing."
  end

  defp package() do
    [
      name: "simpler_cache",
      files: ~w(lib doc .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/IRog/simpler_cache"}
    ]
  end
end
