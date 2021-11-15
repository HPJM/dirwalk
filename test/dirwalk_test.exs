defmodule DirwalkTest do
  use ExUnit.Case
  doctest Dirwalk

  @testdir "testdirs"

  test "walks depth first, top-down by default" do
    assert {{"testdirs", ["dogs", "cats", "felines"], []}, next} = Dirwalk.walk(@testdir)
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
             Dirwalk.walk(@testdir, top_down: false)

    assert {{"testdirs/dogs/domestic", [], ["dog.txt"]}, next} = next.()
    assert {{"testdirs/dogs", ["wild", "domestic"], []}, next} = next.()
    assert {{"testdirs/cats/wild", [], ["tiger.txt", "lion.txt"]}, next} = next.()
    assert {{"testdirs/cats/domestic", [], ["cat.txt"]}, next} = next.()
    assert {{"testdirs/cats", ["wild", "domestic"], []}, next} = next.()
    assert {{"testdirs", ["dogs", "cats", "felines"], []}, next} = next.()
    assert :done = next.()
  end

  test "walks breadth first if option specified" do
    assert {{"testdirs", ["dogs", "cats", "felines"], []}, next} =
             Dirwalk.walk(@testdir, depth_first: false)

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
    assert :done = Dirwalk.walk("non_existent_dir", top_down: false)
  end

  test "invokes on_error/1 if passed with any errors encountered" do
    {:ok, agent} = Agent.start(fn -> [] end)

    Dirwalk.walk("non_existent_dir", on_error: fn error -> Agent.update(agent, &[error | &1]) end)

    assert Agent.get(agent, & &1) == [{"non_existent_dir", :enoent}]
  end

  test "invokes on_error/2 if passed with any errors encountered" do
    {:ok, agent} = Agent.start(fn -> [] end)

    Dirwalk.walk("non_existent_dir",
      on_error: fn path, error -> Agent.update(agent, &["#{path}: #{error}" | &1]) end
    )

    assert Agent.get(agent, & &1) == ["non_existent_dir: enoent"]
  end

  test "can follow symlinks" do
    assert {{"testdirs", ["dogs", "cats", "felines"], []}, next} =
             Dirwalk.walk(@testdir, follow_symlinks: true)

    assert {{"testdirs/dogs", ["wild", "domestic"], []}, next} = next.()
    assert {{"testdirs/dogs/wild", [], ["coyote.txt", "wolf.txt"]}, next} = next.()
    assert {{"testdirs/dogs/domestic", [], ["dog.txt"]}, next} = next.()
    assert {{"testdirs/cats", ["wild", "domestic"], []}, next} = next.()
    assert {{"testdirs/cats/wild", [], ["tiger.txt", "lion.txt"]}, next} = next.()
    assert {{"testdirs/cats/domestic", [], ["cat.txt"]}, next} = next.()

    # Symlink followed
    assert {{"testdirs/felines", ["wild", "domestic"], []}, next} = next.()
    assert {{"testdirs/felines/wild", [], ["tiger.txt", "lion.txt"]}, next} = next.()
    assert {{"testdirs/felines/domestic", [], ["cat.txt"]}, next} = next.()
    assert :done = next.()
  end
end
