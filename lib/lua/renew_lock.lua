-- KEYS
local key_user_lock = KEYS["user_lock"]
local key_user_tolerance_start = KEYS["user_tolerance_start"]

-- ARGV
local max_locks = tonumber(ARGV["max_locks"])
local lock_id = ARGV["lock_id"]
local now = ARGV["now"]
local ttl = ARGV["ttl"]
local expired_time_limit = tonumber(ARGV["expired_time_limit"])
local tolerance_time_limit = tonumber(ARGV["tolerance_time_limit"])

-- SCRIPT
local tolerance_start_time = redis.call("GET", key_user_tolerance_start)
if tolerance_start_time
  and tonumber(tolerance_start_time) < tolerance_time_limit then
  redis.call("ZREMRANGEBYRANK", key_user_lock, 0, max_locks*-1-1)
end

local created_at = redis.call("ZSCORE", key_user_lock, lock_id)
if not(created_at) or tonumber(created_at) < expired_time_limit then
  return "NOT_FOUND"
else
  redis.call("ZADD", key_user_lock, "XX", now, lock_id)
  redis.call("PEXPIRE", key_user_lock, ttl)
  return "OK"
end
