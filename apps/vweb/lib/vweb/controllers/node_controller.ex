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

end
