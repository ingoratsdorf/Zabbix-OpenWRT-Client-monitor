#!/usr/bin/env lua

local json_entries = {}

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
  local ip = fields[3] or ""
  local hostname = mac

  if ip ~= "" then
    local ns = io.popen("nslookup " .. ip)
    local ns_output = ns:read("*a")
    ns:close()

    local name = ns_output:match("name = ([^%s]+)%.?")
    if name and name ~= "" then
      hostname = name
    end
  end

  local entry = string.format(
    '{"{#NETWORK_CLIENT}":"%s","{#MACADDR}":"%s","{#IPADDR}":"%s"}',
    hostname, mac, ip
  )
  table.insert(json_entries, entry)
end

-- Output JSON
print('{"data":[' .. table.concat(json_entries, ",") .. ']}')
