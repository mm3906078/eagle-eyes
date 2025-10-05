defmodule VcentralTest do
  use ExUnit.Case, async: true
  doctest Vcentral

  test "module exists" do
    assert Code.ensure_loaded?(Vcentral)
  end
end
