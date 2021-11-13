defmodule DirwalkTest do
  use ExUnit.Case

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
end
