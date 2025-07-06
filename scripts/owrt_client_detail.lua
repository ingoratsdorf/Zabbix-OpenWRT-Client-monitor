#!/usr/bin/env lua

-- Get the MAC address from the command-line arguments
local args = {...}
local target_mac = args[1]

-- Run the nlbw command and capture output
local handle = io.popen("sudo /usr/sbin/nlbw -c csv -n -g mac -q")
local output = handle:read("*a")
handle:close()

-- Search for the line containing the target MAC address
for line in output:gmatch("[^\r\n]+") do
  if line:find(target_mac, 1, true) then
    print(line)
    break
  end
end
