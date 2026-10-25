-- Run with: wrk -t4 -c100 -d30s -s wrk.lua http://localhost:8000

local alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
local key_length = 24
local payload_size = 5 * 1024
local payload
local pending_get
local next_thread_id = 1

local function random_string(length)
  local chars = {}
  for i = 1, length do
    local index = math.random(#alphabet)
    chars[i] = alphabet:sub(index, index)
  end
  return table.concat(chars)
end

function setup(thread)
  thread:set("id", next_thread_id)
  next_thread_id = next_thread_id + 1
end

function init()
  math.randomseed(os.time() + id * 1000)
  payload = random_string(payload_size)
end

function request()
  if pending_get then
    local path = pending_get
    pending_get = nil
    return wrk.format("GET", path)
  end

  pending_get = "/" .. random_string(key_length)
  return wrk.format("POST", pending_get, {
    ["Content-Type"] = "application/x-www-form-urlencoded",
  }, payload)
end
