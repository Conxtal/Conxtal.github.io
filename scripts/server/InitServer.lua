--[[
	InitServer.server.lua
	Server-side combat initialization with posture regen loop
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[CombatServer] Starting initialization...")

-- Wait for Combat folder
local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
local Config = require(CombatFolder.Config)
local StateManager = require(CombatFolder.Modules.StateManager)
local CooldownManager = require(CombatFolder.Modules.CooldownManager)

-- Create Remotes folder
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not RemotesFolder then
    RemotesFolder = Instance.new("Folder")
    RemotesFolder.Name = "Remotes"
    RemotesFolder.Parent = ReplicatedStorage
end

-- Create remote events
local REMOTE_NAMES = {
    "Attack", "Uptilt", "Aerial", "Block", "Dash", "Hit",
    "State", "Ability", "Notification", "Passive",
    "CombatLock"
}

local Remotes = {}
for _, name in pairs(REMOTE_NAMES) do
    local remote = RemotesFolder:FindFirstChild(name)
    if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = RemotesFolder
    end
    Remotes[name] = remote
end

-- Create remote functions
local getCharRemote = RemotesFolder:FindFirstChild("GetCharacter")
if not getCharRemote then
    getCharRemote = Instance.new("RemoteFunction")
    getCharRemote.Name = "GetCharacter"
    getCharRemote.Parent = RemotesFolder
end

local getCharDataRemote = RemotesFolder:FindFirstChild("GetCharacterData")
if not getCharDataRemote then
    getCharDataRemote = Instance.new("RemoteFunction")
    getCharDataRemote.Name = "GetCharacterData"
    getCharDataRemote.Parent = RemotesFolder
end

-- Load handlers
-- NOTE: Handlers are currently in shared/server folders, we'll need to reorganize them
local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
local SharedHandlers = CombatFolder.Handlers or CombatFolder

local CharacterRegistry = require(SharedHandlers.CharacterRegistry)
local AttackHandler = require(SharedHandlers.AttackHandler)
local UptiltHandler = require(script.UptiltHandler)  -- New handler in server folder
local AerialHandler = require(script.AerialHandler)  -- New handler in server folder
local BlockHandler = require(SharedHandlers.BlockHandler)
local DashHandler = require(SharedHandlers.DashHandler)
local PassiveHandler = require(SharedHandlers.PassiveHandler)
local CombatLockHandler = require(SharedHandlers.CombatLock)

-- Initialize handlers
CharacterRegistry.Init(Remotes)
AttackHandler.Init(Remotes, CharacterRegistry)
UptiltHandler.Init(Remotes, CharacterRegistry)
AerialHandler.Init(Remotes, CharacterRegistry)
BlockHandler.Init(Remotes, CharacterRegistry)
DashHandler.Init(Remotes, CharacterRegistry)
PassiveHandler.Init(Remotes, CharacterRegistry)
CombatLockHandler.Init(Remotes)

-- Remote function handlers
getCharRemote.OnServerInvoke = function(player)
    return StateManager.GetCharacter(player)
end

getCharDataRemote.OnServerInvoke = function(player, characterName)
    local charData = CharacterRegistry.Get(characterName)
    if charData then
        return {
            Name = charData.Name,
            Animations = charData.Animations,
            AnimationSpeeds = charData.AnimationSpeeds, 
            Sounds = charData.Sounds,
            VFXColors = charData.VFXColors,
        }
    end
    return nil
end

-- ========================================
-- PLAYER SETUP
-- ========================================

local function SetupPlayer(player)
    StateManager.Setup(player, {
        character = CharacterRegistry.GetDefault(),
    })

    PassiveHandler.SetupPlayer(player)

    player.CharacterAdded:Connect(function(char)
        local data = StateManager.Get(player)
        if data then
            data.state = "Idle"
            data.combo = 0
            data.blocking = false
            data.iframes = false
            data.awakened = false

            -- Reset posture
            data.posture = data.maxPosture
            data.isGuardBroken = false
        end

        CooldownManager.ResetAll(player)

        task.wait(0.1)
        local charName = StateManager.GetCharacter(player)
        local charData = CharacterRegistry.Get(charName)
        if charData then
            CharacterRegistry.ApplyStats(player, charData)

            -- Set character-specific max posture
            if data and charData.Stats and charData.Stats.PostureMax then
                data.maxPosture = charData.Stats.PostureMax
                data.posture = charData.Stats.PostureMax
            end
        end
    end)
end

local function CleanupPlayer(player)
    StateManager.Remove(player)
    CooldownManager.Cleanup(player)
    PassiveHandler.CleanupPlayer(player)
end

Players.PlayerAdded:Connect(SetupPlayer)
Players.PlayerRemoving:Connect(CleanupPlayer)

for _, player in pairs(Players:GetPlayers()) do
    SetupPlayer(player)
end

-- ========================================
-- STAMINA REGEN LOOP
-- ========================================

task.spawn(function()
    while true do
        task.wait(0.1)

        local regenDelay = Config.Stamina.RegenDelay
        local regenRate = Config.Stamina.RegenRate
        local maxStamina = Config.Stamina.Max

        for player, data in pairs(StateManager.GetAll()) do
            if data.stamina < maxStamina then
                if StateManager.TimeSinceStamUse(player) > regenDelay then
                    local charData = CharacterRegistry.Get(data.character)
                    local regenMod = 1.0
                    if charData and charData.Stats then
                        regenMod = charData.Stats.StaminaRegen or 1.0
                    end

                    local amount = regenRate * regenMod * 0.1
                    StateManager.RegenStamina(player, amount, maxStamina)
                end
            end
        end
    end
end)

-- ========================================
-- POSTURE REGEN LOOP (NEW)
-- ========================================

task.spawn(function()
    while true do
        task.wait(0.1)

        local regenRate = Config.Combat.Posture.RegenRate
        local regenDelay = Config.Combat.Posture.RegenDelay

        for player, data in pairs(StateManager.GetAll()) do
            local maxPosture = StateManager.GetMaxPosture(player)

            if data.posture < maxPosture and not data.isGuardBroken then
                local timeSinceDamage = StateManager.TimeSincePostureDamage(player)

                -- Only regen after delay
                if timeSinceDamage > regenDelay then
                    local regenMod = 1.0

                    -- SEKIRO MECHANIC: Slow regen when being pressured
                    local timeSincePressure = StateManager.TimeSincePressure(player)
                    if timeSincePressure < 3.0 then
                        regenMod = Config.Combat.Posture.PressureRegenMultiplier
                    end

                    -- Slower regen at low HP
                    local char = player.Character
                    local hum = char and char:FindFirstChild("Humanoid")
                    if hum and hum.Health < hum.MaxHealth * 0.3 then
                        regenMod = regenMod * Config.Combat.Posture.LowHPMultiplier
                    end

                    -- Character-specific regen modifier
                    local charData = CharacterRegistry.Get(data.character)
                    if charData and charData.Stats and charData.Stats.PostureRegenMultiplier then
                        regenMod = regenMod * charData.Stats.PostureRegenMultiplier
                    end

                    local amount = regenRate * regenMod * 0.1
                    StateManager.RegenPosture(player, amount)
                end
            end
        end
    end
end)

print("[CombatServer] Initialized!")