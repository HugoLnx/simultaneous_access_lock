defmodule SimultaneousAccessLock.CompiledLuaScript do
  require Logger

  defstruct script: nil, argv_names: nil, keys_names: nil

  def compile(script_template) do
    argv_names = script_template |> scan_for_names("ARGV")
    keys_names = script_template |> scan_for_names("KEYS")
    script = script_template
    |> replace_names("ARGV", argv_names)
    |> replace_names("KEYS", keys_names)
    %__MODULE__{script: script, argv_names: argv_names, keys_names: keys_names}
  end

  def eval_args(%__MODULE__{argv_names: argv_names, keys_names: keys_names}, %{argv: argv, keys: keys}) do
    validate_args("argv", argv_names, argv)
    validate_args("keys", keys_names, keys)
    [length(keys_names)] ++ args_list_for(keys_names, keys) ++ args_list_for(argv_names, argv)
  end

  defp args_list_for(names, args) do
    names
    |> Enum.map(&String.to_atom/1)
    |> Enum.map(fn name -> Map.get(args, name, nil) end)
  end

  defp scan_for_names(script_template, table_name) do
    ~r{#{table_name}\[["']([^'"\]]*)["']\]}
    |> Regex.scan(script_template)
    |> Enum.map(&List.last/1)
    |> List.flatten
    |> Enum.uniq
  end

  defp replace_names(script_template, table_name, names) do
    names
    |> Enum.with_index
    |> Enum.reduce(script_template, fn {name, i}, script_template ->
      ~r{#{table_name}\[["']#{name}["']\]}
      |> Regex.replace(script_template, "#{table_name}[#{i+1}]")
    end)
  end

  defp validate_args(args_name, names, args) do
    names = names
    |> Enum.map(&String.to_atom/1)
    |> MapSet.new

    args = args
    |> Map.keys
    |> MapSet.new

    missing_args = MapSet.difference(names, args)
    unless Enum.empty?(missing_args) do
      msg = "RedisScriptCallError: Expected #{args_name} to include #{Enum.join(missing_args, ", ")}"
      Logger.error(msg)
      raise ArgumentError, msg
    end
  end
end
