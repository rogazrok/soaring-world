-- Single named action map for Soaring's session/menu input, so main.lua and
-- location_controller.lua never read a raw button name independently. This
-- covers session-level (menu/prompt) input only.
--
-- Flight's own per-frame turning/altitude handling in flight.lua is
-- deliberately NOT routed through this: this pass's brief is explicit that
-- flight/camera feel must not change, and flight.lua already reads
-- up/down/left/right/a/b directly for that every frame. FLY and ALTITUDE
-- are still named below so this map documents the complete control surface
-- (as asked for), with a comment at each explaining why it stays a
-- pass-through description rather than something main.lua/location_
-- controller.lua call through.
local M = {}

-- Each action names one or more physical buttons. The same physical button
-- appearing under two action names (e.g. 'a' for both INTERACT and
-- LANDING_CONFIRM) is intentional: they are the same control used for two
-- different session-state meanings, not aliases of one "true" action.
M.ACTIONS = {
  -- Descriptive only -- see the file comment above. flight.lua reads these
  -- buttons directly; nothing here gates or renames that.
  FLY      = { 'up', 'down', 'left', 'right' },
  ALTITUDE = { 'a', 'b' },

  -- Open the landing prompt: LANDING -> CONFIRM (location_controller.lua).
  INTERACT = { 'a' },
  -- Inside the landing prompt (location_controller.lua CONFIRM state):
  LANDING_CONFIRM = { 'a' },   -- accept YES
  PROMPT_CANCEL   = { 'b' },   -- decline / back out of the prompt entirely
  PROMPT_UP       = { 'up', 'left' },
  PROMPT_DOWN     = { 'down', 'right' },

  -- Existing camera control (main.lua), unrelated to cancelling Soaring.
  -- Camera behaviour itself is out of scope for this pass; only listed here
  -- so every session-level button read lives in one map.
  CAMERA_CYCLE = { 'select' },

  -- Diagnostic use of START: dismissing a diagnostic ("SOARING
  -- ERROR") screen when construction/update/draw failed. Not a flight
  -- cancel -- there is no session to cancel out of on that screen.
  DIAGNOSTIC_DISMISS = { 'start' },

  -- START opens the read-only Kanto map over the paused flight.
  START_ACTION  = { 'start' },
  SELECT_ACTION = {},
}

-- True if any button bound to `action` was pressed this frame.
function M.pressed(input, action)
  for _, key in ipairs(M.ACTIONS[action] or {}) do
    if input:wasPressed(key) then return true end
  end
  return false
end

return M
