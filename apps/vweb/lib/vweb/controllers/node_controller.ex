defmodule Vweb.NodeController do
  use Vweb, :controller
  use OpenApiSpex.ControllerSpecs
  alias Vcentral.Master

  alias Vweb.Schema.{
    AgentListResponse,
    DetailErrorResponse,
    StateResponse
  }

  operation(:list,
    summary: "List nodes",
    responses: %{
      ok: {"List of nodes", "application/json", AgentListResponse},
      internal_server_error: {"Detail error response", "application/json", DetailErrorResponse}
    }
  )

  def list(conn, _params) do
    nodes = Master.get_nodes()
    render(conn, "list.json", %{nodes: nodes})
  end

  operation(:state,
    summary: "Get master state",
    responses: %{
      ok: {"Master state", "application/json", StateResponse},
      internal_server_error: {"Detail error response", "application/json", DetailErrorResponse}
    }
  )

  def state(conn, _params) do
    state = Master.get_master_state()
    render(conn, "state.json", %{state: state})
  end

  operation(:install_app,
    summary: "Install app with the specified version",
    parameters: [
      node: [
        in: :query,
        description: "Node name",
        required: true,
        type: :string,
        example: "node1@192.168.1.10"
      ],
      app: [
        in: :query,
        description: "App name",
        required: true,
        type: :string,
        example: "vagent"
      ],
      version: [
        in: :query,
        description: "App version",
        required: false,
        type: :string,
        example: "0.1.0"
      ]
    ]
  )

  def install_app(conn, params) do
    node = String.to_atom(Map.get(params, "node"))
    app = Map.get(params, "app")
    version = Map.get(params, "version", "latest")

    case Master.install_app(app, version, node) do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{message: "App going to be installed"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{message: "Failed to install app", reason: reason})
    end
  end

  operation(:remove_app,
    summary: "Remove app",
    parameters: [
      node: [
        in: :query,
        description: "Node name",
        required: true,
        type: :string,
        example: "node1@192.168.1.10"
      ],
      app: [
        in: :query,
        description: "App name",
        required: true,
        type: :string,
        example: "vagent"
      ]
    ]
  )

  def remove_app(conn, params) do
    node = String.to_atom(Map.get(params, "node"))
    app = Map.get(params, "app")

    case Master.remove_app(app, node) do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{message: "App going to be removed"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{message: "Failed to remove app", reason: reason})
    end
  end

  operation(:check_node,
    summary: "Check node for CVEs",
    parameters: [
      node: [
        in: :query,
        description: "Node name",
        required: true,
        type: :string,
        example: "node1@192.168.1.10"
      ]
    ]
  )

  def check_node(conn, params) do
    node = Map.get(params, "node")
    Master.check_node_async(node)

    conn
    |> put_status(:ok)
    |> json(%{message: "Node started checking for CVEs"})
  end
end
