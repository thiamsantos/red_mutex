defmodule RedMutex.MixProject do
  use Mix.Project

  @version "0.2.2"

  def project do
    [
      app: :red_mutex,
      version: @version,
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Redlock (Redis Distributed Lock) implementation",
      package: package(),
      docs: docs(),
      name: "RedMutex",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.travis": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: ["Thiago Santos"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/thiamsantos/red_mutex"}
    ]
  end

  defp docs do
    [
      main: "RedMutex",
      source_url: "https://github.com/thiamsantos/red_mutex"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:redix, "~> 1.0"},
      {:excoveralls, "~> 0.13", only: :test, runtime: false},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end
end
