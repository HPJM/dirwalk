# Dirwalk

A simple-to-use module to help traverse directories in Elixir. Inspired by Python's `os.walk`.

`Dirwalk` enables you to walk directories lazily or greedily. Any of the `Enum` functions can be used as it implements `Enumerable`.

Symlink and error handling are included, as is specifying the order of traversal.

The data structure used to represent the directory listing is a triple / 3-tuple consisting of the current directory, and the subdirectories and files in that directory.

While using `Dirwalk` with `Enum` is normally most convenient, you can use `Dirwalk.walk` directly, and manually call the continuation function when you want to consume the next result. This gives you more control of the traversal. See `Dirwalk.walk` for more info and the full list of options.

## Example: finding empty directories

```elixir
defmodule EmptyDirChecker do
  def run(path) do
    path
    |> Dirwalk.new(on_error: &handle_error/2)
    |> Enum.filter(fn {_path, dirs, files} -> dirs == [] and files == [] end)
    |> Enum.map(&elem(&1, 0))
  end

  def handle_error(path, reason) do
    IO.puts "Could not access #{path}: #{inspect(reason)}"
  end
end
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `dirwalk` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:dirwalk, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/dirwalk](https://hexdocs.pm/dirwalk).

