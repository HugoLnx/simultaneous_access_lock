local created_at = redis.call("ZSCORE", KEYS["user_lock"], ARGV["session_id"])
if created_at and tonumber(created_at) > tonumber(ARGV["expired_time_limit"]) then
	redis.call("ZADD", KEYS["user_lock"], "XX", ARGV["now"], ARGV["session_id"])
	redis.call("PEXPIRE", KEYS["user_lock"], ARGV["ttl"])
	return "OK"
else
	return "NOT_FOUND"
end
