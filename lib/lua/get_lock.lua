-- KEYS
local key_user_lock = KEYS["user_lock"]
local key_user_tolerance_start = KEYS["user_tolerance_start"]

-- ARGV
local max_locks = tonumber(ARGV["max_locks"])
local new_lock_id = ARGV["new_lock_id"]
local now = ARGV["now"]
local ttl = ARGV["ttl"]
local expired_time_limit = tonumber(ARGV["expired_time_limit"])
local tolerance_time_limit = tonumber(ARGV["tolerance_time_limit"])
local tolerance_max_slots = tonumber(ARGV["tolerance_max_slots"])

-- SCRIPT
local locks_amount = redis.call("ZCOUNT", key_user_lock, expired_time_limit, math.huge)

if locks_amount <= max_locks then
  redis.call("DEL", key_user_tolerance_start)
end

if locks_amount < max_locks then
  redis.call("ZADD", key_user_lock, "NX", now, new_lock_id)
  redis.call("PEXPIRE", key_user_lock, ttl)
  return "OK"
else
  if locks_amount >= tolerance_max_slots then
    return "NO_SLOTS"
  else
    local tolerance_start_time = redis.call("GET", key_user_tolerance_start)
    if tolerance_start_time
      and tonumber(tolerance_start_time) < tolerance_time_limit
      and locks_amount > max_locks then
      return "NO_SLOTS"
    else
      redis.call("ZADD", key_user_lock, "NX", now, new_lock_id)
      redis.call("PEXPIRE", key_user_lock, ttl)
      if not(tolerance_start_time) and locks_amount >= max_locks then
        redis.call("SET", key_user_tolerance_start, now)
      end
      return "OK"
    end
  end
end
