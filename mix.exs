defmodule VersionControl.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools, :httpoison],
      mod: {VersionControl.Umbrella.Application, []}
    ]
  end

  defp deps do
    []
  end

  defp releases() do
    [
      agent: [
        applications: [
          vagent: :permanent
        ],
        steps: [:assemble, :tar]
      ],
      master: [
        applications: [
          vcentral: :permanent,
          vweb: :permanent
        ],
        steps: [:assemble, :tar]
      ]
    ]
  end

end
