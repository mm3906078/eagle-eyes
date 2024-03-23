defmodule Vcentral.Master do
  use GenServer
  alias Vcentral.CVEManager

  require Logger

  @update_interval 10 * 60 * 1000 # 10 minutes

  # Client
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_nodes() do
    :pg.get_members(:nodes)
    |> Enum.map(fn pid -> GenServer.call(pid, :get_node_name) end)
  end

  def get_master_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def check_node(node) do
    GenServer.call(__MODULE__, {:check_node, node}, 1_000_000)
  end

  def update_app(app, version, node) do
    GenServer.call({Vagent.VersionControl, node}, {:update_app, app, version})
  end

  # Server
  @impl true
  def init(_opts) do
    {:ok, %{nodes: %{}}, {:continue, :initialize}}
  end

  @impl true
  def handle_continue(:initialize, state) do
    :net_kernel.monitor_nodes(true)
    nodes = Node.list()
    Logger.info("Master initialized with nodes: #{inspect(nodes)}")
    Process.send_after(self(), :monitor, @update_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(:monitor, state) do
    nodes = Node.list()

    updated_state =
      Enum.reduce(nodes, state, fn node, acc_state ->
        Logger.info("Checking node: #{inspect(node)}")

        case GenServer.call({Vagent.VersionControl, node}, :get_version) do
          {:ok, version} ->
            Map.update(acc_state, :nodes, 0, fn nodes -> Map.put(nodes, node, version) end)

          {:error, _} ->
            Logger.error("Failed to get version from node: #{inspect(node)}")
            acc_state
        end
      end)

    Process.send_after(self(), :monitor, @update_interval)
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    Logger.info("Node up: #{inspect(node)}")

    case GenServer.call({Vagent.VersionControl, node}, :get_version) do
      {:ok, apps} ->
        new_state = Map.update(state, :nodes, 0, fn nodes -> Map.put(nodes, node, apps) end)
        {:noreply, new_state}

      {:error, _} ->
        Logger.error("Failed to get version from node: #{inspect(node)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    Logger.info("Node down: #{inspect(node)}")
    new_state = Map.update(state, :nodes, 0, fn nodes -> Map.delete(nodes, node) end)
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:check_node, node}, _from, state) do
    apps = Map.get(state[:nodes], String.to_atom(node), %{})

    updated_apps =
      Enum.reduce(apps, %{}, fn {app_name, app_info}, acc ->
        Logger.debug("Checking app: #{app_name} with version: #{app_info[:version]}")
        updated_app_info = update_app_info(app_name, app_info)
        Map.put(acc, app_name, updated_app_info)
      end)

    new_nodes = Map.put(state[:nodes], String.to_atom(node), updated_apps)
    new_state = Map.put(state, :nodes, new_nodes)

    {:reply, new_state, new_state}
  end

  defp update_app_info(app_name, app_info) do
    case CVEManager.get_CPEs_local(app_name, app_info[:version]) do
      {:ok, cpe_list} when is_list(cpe_list) and cpe_list != [] ->
        Enum.reduce(cpe_list, app_info, fn cpe, acc_info ->
          Logger.debug("Got CPE for #{app_name}: #{cpe}")
          handle_cpe_and_cves(app_name, cpe, acc_info)
        end)

      {:ok, _} ->
        Logger.debug("No CPE found for #{app_name}")
        app_info

      {:error, reason} ->
        Logger.warning("Failed to get CPE for #{app_name}: #{inspect(reason)}")
        app_info
    end
  end

  defp handle_cpe_and_cves(app_name, cpe, app_info) do
    case CVEManager.get_CVEs(cpe) do
      {:ok, res} ->
        Logger.debug("Got CVEs for #{app_name} with CPE #{cpe}: #{inspect(res)}")
        safe_version = Map.get(res, :last_version, app_info[:version])

        Map.put(app_info, :safe_version, safe_version)
        |> Map.put(:cpe, cpe)

      {:error, reason} ->
        Logger.debug("Failed to get CVEs for #{app_name} with CPE #{cpe}: #{inspect(reason)}")
        Map.put(app_info, :cpe, cpe)
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
