-- picturebook-glossary.lua
-- Parses a CSV glossary file and emits a LaTeX description list.
--
-- CSV schema: src,prefix,word,ipa,dst,meaning
-- IPA/prefix propagation: if a row has empty IPA or prefix, it is filled
-- from another row with the same (src, word) pair.

local M = {}

--- Parse a single CSV line respecting quoted fields.
-- Returns a list of field strings.
local function parse_csv_line(line)
  local fields = {}
  local i = 1
  local n = #line
  while i <= n do
    if line:sub(i, i) == '"' then
      -- Quoted field
      i = i + 1
      local parts = {}
      while i <= n do
        if line:sub(i, i) == '"' then
          if line:sub(i + 1, i + 1) == '"' then
            -- Escaped quote
            parts[#parts + 1] = '"'
            i = i + 2
          else
            -- End of quoted field
            i = i + 1
            break
          end
        else
          parts[#parts + 1] = line:sub(i, i)
          i = i + 1
        end
      end
      fields[#fields + 1] = table.concat(parts)
      -- Skip comma after field
      if i <= n and line:sub(i, i) == ',' then
        i = i + 1
      end
    else
      -- Unquoted field
      local j = line:find(',', i)
      if j then
        fields[#fields + 1] = line:sub(i, j - 1)
        i = j + 1
      else
        fields[#fields + 1] = line:sub(i)
        i = n + 1
      end
    end
  end
  return fields
end

--- Load and parse the glossary CSV.
-- Returns a list of entries filtered by src_lang and dst_lang.
-- Each entry is {prefix=, word=, ipa=, meaning=}.
-- IPA and prefix are propagated from other rows with the same (src, word)
-- if missing.
function M.load(filepath, src_lang, dst_lang)
  local file = io.open(filepath, "r")
  if not file then
    texio.write_nl("WARNING: glossary file not found: " .. filepath)
    return {}
  end

  -- First pass: collect all rows and build lookups
  local all_rows = {}
  local ipa_lookup = {}     -- ipa_lookup[src.."\t"..word] = ipa
  local prefix_lookup = {}  -- prefix_lookup[src.."\t"..word] = prefix
  local header_skipped = false

  for line in file:lines() do
    if not header_skipped then
      header_skipped = true
    else
      local fields = parse_csv_line(line)
      if #fields >= 6 then
        local src = fields[1]
        local prefix = fields[2]
        local word = fields[3]
        local ipa = fields[4]
        local dst = fields[5]
        local meaning = fields[6]
        all_rows[#all_rows + 1] = {
          src = src, prefix = prefix, word = word,
          ipa = ipa, dst = dst, meaning = meaning
        }
        local key = src .. "\t" .. word
        -- Store IPA if present
        if ipa and ipa ~= "" and not ipa_lookup[key] then
          ipa_lookup[key] = ipa
        end
        -- Store prefix if present
        if prefix and prefix ~= "" and not prefix_lookup[key] then
          prefix_lookup[key] = prefix
        end
      end
    end
  end
  file:close()

  -- Second pass: filter and propagate IPA/prefix
  local entries = {}
  for _, row in ipairs(all_rows) do
    if row.src == src_lang and row.dst == dst_lang and row.meaning ~= "" then
      local key = row.src .. "\t" .. row.word
      local ipa = row.ipa
      if not ipa or ipa == "" then
        ipa = ipa_lookup[key] or ""
      end
      local prefix = row.prefix
      if not prefix or prefix == "" then
        prefix = prefix_lookup[key] or ""
      end
      entries[#entries + 1] = {
        prefix = prefix, word = row.word, ipa = ipa, meaning = row.meaning
      }
    end
  end

  return entries
end

--- Escape special LaTeX characters in a string.
local function escape_latex(s)
  -- Remap Romanian ț/Ț (comma-below) to ţ/Ţ (cedilla) for fonts lacking them
  s = s:gsub("ț", "ţ"):gsub("Ț", "Ţ")
  s = s:gsub("\\", "\\textbackslash{}")
  s = s:gsub("{", "\\{")
  s = s:gsub("}", "\\}")
  s = s:gsub("%$", "\\$")
  s = s:gsub("&", "\\&")
  s = s:gsub("#", "\\#")
  s = s:gsub("%%", "\\%%")
  s = s:gsub("_", "\\_")
  s = s:gsub("%^", "\\^{}")
  s = s:gsub("~", "\\textasciitilde{}")
  return s
end

--- Emit the glossary as LaTeX.
-- Called from \directlua inside the \printglossary macro.
-- Uses a compact one-entry-per-line format with no list overhead.
-- Each entry is a paragraph with hanging indent for wrapped lines.
function M.emit(filepath, src_lang, dst_lang)
  local entries = M.load(filepath, src_lang, dst_lang)

  if #entries == 0 then
    -- No data for this language pair; emit nothing
    return
  end

  local BS = string.char(92)
  local out = {}

  out[#out + 1] = "{" .. BS .. "scriptsize"
  out[#out + 1] = BS .. "setlength{" .. BS .. "parskip}{2pt}"
  out[#out + 1] = BS .. "setlength{" .. BS .. "parindent}{0pt}"
  out[#out + 1] = BS .. "setlength{" .. BS .. "baselineskip}{8pt}"
  out[#out + 1] = BS .. "begin{multicols}{2}"
  out[#out + 1] = BS .. "raggedright"

  for _, entry in ipairs(entries) do
    local label
    if entry.prefix ~= "" then
      label = escape_latex(entry.prefix) .. " " .. BS .. "textbf{" .. escape_latex(entry.word) .. "}"
    else
      label = BS .. "textbf{" .. escape_latex(entry.word) .. "}"
    end
    local meaning_esc = escape_latex(entry.meaning)
    local item
    if entry.ipa ~= "" then
      local ipa_esc = escape_latex(entry.ipa)
      item = label .. " ({" .. BS .. "fontspec{Charis SIL}" .. ipa_esc .. "}) " .. BS .. "textemdash{} " .. meaning_esc
    else
      item = label .. " " .. BS .. "textemdash{} " .. meaning_esc
    end
    out[#out + 1] = item .. BS .. "par"
  end

  out[#out + 1] = BS .. "end{multicols}"
  out[#out + 1] = "}"

  tex.print(out)
end

return M
