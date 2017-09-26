local sessions_amount = redis.call("ZCOUNT", KEYS["user_lock"], ARGV["expired_time_limit"], math.huge)
if sessions_amount < tonumber(ARGV["max_locks"]) then
	redis.call("ZADD", KEYS["user_lock"], "NX", ARGV["now"], ARGV["new_session_id"])
	redis.call("PEXPIRE", KEYS["user_lock"], ARGV["ttl"])
	return "OK"
else
	return "NO_SLOTS"
end
