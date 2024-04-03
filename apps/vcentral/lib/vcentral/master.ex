defmodule Vcentral.Master do
  use GenServer
  alias Vcentral.CVEManager
  alias Vagent.VersionControl

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
    case get_agent_pid(node) do
      {:ok, pid} ->
        VersionControl.install_app(pid, app, version)

      {:error, _} ->
        Logger.error("Failed to get PID for node: #{inspect(node)}")
    end
  end

  def install_app(app, version, node) do
    case get_agent_pid(node) do
      {:ok, pid} ->
        VersionControl.install_app(pid, app, version)

      {:error, _} ->
        Logger.error("Failed to get PID for node: #{inspect(node)}")
    end
  end

  # def update_all_apps(node) do
  #   # TODO: Implement
  # end

  def search_app(apps, node) do
    GenServer.call(__MODULE__, {:search_app, apps, node})
  end

  def remove_app(app, node) do
    case get_agent_pid(node) do
      {:ok, pid} ->
        VersionControl.remove_app(pid, app)

      {:error, _} ->
        Logger.error("Failed to get PID for node: #{inspect(node)}")
    end
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
    caller = self()

    Task.start(fn ->
      {:ok, updated_apps, cves} = check_node_func(node, state, "async")
      send(caller, {:check_node_async_result, node, updated_apps, cves})
    end)

    {:noreply, state}
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
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:search_app, apps, node}, _from, state) do
    node_str = to_string(node)

    case fetch_installed_apps_for_node(node) do
      {:ok, apps_installed} ->
        apps_response = get_apps_response(apps, apps_installed, state, node_str)
        {:reply, apps_response, state}

      {:error, :version_check_failed} ->
        Logger.error("Failed to update version for node: #{inspect(node_str)}")
        {:reply, :error, state}

      {:error, :pid_not_found} ->
        Logger.error("Failed to get PID for node: #{inspect(node_str)}")
        {:reply, :error, state}
    end
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    Logger.info("Node down: #{inspect(node)}")
    new_state_app = Map.update(state, :nodes, 0, fn nodes -> Map.delete(nodes, node) end)
    new_state = Map.update(new_state_app, :cves, 0, fn cves -> Map.delete(cves, node) end)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    Logger.info("Node up: #{inspect(node)}")

    node_string = Atom.to_string(node)

    # TODO: THIS IS LIKE SHIT!
    :timer.sleep(1000)

    case fetch_installed_apps_for_node(node) do
      {:ok, apps} ->
        new_state_app =
          Map.update(state, :nodes, %{}, fn nodes -> Map.put(nodes, node_string, apps) end)

        new_state_app_cve =
          Map.update(new_state_app, :cves, %{}, fn cves ->
            Map.put(cves, node_string, %{})
          end)

        {:noreply, new_state_app_cve}

      {:error, _} ->
        Logger.error("Failed to get version from node: #{inspect(node)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:monitor, state) do
    nodes = Node.list()

    updated_state =
      Enum.reduce(nodes, state, fn node, acc_state ->
        Logger.info("Checking node: #{inspect(node)}")

        node_string = Atom.to_string(node)

        case fetch_installed_apps_for_node(node) do
          {:ok, version} ->
            Map.update(acc_state, :nodes, 0, fn nodes ->
              Map.put(nodes, node_string, version)
            end)

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
  def handle_info({:check_node_async_result, node, updated_apps, cves}, state) do
    new_state_app =
      Map.update(state, :nodes, %{}, fn nodes -> Map.put(nodes, node, updated_apps) end)

    new_state =
      Map.update(new_state_app, :cves, %{}, fn cves_map -> Map.put(cves_map, node, cves) end)

    {:noreply, new_state}
  end

  @impl true
  def handle_continue(:initialize, state) do
    :net_kernel.monitor_nodes(true)
    nodes = Node.list()
    Logger.info("Master initialized with nodes: #{inspect(nodes)}")
    Process.send_after(self(), :monitor, @update_interval)
    {:noreply, state}
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

      if status == "async" and cves_node != %{} do
        {:ok, message} = Vcentral.Notifier.create_message(node, cves_node)

        case Vcentral.Notifier.send_message_telegram(message) do
          {:ok, _} ->
            Logger.info("Message sent to telegram")

          {:error, reason} ->
            Logger.error("Failed to send message to telegram: #{inspect(reason)}")
        end
      end

      {:ok, updated_apps, cves_node}
    end
  end

  defp get_agent_pid(node) do
    case :pg.get_members(node) do
      [] ->
        {:error, :not_found}

      [pid | _] ->
        {:ok, pid}
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
    case CVEManager.get_CVEs_nvd(cpe) do
      {:ok, res} ->
        Logger.debug("Got CVEs for #{app_name} with CPE #{cpe}: #{inspect(res)} with NVD")
        updated_app_info = Map.put(app_info, :cpe, cpe)
        {:ok, res, updated_app_info}

      {:error, reason} ->
        Logger.debug(
          "Failed to get CVEs for #{app_name} with CPE #{cpe}: #{inspect(reason)} from NVD"
        )

        case CVEManager.get_CVEs_vuln(cpe) do
          {:ok, res} ->
            Logger.debug("Got CVEs for #{app_name} with CPE #{cpe}: #{inspect(res)} with VulnDB")
            updated_app_info = Map.put(app_info, :cpe, cpe)
            {:ok, res, updated_app_info}

          {:error, reason} ->
            Logger.debug(
              "Failed to get CVEs for #{app_name} with CPE #{cpe}: #{inspect(reason)} from VulnDB"
            )

            Map.put(app_info, :cpe, cpe)
        end
    end
  end

  defp get_apps_response(apps, apps_installed, state, node_str) do
    # Assuming apps is a list of app names you want to search for.
    if Enum.empty?(apps) do
      {:ok, apps_installed}
    else
      apps_cves = Map.get(state.cves, node_str, %{})

      apps_found_details =
        Enum.reduce(apps, %{}, fn app, acc ->
          case Map.fetch(apps_installed, app) do
            :error ->
              acc

            {:ok, app_details} ->
              cves_for_app = Map.get(apps_cves, app, %{})

              Map.put(acc, app, %{
                details: app_details,
                cves: cves_for_app
              })
          end
        end)

      if Map.keys(apps_found_details) == [] do
        {:error, :apps_not_found}
      else
        {:ok, apps_found_details}
      end
    end
  end

  defp fetch_installed_apps_for_node(node) do
    case get_agent_pid(node) do
      {:ok, pid} ->
        case VersionControl.get_version(pid) do
          :ok ->
            VersionControl.get_apps_installed(pid)

          _ ->
            {:error, :version_check_failed}
        end

      {:error, _} ->
        {:error, :pid_not_found}
    end
  end

  defp update_node_apps(state, node_str, apps_installed) do
    new_nodes = Map.put(state.nodes, node_str, apps_installed)
    Map.put(state, :nodes, new_nodes)
  end
end
