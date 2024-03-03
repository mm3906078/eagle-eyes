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
      extra_applications: [:logger, :runtime_tools],
      mod: {VersionControl.Umbrella.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.2"},
      {:syslog, github: "schlagert/syslog"}
    ]
  end

end
