defmodule VwebTest do
  use ExUnit.Case, async: true
  doctest Vweb

  test "module exists" do
    assert Code.ensure_loaded?(Vweb)
  end
end
