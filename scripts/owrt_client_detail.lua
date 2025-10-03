#!/usr/bin/env lua

-- Get the MAC address from the command-line arguments
local args = {...}
local target_mac = args[1]
local field_index = tonumber(args[2])

-- Error out if args are missin from command-line
if not target_mac or not field_index then
  io.stderr:write("Error: Missing MAC address or field index\n")
  os.exit(1)
end

-- Run the nlbw command and capture output
local handle = io.popen("sudo /usr/sbin/nlbw -c csv -n -g mac -q")
local output = handle:read("*a")
handle:close()

-- Search for the line containing the target MAC address
for line in output:gmatch("[^\r\n]+") do
  if line:find(target_mac, 1, true) then
    -- Split the line by tabs into fields
    local fields = {}
    for field in line:gmatch("[^\t]+") do
      table.insert(fields, field)
    end
    -- Convert the value to number
    local value = fields[field_index]
    if value then
      local num = tonumber(value)
      if num then
        print(num)
      else
        io.stderr:write("Error: Field is not numeric\n")
        os.exit(1)
      end
    -- Print the selected field if it exists, else error out
    else
      io.stderr:write("Error: Field index out of range\n")
      os.exit(1)
    end

    break
  end
end
