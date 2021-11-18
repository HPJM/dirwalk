defmodule Dirwalk do
  @moduledoc """
  A simple-to-use module to help traverse directories. Interface inspired by Python's `os.walk`.

  `Dirwalk` enables you to walk directories lazily or greedily. Lazy traversal means that the minimum
  amount of work is needed to get the next result, and each next step has to be done explicitly.

  You must provide a startpoint, which is a path on the filesystem. `Dirwalk` will then
  recursively walk across and down subdirectories.

  Symlink and error handling are included. See `Dirwalk.walk` options for alternatives to the
  top-down, depth-first walk done by default.

  The data structure used is a triple / 3-tuple consisting of the current directory, and the
  subdirectories and files in that directory.

  In the most raw form, you can use `Dirwalk.walk`, and manually call the continuation function
  when you want to consume the next result. This gives you control of how much to do.

  ## Using `walk` (see `testdirs` structure in this repo as an example)

      iex> {{"testdirs", ["dogs", "cats", "felines"], []}, next} = Dirwalk.walk("testdirs")
      iex> {{"testdirs/dogs", ["wild", "domestic"], []}, _next} = next.()

  You can also use the struct based approach to simplify this a bit.

  ## Using helper functions

      iex> dirwalk = Dirwalk.new("testdirs") |> Dirwalk.next()
      iex> Dirwalk.results(dirwalk)
      [{"testdirs", ["dogs", "cats", "felines"], []}]

  But because `Dirwalk` implements `Enumerable`, it is probably easier to use `Enum` functions.
  This allows for greedy traversal too.

  ## Using `Enum` functions

      iex> Dirwalk.new("testdirs") |> Enum.take(1)
      [{"testdirs", ["dogs", "cats", "felines"], []}]
  """

  @type path :: String.t()
  @type dirs :: [String.t()]
  @type files :: [String.t()]
  @type dirlist :: {path, dirs, files}
  @type opts :: []

  @type t :: %__MODULE__{}

  defstruct [:next, results: [], done: false]

  @doc """
  Initialises a `Dirwalk` struct. Options are passed through and are the same as in `Dirwalk.walk`
  """
  @spec new(binary, list) :: Dirwalk.t()
  def new(root, opts \\ []) when is_binary(root) do
    %Dirwalk{next: fn -> Dirwalk.walk(root, opts) end}
  end

  @doc """
  Does the next traversal in the file tree. Stores result and handles completion
  """
  @spec next(Dirwalk.t()) :: Dirwalk.t()
  def next(%Dirwalk{next: next, results: results} = dirwalk) do
    case next.() do
      :done -> %Dirwalk{dirwalk | done: true}
      {dirlist, next} -> %Dirwalk{dirwalk | next: next, results: [dirlist | results]}
    end
  end

  @doc """
  Returns whether traversal has finished.
  """
  @spec done?(Dirwalk.t()) :: boolean
  def done?(%Dirwalk{done: done}), do: done

  @doc """
  Returns accumulated results from the traversal.
  """
  @spec results(Dirwalk.t()) :: [dirlist]
  def results(%Dirwalk{results: results}), do: Enum.reverse(results)

  @doc """
  Returns last accumulated result.
  """
  @spec last(Dirwalk.t()) :: nil | :done | dirlist
  def last(%Dirwalk{results: []}), do: nil
  def last(%Dirwalk{results: [head | _tail]}), do: head

  defimpl Enumerable, for: __MODULE__ do
    def count(_dirwalk), do: {:error, __MODULE__}

    def member?(_dirwalk, _value), do: {:error, __MODULE__}

    def slice(_dirwalk), do: {:error, __MODULE__}

    def reduce(_dirwalk, {:halt, acc}, _fun), do: {:halted, acc}

    def reduce(%Dirwalk{} = dirwalk, {:suspend, acc}, fun) do
      {:suspended, acc, &reduce(dirwalk, &1, fun)}
    end

    def reduce(%Dirwalk{} = dirwalk, {:cont, acc}, fun) do
      dirwalk = Dirwalk.next(dirwalk)

      if Dirwalk.done?(dirwalk) do
        {:done, acc}
      else
        last = Dirwalk.last(dirwalk)
        reduce(dirwalk, fun.(last, acc), fun)
      end
    end
  end

  @doc """
  `walk` takes a directory path and lazily and recursively traverses directories from that root.

  It returns a tuple, consisting of a triple of `{path, directories, files}`, and a `next` function
  to be invoked when the next traversal needs to be done. When there are no more subdirectories
  to handle, `:done` is returned.

  The default behaviour is a depth-first, top-down walk - this can be configured.

  By default errors are silently ignored, though an optional handler can be passed in.

  ## Options:
  - `:on_error`: optional 1- or 2-arity callback that is invoked with either `path` and `error`
    or a tuple of `{path, error}` when an error occurs
  - `:depth_first`: unless `false`, the walk is depth-first, otherwise breadth-first
  - `:top_down`: unless `false`, the traversal is top-down.

  ## Examples (see `testdirs` structure)

      # Top-down, depth-first
      iex> {{"testdirs", ["dogs", "cats", "felines"], []}, next} = Dirwalk.walk("testdirs")
      iex> {{"testdirs/dogs", ["wild", "domestic"], []}, _next} = next.()

      # Bottom-up
      iex> {{"testdirs/dogs/wild", [], ["coyote.txt", "wolf.txt"]}, next} = \
            Dirwalk.walk("testdirs", top_down: false)
      iex> {{"testdirs/dogs/domestic", [], ["dog.txt"]}, _next} = next.()

      # Breadth-first
      iex> {{"testdirs", ["dogs", "cats", "felines"], []}, next} = Dirwalk.walk("testdirs", depth_first: false)
      iex> {{"testdirs/dogs", ["wild", "domestic"], []}, next} = next.()
      iex> {{"testdirs/cats", ["wild", "domestic"], []}, _next} = next.()

  """
  @spec walk(path, opts) :: {dirlist, (() -> any())} | :done
  def walk(path, opts \\ []) do
    on_error = Keyword.get(opts, :on_error)
    depth_first = !!Keyword.get(opts, :depth_first, true)
    top_down = !!Keyword.get(opts, :top_down, true)
    follow_symlinks = !!Keyword.get(opts, :follow_symlinks, false)

    opts = %{
      top_down: top_down,
      depth_first: depth_first,
      follow_symlinks: follow_symlinks,
      on_error: on_error
    }

    do_walk([path], opts, fn -> :done end)
  end

  defp do_walk([], _opts, next), do: next.()

  defp do_walk(
         [path | remaining_dirs],
         %{on_error: on_error, follow_symlinks: follow_symlinks} = opts,
         next
       ) do
    if should_list?(path, follow_symlinks) do
      case get_dirs_and_files(path, on_error) do
        {:ok, {dirs, files}} ->
          child_dirs = build_child_paths(dirs, path)

          {next_dirs, next_fun} =
            prepare_continuation({path, dirs, files}, child_dirs, remaining_dirs, opts, next)

          do_walk(next_dirs, opts, next_fun)

        :error ->
          do_walk(remaining_dirs, opts, next)
      end
    else
      do_walk(remaining_dirs, opts, next)
    end
  end

  defp should_list?(_path, _follow_symlinks = true), do: true
  defp should_list?(path, _follow_symlinks = false), do: not symlink?(path)

  defp get_dirs_and_files(path, on_error) do
    case partition_files(path) do
      {:ok, results} ->
        {:ok, results}

      {:error, reason} ->
        maybe_call_on_error(on_error, path, reason)
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

  defp prepare_continuation(
         dirlist,
         child_dirs,
         remaining_dirs,
         %{top_down: true, depth_first: true} = opts,
         next
       ) do
    # Top-down: yield this directory listing first, before recursing on children and siblings
    next_fun = fn ->
      {dirlist, fn -> do_walk(child_dirs ++ remaining_dirs, opts, next) end}
    end

    {[], next_fun}
  end

  defp prepare_continuation(
         dirlist,
         child_dirs,
         remaining_dirs,
         %{top_down: true, depth_first: false} = opts,
         next
       ) do
    next_fun = fn ->
      {dirlist, fn -> do_walk(remaining_dirs ++ child_dirs, opts, next) end}
    end

    {[], next_fun}
  end

  defp prepare_continuation(dirlist, child_dirs, remaining_dirs, %{top_down: false} = opts, next) do
    # Bottom-up: recurse on children dirs first, before yielding this directory's results
    # and only then recurse on siblings
    next_fun = fn ->
      {dirlist,
       fn ->
         do_walk(remaining_dirs, opts, next)
       end}
    end

    {child_dirs, next_fun}
  end

  defp maybe_call_on_error(on_error, path, reason) when is_function(on_error, 2) do
    on_error.(path, reason)
  end

  defp maybe_call_on_error(on_error, path, reason) when is_function(on_error, 1) do
    on_error.({path, reason})
  end

  defp maybe_call_on_error(_on_error, _path, _reason), do: nil

  defp symlink?(path) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :symlink}} ->
        true

      {:ok, _file_stat} ->
        false

      {:error, _reason} ->
        # Error handling will have already been done
        false
    end
  end
end
