-- Catppuccin Macchiato (matching Ghostty theme)
-- stylua: ignore
local macchiato = {
   rosewater = '#f4dbd6',
   flamingo  = '#f0c6c6',
   pink      = '#f5bde6',
   mauve     = '#c6a0f6',
   red       = '#ed8796',
   maroon    = '#ee99a0',
   peach     = '#f5a97f',
   yellow    = '#eed49f',
   green     = '#a6da95',
   teal      = '#8bd5ca',
   sky       = '#91d7e3',
   sapphire  = '#7dc4e4',
   blue      = '#8aadf4',
   lavender  = '#b7bdf8',
   text      = '#cad3f5',
   subtext1  = '#b8c0e0',
   subtext0  = '#a5adcb',
   overlay2  = '#939ab7',
   overlay1  = '#8087a2',
   overlay0  = '#6e738d',
   surface2  = '#5b6078',
   surface1  = '#494d64',
   surface0  = '#363a4f',
   base      = '#24273a',
   mantle    = '#1e2030',
   crust     = '#181926',
}

local colorscheme = {
   foreground = macchiato.text,
   background = macchiato.base,
   cursor_bg = macchiato.rosewater,
   cursor_border = macchiato.rosewater,
   cursor_fg = macchiato.crust,
   selection_bg = macchiato.surface2,
   selection_fg = macchiato.text,
   ansi = {
      macchiato.surface1,  -- black
      macchiato.red,       -- red
      macchiato.green,     -- green
      macchiato.yellow,    -- yellow
      macchiato.blue,      -- blue
      macchiato.pink,      -- magenta
      macchiato.teal,      -- cyan
      macchiato.subtext1,  -- white
   },
   brights = {
      macchiato.surface2,  -- bright black
      macchiato.red,       -- bright red
      macchiato.green,     -- bright green
      macchiato.yellow,    -- bright yellow
      macchiato.blue,      -- bright blue
      macchiato.pink,      -- bright magenta
      macchiato.teal,      -- bright cyan
      macchiato.text,      -- bright white
   },
   tab_bar = {
      background = 'rgba(0, 0, 0, 0.4)',
      active_tab = {
         bg_color = macchiato.surface2,
         fg_color = macchiato.text,
      },
      inactive_tab = {
         bg_color = macchiato.surface0,
         fg_color = macchiato.subtext1,
      },
      inactive_tab_hover = {
         bg_color = macchiato.surface0,
         fg_color = macchiato.text,
      },
      new_tab = {
         bg_color = macchiato.base,
         fg_color = macchiato.text,
      },
      new_tab_hover = {
         bg_color = macchiato.mantle,
         fg_color = macchiato.text,
         italic = true,
      },
   },
   visual_bell = macchiato.red,
   indexed = {
      [16] = macchiato.peach,
      [17] = macchiato.rosewater,
   },
   scrollbar_thumb = macchiato.surface2,
   split = macchiato.overlay0,
   compose_cursor = macchiato.flamingo,
}

return colorscheme
