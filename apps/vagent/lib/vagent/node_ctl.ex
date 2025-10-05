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

    Logger.info("NodeCtl starting...")
    Logger.info("Current node: #{Node.self()}")
    Logger.info("Master node configured as: #{master}")
    Logger.info("Node cookie: #{Node.get_cookie()}")

    # If no master is configured (e.g., in tests), start without connecting
    case master do
      nil ->
        Logger.info("No master configured - running in standalone mode")
        {:ok, nil}

      master_node ->
        case connect_to_master(master_node) do
          :ok ->
            Logger.info("NodeCtl initialized successfully")
            {:ok, master}

          :error ->
            Logger.error("NodeCtl failed to initialize - could not connect to master")
            {:stop, :error}
        end
    end
  end

  @impl true
  def handle_call(:get_node_name, _from, state) do
    {:reply, Node.self(), state}
  end

  @impl true
  def handle_info({:nodeup, node, _metadata}, state) do
    Logger.info("Node up: #{inspect(node)}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node, %{nodedown_reason: reason}}, state) do
    master = Application.get_env(:vagent, :master)
    Logger.error(%{msg: "disconnected from master", node: node, reason: reason})
    :ok = connect_to_master(master)
    {:noreply, state}
  end

  defp connect_to_master(_master_node, retry \\ 5, delay \\ 5_000)

  defp connect_to_master(master_node, 0, _retry_delay) do
    Logger.error(
      "Failed to connect to master after all retries: #{master_node}. Please check if the master node is running and accessible."
    )

    :error
  end

  defp connect_to_master(master_node, retry, retry_delay) do
    Logger.info("Attempting to connect to master: #{master_node} (#{6 - retry}/5 attempts)")
    ping? = Node.ping(master_node)

    case ping? do
      :pong ->
        Logger.info("Successfully connected to master: #{master_node}")
        :pg.join(:nodes, self())
        :ok

      :pang ->
        Logger.warning(
          "Failed to ping master: #{master_node}. Retrying in #{retry_delay}ms (#{retry} attempts remaining)"
        )

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
end
