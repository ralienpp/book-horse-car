pb_script_fonts = {
  tamil    = { serif = "Noto Serif Tamil",       sans = "Noto Sans Tamil",       mono = "FreeSerif" },
  bengali  = { serif = "Noto Serif Bengali",     sans = "Noto Sans Bengali",     mono = "FreeSerif" },
  hindi    = { serif = "Noto Serif Devanagari",  sans = "Noto Sans Devanagari",  mono = "FreeSerif" },
  persian  = { serif = "Amiri",                  sans = "Noto Naskh Arabic",     mono = "FreeSerif" },
  chinese  = { serif = "AR PL UMing CN",         sans = "AR PL UMing CN",        mono = "AR PL UMing CN",
               cjk   = true },
}
pb_rtl_langs = { persian = true, arabic = true, hebrew = true }

function pb_setup_script_fonts(lang)
  local f = pb_script_fonts[lang]
  if not f then return end
  local bs = string.char(92)
  local ob = string.char(123)
  local cb = string.char(125)
  -- CJK languages need luatexja for inter-character line breaking.
  -- luatexja-fontspec also sets the CJK font so luatexja uses ours,
  -- not its own Japanese defaults.
  if f.cjk then
    tex.print(bs.."RequirePackage"..ob.."luatexja-fontspec"..cb)
    tex.print(bs.."setmainjfont"..ob..f.serif..cb)
    tex.print(bs.."setsansjfont"..ob..f.sans..cb)
  end
  tex.print(bs.."newfontfamily"..ob..bs..lang.."font"..cb..ob..f.serif..cb)
  tex.print(bs.."newfontfamily"..ob..bs..lang.."fontsf"..cb..ob..f.sans..cb)
  tex.print(bs.."newfontfamily"..ob..bs..lang.."fonttt"..cb..ob..f.mono..cb)
end
