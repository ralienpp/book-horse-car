#!/usr/bin/env lua
-- ============================================================
--  check-translations.lua
--  Validates that all translation files define the same set of keys.
--
--  Usage:  lua scripts/check-translations.lua translations/
--
--  Exit code 0 = all files have identical key sets.
--  Exit code 1 = at least one file is missing a key.
-- ============================================================

local dir = arg[1]
if not dir then
  io.stderr:write("Usage: lua check-translations.lua <translations-dir>\n")
  os.exit(1)
end

-- Remove trailing slash for consistency
dir = dir:gsub("/$", "")

-- Discover all .lua files in the directory
local files = {}
local handle = io.popen('ls "' .. dir .. '"/*.lua 2>/dev/null')
if handle then
  for line in handle:lines() do
    table.insert(files, line)
  end
  handle:close()
end

if #files == 0 then
  io.stderr:write("ERROR: No .lua files found in " .. dir .. "/\n")
  os.exit(1)
end

-- Load all translation tables
local tables = {}   -- { filename = { key = true, ... } }
local all_keys = {} -- union of all keys

-- Keys to skip (metadata, not actual translations)
local skip_keys = { polyglossia_lang = true }

for _, filepath in ipairs(files) do
  local t = dofile(filepath)
  if type(t) ~= "table" then
    io.stderr:write("ERROR: " .. filepath .. " did not return a table\n")
    os.exit(1)
  end

  local keys = {}
  for k, _ in pairs(t) do
    if not skip_keys[k] then
      keys[k] = true
      all_keys[k] = true
    end
  end
  tables[filepath] = keys
end

-- Check each file against the union of all keys
local ok = true
local sorted_keys = {}
for k in pairs(all_keys) do
  table.insert(sorted_keys, k)
end
table.sort(sorted_keys)

for _, filepath in ipairs(files) do
  local keys = tables[filepath]
  local missing = {}
  for _, k in ipairs(sorted_keys) do
    if not keys[k] then
      table.insert(missing, k)
    end
  end
  if #missing > 0 then
    ok = false
    local basename = filepath:match("([^/]+)$")
    io.write("MISSING in " .. basename .. ":\n")
    for _, k in ipairs(missing) do
      io.write("  - " .. k .. "\n")
    end
  end
end

-- Summary
io.write("\n")
io.write("Files checked: " .. #files .. "\n")
io.write("Total keys:    " .. #sorted_keys .. "\n")

if ok then
  io.write("Result:        ALL OK — all files have identical key sets.\n")
  os.exit(0)
else
  io.write("Result:        FAIL — some files are missing keys (see above).\n")
  os.exit(1)
end
