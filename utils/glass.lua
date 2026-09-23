-- utils/glass.lua
-- Glass styling + adaptive overlay for wezterm background wallpapers.
-- Ported & trimmed from flash-term's style_presets / scene_presets /
-- overlay_delta_from_hint (8-Sync-Dev/flash-term).
--
-- Three preset styles (neon / ice / mint) × three scenes (focus /
-- cinematic / showcase). The active style controls overlay color, tab
-- hues, and status hues; the active scene controls window/text opacity.
-- Adaptive overlay nudges ±adaptive_strength based on wallpaper hint
-- (bright → less overlay so colors breathe, dark → more so text floats).
--
-- State persists across restarts via utils.state. Reload the config
-- after cycling to see the new look (Ctrl+a r / Ctrl+Shift+F5 by default).

local wezterm = require('wezterm')
local brightness = require('utils.brightness')
local state = require('utils.state')

local M = {}

-- ── Style presets ────────────────────────────────────────────────────────
-- Each style owns: overlay color, base opacity, tab hues, status hues.
-- Tweak a hex value here to retune the entire look.
M.styles = {
   neon_glass = {
      overlay_color = '#0b1220',
      base_opacity = 0.55,
      adaptive_strength = 0.10,
      tab = {
         active_bg = '#24496e',
         active_fg = '#f2feff',
         inactive_bg = '#121d31',
         inactive_fg = '#9badc6',
         hover_bg = '#1a304d',
         hover_fg = '#e6f6ff',
      },
      status = {
         base_bg = '#09101c',
         ws_bg = '#1e40af',
         cwd_bg = '#0f766e',
         proc_bg = '#364152',
      },
   },
   ice_glass = {
      overlay_color = '#0b1521',
      base_opacity = 0.66,
      adaptive_strength = 0.08,
      tab = {
         active_bg = '#27445e',
         active_fg = '#f0f9ff',
         inactive_bg = '#152438',
         inactive_fg = '#8ba1b8',
         hover_bg = '#1f334a',
         hover_fg = '#e0f2fe',
      },
      status = {
         base_bg = '#0b1521',
         ws_bg = '#0369a1',
         cwd_bg = '#0f766e',
         proc_bg = '#334155',
      },
   },
   mint_glass = {
      overlay_color = '#0b1f1a',
      base_opacity = 0.67,
      adaptive_strength = 0.08,
      tab = {
         active_bg = '#21544a',
         active_fg = '#f0fdf4',
         inactive_bg = '#132a24',
         inactive_fg = '#95b8ae',
         hover_bg = '#1a3b33',
         hover_fg = '#dcfce7',
      },
      status = {
         base_bg = '#0b1713',
         ws_bg = '#0f766e',
         cwd_bg = '#047857',
         proc_bg = '#2f4f46',
      },
   },
}

-- ── Scene presets ────────────────────────────────────────────────────────
-- A scene is just a window/text opacity pair.
M.scenes = {
   focus = {
      window_opacity = 0.93,
      text_opacity = 0.90,
   },
   cinematic = {
      window_opacity = 0.89,
      text_opacity = 0.86,
   },
   showcase = {
      window_opacity = 0.84,
      text_opacity = 0.82,
   },
}

-- Ordered lists for cycling.
M.style_order = { 'neon_glass', 'ice_glass', 'mint_glass' }
M.scene_order = { 'focus', 'cinematic', 'showcase' }

---Clamp helper.
---@param value number
---@param min number
---@param max number
---@return number
local function clamp(value, min, max)
   if value < min then return min end
   if value > max then return max end
   return value
end

---Pick the first valid name from (env, persisted, presets).
---@param env_value string|nil
---@param persisted_value string|nil
---@param presets table
---@return string|nil
local function pick_name(env_value, persisted_value, presets)
   if env_value and presets[env_value] then
      return env_value
   end
   if persisted_value and presets[persisted_value] then
      return persisted_value
   end
   return nil
end

---Resolve the active style/scene from env → state-file → default.
---@return string style_name
---@return string scene_name
---@return string overlay_color
---@return number window_opacity
---@return number text_opacity
---@return number adaptive_strength
function M.resolve()
   local env_style = os.getenv('WEZTERM_GLASS_STYLE')
   local env_scene = os.getenv('WEZTERM_GLASS_SCENE')

   local persisted = state.load('current-style', {})

   local style_name = pick_name(env_style, persisted.style, M.styles) or 'neon_glass'
   local scene_name = pick_name(env_scene, persisted.scene, M.scenes) or 'focus'

   local style = M.styles[style_name]
   local scene = M.scenes[scene_name]

   return style_name, scene_name,
      style.overlay_color,
      scene.window_opacity,
      scene.text_opacity,
      style.adaptive_strength
end

---Compute the overlay opacity for a given wallpaper.
---@param bg_path string|nil  wallpaper file path (used for brightness hint)
---@return number opacity in [0, 1]
function M.overlay_opacity(bg_path)
   local style_name, _, _, _, _, adaptive_strength = M.resolve()
   local base = M.styles[style_name].base_opacity

   local hint = brightness.from_path(bg_path)
   local delta = brightness.overlay_delta(hint, adaptive_strength)
   return clamp(base + delta, 0, 1)
end

---Build the layered background table for `background = { ... }`.
---@param bg_path string|nil
---@return table[]
function M.build_background(bg_path)
   if not bg_path or bg_path == '' then
      return {}
   end

   local _, _, overlay_color, _, _, _ = M.resolve()

   return {
      {
         source = { File = bg_path },
         horizontal_align = 'Center',
      },
      {
         source = { Color = overlay_color },
         height = '120%',
         width = '120%',
         vertical_offset = '-10%',
         horizontal_offset = '-10%',
         opacity = M.overlay_opacity(bg_path),
      },
   }
end

---Apply the current glass style to a window — overrides window opacity,
--- text opacity, and re-runs the background builder against the active
--- wallpaper. Safe to call on any window event.
---@param window any WezTerm Window
---@param bg_path string|nil current wallpaper path
function M.apply(window, bg_path)
   local _, _, _, win_opacity, text_opacity, _ = M.resolve()
   local overrides = window:get_config_overrides() or {}
   overrides.background = M.build_background(bg_path)
   overrides.window_background_opacity = win_opacity
   overrides.text_background_opacity = text_opacity
   window:set_config_overrides(overrides)
end

---Cycle to the next style and persist.
---@param window any WezTerm Window
---@param bg_path string|nil
---@return string new_style_name
function M.cycle_style(window, bg_path)
   local persisted = state.load('current-style', {})
   local current = persisted.style or 'neon_glass'
   local idx = 1
   for i, name in ipairs(M.style_order) do
      if name == current then
         idx = i
         break
      end
   end
   local next_idx = (idx % #M.style_order) + 1
   local next_style = M.style_order[next_idx]
   state.save('current-style', { style = next_style, scene = persisted.scene })
   M.apply(window, bg_path)
   wezterm.log_info('glass: style → ' .. next_style)
   return next_style
end

---Cycle to the next scene and persist.
---@param window any WezTerm Window
---@param bg_path string|nil
---@return string new_scene_name
function M.cycle_scene(window, bg_path)
   local persisted = state.load('current-style', {})
   local current = persisted.scene or 'focus'
   local idx = 1
   for i, name in ipairs(M.scene_order) do
      if name == current then
         idx = i
         break
      end
   end
   local next_idx = (idx % #M.scene_order) + 1
   local next_scene = M.scene_order[next_idx]
   state.save('current-style', { style = persisted.style, scene = next_scene })
   M.apply(window, bg_path)
   wezterm.log_info('glass: scene → ' .. next_scene)
   return next_scene
end

---Return the current style + scene for display (e.g. status bar).
---@return string
function M.current_label()
   local style, scene = M.resolve()
   return style .. ' · ' .. scene
end

return M
