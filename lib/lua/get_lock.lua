local locks_amount = redis.call("ZCOUNT", KEYS["user_lock"], ARGV["expired_time_limit"], math.huge)

if locks_amount <= tonumber(ARGV["max_locks"]) then
	redis.call("DEL", KEYS["user_tolerance_start"])
end

if locks_amount < tonumber(ARGV["max_locks"]) then
	redis.call("ZADD", KEYS["user_lock"], "NX", ARGV["now"], ARGV["new_lock_id"])
	redis.call("PEXPIRE", KEYS["user_lock"], ARGV["ttl"])
	return "OK"
else
	if locks_amount >= tonumber(ARGV["tolerance_max_slots"]) then
		return "NO_SLOTS"
	else
		local tolerance_start_time = redis.call("GET", KEYS["user_tolerance_start"])
		if tolerance_start_time
			and tonumber(tolerance_start_time) < tonumber(ARGV["tolerance_time_limit"])
			and locks_amount > tonumber(ARGV["max_locks"]) then
			return "NO_SLOTS"
		else
			redis.call("ZADD", KEYS["user_lock"], "NX", ARGV["now"], ARGV["new_lock_id"])
			redis.call("PEXPIRE", KEYS["user_lock"], ARGV["ttl"])
			if not(tolerance_start_time) and locks_amount >= tonumber(ARGV["max_locks"]) then
				redis.call("SET", KEYS["user_tolerance_start"], ARGV["now"])
			end
			return "OK"
		end
	end
end
