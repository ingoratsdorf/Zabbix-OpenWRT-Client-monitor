#!/usr/bin/env lua

local json = require("cjson")  -- Requires cjson, opkg install lua-cjson
local cache_file_path = "/tmp/owrt_client_discovery.maclist.json"
local user_list_path = "./owrt_client_discovery.maclist.txt"
local json_entries = {}

-- Load hostname cache
local function load_cache()
  local cache = {}
  local f = io.open(cache_file_path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    cache = json.decode(content) or {}
  end
  return cache
end

-- Save hostname cache
local function save_cache(cache)
  local f = io.open(cache_file_path, "w")
  if f then
    f:write(json.encode(cache))
    f:close()
  end
end

-- load local cache
local hostname_cache = load_cache()

-- Load DHCP leases into a lookup table
local leases = {}
local lease_file = io.open("/tmp/dhcp.leases", "r")
if lease_file then
  for line in lease_file:lines() do
    local ts, mac, ip, name = line:match("^(%d+)%s+(%S+)%s+(%S+)%s+(%S+)")
    if ip and name and name ~= "*" then
      leases[ip] = name
    end
  end
  lease_file:close()
end


-- try the owrt_client_discovery.maclist.txt file for custom hostnames
-- this file should contain lines like:
-- 00:11:22:33:44:55 mydevice
-- where the first part is the MAC address and the second part is the hostname
-- this allows users to define custom names for devices that may not have a hostname
-- or to override the default hostname resolution
-- the file should be placed in the same directory as this script
-- and should be readable by the user running this script
local hosts = {}
local userdef_file = io.open(user_list_path, "r")
if userdef_file then
  for line in userdef_file:lines() do
    local mac, name = line:match("^(%x+:%x+:%x+:%x+:%x+:%x+)%s+(%S+)")
    if mac and name then
      hosts[string.lower(mac)] = name
    end
  end
  userdef_file:close()
end

-- Run the nlbw command and capture output
local handle = io.popen("sudo nlbw -c csv -n -g mac,ip,fam -q")
local output = handle:read("*a")
handle:close()

-- Split lines
local lines = {}
for line in output:gmatch("[^\r\n]+") do
  if not line:find("00:00:00") then
    table.insert(lines, line)
  end
end

-- Process each line (skip header)
for i = 2, #lines do
  local line = lines[i]
  local fields = {}
  for field in line:gmatch("%S+") do
    table.insert(fields, field)
  end

  local mac = fields[2] or ""
  mac = string.lower(mac)
  local ip = fields[3] or ""
  local hostname = mac

  -- try userdef host mappings first
  local resolved = hosts[mac]

  -- Use cache if available
  if not resolved and hostname_cache[mac] then
    resolved = hostname_cache[mac]
  end

  -- Try to resolve hostname via leases file next
  if not resolved and ip ~= "" then
    resolved = leases[ip] 
  end

  -- if none worked, try lookup (slowest)
  if not resolved or resolved == "" then
    local ns = io.popen("nslookup " .. ip .. " 2>/dev/null")
    local ns_output = ns:read("*a")
    ns:close()
    resolved = ns_output:match("name = ([^%s]+)%.?")
  end
  if resolved and resolved ~= "" then
    hostname = resolved
  else
    hostname = mac
  end

  -- add discovered hostname to the cache
  hostname_cache[mac] = resolved

  local entry = string.format(
    '{"{#NETWORK_CLIENT}":"%s","{#MACADDR}":"%s","{#IPADDR}":"%s"}',
    hostname, mac, ip
  )
  table.insert(json_entries, entry)
end

-- Save updated cache
save_cache(hostname_cache)

-- Output JSON
print('{"data":[' .. table.concat(json_entries, ",\n") .. ']}')