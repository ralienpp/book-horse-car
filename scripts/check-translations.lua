#!/usr/bin/env lua
-- ============================================================
--  check-translations.lua
--  Reports which keys are missing in non-primary languages.
--
--  Missing keys are NOT errors — the build falls back to Romanian
--  and marks them [TODO] in the PDF. This script just makes the
--  TODO debt visible so translators know what needs attention.
--
--  Usage:  texlua scripts/check-translations.lua translations/
--
--  Exit code 0 = all files are complete (no TODOs needed).
--  Exit code 1 = at least one non-primary file has missing keys.
-- ============================================================

local primary = "ro"   -- source / fallback language

local dir = arg[1]
if not dir then
  io.stderr:write("Usage: texlua check-translations.lua <translations-dir>\n")
  os.exit(1)
end

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

-- Keys to skip (metadata, not actual translations)
local skip_keys = { polyglossia_lang = true }

-- Load all translation tables
local tables  = {}
local primary_keys = {}

for _, filepath in ipairs(files) do
  local t = dofile(filepath)
  if type(t) ~= "table" then
    io.stderr:write("ERROR: " .. filepath .. " did not return a table\n")
    os.exit(1)
  end
  local basename = filepath:match("([^/]+)%.lua$")
  local keys = {}
  for k, _ in pairs(t) do
    if not skip_keys[k] then
      keys[k] = true
    end
  end
  tables[basename] = keys
  if basename == primary then
    primary_keys = keys
  end
end

if not next(primary_keys) then
  io.stderr:write("ERROR: primary language '" .. primary .. ".lua' not found or empty\n")
  os.exit(1)
end

-- Sort primary keys for stable output
local sorted_primary = {}
for k in pairs(primary_keys) do
  table.insert(sorted_primary, k)
end
table.sort(sorted_primary)

-- Check each non-primary file against the primary
local total_missing = 0
local any_missing = false

for _, filepath in ipairs(files) do
  local basename = filepath:match("([^/]+)%.lua$")
  if basename ~= primary then
    local keys = tables[basename]
    local missing = {}
    for _, k in ipairs(sorted_primary) do
      if not keys[k] then
        table.insert(missing, k)
      end
    end
    if #missing > 0 then
      any_missing = true
      total_missing = total_missing + #missing
      io.write("TODO in " .. basename .. ".lua (" .. #missing .. " key(s)):\n")
      for _, k in ipairs(missing) do
        io.write("  - " .. k .. "\n")
      end
    end
  end
end

-- Summary
io.write("\n")
io.write("Primary language:  " .. primary .. " (" .. #sorted_primary .. " keys)\n")
io.write("Files checked:     " .. #files .. "\n")
io.write("Total TODO keys:   " .. total_missing .. "\n")
io.write("\n")

if not any_missing then
  io.write("Result: ALL OK — all translations are complete.\n")
  os.exit(0)
else
  io.write("Result: " .. total_missing .. " key(s) need translation.\n")
  io.write("        Missing keys fall back to Romanian with [TODO] marker in the PDF.\n")
  os.exit(1)
end
