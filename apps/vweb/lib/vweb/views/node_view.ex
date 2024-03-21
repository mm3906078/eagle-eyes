defmodule Vweb.NodeView do
  use Vweb, :view

  def render("list.json", %{nodes: nodes}) do
    %{data: nodes}
  end

  def render("state.json", %{state: state}) do
    %{data: state}
  end
end
