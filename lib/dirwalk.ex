defmodule Dirwalk do
  @moduledoc """
  A simple module to help traverse directories.
  """

  @type path :: String.t()
  @type dirs :: [String.t()]
  @type files :: [String.t()]
  @type dirlist :: {path, dirs, files}
  @type opts :: []

  @doc """
  `walk` takes a path startpoint and lazily traverses directories from that root.

  It returns a tuple, consisting of a triple of `{path, directories, files}`, and a `next` function
  to be invoked when the next traversal needs to be done. When there are no more directories
  to handle, `:done` is returned.

  The default behaviour is a depth-first, topdown walk.

  By default errors are silently ignored - see options.

  Options:
  - `:on_error`: optional callback that is invoked with `{path, error_reason}` when an error occurs
  - `:search`: type of search, unless `:breadth` is specified it's depth-first

  ## Examples

      iex> {{"testdirs", ["dogs", "cats"], []}, next} = Dirwalk.walk("testdirs")
      iex> {{"testdirs/dogs", ["wild", "domestic"], []}, _next} = next.()

  """
  @spec walk(path, opts) :: {dirlist, (() -> any())} | :done
  def walk(path \\ __DIR__, opts \\ []) do
    on_error = Keyword.get(opts, :on_error, & &1)
    search = Keyword.get(opts, :search)
    do_walk([path], on_error, search)
  end

  defp do_walk([], _on_error, _search), do: :done

  defp do_walk([path | remaining_dirs], on_error, search) do
    {dirs, files} = get_dirs_and_files(path, on_error)
    remaining_dirs = dirs |> get_siblings(path) |> build_remaining_dirs(remaining_dirs, search)

    {{path, dirs, files}, fn -> do_walk(remaining_dirs, on_error, search) end}
  end

  defp get_dirs_and_files(path, on_error) do
    case partition_files(path) do
      {:ok, results} ->
        results

      {:error, reason} ->
        on_error.({path, reason})
        {[], []}
    end
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
end
