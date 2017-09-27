defmodule SimultaneousAccessLock do
  alias SimultaneousAccessLock.LoadedLuaScripts

  @ttl Application.get_env(:simultaneous_access_lock, :ttl)

  def get_lock(user_id, max_locks) do
    get_lock(user_id, max_locks, tolerance: %{milliseconds: 1000, max_locks: max_locks})
  end

  def get_lock(user_id, max_locks, tolerance: %{milliseconds: tolerance_time, max_locks: tolerance_max_locks}) do
    now = :os.system_time(:milli_seconds)
    lock_id = create_lock()
    LoadedLuaScripts.exec(:get_lock, %{
      keys: %{
        user_lock: "lock:#{user_id}",
        user_tolerance_start: "locks:#{user_id}:tolerance-start",
      },
      argv: %{
        max_locks: max_locks,
        now: now,
        ttl: @ttl,
        expired_time_limit: now - @ttl,
        new_lock_id: lock_id,
        tolerance_max_slots: tolerance_max_locks,
        tolerance_time_limit: now - tolerance_time,
      },
    })
    |> case do
      {:ok, "OK"} -> {:ok, lock_id}
      _ -> {:error, :no_slots}
    end
  end

  def renew_lock(user_id, lock_id) do
    renew_lock(user_id, lock_id, max_locks: 99, tolerance: %{milliseconds: 100, max_locks: 99})
  end

  def renew_lock(user_id, lock_id, max_locks: max_locks, tolerance: %{milliseconds: tolerance_time}) do
    now = :os.system_time(:milli_seconds)
    LoadedLuaScripts.exec(:renew_lock, %{
      keys: %{
        user_lock: "lock:#{user_id}",
        user_tolerance_start: "locks:#{user_id}:tolerance-start",
      },
      argv: %{
        now: now,
        ttl: @ttl,
        expired_time_limit: now - @ttl,
        lock_id: lock_id,
        tolerance_time_limit: now - tolerance_time,
        max_locks: max_locks,
      },
    })
    |> case do
      {:ok, "OK"} -> {:ok, lock_id}
      _ -> {:error, :not_found}
    end
  end

  defp create_lock, do: UUID.uuid1()
end
