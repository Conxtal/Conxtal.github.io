--[[
	CharacterRegistry.lua
	Manages character data, selection, and stats
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterRegistry = {}
CharacterRegistry.Characters = {}
CharacterRegistry.DefaultCharacter = "Arthur"

local Remotes
local StateManager

local function LoadCharacters()
    local count = 0
    local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
    local DataFolder = CombatFolder:FindFirstChild("Data")

    if DataFolder then
        for _, child in pairs(DataFolder:GetChildren()) do
            if child:IsA("ModuleScript") and child.Name ~= "CharacterVFX" then
                local success, charData = pcall(require, child)
                if success and charData and charData.Name then
                    CharacterRegistry.Characters[charData.Name] = charData
                    count = count + 1
                    print("[CharacterRegistry] Loaded:", charData.Name)
                else
                    warn("[CharacterRegistry] Failed to load:", child.Name)
                end
            end
        end
    end

    return count
end

local function WeldWeaponToRightHand(character, weaponName)
    if not character or not weaponName then return end

    -- Get hand (R15 / R6)
    local hand =
        character:FindFirstChild("RightHand")
        or character:FindFirstChild("Right Arm")

    if not hand then
        warn("[Weapon] No right hand found")
        return
    end

    -- Get weapon template (SINGLE PART ONLY)
    local toolsFolder = ReplicatedStorage:WaitForChild("Tools")
    local weaponTemplate = toolsFolder:FindFirstChild(weaponName)

    if not weaponTemplate or not weaponTemplate:IsA("BasePart") then
        warn("[Weapon] Weapon must be a BasePart or MeshPart:", weaponName)
        return
    end

    -- Remove old weapon
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("BasePart") and child:GetAttribute("IsWeapon") then
            child:Destroy()
        end
    end

    -- Clone weapon
    local weapon = weaponTemplate:Clone()
    weapon.Name = "Weapon"
    weapon:SetAttribute("IsWeapon", true)
    weapon.Anchored = false
    weapon.CanCollide = false
    weapon.Massless = true
    weapon.Parent = character

    -- Clear old welds
    for _, c in ipairs(weapon:GetChildren()) do
        if c:IsA("Weld") or c:IsA("WeldConstraint") then
            c:Destroy()
        end
    end

    -- Snap to hand
    weapon.CFrame = hand.CFrame * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, 2, -1)


    -- Weld
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hand
    weld.Part1 = weapon
    weld.Parent = weapon
end

function CharacterRegistry.Init(remotes)
    Remotes = remotes

    local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
    StateManager = require(CombatFolder.Modules.StateManager)

    local charCount = LoadCharacters()
    
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            task.defer(function()
                WeldWeaponToRightHand(character, "ArthurSword")
            end)
        end)
    end)
    
    Players.PlayerAdded:Connect(function(player)
        player.Chatted:Connect(function(message)
            CharacterRegistry.HandleChatCommand(player, message)
        end)
    end)

    for _, player in pairs(Players:GetPlayers()) do
        player.Chatted:Connect(function(message)
            CharacterRegistry.HandleChatCommand(player, message)
        end)
    end

    print("[CharacterRegistry] Initialized with", charCount, "characters")
    return CharacterRegistry
end

function CharacterRegistry.Get(name)
    return CharacterRegistry.Characters[name]
end

function CharacterRegistry.Exists(name)
    return CharacterRegistry.Characters[name] ~= nil
end

function CharacterRegistry.GetDefault()
    return CharacterRegistry.DefaultCharacter
end

function CharacterRegistry.SelectCharacter(player, characterName)
    if not CharacterRegistry.Exists(characterName) then
        return false
    end

    local charData = CharacterRegistry.Characters[characterName]
    StateManager.SetCharacter(player, characterName)

    local data = StateManager.Get(player)
    if data then
        data.combo = 0
        data.awakened = false
        data.awakeningEndTime = nil
        data.state = "Idle"
        data.blocking = false
        data.iframes = false
    end

    CharacterRegistry.ApplyStats(player, charData)

    task.defer(function()
        if player.Character then
            WeldWeaponToRightHand(player.Character)
        end
    end)

    if Remotes and Remotes.State then
        Remotes.State:FireAllClients(player, "CharacterSelect", characterName)
    end

    return true
end


function CharacterRegistry.ApplyStats(player, charData)
    local char = player.Character
    if not char then return end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local stats = charData.Stats or {}

    humanoid.MaxHealth = stats.Health or 100
    humanoid.Health = humanoid.MaxHealth
    humanoid.WalkSpeed = stats.WalkSpeed or 16
    humanoid.JumpPower = stats.JumpPower or 50

    local data = StateManager.Get(player)
    if data then
        data.stamina = 100 * (stats.Stamina or 1)
    end
end

function CharacterRegistry.HandleChatCommand(player, message)
    local args = string.split(message:lower(), " ")
    local command = args[1]

    if command == "/char" or command == "/selectchar" then
        local charName = args[2]
        if not charName then
            CharacterRegistry.SendMessage(player, "Usage: /char <name>")
            CharacterRegistry.SendMessage(player, "Available: " .. CharacterRegistry.GetAvailableCharacters())
            return
        end

        local matched = CharacterRegistry.FindCharacterName(charName)
        if matched then
            local success = CharacterRegistry.SelectCharacter(player, matched)
            if success then
                CharacterRegistry.SendMessage(player, "Switched to " .. matched .. "!")
            end
        else
            CharacterRegistry.SendMessage(player, "Character not found.")
        end

    elseif command == "/chars" then
        CharacterRegistry.SendMessage(player, "Available: " .. CharacterRegistry.GetAvailableCharacters())
    end
end

function CharacterRegistry.SendMessage(player, message)
    if Remotes and Remotes.Notification then
        Remotes.Notification:FireClient(player, message)
    end
end

function CharacterRegistry.FindCharacterName(input)
    input = input:lower()
    for name in pairs(CharacterRegistry.Characters) do
        if name:lower() == input then return name end
        if name:lower():sub(1, #input) == input then return name end
    end
    return nil
end

function CharacterRegistry.GetAvailableCharacters()
    local names = {}
    for name in pairs(CharacterRegistry.Characters) do
        table.insert(names, name)
    end
    return table.concat(names, ", ")
end

function CharacterRegistry.GetCharacter(player)
    return StateManager.GetCharacter(player)
end

function CharacterRegistry.GetCharacterData(player)
    local characterName = StateManager.GetCharacter(player)
    return CharacterRegistry.Characters[characterName]
end

function CharacterRegistry.GetAbilityBySlot(characterName, slot, isAwakened)
    local char = CharacterRegistry.Characters[characterName]
    if not char then return nil, nil end

    local abilities = isAwakened and char.AwakeningAbilities or char.Abilities
    local abilityName = abilities and abilities[slot]
    if not abilityName then return nil, nil end

    return abilityName, char.AbilityData and char.AbilityData[abilityName]
end

return CharacterRegistry
