defmodule Vcentral.MixProject do
  use Mix.Project

  def project do
    [
      app: :vcentral,
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
      mod: {Vcentral.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.2"},
      {:syslog, github: "schlagert/syslog"},
      {:user_agent_generator, "~> 1.0.1"},
      {:httpoison, "~> 1.8"},
      {:phoenix_pubsub, "~> 2.1.3"}
    ]
  end
end
