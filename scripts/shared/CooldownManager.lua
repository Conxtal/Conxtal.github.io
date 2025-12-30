--[[
	CooldownManager.lua
	Centralized cooldown tracking
	Location: ReplicatedStorage/Combat/Modules/CooldownManager
]]

local CooldownManager = {}

local Cooldowns = {}

CooldownManager.Actions = {
    M1 = "M1",
    DASH = "Dash",
    BLOCK = "Block",
    UPTILT = "Uptilt",
    ABILITY_1 = "Ability1",
    ABILITY_2 = "Ability2",
    ABILITY_3 = "Ability3",
    ABILITY_4 = "Ability4",
    AWAKENING = "Awakening",
}

function CooldownManager.Set(player, action, duration)
    Cooldowns[player] = Cooldowns[player] or {}
    Cooldowns[player][action] = tick() + duration
end

function CooldownManager.Get(player, action)
    Cooldowns[player] = Cooldowns[player] or {}
    return Cooldowns[player][action] or 0
end

function CooldownManager.IsReady(player, action)
    Cooldowns[player] = Cooldowns[player] or {}
    local endTime = Cooldowns[player][action] or 0
    return tick() >= endTime
end

function CooldownManager.GetRemaining(player, action)
    Cooldowns[player] = Cooldowns[player] or {}
    local endTime = Cooldowns[player][action] or 0
    local remaining = endTime - tick()
    return remaining > 0 and remaining or 0
end

function CooldownManager.Reset(player, action)
    if Cooldowns[player] then
        Cooldowns[player][action] = nil
    end
end

function CooldownManager.ResetAll(player)
    Cooldowns[player] = {}
end

function CooldownManager.Cleanup(player)
    Cooldowns[player] = nil
end

return CooldownManager
