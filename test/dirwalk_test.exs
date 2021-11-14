defmodule DirwalkTest do
  use ExUnit.Case
  doctest Dirwalk

  test "walks depth first" do
    assert {{"testdirs", ["dogs", "cats"], []}, next} = Dirwalk.walk("testdirs")
    assert {{"testdirs/dogs", ["wild", "domestic"], []}, next} = next.()
    assert {{"testdirs/dogs/wild", [], ["coyote.txt", "wolf.txt"]}, next} = next.()
    assert {{"testdirs/dogs/domestic", [], ["dog.txt"]}, next} = next.()
    assert {{"testdirs/cats", ["wild", "domestic"], []}, next} = next.()
    assert {{"testdirs/cats/wild", [], ["tiger.txt", "lion.txt"]}, next} = next.()
    assert {{"testdirs/cats/domestic", [], ["cat.txt"]}, next} = next.()
    assert :done = next.()
  end

  test "walks bottom-up if option given" do
    assert {{"testdirs/dogs/wild", [], ["coyote.txt", "wolf.txt"]}, next} =
             Dirwalk.walk("testdirs", topdown: false)

    assert {{"testdirs/dogs/domestic", [], ["dog.txt"]}, next} = next.()
    assert {{"testdirs/dogs", ["wild", "domestic"], []}, next} = next.()
    assert {{"testdirs/cats/wild", [], ["tiger.txt", "lion.txt"]}, next} = next.()
    assert {{"testdirs/cats/domestic", [], ["cat.txt"]}, next} = next.()
    assert {{"testdirs/cats", ["wild", "domestic"], []}, next} = next.()
    assert {{"testdirs", ["dogs", "cats"], []}, next} = next.()
    assert :done = next.()
  end

  test "walks breadth first" do
    assert {{"testdirs", ["dogs", "cats"], []}, next} = Dirwalk.walk("testdirs", search: :breadth)
    assert {{"testdirs/dogs", ["wild", "domestic"], []}, next} = next.()
    assert {{"testdirs/cats", ["wild", "domestic"], []}, next} = next.()
    assert {{"testdirs/dogs/wild", [], ["coyote.txt", "wolf.txt"]}, next} = next.()
    assert {{"testdirs/dogs/domestic", [], ["dog.txt"]}, next} = next.()
    assert {{"testdirs/cats/wild", [], ["tiger.txt", "lion.txt"]}, next} = next.()
    assert {{"testdirs/cats/domestic", [], ["cat.txt"]}, next} = next.()
    assert :done = next.()
  end

  test "by default ignores errors" do
    assert :done = Dirwalk.walk("non_existent_dir")
    assert :done = Dirwalk.walk("non_existent_dir", topdown: false)
  end

  test "invokes on_error/1 with any errors encountered" do
    {:ok, agent} = Agent.start(fn -> [] end)

    Dirwalk.walk("non_existent_dir", on_error: fn error -> Agent.update(agent, &[error | &1]) end)

    assert Agent.get(agent, & &1) == [{"non_existent_dir", :enoent}]
  end

  test "invokes on_error/2 with any errors encountered" do
    {:ok, agent} = Agent.start(fn -> [] end)

    Dirwalk.walk("non_existent_dir",
      on_error: fn path, error -> Agent.update(agent, &["#{path}: #{error}" | &1]) end
    )

    assert Agent.get(agent, & &1) == ["non_existent_dir: enoent"]
  end
end
