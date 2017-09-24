defmodule SimultaneousAccessLockTest do
  use ExUnit.Case
  doctest SimultaneousAccessLock

  test "greets the world" do
    assert SimultaneousAccessLock.hello() == :world
  end
end
