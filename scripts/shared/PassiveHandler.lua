--[[
	PassiveHandler.lua
	Handles passive abilities
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Loader = require(ReplicatedStorage.Combat.ModuleLoader)

local PassiveHandler = {}

-- Dependencies
local State
local Remotes, CharacterManager
local PassiveData = {}

function PassiveHandler.Init(remotes, charManager)
    Remotes = remotes
    CharacterManager = charManager

    -- Load core dependencies via ModuleLoader
    State = Loader.GetCore("StateManager")

    print("[PassiveHandler] Initialized")
    return PassiveHandler
end

function PassiveHandler.SetupPlayer(player)
    PassiveData[player] = {
        -- Arthur - Ether Resonance / King's Legacy
        combatFocusStacks = 0,
        combatFocusDecaying = false,
        combatFocusDecayStart = 0,
        combatFocusCooldownEnd = 0,
        lastStackTime = 0,

        -- Jigen - Shrink
        shrinkWindowReady = false,
        shrinkWindowActive = false,
        shrinkWindowEndTime = 0,
        lastShrinkWindow = 0,
        shrinkCooldown = 12,
    }

    -- Start tick loop for this player
    PassiveHandler.StartTickLoop(player)
end

function PassiveHandler.CleanupPlayer(player)
    PassiveData[player] = nil
end

function PassiveHandler.StartTickLoop(player)
    task.spawn(function()
        while PassiveData[player] do
            task.wait(0.1)
            PassiveHandler.TickPlayer(player)
        end
    end)
end

function PassiveHandler.TickPlayer(player)
    local data = PassiveData[player]
    if not data then return end

    local now = tick()
    local charName = State.GetCharacter(player)
    local charData = CharacterManager.Get(charName)
    if not charData or not charData.Passive then return end

    local passive = charData.Passive

    if charName == "Arthur" then
        -- Check if on cooldown
        if now < data.combatFocusCooldownEnd then
            -- Still on cooldown, keep stacks at 0
            if data.combatFocusStacks > 0 then
                data.combatFocusStacks = 0
                PassiveHandler.FireClient(player, "CombatFocusStacks", 0)
            end
            -- Check if decaying
        elseif data.combatFocusDecaying then
            local decayDuration = passive.DecayDuration or 8
            local timeSinceDecayStart = now - data.combatFocusDecayStart

            if timeSinceDecayStart >= decayDuration then
                -- Decay finished - start cooldown and remove VFX
                data.combatFocusStacks = 0
                data.combatFocusDecaying = false
                data.combatFocusCooldownEnd = now + (passive.Cooldown or 30)
                PassiveHandler.FireClient(player, "CombatFocusStacks", 0)
                PassiveHandler.FireClient(player, "CombatFocusCooldown", passive.Cooldown or 30)

                if Remotes and Remotes.State then
                    Remotes.State:FireAllClients(player, "PassiveVFX", "CombatFocusEnd", {})
                end
            else
                -- Currently decaying - calculate current stacks based on time
                local maxStacks = passive.MaxStacks or 8
                local progress = timeSinceDecayStart / decayDuration
                local currentStacks = math.floor(maxStacks * (1 - progress))

                if currentStacks ~= data.combatFocusStacks then
                    data.combatFocusStacks = currentStacks
                    PassiveHandler.FireClient(player, "CombatFocusStacks", currentStacks)
                end
            end
        end
    end

    if charName == "Jigen" then
        local stateData = State.Get(player)
        local isAwakened = stateData and stateData.awakened

        local cooldown = passive.Cooldown
        if isAwakened and passive.AwakeningCooldown then
            cooldown = passive.AwakeningCooldown
        end
        data.shrinkCooldown = cooldown

        if not data.shrinkWindowReady and not data.shrinkWindowActive then
            if (now - data.lastShrinkWindow) >= cooldown then
                data.shrinkWindowReady = true
                data.shrinkWindowActive = true
                data.shrinkWindowEndTime = now + passive.WindowDuration
                PassiveHandler.FireClient(player, "ShrinkWindowReady", true)
            end
        end

        if data.shrinkWindowActive and now > data.shrinkWindowEndTime then
            data.shrinkWindowActive = false
            data.shrinkWindowReady = false
            data.lastShrinkWindow = now
            PassiveHandler.FireClient(player, "ShrinkWindowExpired", true)
        end
    end
end

function PassiveHandler.Get(player)
    return PassiveData[player]
end

function PassiveHandler.OnHit(attacker, victim, hitInfo)
    local charName = State.GetCharacter(attacker)

    if charName == "Arthur" then
        PassiveHandler.ArthurOnHit(attacker)
    end
end

function PassiveHandler.ArthurOnHit(player)
    local data = PassiveData[player]
    if not data then 
        return 
    end

    local charData = CharacterManager.Get("Arthur")
    if not charData or not charData.Passive then return end

    local passive = charData.Passive
    local now = tick()

    -- Can't gain stacks if on cooldown or decaying
    if now < data.combatFocusCooldownEnd then
        return
    end

    -- ADD THIS CHECK - can't gain stacks while decaying
    if data.combatFocusDecaying then
        return
    end

    local maxStacks = passive.MaxStacks or 8

    -- Gain a stack (awakening gives double stacks)
    local stateData = State.Get(player)
    local stacksToAdd = 1
    if stateData and stateData.awakened then
        stacksToAdd = passive.AwakeningStackRate or 2
    end

    local oldStacks = data.combatFocusStacks
    data.combatFocusStacks = math.min(data.combatFocusStacks + stacksToAdd, maxStacks)
    data.lastStackTime = now

    PassiveHandler.FireClient(player, "CombatFocusStacks", data.combatFocusStacks)

    -- If reached max stacks, start decay
    if data.combatFocusStacks >= maxStacks then
        data.combatFocusDecaying = true
        data.combatFocusDecayStart = now
        PassiveHandler.FireClient(player, "CombatFocusMaxReached", true)

        -- Fire VFX
        if Remotes and Remotes.State then
            Remotes.State:FireAllClients(player, "PassiveVFX", "CombatFocusMax", {})
        end
    end
end

function PassiveHandler.CheckJigenEvade(player)
    local data = PassiveData[player]
    if not data or not data.shrinkWindowActive then return false end

    data.shrinkWindowActive = false
    data.shrinkWindowReady = false
    data.lastShrinkWindow = tick()

    PassiveHandler.FireClient(player, "ShrinkEvade", true)

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and Remotes and Remotes.State then
        Remotes.State:FireAllClients(player, "PassiveVFX", "ShrinkEvade", { position = hrp.Position })
    end

    return true
end

function PassiveHandler.GetDamageMultiplier(player)
    local charName = State.GetCharacter(player)
    local data = PassiveData[player]

    if charName == "Arthur" and data and data.combatFocusStacks > 0 then
        local charData = CharacterManager.Get("Arthur")
        if charData and charData.Passive then
            local damagePerStack = charData.Passive.DamagePerStack or 0.02
            local multiplier = 1 + (data.combatFocusStacks * damagePerStack)
            return multiplier
        end
    end

    return 1.0
end

function PassiveHandler.GetAttackSpeedMultiplier(player)
    local charName = State.GetCharacter(player)
    local data = PassiveData[player]

    if charName == "Arthur" and data and data.combatFocusStacks > 0 then
        local charData = CharacterManager.Get("Arthur")
        if charData and charData.Passive then
            local speedPerStack = charData.Passive.AttackSpeedPerStack or 0.02
            return 1 + (data.combatFocusStacks * speedPerStack)
        end
    end

    return 1.0
end

function PassiveHandler.GetStacks(player)
    local data = PassiveData[player]
    return data and data.combatFocusStacks or 0
end

function PassiveHandler.ResetStacks(player)
    local data = PassiveData[player]
    if data then
        data.combatFocusStacks = 0
        data.combatFocusDecaying = false
        PassiveHandler.FireClient(player, "CombatFocusStacks", 0)
    end
end

function PassiveHandler.FireClient(player, eventType, eventData)
    if Remotes and Remotes.State then
        Remotes.State:FireClient(player, "Passive", eventType, eventData)
    end
end

return PassiveHandler