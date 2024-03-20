defmodule Vweb.Schema do
  alias OpenApiSpex.Schema

  defmodule AgentListResponse do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "List of agents",
        description: "List of agents already registered",
        type: :array,
        items: %Schema{type: :string, description: "Agent name@host"}
      },
      example: [
        "agent_name@host"
      ]
    )
  end

  defmodule DetailErrorResponse do
    require OpenApiSpex

    OpenApiSpex.schema(
      %{
        title: "Error detail",
        description: "Error detail",
        type: :object,
        properties: %{
          detail: %Schema{
            type: :string,
            description: "Error reason."
          }
        }
      },
      example: %{
        "detail" => "action failed because of some internal error."
      }
    )
  end

  defmodule StateResponse do
    require OpenApiSpex

    @node_app_schema %Schema{
      type: :object,
      properties: %{
        version: %Schema{
          type: :string,
          description: "App version"
        },
        cpe: %Schema{
          type: :string,
          description: "CPE name"
        },
        safe_version: %Schema{
          type: :string,
          description: "Safe version"
        },
        score: %Schema{
          type: :integer,
          description: "Score"
        }
      }
    }

    OpenApiSpex.schema(%Schema{
      title: "Master state",
      description: "Master state",
      type: :object,
      properties: %{
        nodes: %Schema{
          type: :object,
          description: "List of nodes and their apps",
          additionalProperties: @node_app_schema
        }
      },
      example: %{
        nodes: %{
          "vagent@192.168.1.10": %{
            "libcairo-script-interpreter2" => %{
              version: "1.16.0",
              cpe: "",
              safe_version: "",
              score: 0
            }
          }
        }
      }
    })
  end
end
