-- utils/state.lua
-- Corruption-tolerant state-file loader/saver.
-- Ported from flash-term's state-file pattern (wezterm.lua).
-- State is persisted as plain Lua-returned values in `state/<name>.lua`,
-- loaded with pcall(dofile) so a broken file yields defaults — never a dead
-- terminal. Environment variables win over state files; per-profile variants
-- (`<name>-<profile>.lua`) win over both when WEZTERM_PROFILE is set.

local wezterm = require('wezterm')

local M = {}

local STATE_DIR = wezterm.config_dir .. '/state/'

---@param path string
---@return boolean
local function file_exists(path)
   local f = io.open(path, 'r')
   if f then
      f:close()
      return true
   end
   return false
end

---Ensure state directory exists. Idempotent.
function M.ensure_dir()
   wezterm.run_child_process({ 'mkdir', '-p', STATE_DIR })
end

---Build the on-disk path for a state slot, honouring WEZTERM_PROFILE.
---@param name string slot name (e.g. "current-style")
---@return string path
function M.path(name)
   local profile = os.getenv('WEZTERM_PROFILE')
   if profile and profile ~= '' and profile ~= 'default' then
      local variant = STATE_DIR .. name .. '-' .. profile .. '.lua'
      if file_exists(variant) then
         return variant
      end
   end
   return STATE_DIR .. name .. '.lua'
end

---Load a Lua state file, falling back to a default on any failure.
---@param name string
---@param default any
---@return any
function M.load(name, default)
   local path = M.path(name)
   if not file_exists(path) then
      return default
   end
   local ok, value = pcall(dofile, path)
   if not ok then
      return default
   end
   return value
end

---Atomically write a Lua-returned value to a state file. Creates parent dir
---on first call. Wraps the value in a function so it can be `dofile`d back.
---@param name string
---@param value any  must be representable as a Lua literal
---@return boolean ok
function M.save(name, value)
   M.ensure_dir()
   local path = M.path(name)
   local f, open_err = io.open(path, 'w')
   if not f then
      wezterm.log_error('state.save: cannot open ' .. path .. ': ' .. tostring(open_err))
      return false
   end

   local serialized
   if type(value) == 'string' then
      serialized = string.format('return %q\n', value)
   elseif type(value) == 'number' or type(value) == 'boolean' then
      serialized = 'return ' .. tostring(value) .. '\n'
   elseif type(value) == 'table' then
      -- Hand-rolled formatter limited to flat string/number/boolean tables.
      -- Deeper nesting isn't needed for current state slots.
      local parts = {}
      for k, v in pairs(value) do
         local key = type(k) == 'number' and ('[' .. k .. ']') or string.format('[%q]', tostring(k))
         if type(v) == 'string' then
            table.insert(parts, key .. ' = ' .. string.format('%q', v))
         elseif type(v) == 'number' or type(v) == 'boolean' then
            table.insert(parts, key .. ' = ' .. tostring(v))
         end
      end
      serialized = 'return { ' .. table.concat(parts, ', ') .. ' }\n'
   else
      f:close()
      wezterm.log_error('state.save: unsupported type ' .. type(value))
      return false
   end

   f:write(serialized)
   f:close()
   return true
end

return M
