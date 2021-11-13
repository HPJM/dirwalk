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
  def walk(path \\ __DIR__, opts \\ []) do
    on_error = Keyword.get(opts, :on_error, & &1)
    do_walk(path, [], on_error)
  end

  defp do_walk(path, remaining_dirs, on_error) do
    {dirs, files} =
      case partition_files(path) do
        {:ok, results} ->
          results

        {:error, reason} ->
          on_error.({path, reason})
          {[], []}
      end

    fileset = {path, dirs, files}

    {fileset, fn -> next(fileset, get_siblings(dirs, path) ++ remaining_dirs, on_error) end}
  end

  defp partition_files(path) do
    path
    |> File.ls()
    |> case do
      {:ok, files} ->
        {:ok, Enum.split_with(files, fn f -> path |> Path.join(f) |> File.dir?() end)}

      {:error, _reason} = error ->
        error
    end
  end

  defp get_siblings([], _path), do: []
  defp get_siblings(dirs, path), do: dirs |> tl |> Enum.map(&Path.join(path, &1))

  defp next({_path, [], _files}, [], _on_error), do: :done

  defp next({_path, [], _files}, [next_dir | remaining_dirs], on_error) do
    do_walk(next_dir, remaining_dirs, on_error)
  end

  defp next({path, [dir | _dirs], _files}, remaining_dirs, on_error) do
    path
    |> Path.join(dir)
    |> do_walk(remaining_dirs, on_error)
  end
end
