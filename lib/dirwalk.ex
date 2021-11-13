defmodule Dirwalk do
  @moduledoc """
  Documentation for `Dirwalk`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Dirwalk.hello()
      :world

  """
  def walk(path \\ __DIR__) do
    do_walk(path, [])
  end

  defp do_walk(path, remaining_dirs) do
    {dirs, files} = partition_files(path)
    fileset = {path, dirs, files}

    {fileset, fn -> next(fileset, get_siblings(dirs, path) ++ remaining_dirs) end}
  end

  defp partition_files(path) do
    path
    |> File.ls!()
    |> Enum.split_with(fn f -> path |> Path.join(f) |> File.dir?() end)
  end

  defp get_siblings([], _path), do: []
  defp get_siblings(dirs, path), do: dirs |> tl |> Enum.map(&Path.join(path, &1))

  defp next({_path, [], _files}, []), do: :done

  defp next({_path, [], _files}, [next_dir | remaining_dirs]) do
    do_walk(next_dir, remaining_dirs)
  end

  defp next({path, [dir | _dirs], _files}, remaining_dirs) do
    path
    |> Path.join(dir)
    |> do_walk(remaining_dirs)
  end
end
