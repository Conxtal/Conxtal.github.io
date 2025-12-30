--[[
	StateManager.lua
	Manages player combat state + posture system
	Location: ReplicatedStorage/Combat/Modules/StateManager
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
local Config = require(CombatFolder.Config)

local StateManager = {}

local PlayerData = {}

StateManager.States = {
    IDLE = "Idle",
    ATTACKING = "Attacking",
    BLOCKING = "Blocking",
    STUNNED = "Stunned",
    DASHING = "Dashing",
    RECOVERY = "Recovery",
    AIRBORNE = "Airborne",
    GUARD_BROKEN = "GuardBroken", -- NEW
}

-- ========================================
-- SETUP & CLEANUP
-- ========================================

function StateManager.Setup(player, options)
    options = options or {}

    PlayerData[player] = {
        character = options.character or "Arthur",
        state = "Idle",
        combo = 0,
        lastAttack = 0,
        stamina = Config.Stamina.Max,
        lastStamUse = 0,

        -- POSTURE SYSTEM
        posture = Config.Combat.Posture.Max,
        maxPosture = Config.Combat.Posture.Max,
        lastPostureDamage = 0,
        isGuardBroken = false,
        lastPressureTime = 0,

        blocking = false,
        blockStart = 0,
        iframes = false,
        iframeEnd = 0,
        awakened = false,
    }
end

function StateManager.Remove(player)
    PlayerData[player] = nil
end

function StateManager.Get(player)
    return PlayerData[player]
end

function StateManager.GetAll()
    return PlayerData
end

-- ========================================
-- STATE MANAGEMENT
-- ========================================

function StateManager.SetState(player, newState)
    local data = PlayerData[player]
    if data then
        data.state = newState
    end
end

function StateManager.GetState(player)
    local data = PlayerData[player]
    return data and data.state or "Idle"
end

function StateManager.IsIdle(player)
    return StateManager.GetState(player) == StateManager.States.IDLE
end

function StateManager.IsAttacking(player)
    return StateManager.GetState(player) == StateManager.States.ATTACKING
end

function StateManager.IsStunned(player)
    return StateManager.GetState(player) == StateManager.States.STUNNED
end

function StateManager.IsBlocking(player)
    return StateManager.GetState(player) == StateManager.States.BLOCKING
end

function StateManager.IsDashing(player)
    return StateManager.GetState(player) == StateManager.States.DASHING
end

function StateManager.IsRecovery(player)
    return StateManager.GetState(player) == StateManager.States.RECOVERY
end

function StateManager.IsGuardBrokenState(player)
    return StateManager.GetState(player) == StateManager.States.GUARD_BROKEN
end

-- ========================================
-- POSTURE SYSTEM
-- ========================================

function StateManager.GetPosture(player)
    local data = PlayerData[player]
    return data and data.posture or 0
end

function StateManager.GetMaxPosture(player)
    local data = PlayerData[player]
    return data and data.maxPosture or Config.Combat.Posture.Max
end

function StateManager.DamagePosture(player, amount)
    local data = PlayerData[player]
    if not data then return false end

    data.posture = math.max(0, data.posture - amount)
    data.lastPostureDamage = tick()

    -- Check for guard break
    if data.posture <= 0 and not data.isGuardBroken then
        data.isGuardBroken = true
        return true -- guard break triggered
    end

    return false
end

function StateManager.RegenPosture(player, amount)
    local data = PlayerData[player]
    if not data then return end

    data.posture = math.min(data.maxPosture, data.posture + amount)
end

function StateManager.IsGuardBroken(player)
    local data = PlayerData[player]
    return data and data.isGuardBroken or false
end

function StateManager.ClearGuardBreak(player)
    local data = PlayerData[player]
    if data then
        data.isGuardBroken = false
        data.posture = data.maxPosture -- restore posture on recovery
    end
end

function StateManager.UpdatePressure(player)
    local data = PlayerData[player]
    if data then
        data.lastPressureTime = tick()
    end
end

function StateManager.TimeSincePressure(player)
    local data = PlayerData[player]
    if not data then return math.huge end
    return tick() - (data.lastPressureTime or 0)
end

function StateManager.TimeSincePostureDamage(player)
    local data = PlayerData[player]
    if not data then return math.huge end
    return tick() - (data.lastPostureDamage or 0)
end

-- ========================================
-- COMBO SYSTEM
-- ========================================

function StateManager.GetCombo(player)
    local data = PlayerData[player]
    return data and data.combo or 0
end

function StateManager.SetCombo(player, combo)
    local data = PlayerData[player]
    if data then
        data.combo = combo
    end
end

function StateManager.ResetCombo(player)
    StateManager.SetCombo(player, 0)
end

function StateManager.SetLastAttack(player)
    local data = PlayerData[player]
    if data then
        data.lastAttack = tick()
    end
end

function StateManager.TimeSinceAttack(player)
    local data = PlayerData[player]
    if not data then return math.huge end
    return tick() - (data.lastAttack or 0)
end

-- ========================================
-- BLOCKING SYSTEM
-- ========================================

function StateManager.SetBlocking(player, isBlocking)
    local data = PlayerData[player]
    if not data then return end

    data.blocking = isBlocking
    if isBlocking then
        data.blockStart = tick()
    end
end

function StateManager.IsBlockingActive(player)
    local data = PlayerData[player]
    return data and data.blocking or false
end

function StateManager.GetBlockTime(player)
    local data = PlayerData[player]
    if not data or not data.blocking then return math.huge end
    return tick() - (data.blockStart or tick())
end

-- ========================================
-- IFRAME SYSTEM
-- ========================================

function StateManager.SetIFrames(player, duration)
    local data = PlayerData[player]
    if data then
        data.iframes = true
        data.iframeEnd = tick() + duration
    end
end

function StateManager.ClearIFrames(player)
    local data = PlayerData[player]
    if data then
        data.iframes = false
        data.iframeEnd = 0
    end
end

function StateManager.HasIFrames(player)
    local data = PlayerData[player]
    if not data or not data.iframes then return false end

    if tick() >= data.iframeEnd then
        StateManager.ClearIFrames(player)
        return false
    end

    return true
end

-- ========================================
-- STAMINA SYSTEM
-- ========================================

function StateManager.GetStamina(player)
    local data = PlayerData[player]
    return data and data.stamina or 0
end

function StateManager.UseStamina(player, amount)
    local data = PlayerData[player]
    if not data then return false end

    if data.stamina >= amount then
        data.stamina = data.stamina - amount
        data.lastStamUse = tick()
        return true
    end

    return false
end

function StateManager.HasStamina(player, amount)
    local data = PlayerData[player]
    return data and data.stamina >= amount or false
end

function StateManager.RegenStamina(player, amount, maxStamina)
    local data = PlayerData[player]
    if data then
        data.stamina = math.min(maxStamina, data.stamina + amount)
    end
end

function StateManager.TimeSinceStamUse(player)
    local data = PlayerData[player]
    if not data then return math.huge end
    return tick() - (data.lastStamUse or 0)
end

-- ========================================
-- CHARACTER SYSTEM
-- ========================================

function StateManager.GetCharacter(player)
    local data = PlayerData[player]
    return data and data.character or "Arthur"
end

function StateManager.SetCharacter(player, characterName)
    local data = PlayerData[player]
    if data then
        data.character = characterName
    end
end

return StateManager