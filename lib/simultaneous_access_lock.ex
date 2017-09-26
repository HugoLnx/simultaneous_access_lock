defmodule SimultaneousAccessLock do
  alias SimultaneousAccessLock.LoadedLuaScripts

  @ttl Application.get_env(:simultaneous_access_lock, :ttl)

  def get_lock(user_id, max_locks) do
    now = :os.system_time(:milli_seconds)
    lock_id = create_lock()
    LoadedLuaScripts.exec(:get_lock, %{
      keys: %{user_lock: "lock:#{user_id}"},
      argv: %{
        max_locks: max_locks,
        now: now,
        ttl: @ttl,
        expired_time_limit: now - @ttl,
        new_lock_id: lock_id,
      },
    })
    |> case do
      {:ok, "OK"} -> {:ok, lock_id}
      _ -> {:error, :no_slots}
    end
  end

  def renew_lock(user_id, lock_id) do
    now = :os.system_time(:milli_seconds)
    LoadedLuaScripts.exec(:renew_lock, %{
      keys: %{user_lock: "lock:#{user_id}"},
      argv: %{
        now: now,
        ttl: @ttl,
        expired_time_limit: now - @ttl,
        lock_id: lock_id,
      },
    })
    |> case do
      {:ok, "OK"} -> {:ok, lock_id}
      _ -> {:error, :not_found}
    end
  end

  defp create_lock, do: UUID.uuid1()
end
