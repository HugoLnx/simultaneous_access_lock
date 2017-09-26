defmodule SimultaneousAccessLock do
  alias SimultaneousAccessLock.LoadedLuaScripts

  @ttl Application.get_env(:simultaneous_access_lock, :ttl)

  def get_lock(user_id, max_sessions) do
    now = :os.system_time(:milli_seconds)
    session_id = create_session()
    LoadedLuaScripts.exec(:get_lock, %{
      keys: %{user_lock: "lock:#{user_id}"},
      argv: %{
        max_locks: max_sessions,
        now: now,
        ttl: @ttl,
        expired_time_limit: now - @ttl,
        new_session_id: session_id,
      },
    })
    |> case do
      {:ok, "OK"} -> {:ok, session_id}
      _ -> {:error, :no_slots}
    end
  end

  def renew_lock(user_id, session_id) do
    now = :os.system_time(:milli_seconds)
    redis(["EVAL", @renew_lock_script, 1, "lock:#{user_id}", now, @ttl, now-@ttl, session_id])
    LoadedLuaScripts.exec(:renew_lock, %{
      keys: %{user_lock: "lock:#{user_id}"},
      argv: %{
        now: now,
        ttl: @ttl,
        expired_time_limit: now - @ttl,
        session_id: session_id,
      },
    })
    |> case do
      {:ok, "OK"} -> {:ok, session_id}
      _ -> {:error, :not_found}
    end
  end

  defp redis([commands | _] = all_commands) when is_list(commands) do
    Redix.pipeline(:redix, all_commands)
  end

  defp redis(command) do
    Redix.command(:redix, command)
  end

  defp create_session, do: UUID.uuid1()
end
