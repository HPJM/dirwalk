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
    search = Keyword.get(opts, :search)
    do_walk(path, [], on_error, search)
  end

  defp do_walk(path, remaining_dirs, on_error, search) do
    {dirs, files} =
      case partition_files(path) do
        {:ok, results} ->
          results

        {:error, reason} ->
          on_error.({path, reason})
          {[], []}
      end

    fileset = {path, dirs, files}

    remaining_dirs = dirs |> get_siblings(path) |> build_remaining_dirs(remaining_dirs, search)

    {fileset, fn -> next(fileset, remaining_dirs, on_error, search) end}
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
  defp get_siblings(dirs, path), do: dirs |> Enum.map(&Path.join(path, &1))

  defp build_remaining_dirs(siblings, remaining_dirs, :breadth) do
    remaining_dirs ++ siblings
  end

  defp build_remaining_dirs(siblings, remaining_dirs, _search) do
    siblings ++ remaining_dirs
  end

  defp next({_path, _dirs, _files}, [], _on_error, search), do: :done

  defp next({_path, _dirs, _files}, [next_dir | remaining_dirs], on_error, search) do
    do_walk(next_dir, remaining_dirs, on_error, search)
  end
end
