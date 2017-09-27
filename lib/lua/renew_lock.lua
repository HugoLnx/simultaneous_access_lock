local tolerance_start_time = redis.call("GET", KEYS["user_tolerance_start"])
if tolerance_start_time
	and tonumber(tolerance_start_time) < tonumber(ARGV["tolerance_time_limit"]) then
	redis.call("ZREMRANGEBYRANK", KEYS["user_lock"], 0, tonumber(ARGV["max_locks"])*-1-1)
end

local created_at = redis.call("ZSCORE", KEYS["user_lock"], ARGV["lock_id"])
if not(created_at) or tonumber(created_at) < tonumber(ARGV["expired_time_limit"]) then
	return "NOT_FOUND"
else
	redis.call("ZADD", KEYS["user_lock"], "XX", ARGV["now"], ARGV["lock_id"])
	redis.call("PEXPIRE", KEYS["user_lock"], ARGV["ttl"])
	return "OK"
end
