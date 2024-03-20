defmodule Vweb.MixProject do
  use Mix.Project

  def project do
    [
      app: :vweb,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {Vweb.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.0"},
      {:phoenix, "~> 1.7.11"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_view, "~> 0.20.2"},
      {:gettext, "~> 0.20"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:jason, "~> 1.2"},
      {:syslog, github: "schlagert/syslog"},
      {:vcentral, in_umbrella: true},
      {:open_api_spex, "~> 3.18"},
      {:phoenix_view, "~> 2.0.3"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:bandit, "~> 1.0"},
      {:cors_plug, "~> 3.0"},
    ]
  end
end
