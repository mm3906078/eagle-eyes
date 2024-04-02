defmodule Vagent.NodeCtl do
  use ExUnit.Case

  alias Vagent.NodeCtl
  alias Vagent.Master

  setup do
    :pg.start_link()
    node_ctl = start_supervised!(NodeCtl)
    master = start_supervised!(Vagent.Master)
    master_node = Vagent.Node.self()
    {:ok, node_ctl: node_ctl, master: master_node}
    :ok
  end

  discribe "NodeCtl" do
    test "check node name" do
      assert NodeCtl.get_node_name() == Node.self()
    end
  end
end
