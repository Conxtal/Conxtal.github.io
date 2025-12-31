--[[
	AerialComboSystem.lua
	Handles ALL aerial combat logic (air combos, launchers, slams)

	FEATURES:
	- Aerial M1 combos after uptilt
	- Combo inheritance (uptilt at M1-3 gives remaining air hits)
	- Spacebar hold detection (hold = knockback, tap = slam)
	- Mid-air knockback mechanics
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local AerialComboSystem = {}

-- ==============================
-- STATE TRACKING
-- ==============================

local AerialState = {}  -- [player] = { inAir, comboCount, maxAirHits, lastAttack }
local SpacebarHoldStart = {}  -- [player] = tick() when spacebar pressed

-- ==============================
-- CONSTANTS
-- ==============================

local HOLD_THRESHOLD = 0.25  -- Hold spacebar for this long = knockback instead of slam
local AIR_COMBO_WINDOW = 0.6  -- Time window for air combo chain

-- ==============================
-- INITIALIZATION
-- ==============================

function AerialComboSystem.Init()
	-- Track spacebar hold on client
	if UserInputService then
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then return end
			if input.KeyCode == Enum.KeyCode.Space then
				local player = Players.LocalPlayer
				SpacebarHoldStart[player] = tick()
			end
		end)

		UserInputService.InputEnded:Connect(function(input, processed)
			if input.KeyCode == Enum.KeyCode.Space then
				local player = Players.LocalPlayer
				SpacebarHoldStart[player] = nil
			end
		end)
	end

	print("[AerialComboSystem] Initialized")
	return AerialComboSystem
end

-- ==============================
-- AERIAL STATE MANAGEMENT
-- ==============================

function AerialComboSystem.StartAerialState(player, groundCombo)
	-- Calculate how many air hits they get based on ground combo
	local maxAirHits = 4 - groundCombo  -- If uptilt at M1-3, get remaining hits

	if maxAirHits < 0 then maxAirHits = 0 end
	if maxAirHits > 4 then maxAirHits = 4 end

	AerialState[player] = {
		inAir = true,
		comboCount = 0,
		maxAirHits = maxAirHits,
		lastAttack = 0,
		startedFromCombo = groundCombo,
	}

	return maxAirHits
end

function AerialComboSystem.EndAerialState(player)
	AerialState[player] = nil
end

function AerialComboSystem.GetAerialState(player)
	return AerialState[player]
end

function AerialComboSystem.IsInAir(player)
	local state = AerialState[player]
	return state and state.inAir or false
end

function AerialComboSystem.GetAirCombo(player)
	local state = AerialState[player]
	return state and state.comboCount or 0
end

function AerialComboSystem.GetMaxAirHits(player)
	local state = AerialState[player]
	return state and state.maxAirHits or 0
end

function AerialComboSystem.IncrementAirCombo(player)
	local state = AerialState[player]
	if not state then return false end

	if state.comboCount < state.maxAirHits then
		state.comboCount = state.comboCount + 1
		state.lastAttack = tick()
		return true
	end

	return false
end

function AerialComboSystem.TimeSinceLastAirAttack(player)
	local state = AerialState[player]
	if not state then return math.huge end
	return tick() - state.lastAttack
end

function AerialComboSystem.CanAirCombo(player)
	local state = AerialState[player]
	if not state or not state.inAir then return false end

	-- Check if they have air hits remaining
	if state.comboCount >= state.maxAirHits then return false end

	-- Check combo window
	if AerialComboSystem.TimeSinceLastAirAttack(player) > AIR_COMBO_WINDOW then
		return false
	end

	return true
end

-- ==============================
-- SPACEBAR DETECTION
-- ==============================

function AerialComboSystem.IsSpacebarHeld(player)
	if not SpacebarHoldStart[player] then return false end

	local holdTime = tick() - SpacebarHoldStart[player]
	return holdTime >= HOLD_THRESHOLD
end

function AerialComboSystem.GetHoldTime(player)
	if not SpacebarHoldStart[player] then return 0 end
	return tick() - SpacebarHoldStart[player]
end

-- ==============================
-- AERIAL ATTACK HELPERS
-- ==============================

function AerialComboSystem.ShouldKnockback(player)
	-- If holding spacebar = knockback
	return AerialComboSystem.IsSpacebarHeld(player)
end

function AerialComboSystem.ShouldDownSlam(player)
	-- If NOT holding spacebar = down slam
	return not AerialComboSystem.IsSpacebarHeld(player)
end

-- ==============================
-- CLEANUP
-- ==============================

function AerialComboSystem.Cleanup(player)
	AerialState[player] = nil
	SpacebarHoldStart[player] = nil
end

return AerialComboSystem
