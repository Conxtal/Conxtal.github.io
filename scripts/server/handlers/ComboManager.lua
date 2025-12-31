--[[
	ComboManager.lua
	Central combo tracking system

	Manages:
	- Ground combo count
	- Aerial combo count
	- Combo windows
	- Combo resets
]]

local ComboManager = {}

-- ====================================
-- STATE
-- ====================================

local PlayerCombos = {}  -- [player] = { ground, aerial, lastAttack }

-- ====================================
-- SETUP
-- ====================================

function ComboManager.Setup(player)
	PlayerCombos[player] = {
		ground = 0,
		aerial = 0,
		lastAttack = 0,
	}
end

function ComboManager.Cleanup(player)
	PlayerCombos[player] = nil
end

-- ====================================
-- GROUND COMBO
-- ====================================

function ComboManager.GetGroundCombo(player)
	local data = PlayerCombos[player]
	return data and data.ground or 0
end

function ComboManager.SetGroundCombo(player, count)
	local data = PlayerCombos[player]
	if data then
		data.ground = count
	end
end

function ComboManager.IncrementGroundCombo(player)
	local data = PlayerCombos[player]
	if data then
		data.ground = data.ground + 1
		return data.ground
	end
	return 0
end

function ComboManager.ResetGroundCombo(player)
	ComboManager.SetGroundCombo(player, 0)
end

-- ====================================
-- AERIAL COMBO
-- ====================================

function ComboManager.GetAerialCombo(player)
	local data = PlayerCombos[player]
	return data and data.aerial or 0
end

function ComboManager.SetAerialCombo(player, count)
	local data = PlayerCombos[player]
	if data then
		data.aerial = count
	end
end

function ComboManager.IncrementAerialCombo(player)
	local data = PlayerCombos[player]
	if data then
		data.aerial = data.aerial + 1
		return data.aerial
	end
	return 0
end

function ComboManager.ResetAerialCombo(player)
	ComboManager.SetAerialCombo(player, 0)
end

-- ====================================
-- TOTAL COMBO
-- ====================================

function ComboManager.GetTotalCombo(player)
	local ground = ComboManager.GetGroundCombo(player)
	local aerial = ComboManager.GetAerialCombo(player)
	return ground + aerial
end

function ComboManager.ResetAll(player)
	ComboManager.ResetGroundCombo(player)
	ComboManager.ResetAerialCombo(player)
end

-- ====================================
-- TIMING
-- ====================================

function ComboManager.UpdateLastAttack(player)
	local data = PlayerCombos[player]
	if data then
		data.lastAttack = tick()
	end
end

function ComboManager.TimeSinceLastAttack(player)
	local data = PlayerCombos[player]
	if not data then return math.huge end
	return tick() - (data.lastAttack or 0)
end

-- ====================================
-- UTILITIES
-- ====================================

function ComboManager.GetComboData(player)
	return PlayerCombos[player]
end

function ComboManager.HasActiveCombo(player, window)
	window = window or 0.5
	return ComboManager.TimeSinceLastAttack(player) < window
end

return ComboManager
