-- utils/brightness.lua
-- Infer whether a wallpaper is bright / dark / neutral from its filename.
-- Ported from flash-term's `infer_bg_hint_from_path` (8-Sync-Dev/flash-term).
-- Cheap filename heuristic — no PNG parsing needed. Returns one of
--   "bright" | "dark" | "neutral"
-- so the glass module can nudge its overlay opacity by ±adaptive_strength.

local M = {}

-- Lowercase tokens that signal a bright wallpaper (light source dominant).
-- Order is irrelevant — we return on the FIRST match in this list, so put
-- common bright signals first. A filename like `pastel-samurai.jpg` matches
-- `pastel` first and is classified as bright even though "samurai" is also
-- in the dark list. This biases toward "treat as bright" when ambiguous,
-- since text contrast on a near-white background is harder to fix than on
-- a dark one (you can always add more overlay opacity to fight a dark bg).
local BRIGHT_TOKENS = {
   'bright', 'light', 'snow', 'day', 'white', 'sun', 'sky', 'dawn',
   'morning', 'cloud', 'sakura', 'pastel', 'house',
}

-- Lowercase tokens that signal a dark wallpaper (low-key or high-contrast).
local DARK_TOKENS = {
   'dark', 'night', 'moon', 'space', 'black', 'neon', 'samurai',
   'angry', 'lava', 'jelly', 'final', 'frieren', 'totoro', 'astro',
   'quasar', '5-cm', 'sword', 'voyage', 'sunset', 'cherry',
}

---@param path string|nil absolute path or basename of wallpaper file
---@return 'bright'|'dark'|'neutral'
function M.from_path(path)
   if not path or path == '' then
      return 'neutral'
   end

   -- basename only — directories are noisy and tokens like "/day/" in
   -- parent paths would false-positive on dark files.
   local basename = path:match('([^/\\]+)$') or path
   local lowered = string.lower(basename)

   for _, token in ipairs(BRIGHT_TOKENS) do
      if lowered:find(token, 1, true) then
         return 'bright'
      end
   end

   for _, token in ipairs(DARK_TOKENS) do
      if lowered:find(token, 1, true) then
         return 'dark'
      end
   end

   return 'neutral'
end

---@param hint 'bright'|'dark'|'neutral'
---@param strength number magnitude of the delta (0..1)
---@return number signed delta: +strength / -strength / 0
function M.overlay_delta(hint, strength)
   if hint == 'bright' then
      return strength
   end
   if hint == 'dark' then
      return -strength
   end
   return 0
end

return M
