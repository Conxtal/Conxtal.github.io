--[[
	InputBuffer.lua
	Handles input buffering for tight combo windows

	FEATURES:
	- Buffer inputs during recovery
	- Hold vs tap detection
	- Input queueing
	- Prevents input loss during animations
]]

local InputBuffer = {}

-- ==============================
-- STATE
-- ==============================

local BufferedInputs = {}  -- [player] = { action, timestamp, data }
local InputHoldState = {}  -- [player][keycode] = { pressed, timestamp }

-- ==============================
-- CONSTANTS
-- ==============================

local BUFFER_WINDOW = 0.20  -- How long to buffer inputs
local HOLD_THRESHOLD = 0.15  -- Minimum time to count as "hold"

-- ==============================
-- BUFFERING
-- ==============================

function InputBuffer.Buffer(player, action, data)
	BufferedInputs[player] = {
		action = action,
		timestamp = tick(),
		data = data or {}
	}
end

function InputBuffer.GetBuffered(player)
	local buffered = BufferedInputs[player]
	if not buffered then return nil end

	-- Check if buffer expired
	if tick() - buffered.timestamp > BUFFER_WINDOW then
		BufferedInputs[player] = nil
		return nil
	end

	return buffered
end

function InputBuffer.ConsumeBuffered(player)
	local buffered = InputBuffer.GetBuffered(player)
	BufferedInputs[player] = nil
	return buffered
end

function InputBuffer.ClearBuffer(player)
	BufferedInputs[player] = nil
end

function InputBuffer.HasBuffered(player)
	return InputBuffer.GetBuffered(player) ~= nil
end

-- ==============================
-- HOLD DETECTION
-- ==============================

function InputBuffer.OnKeyDown(player, keyCode)
	if not InputHoldState[player] then
		InputHoldState[player] = {}
	end

	InputHoldState[player][keyCode] = {
		pressed = true,
		timestamp = tick()
	}
end

function InputBuffer.OnKeyUp(player, keyCode)
	if not InputHoldState[player] then return end

	InputHoldState[player][keyCode] = nil
end

function InputBuffer.IsHeld(player, keyCode)
	if not InputHoldState[player] then return false end

	local state = InputHoldState[player][keyCode]
	if not state or not state.pressed then return false end

	local holdTime = tick() - state.timestamp
	return holdTime >= HOLD_THRESHOLD
end

function InputBuffer.GetHoldDuration(player, keyCode)
	if not InputHoldState[player] then return 0 end

	local state = InputHoldState[player][keyCode]
	if not state or not state.pressed then return 0 end

	return tick() - state.timestamp
end

function InputBuffer.IsKeyDown(player, keyCode)
	if not InputHoldState[player] then return false end

	local state = InputHoldState[player][keyCode]
	return state and state.pressed or false
end

-- ==============================
-- CLEANUP
-- ==============================

function InputBuffer.Cleanup(player)
	BufferedInputs[player] = nil
	InputHoldState[player] = nil
end

return InputBuffer
