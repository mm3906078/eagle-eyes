defmodule Vagent.VersionControl do
  use GenServer

  require Logger

  # Client
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_version(pid) do
    GenServer.call(pid, :get_version)
  end

  def update_app(pid, app, version) do
    GenServer.call(pid, {:update_app, app, version})
  end

  def update_all_apps(pid) do
    GenServer.call(pid, :update_all_apps)
  end

  def install_app(pid, app, version) do
    GenServer.call(pid, {:install_app, app, version})
  end

  def remove_app(pid, app) do
    GenServer.call(pid, {:remove_app, app})
  end

  # Server
  def init(_opts) do
    apps = %{
      "vagent" => "0.1.0"
    }

    {:ok, apps}
  end

  def handle_call({:remove_app, app}, _from, state) do
    IO.puts("Removing app: #{app}")

    case System.cmd("apt-get", ["remove", app]) do
      {output, 0} ->
        {:reply, :ok, state}

      {output, _} ->
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
      {output, 0} ->
        case System.cmd("apt-get", ["upgrade", "-y"]) do
          {output, 0} ->
            {:reply, :ok, state}

          {output, _} ->
            {:reply, :error, state}
        end

      {output, _} ->
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
    case get_apps() do
      {:ok, apps} ->
        {:reply, apps, state}

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        {:reply, %{}, state}
    end
  end

  defp update_app_version(app, version) do
    case System.cmd("apt-get", ["install", "#{app}=#{version}"]) do
      {output, 0} ->
        {:ok, output}

      {output, _} ->
        {:error, output}
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

  defp get_apps do
    case System.cmd("dpkg-query", ["-W", "-f='${Version}\t${Package}\n'"]) do
      {output, 0} ->
        apps =
          output
          |> String.split("'", trim: true)
          |> Enum.map(fn line ->
            [version, app] = String.split(line, "\t")
            {app |> String.replace("\n", ""), version}
          end)

        {:ok, apps}

      {output, code} ->
        {:error, output}
    end
  end
end
