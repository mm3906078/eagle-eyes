defmodule Vcentral.Master do
  use GenServer

  require Logger

  @master :"vcentral@192.168.1.10"
  @cookie "cookie"

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

  # Server
  @impl true
  def init(_opts) do
    {:ok, %{nodes: %{}}, {:continue, :initialize}}
  end

  @impl true
  def handle_continue(:initialize, state) do
    Node.start(@master)
    # Node.set_cookie(Node.self(), @cookie)
    :net_kernel.monitor_nodes(true)
    nodes = Node.list()
    Logger.info("Master initialized with nodes: #{inspect(nodes)}")
    Process.send_after(self(), :monitor, 5_000)
    {:noreply, state}
  end

  @impl true
  def handle_info(:monitor, state) do
    nodes = Node.list()

    updated_state =
      Enum.reduce(nodes, state, fn node, acc_state ->
        if Map.get(acc_state.nodes, node) == nil do
          Logger.info("New node detected: #{inspect(node)}")

          case GenServer.call({Vagent.VersionControl, node}, :get_version) do
            version ->
              Map.update(acc_state, :nodes, 0, fn nodes -> Map.put(nodes, node, version) end)

            :error ->
              Logger.error("Failed to get version from node: #{inspect(node)}")
              acc_state
          end
        else
          acc_state
        end
      end)

    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    Logger.info("Node up: #{inspect(node)}")

    case GenServer.call({Vagent.VersionControl, node}, :get_version) do
      apps ->
        new_state = Map.update(state, :nodes, 0, fn nodes -> Map.put(nodes, node, apps) end)
        {:noreply, new_state}

      :error ->
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
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
