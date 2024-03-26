defmodule Vcentral.Master do
  use GenServer
  alias Vcentral.CVEManager

  require Logger

  # 1 Day
  @update_interval 86_400_000

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
    GenServer.call(__MODULE__, {:check_node, node}, 50_000)
  end

  def check_node_async(node) do
    GenServer.cast(__MODULE__, {:check_node_async, node})
  end

  def update_app(app, version, node) do
    GenServer.call({Vagent.VersionControl, node}, {:update_app, app, version})
  end

  def install_app(app, version, node) do
    GenServer.call({Vagent.VersionControl, node}, {:install_app, app, version})
  end

  def update_all_apps(node) do
    GenServer.call({Vagent.VersionControl, node}, :update_all_apps)
  end

  def remove_app(app, node) do
    GenServer.call({Vagent.VersionControl, node}, {:remove_app, app})
  end

  # Server
  @impl true
  def init(_opts) do
    # State structure:
    # %{
    #   nodes: %{"agent@ip" => %{"vlc" => %{version: "0.1.0", cpe: "cpe:2.3:a:videolan:vlc_media_player:3.0.16:*:*:*:*:*:*:*"}}},
    #   cves: %{
    #     "agent@ip" => %{
    #       "vlc" => %{
    #         "CVE-2022-41325" => %{
    #           description:
    #             "An integer overflow in the VNC module in VideoLAN VLC Media Player through 3.0.17.4 allows attackers, by tricking a user into opening a crafted playlist or connecting to a rogue VNC server, to crash VLC or execute code under some conditions.",
    #           baseScore: 7.8,
    #           lastVersion: "3.1"
    #         }
    #       }
    #     }
    #   }
    # }
    {:ok, %{nodes: %{}, cves: %{}}, {:continue, :initialize}}
  end

  @impl true
  def handle_cast({:check_node_async, node}, state) do
    Task.start(fn -> check_node_func(node, state, "async") end)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:check_node, node}, _from, state) do
    {:ok, updated_apps, cves} = check_node_func(node, state, "sync")

    new_state_app =
      Map.update(state, :nodes, %{}, fn nodes -> Map.put(nodes, node, updated_apps) end)

    new_state =
      Map.update(new_state_app, :cves, %{}, fn cves_map -> Map.put(cves_map, node, cves) end)

    {:reply, new_state, new_state}
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

        node_string = Atom.to_string(node)

        case GenServer.call({Vagent.VersionControl, node}, :get_version) do
          {:ok, version} ->
            Map.update(acc_state, :nodes, 0, fn nodes -> Map.put(nodes, node_string, version) end)

          # this line commented out to make debugging easier
          # Map.update(acc_state, :cves, 0, fn cves -> Map.put(cves, node_string, %{}) end)

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

    node_string = Atom.to_string(node)

    case GenServer.call({Vagent.VersionControl, node}, :get_version) do
      {:ok, apps} ->
        new_state_app =
          Map.update(state, :nodes, %{}, fn nodes -> Map.put(nodes, node_string, apps) end)

        new_state_app_cve =
          Map.update(new_state_app, :cves, %{}, fn cves -> Map.put(cves, node_string, %{}) end)

        {:noreply, new_state_app_cve}

      {:error, _} ->
        Logger.error("Failed to get version from node: #{inspect(node)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    Logger.info("Node down: #{inspect(node)}")
    new_state_app = Map.update(state, :nodes, 0, fn nodes -> Map.delete(nodes, node) end)
    new_state = Map.update(new_state_app, :cves, 0, fn cves -> Map.delete(cves, node) end)
    {:noreply, new_state}
  end

  defp check_node_func(node, state, status) do
    apps = Map.get(state[:nodes], node, %{})

    if state[:cves][node] != %{} do
      {:ok, apps, state[:cves][node]}
    else
      {updated_apps, cves_node} =
        Enum.reduce(apps, {%{}, %{}}, fn {app_name, app_info}, {acc_apps, acc_cves} ->
          Logger.debug("Checking app: #{app_name} with version: #{app_info[:version]}")

          case update_app_info(app_name, app_info) do
            {updated_app_info, cves_app} ->
              {Map.put(acc_apps, app_name, updated_app_info),
               Map.put(acc_cves, app_name, cves_app)}

            updated_app_info ->
              {Map.put(acc_apps, app_name, updated_app_info), acc_cves}
          end
        end)

      if status == "async" do
        {:ok, message} = Vcentral.Notifier.create_message(node, cves_node)

        case Vcentral.Notifier.send_message_telegram(message) do
          {:ok, _} ->
            Logger.info("Message sent to telegram")

          {:error, reason} ->
            Logger.error("Failed to send message to telegram: #{inspect(reason)}")
        end
      end

      Logger.debug(
        "Node: #{node} updated apps: #{inspect(updated_apps)} with CVEs: #{inspect(cves_node)}"
      )

      {:ok, updated_apps, cves_node}
    end
  end

  defp update_app_info(app_name, app_info) do
    case CVEManager.cpe_checker(app_name, app_info[:version]) do
      {:ok, cpe_list} when is_list(cpe_list) and length(cpe_list) > 1 ->
        Logger.warning("Multiple CPEs found for #{app_name}, so skipping")
        app_info

      {:ok, cpe_list} when is_list(cpe_list) and length(cpe_list) == 1 ->
        Enum.reduce(cpe_list, app_info, fn cpe, acc_info ->
          Logger.debug("Got CPE for #{app_name}: #{cpe}")

          case handle_cpe_and_cves(app_name, cpe, acc_info) do
            {:ok, cves_app, updated_app_info} ->
              Logger.debug("Updated app_info: #{inspect(updated_app_info)}")
              {updated_app_info, cves_app}

            _ ->
              acc_info
          end
        end)

      {:ok, _} ->
        Logger.debug("No CPE found for #{app_name}")
        app_info

      {:error, reason} ->
        Logger.warning("Failed to get CPE for #{app_name}: #{inspect(reason)}")
        app_info

      :error ->
        Logger.warning("Failed to get CPEs for #{app_name}")
        app_info
    end
  end

  defp handle_cpe_and_cves(app_name, cpe, app_info) do
    case CVEManager.get_CVEs(cpe) do
      {:ok, res} ->
        Logger.debug("Got CVEs for #{app_name} with CPE #{cpe}: #{inspect(res)}")
        updated_app_info = Map.put(app_info, :cpe, cpe)
        {:ok, res, updated_app_info}

      {:error, reason} ->
        Logger.debug("Failed to get CVEs for #{app_name} with CPE #{cpe}: #{inspect(reason)}")
        Map.put(app_info, :cpe, cpe)
    end
  end
end
