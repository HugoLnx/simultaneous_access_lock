defmodule SimultaneousAccessLock.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      worker(Redix, [[], [name: :redix]]),
      worker(SimultaneousAccessLock.LoadedLuaScripts, [
        [templates: [
            get_lock: "lib/lua/get_lock.lua",
            renew_lock: "lib/lua/renew_lock.lua",
        ]],
        [name: :lua_scripts],
      ]),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SimultaneousAccessLock.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
