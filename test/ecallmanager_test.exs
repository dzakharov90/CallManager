defmodule EcallmanagerTest do
  use ExUnit.Case
  doctest Ecallmanager

  test "pmap spawns async tasks" do
    pmap([1,2,3], fn x -> x * 2 end)

    assert_received({pid1, :ok})
    assert_received({pid2, :ok})
    assert_received({pid3, :ok})
    refute pid1 == pid2
    refute pid1 == pid3
    refute pid2 == pid3
  end
end
