defmodule RedMutexTest do
  use ExUnit.Case
  doctest RedMutex

  test "greets the world" do
    assert RedMutex.hello() == :world
  end
end
