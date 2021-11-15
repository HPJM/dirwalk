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
  `walk` takes a directory path and lazily and recursively traverses directories from that root.

  It returns a tuple, consisting of a triple of `{path, directories, files}`, and a `next` function
  to be invoked when the next traversal needs to be done. When there are no more subdirectories
  to handle, `:done` is returned.

  The default behaviour is a depth-first, top-down walk - this can be configured.

  By default errors are silently ignored, though an optional handler can be passed in.

  Options:
  - `:on_error`: optional 1- or 2-arity callback that is invoked with either `path` and `error`
    or a tuple of `{path, error}` when an error occurs
  - `:depth_first`: unless `false`, the walk is depth-first, otherwise breadth-first
  - `:top_down`: unless `false`, the traversal is top-down.

  ## Examples (see `testdirs` structure)

      # Top-down, depth-first
      iex> {{"testdirs", ["dogs", "cats"], []}, next} = Dirwalk.walk("testdirs")
      iex> {{"testdirs/dogs", ["wild", "domestic"], []}, _next} = next.()

      # Bottom-up
      iex> {{"testdirs/dogs/wild", [], ["coyote.txt", "wolf.txt"]}, next} = \
            Dirwalk.walk("testdirs", top_down: false)
      iex> {{"testdirs/dogs/domestic", [], ["dog.txt"]}, _next} = next.()

      # Breadth-first
      iex> {{"testdirs", ["dogs", "cats"], []}, next} = Dirwalk.walk("testdirs", depth_first: false)
      iex> {{"testdirs/dogs", ["wild", "domestic"], []}, next} = next.()
      iex> {{"testdirs/cats", ["wild", "domestic"], []}, _next} = next.()

  """
  @spec walk(path, opts) :: {dirlist, (() -> any())} | :done
  def walk(path, opts \\ []) do
    on_error = Keyword.get(opts, :on_error, & &1)
    depth_first = !!Keyword.get(opts, :depth_first, true)
    top_down = !!Keyword.get(opts, :top_down, true)

    if top_down do
      do_walk([path], on_error, depth_first)
    else
      do_walk_bottom_up([path], on_error, fn -> :done end)
    end
  end

  defp do_walk_bottom_up([], _on_error, next), do: next.()

  defp do_walk_bottom_up([path | remaining_dirs], on_error, next) do
    case get_dirs_and_files(path, on_error) do
      {:ok, {dirs, files}} ->
        dirs
        |> build_child_paths(path)
        |> do_walk_bottom_up(on_error, fn ->
          {{path, dirs, files},
           fn ->
             do_walk_bottom_up(remaining_dirs, on_error, next)
           end}
        end)

      :error ->
        do_walk_bottom_up(remaining_dirs, on_error, next)
    end
  end

  defp do_walk([], _on_error, _depth_first), do: :done

  defp do_walk([path | remaining_dirs], on_error, depth_first) do
    case get_dirs_and_files(path, on_error) do
      {:ok, {dirs, files}} ->
        child_dirs = build_child_paths(dirs, path)

        remaining_dirs =
          if depth_first, do: child_dirs ++ remaining_dirs, else: remaining_dirs ++ child_dirs

        {{path, dirs, files}, fn -> do_walk(remaining_dirs, on_error, depth_first) end}

      :error ->
        do_walk(remaining_dirs, on_error, depth_first)
    end
  end

  defp get_dirs_and_files(path, on_error) do
    case partition_files(path) do
      {:ok, results} ->
        {:ok, results}

      {:error, reason} ->
        call_on_error(on_error, path, reason)
        :error
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

  defp build_child_paths(dirs, path), do: Enum.map(dirs, &Path.join(path, &1))

  defp call_on_error(on_error, path, reason) when is_function(on_error, 2) do
    on_error.(path, reason)
  end

  defp call_on_error(on_error, path, reason) do
    on_error.({path, reason})
  end
end
