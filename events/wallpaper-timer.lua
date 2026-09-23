-- events/wallpaper-timer.lua
-- Auto-cycle the wezterm background wallpaper at a fixed interval.
-- Driven by `wezterm.time.call_after()` so the schedule is wall-clock
-- based and keeps firing even when no window is focused (the previous
-- `update-status` render-loop approach paused whenever wezterm wasn't
-- being painted, which left the wallpaper stuck for hours at a time).
-- Ported in spirit from flash-term's wallpaper loop
-- (8-Sync-Dev/flash-term).

local wezterm = require('wezterm')

-- Try wezterm.time (C plugin, requires allow_builtin_plugins = true).
-- Fall back to wezterm.call_after. If neither is available, M.setup
-- will pcall-wrap itself so wallpaper-timer failing never blocks
-- wezterm.lua from loading the rest of the config.
local ok_time, time = pcall(require, 'wezterm.time')
if not ok_time then
   time = wezterm.call_after and { call_after = wezterm.call_after } or nil
   if time then
      wezterm.log_warn('wallpaper-timer: wezterm.time unavailable, using wezterm.call_after')
   else
      wezterm.log_warn('wallpaper-timer: no timer API available, wallpaper cycling disabled')
   end
end

local M = {}

---@class WallpaperTimerOptions
---@field interval number  seconds between cycles. Default 300 (5 min).
---@field mode 'forward'|'random'|'cycle'  how to advance. Default 'random'.
---@field only_when_focused boolean  pause cycling while no window is focused. Default false.

local opts = {
   interval = 300,
   mode = 'random',
   only_when_focused = false,
}

---Pick the next wallpaper path using utils.backdrops, then re-apply the
---current glass style so the adaptive overlay recalculates against the
---new image. Falls back to direct backdrop call if glass isn't loaded.
---@param window any WezTerm Window
---@return string|nil path
local function advance(window)
   local ok_back, backdrops = pcall(require, 'utils.backdrops')
   if not ok_back or type(backdrops) ~= 'table' then
      wezterm.log_warn('wallpaper-timer: utils.backdrops not available')
      return nil
   end

   local path
   if opts.mode == 'forward' and backdrops.cycle_forward then
      backdrops.cycle_forward(window)
      path = backdrops.images and backdrops.images[backdrops.current_idx]
   elseif backdrops.random then
      backdrops.random(window)
      path = backdrops.images and backdrops.images[backdrops.current_idx]
   else
      return nil
   end

   -- Re-apply glass styling so the new wallpaper's brightness hint
   -- recomputes the overlay opacity (adaptive overlay).
   local ok_glass, glass = pcall(require, 'utils.glass')
   if ok_glass and type(glass) == 'table' and glass.apply then
      glass.apply(window, path)
   end

   if path then
      wezterm.log_info(string.format('wallpaper-timer: → %s', path))
   end
   return path
end

---Re-schedule the next advance. Recursive one-shot via call_after so the
---schedule is wall-clock based and keeps ticking regardless of whether any
---wezterm window is currently focused or being rendered.
---@private
local function schedule_next()
   time.call_after(opts.interval, function()
      -- Enumerate every mux window and apply the new backdrop to each one.
      -- wezterm.mux.all_windows() returns a list of Window objects (added in
      -- 20230408+); pcall guards against older builds where the method is
      -- missing so a broken wezterm still loads.
      local windows = {}
      local ok, win_list = pcall(function()
         return wezterm.mux.all_windows()
      end)
      if ok and type(win_list) == 'table' then
         for _, win in ipairs(win_list) do
            windows[win] = true
         end
      end

      if next(windows) == nil then
         -- No windows exist (e.g. headless / config-reload race). Just
         -- re-schedule so we keep trying.
         schedule_next()
         return
      end

      for win in pairs(windows) do
         if opts.only_when_focused then
            if win.is_focused and not win:is_focused() then
               -- At least one window exists but none are focused — defer.
               schedule_next()
               return
            end
         end
         advance(win)
      end

      -- Always re-schedule so the cycle continues; if all windows close,
      -- next setup() will restart the chain.
      schedule_next()
   end)
end

---Start the wallpaper timer. Idempotent — safe to call once per setup.
---@param user_opts WallpaperTimerOptions|nil
M.setup = function(user_opts)
   -- Guard: if no timer API is available at all, log and bail out cleanly.
   -- This prevents wallpaper-timer from crashing the entire config load.
   if not time then
      wezterm.log_warn('wallpaper-timer: setup skipped — no timer API')
      return
   end

   if user_opts then
      for k, v in pairs(user_opts) do
         opts[k] = v
      end
   end

   wezterm.log_info(string.format(
      'wallpaper-timer: setup interval=%ds mode=%s',
      opts.interval, opts.mode
   ))

   -- First advance after INTERVAL seconds (not at load time).
   schedule_next()
end

---Force the next pick immediately (useful for tests / manual trigger).
M.advance_now = function(window)
   advance(window)
end

return M
