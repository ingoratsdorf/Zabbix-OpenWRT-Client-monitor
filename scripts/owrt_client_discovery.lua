#!/usr/bin/env lua

local json_entries = {}

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

-- try the userde.txt file for custom hostnames
-- this file should contain lines like:
-- 00:11:22:33:44:55 mydevice
-- where the first part is the MAC address and the second part is the hostname
-- this allows users to define custom names for devices that may not have a hostname
-- or to override the default hostname resolution
-- the file should be placed in the same directory as this script
-- and should be readable by the user running this script
local hosts = {}
local userdef_file = io.open("userdef.txt", "r")
if userdef_file then
  for line in userdef_file:lines() do
    local mac, name = line:match("^(%S+)%s+(%S+)")
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

  local entry = string.format(
    '{"{#NETWORK_CLIENT}":"%s","{#MACADDR}":"%s","{#IPADDR}":"%s"}',
    hostname, mac, ip
  )
  table.insert(json_entries, entry)
end

-- Output JSON
print('{"data":[' .. table.concat(json_entries, ",") .. ']}')