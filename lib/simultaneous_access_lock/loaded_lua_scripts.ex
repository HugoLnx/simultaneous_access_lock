defmodule SimultaneousAccessLock.LoadedLuaScripts do
  alias SimultaneousAccessLock.CompiledLuaScript
  use GenServer

  def start_link(opts, genserver_opts) do
    GenServer.start_link(__MODULE__, opts, genserver_opts)
  end

  def init(opts) do
    templates = opts[:templates]
    scripts = templates
    |> Enum.reduce(%{}, fn {name, template_path}, loaded_scripts ->
      {:ok, template} = File.read(template_path)
      compiled = CompiledLuaScript.compile(template)
      {:ok, sha1} = Redix.command(:redix, ["SCRIPT", "LOAD", compiled.script])

      loaded_scripts
      |> Map.put(name, %{compiled: compiled, sha1: sha1})
    end)

    {:ok, %{scripts: scripts}}
  end

  def handle_call({:execute, name, args}, _from, %{scripts: scripts}=state) do
    %{compiled: compiled, sha1: sha1} = scripts[name]
    result = Redix.command(:redix, ["EVALSHA", sha1] ++ CompiledLuaScript.eval_args(compiled, args))
    {:reply, result, state}
  end

  def exec(name, args) do
    GenServer.call(:lua_scripts, {:execute, name, args})
  end
end
