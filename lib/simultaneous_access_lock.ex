defmodule SimultaneousAccessLock do
  @ttl Application.get_env(:simultaneous_access_lock, :ttl)

  def get_lock(user_id, max_sessions) do
    now = :os.system_time(:milli_seconds)
    {:ok, sessions_amount} = redis(["ZCOUNT", "lock:#{user_id}", now-@ttl, "+inf"])
    if sessions_amount < max_sessions do
      session = create_session()
      redis([
        ["ZADD", "lock:#{user_id}", "NX", now, session],
        ["PEXPIRE", "lock:#{user_id}", @ttl],
      ])
      {:ok, session}
    else
      {:error, :no_slots}
    end
  end

  def renew_lock(user_id, session_id) do
    now = :os.system_time(:milli_seconds)
    {:ok, created_at} = redis(["ZSCORE", "lock:#{user_id}", session_id])
    created_at = String.to_integer(created_at || "0")
    if created_at > now - @ttl do
      redis([
        ["ZADD", "lock:#{user_id}", "XX", now, session_id],
        ["PEXPIRE", "lock:#{user_id}", @ttl],
      ])
      {:ok, session_id}
    else
      {:error, :not_found}
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
