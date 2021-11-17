defmodule DirwalkTest do
  use ExUnit.Case
  doctest Dirwalk

  @testdir "testdirs"

  describe "walk/1-2" do
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

      Dirwalk.walk("non_existent_dir",
        on_error: fn error -> Agent.update(agent, &[error | &1]) end
      )

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

  describe "new/1-2" do
    test "new/1 returns Dirwalk struct and stores reference to walk call" do
      dirwalk = %Dirwalk{} = Dirwalk.new(@testdir)
      assert dirwalk.results == []
      refute dirwalk.done
      assert {{"testdirs", ["dogs", "cats", "felines"], []}, _next} = dirwalk.next.()
    end

    test "new/2 passes through options" do
      dirwalk = Dirwalk.new(@testdir, top_down: false)
      assert {{"testdirs/dogs/wild", [], ["coyote.txt", "wolf.txt"]}, _next} = dirwalk.next.()
    end
  end

  describe "next/1" do
    test "next/1 calls continuation and stores results" do
      dirwalk = Dirwalk.new(@testdir)

      dirwalk = Dirwalk.next(dirwalk)
      assert dirwalk.results == [{"testdirs", ["dogs", "cats", "felines"], []}]

      dirwalk = Dirwalk.next(dirwalk)

      assert dirwalk.results == [
               {"testdirs/dogs", ["wild", "domestic"], []},
               {"testdirs", ["dogs", "cats", "felines"], []}
             ]
    end

    test "next/1 registers when traversal done" do
      dirwalk = Dirwalk.new("nonexistent")
      refute dirwalk.done

      dirwalk = Dirwalk.next(dirwalk)
      assert dirwalk.done
      # :done shouldn't be stored
      assert dirwalk.results == []
    end
  end

  describe "last/1" do
    test "last/1 returns latest result" do
      dirwalk = @testdir |> Dirwalk.new() |> Dirwalk.next()

      result = Dirwalk.last(dirwalk)
      assert result == {"testdirs", ["dogs", "cats", "felines"], []}
    end

    test "last/1 returns nil if no results yet" do
      dirwalk = Dirwalk.new(@testdir)

      assert Dirwalk.last(dirwalk) == nil
    end
  end

  describe "done?/1" do
    test "done?/1 returns whether traversal done" do
      dirwalk = Dirwalk.new("nonexistent")
      refute Dirwalk.done?(dirwalk)

      dirwalk = Dirwalk.next(dirwalk)
      assert Dirwalk.done?(dirwalk)
    end
  end

  describe "Enumerable" do
    test "implements Enumerable" do
      assert Enumerable.impl_for(%Dirwalk{}) == Enumerable.Dirwalk
    end

    test "can be enumerated" do
      dirwalk = Dirwalk.new(@testdir)

      assert Enum.take(dirwalk, 1) == [{"testdirs", ["dogs", "cats", "felines"], []}]
    end
  end
end
