--[[
	CombatClient.lua
	Main client combat controller
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
local State = require(CombatFolder.Modules.StateManager)
local Cooldown = require(CombatFolder.Modules.CooldownManager)

local Player = Players.LocalPlayer

local CombatClient = {}

local Remotes = nil
local InputHandler = nil
local AnimHandler = nil
local VFXHandler = nil

function CombatClient.Init()
    -- Get remotes
    local folder = ReplicatedStorage:WaitForChild("Remotes")
    Remotes = {
        Attack = folder:WaitForChild("Attack"),
        Uptilt = folder:WaitForChild("Uptilt"),
        Block = folder:WaitForChild("Block"),
        Dash = folder:WaitForChild("Dash"),
        Hit = folder:WaitForChild("Hit"),
        State = folder:WaitForChild("State"),
        Ability = folder:WaitForChild("Ability"),
        Notification = folder:WaitForChild("Notification"),
    }

    -- Setup local state
    State.Setup(Player)

    -- Load handlers
    InputHandler = require(script.Parent.Handlers.InputHandler)
    AnimHandler = require(script.Parent.Handlers.AnimationHandler)
    VFXHandler = require(script.Parent.Handlers.VFXHandler)

    InputHandler.Init(Remotes)
    AnimHandler.Init()
    VFXHandler.Init()

    -- Listen for events
    Remotes.State.OnClientEvent:Connect(CombatClient.OnState)
    Remotes.Hit.OnClientEvent:Connect(CombatClient.OnHit)
    Remotes.Notification.OnClientEvent:Connect(CombatClient.OnNotification)

    print("[CombatClient] Initialized")
    return CombatClient
end

function CombatClient.OnState(player, stateType, data, extra)
    local char = player.Character
    if not char then return end

    local isLocal = player == Player

    if stateType == "M1" then
        local combo = data
        local info = extra or {}
        VFXHandler.ScreenFlash(Color3.fromHSV(0.916667, 0.082475, 0.380392), .1)

        -- Play animation
        if isLocal then
            AnimHandler.PlayM1(char, combo)
        else
            AnimHandler.PlayOn(char, "M1_" .. combo, { fadeIn = 0.05, priority = Enum.AnimationPriority.Action2 })
        end

        -- VFX
        VFXHandler.OnM1(player, combo, info)

    elseif stateType == "Uptilt" then
        local info = data or {}

        if isLocal then
            AnimHandler.PlayUptilt(char)
        else
            AnimHandler.PlayOn(char, "Uptilt", { fadeIn = 0.05, priority = Enum.AnimationPriority.Action2 })
        end

        VFXHandler.OnUptilt(player, info)

    elseif stateType == "Dash" then
        local info = data or {}

        -- info.intent is authoritative ("Forward", "Back", "Left", "Right")
        local intent = info.intent or "Forward"

        -- Play dash animation for BOTH local and others
        AnimHandler.PlayDash(char, intent)

        task.delay(0.03, function()
            if char and char.Parent then
                VFXHandler.OnDash(char, intent, info)
            end
        end)
 
    elseif stateType == "BlockStart" then
        local info = data or {}

        if isLocal then
            AnimHandler.PlayBlock(char)
        else
            AnimHandler.PlayOn(char, "BlockIdle", { fadeIn = 0.08, looped = true })
        end

        VFXHandler.OnBlockStart(char, info)

    elseif stateType == "BlockEnd" then
        if isLocal then
            AnimHandler.Stop(char, "BlockIdle")
        end

        VFXHandler.OnBlockEnd(char, data)

    elseif stateType == "CharacterSelect" then
        local characterName = data

        if isLocal then
            -- Reload animations for new character
            Cooldown.ResetAll(Player)
            AnimHandler.LoadCharacterAnims(char, characterName)
            VFXHandler.SetCharacter(characterName)
        end

    elseif stateType == "Ability" then
        local abilityName = data
        local info = extra or {}

        if isLocal then
            AnimHandler.PlayAbility(char, abilityName)
        else
            AnimHandler.PlayOn(char, abilityName, { fadeIn = 0.05, priority = Enum.AnimationPriority.Action2 })
        end

        VFXHandler.OnAbility(player, abilityName, info)

    elseif stateType == "Passive" then
        if isLocal then
            CombatClient.OnPassive(data, extra)
        end

    elseif stateType == "PassiveVFX" then
        VFXHandler.OnPassiveVFX(char, data, extra)
    end
end

function CombatClient.OnHit(hitData)
    -- Play hit reaction on victim
    local victimChar = hitData.victimChar
    if victimChar and not hitData.blocked then
        local isLocal = hitData.victim == Player

        if isLocal then
            AnimHandler.PlayHitReaction(victimChar, hitData.hitType)
        else
            local animName = "HitLight"
            if hitData.hitType == "Final" then animName = "HitHeavy"
            elseif hitData.hitType == "Uptilt" then animName = "HitLaunch"
            end
            AnimHandler.PlayOn(victimChar, animName, { fadeIn = 0.02, priority = Enum.AnimationPriority.Action4 })
        end
    end

    -- VFX
    VFXHandler.OnHit(hitData)
end

function CombatClient.OnPassive(eventType, data)
    print("[Passive]", eventType, data)
end

function CombatClient.OnNotification(message)
    print("[Notification]", message)
    -- TODO: Show UI notification
end

function CombatClient.GetRemotes()
    return Remotes
end

return CombatClient