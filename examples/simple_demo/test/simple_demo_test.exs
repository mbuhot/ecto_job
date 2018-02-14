defmodule SimpleDemoTest do
  use ExUnit.Case
  doctest SimpleDemo

  test "greets the world" do
    assert SimpleDemo.hello() == :world
  end
end
