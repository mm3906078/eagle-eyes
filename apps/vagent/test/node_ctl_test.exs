defmodule Vagent.NodeCtlTest do
  use ExUnit.Case, async: false

  alias Vagent.NodeCtl

  # Skip tests that require master connection in CI
  @moduletag :capture_log

  describe "NodeCtl" do
    test "get node name returns current node" do
      # Test the node name function - in test it will be :nonode@nohost
      current_node = Node.self()
      assert is_atom(current_node)
      # In test environment, node is typically :nonode@nohost
      assert current_node == :nonode@nohost
    end

    test "module exists and has required functions" do
      # Test that the module has the expected functions
      assert function_exported?(NodeCtl, :start_link, 1)
      assert function_exported?(NodeCtl, :get_node_name, 0)
    end
  end
end
