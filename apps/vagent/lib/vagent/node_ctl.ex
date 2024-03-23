defmodule Vagent.NodeCtl do
  use GenServer
  require Logger

  # Client
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_node_name() do
    GenServer.call(__MODULE__, :get_node_name)
  end

  # Server
  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)
    :net_kernel.monitor_nodes(true, %{nodedown_reason: true})
    master = Application.get_env(:vagent, :master)
    case connect_to_master(master) do
      :ok ->
        {:ok, master}

      :error ->
        {:stop, :error}
    end
  end

  @impl true
  def handle_call(:get_node_name, _from, state) do
    {:reply, Node.self(), state}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    Logger.info("Node up: #{inspect(node)}")
    {:noreply, state}
  end

  defp connect_to_master(_master_node, retry \\ 5, delay \\ 5_000)

  defp connect_to_master(master_node, 0, _retry_delay) do
    Logger.error("Failed to connect to master: #{master_node}")
    :error
  end

  defp connect_to_master(master_node, retry, retry_delay) do
    ping? = Node.ping(master_node)

    case ping? do
      :pong ->
        Logger.info("Connected to master: #{master_node}")
        :pg.join(:nodes, self())
        :ok

      :pang ->
        Logger.error("Failed to connect to master: #{master_node}")
        Process.sleep(retry_delay)
        connect_to_master(master_node, retry - 1, retry_delay)
    end
  end

  @impl true
  def terminate(_reason, _state) do
    :pg.leave(:nodes, self())
    Logger.info("NodeCtl terminated")
    :ok
  end

  @impl true
  def handle_info({:nodedown, node, %{nodedown_reason: reason}}, state) do
    master = Application.get_env(:vagent, :master)
    Logger.error(%{msg: "disconnected from master", node: node, reason: reason})
    :ok = connect_to_master(master)
    {:noreply, state}
  end
end
