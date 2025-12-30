--[[
    AbilityHandler.lua
    Handles ability slot activation (1-4)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityHandler = {}

local Config, StateManager, CooldownManager, HitboxHandler
local Remotes, CharacterRegistry, PassiveHandler

local function ExecuteAbility(player, slot)
    local data = StateManager.Get(player)
    if not data then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    local charName = StateManager.GetCharacter(player)
    local charData = CharacterRegistry.Get(charName)
    if not charData then return end

    local abilities = data.awakened and charData.AwakeningAbilities or charData.Abilities
    if not abilities or not abilities[slot] then return end

    local abilityName = abilities[slot]
    local abilityData = charData.AbilityData and charData.AbilityData[abilityName]
    if not abilityData then return end

    if StateManager.IsStunned(player) then
        return
    end

    local cdAction = "Ability" .. slot
    if not CooldownManager.IsReady(player, cdAction) then
        return
    end

    if abilityData.StaminaCost and not StateManager.HasStamina(player, abilityData.StaminaCost) then
        return
    end

    if abilityData.StaminaCost then
        StateManager.UseStamina(player, abilityData.StaminaCost)
    end

    CooldownManager.Set(player, cdAction, abilityData.Cooldown or 5)

    StateManager.SetState(player, StateManager.States.ATTACKING)

    Remotes.State:FireAllClients(player, "Ability", abilityName, {
        character = charName,
        slot = slot,
    })

    local totalDuration = (abilityData.Startup or 0) + (abilityData.Active or 0.1) + (abilityData.Recovery or 0)

    task.delay(totalDuration, function()
        if StateManager.IsAttacking(player) then
            StateManager.SetState(player, StateManager.States.IDLE)
        end
    end)
end

function AbilityHandler.Init(remotes, charRegistry)
    Remotes = remotes
    CharacterRegistry = charRegistry

    local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
    Config = require(CombatFolder.Config)
    StateManager = require(CombatFolder.Modules.StateManager)
    CooldownManager = require(CombatFolder.Modules.CooldownManager)
    HitboxHandler = require(CombatFolder.Modules.HitboxHandler)

    PassiveHandler = require(script.Parent.PassiveHandler)

    Remotes.Ability.OnServerEvent:Connect(function(player, slot)
        if typeof(slot) ~= "number" then return end
        slot = math.clamp(math.floor(slot), 1, 4)
        ExecuteAbility(player, slot)
    end)

    print("[AbilityHandler] Initialized")
    return AbilityHandler
end

return AbilityHandler