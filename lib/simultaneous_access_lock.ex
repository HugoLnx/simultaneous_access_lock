defmodule SimultaneousAccessLock do
  alias SimultaneousAccessLock.LoadedLuaScripts

  @ttl Application.get_env(:simultaneous_access_lock, :ttl)
  @five_years :timer.hours(5*366*24)
  @locks_max_configuration 1_000_000

  def get_lock(user_id, max_locks, opts \\ %{}) do
    tolerance_time = opts
    |> Map.get(:tolerance, %{})
    |> Map.get(:milliseconds, @five_years)

    tolerance_max_locks = opts
    |> Map.get(:tolerance, %{})
    |> Map.get(:max_locks, max_locks)

    lock_id = opts
    |> Map.get(:lock_id, create_lock())

    now = :os.system_time(:milli_seconds)
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

  def renew_lock(user_id, lock_id, opts \\ %{}) do
    max_locks = opts
    |> Map.get(:max_locks, @locks_max_configuration)

    tolerance_time = opts
    |> Map.get(:tolerance, %{})
    |> Map.get(:milliseconds, @five_years)

    tolerance_max_locks = opts
    |> Map.get(:tolerance, %{})
    |> Map.get(:max_locks, max_locks)
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
