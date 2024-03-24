defmodule Vagent.VersionControl do
  use GenServer

  require Logger

  # Client
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_version() do
    GenServer.call(__MODULE__, :get_version)
  end

  def update_app(app, version) do
    GenServer.call(__MODULE__, {:update_app, app, version})
  end

  def update_all_apps() do
    GenServer.call(__MODULE__, :update_all_apps)
  end

  def install_app(app, version) do
    GenServer.call(__MODULE__, {:install_app, app, version})
  end

  def remove_app(app) do
    GenServer.call(__MODULE__, {:remove_app, app})
  end

  # Server
  def init(_opts) do
    apps = %{
      "vagent" => %{version: "0.1.0", cpe: "", safe_version: "0.1.0"}
    }

    Logger.info("Version control initialized with apps: #{inspect(apps)}")

    {:ok, apps}
  end

  def handle_call({:remove_app, app}, _from, state) do
    IO.puts("Removing app: #{app}")

    case System.cmd("apt-get", ["remove", app]) do
      {_, 0} ->
        {:reply, :ok, state}

      {_, _} ->
        {:reply, :error, state}
    end
  end

  def handle_call({:install_app, app, version}, _from, state) do
    IO.puts("Installing app: #{app} version: #{version}")

    case install_app_version(app, version) do
      {:ok, _} ->
        {:reply, :ok, state}

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        {:reply, :error, state}
    end
  end

  def handle_call(:update_all_apps, _from, state) do
    IO.puts("Updating all apps")

    case System.cmd("apt-get", ["update"]) do
      {_, 0} ->
        case System.cmd("apt-get", ["upgrade", "-y"]) do
          {_, 0} ->
            {:reply, :ok, state}

          {_, _} ->
            {:reply, :error, state}
        end

      {_, _} ->
        {:reply, :error, state}
    end
  end

  def handle_call({:update_app, app, version}, _from, state) do
    IO.puts("Updating app: #{app} to version: #{version}")

    case update_app_version(app, version) do
      {:ok, _} ->
        {:reply, :ok, state}

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        {:reply, :error, state}
    end
  end

  def handle_call(:get_version, _from, state) do
    Logger.info("Getting version")

    case Application.get_env(:vagent, :demo) do
      true ->
        status = :demo

        case get_apps(status) do
          {:ok, apps} ->
            {:reply, {:ok, apps}, state}

          {:error, reason} ->
            Logger.error("Failed to get apps: #{reason}")
            {:reply, {:error, reason}, state}
        end

      _ ->
        status = :all

        case get_apps(status) do
          {:ok, apps} ->
            {:reply, {:ok, apps}, state}

          {:error, reason} ->
            Logger.error("Failed to get apps: #{reason}")
            {:reply, {:error, reason}, state}
        end
    end
  end

  defp update_app_version(app, version) do
    if version == "latest" do
      case System.cmd("apt-get", ["install", app]) do
        {output, 0} ->
          {:ok, output}

        {output, _} ->
          {:error, output}
      end
    else
      case System.cmd("apt-get", ["install", "#{app}=#{version}"]) do
        {output, 0} ->
          {:ok, output}

        {output, _} ->
          {:error, output}
      end
    end
  end

  defp install_app_version(app, version) do
    if version == "latest" do
      case System.cmd("apt-get", ["install", app]) do
        {output, 0} ->
          {:ok, output}

        {output, _} ->
          {:error, output}
      end
    else
      case System.cmd("apt-get", ["install", "#{app}=#{version}"]) do
        {output, 0} ->
          {:ok, output}

        {output, _} ->
          {:error, output}
      end
    end
  end

  defp get_apps(status) do
    case status do
      :all ->
        case System.cmd("dpkg-query", ["-W", "-f='${Package}: ${Version}\n'"]) do
          {output, 0} ->
            apps =
              output
              |> String.trim()
              |> String.split("\n")
              |> Enum.reduce(%{}, fn line, acc ->
                case String.split(line, ": ", parts: 2) do
                  [app, version] when app != "" ->
                    cleaned_app = String.trim(app, "'")
                    # TODO: This is a hack, we should use a proper version comparison
                    version_final = Enum.at(String.split(version, "-"), 0)

                    app_info = %{
                      version: version_final,
                      cpe: "",
                      safe_version: "",
                      score: 0
                    }

                    Map.put(acc, cleaned_app, app_info)

                  _ ->
                    acc
                end
              end)

            {:ok, apps}

          {output, _} ->
            {:error, output}
        end

      :demo ->
        {output, 0} =
          System.cmd("sh", [
            "-c",
            "dpkg-query -W -f='${Package}: ${Version}\n' | grep 'vlc: 3.0.16-1build7'"
          ])

        [app, version] = String.split(output, ": ", parts: 2)
        version_final = Enum.at(String.split(version, "-"), 0)

        app_info = %{
          version: version_final,
          cpe: ""
        }

        {:ok, %{app => app_info}}

      :shallow ->
        # TODO: Implement for smaller list of apps
        {:error, "Not implemented"}
    end
  end
end
