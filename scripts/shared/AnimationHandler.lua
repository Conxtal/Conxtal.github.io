--[[
	AnimationHandler.lua
	Loads and plays animations from character data
	FULLY FIXED VERSION
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local AnimationHandler = {}

-- ==============================
-- INTERNAL STATE
-- ==============================

local CharacterData = {}          -- [characterName] = data
local LoadedTracks = {}           -- [character] = { [animName] = AnimationTrack }
local Animators = {}              -- [character] = Animator

-- ==============================
-- HELPERS
-- ==============================

local function GetState()
    local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
    return require(CombatFolder.Modules.StateManager)
end

local function GetLocalCharacterName()
    return GetState().GetCharacter(Player) or "Arthur"
end

local function GetCharacterDataByName(name)
    if CharacterData[name] then
        return CharacterData[name]
    end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local rf = remotes:FindFirstChild("GetCharacterData")
        if rf then
            local data = rf:InvokeServer(name)
            if data then
                CharacterData[name] = data
                return data
            end
        end
    end

    return nil
end

local function GetAnimSpeed(characterName, animName)
    local data = GetCharacterDataByName(characterName)
    if data and data.AnimationSpeeds then
        return data.AnimationSpeeds[animName]
    end
    return nil
end

-- ==============================
-- INIT
-- ==============================

function AnimationHandler.Init()
    if Player.Character then
        AnimationHandler.SetupCharacter(Player.Character)
    end

    Player.CharacterAdded:Connect(AnimationHandler.SetupCharacter)

    print("[AnimationHandler] Initialized")
    return AnimationHandler
end

function AnimationHandler.SetupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    Animators[character] = animator
    LoadedTracks[character] = {}

    local charName = GetLocalCharacterName()
    AnimationHandler.LoadCharacterAnims(character, charName)

    humanoid.Died:Connect(function()
        AnimationHandler.CleanupCharacter(character)
    end)
end

function AnimationHandler.CleanupCharacter(character)
    if LoadedTracks[character] then
        for _, track in pairs(LoadedTracks[character]) do
            track:Stop(0)
            track:Destroy()
        end
    end

    LoadedTracks[character] = nil
    Animators[character] = nil
end

-- ==============================
-- LOAD ANIMATIONS
-- ==============================

function AnimationHandler.LoadCharacterAnims(character, characterName)
    local animator = Animators[character]
    if not animator then return end

    LoadedTracks[character] = {}

    local charData = GetCharacterDataByName(characterName)
    if not charData or not charData.Animations then return end

    for animName, animId in pairs(charData.Animations) do
        if animId ~= "" and animId ~= "rbxassetid://0" then
            local anim = Instance.new("Animation")
            anim.AnimationId = animId
            local track = animator:LoadAnimation(anim)
            LoadedTracks[character][animName] = track
        end
    end
end

-- ==============================
-- CORE PLAY FUNCTION (FIXED)
-- ==============================

function AnimationHandler.Play(character, animName, options)
    character = character or Player.Character
    if not character then return end

    local tracks = LoadedTracks[character]
    if not tracks then return end

    local track = tracks[animName]
    if not track then return end

    options = options or {}

    track.Looped = options.looped or false
    track.Priority = options.priority or Enum.AnimationPriority.Action

    -- STOP OTHER TRACKS FIRST
    if not options.dontStopOthers then
        for _, other in pairs(tracks) do
            if other ~= track and other.IsPlaying then
                if not other.Looped or options.stopLooped then
                    other:Stop(options.fadeOut or 0.1)
                end
            end
        end
    end

    -- APPLY SPEED
    local speed = options.speed
    if speed == nil then
        local charName = GetLocalCharacterName()
        speed = GetAnimSpeed(charName, animName)
    end

    if speed then
        track:AdjustSpeed(speed)
    end

    -- PLAY ONCE (NO DOUBLE PLAY)
    track:Play(options.fadeIn or 0.05)

    return track
end

-- ==============================
-- SPECIFIC ACTIONS
-- ==============================

function AnimationHandler.PlayM1(character, combo)
    return AnimationHandler.Play(character, "M1_" .. combo, {
        priority = Enum.AnimationPriority.Action2,
    })
end

function AnimationHandler.PlayUptilt(character)
    return AnimationHandler.Play(character, "Uptilt", {
        priority = Enum.AnimationPriority.Action2,
    })
end

function AnimationHandler.PlayDash(character, direction)
    local anim = "DashForward"

    if direction == "Left" then anim = "DashLeft"
    elseif direction == "Right" then anim = "DashRight"
    elseif direction == "Back" then anim = "DashBack"
    end

    local track = AnimationHandler.Play(character, anim, {
        priority = Enum.AnimationPriority.Action4,
        dontStopOthers = true,
        stopLooped = true,
    })

    if track then
        task.delay(0.12, function()
            if track.IsPlaying then
                track:Stop(0.05)
            end
        end)
    end
end

function AnimationHandler.PlayBlock(character)
    return AnimationHandler.Play(character, "BlockIdle", {
        looped = true,
        priority = Enum.AnimationPriority.Action,
    })
end

function AnimationHandler.PlayHitReaction(character, hitType)
    local anim = "HitLight"
    if hitType == "Final" then anim = "HitHeavy"
    elseif hitType == "Uptilt" then anim = "HitLaunch" end

    return AnimationHandler.Play(character, anim, {
        priority = Enum.AnimationPriority.Action4,
    })
end

function AnimationHandler.PlayAbility(character, ability)
    return AnimationHandler.Play(character, ability, {
        priority = Enum.AnimationPriority.Action2,
    })
end

-- ==============================
-- REMOTE PLAYERS
-- ==============================

function AnimationHandler.PlayOn(character, animName, options)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local player = Players:GetPlayerFromCharacter(character)
    local charName = player and GetState().GetCharacter(player) or "Arthur"
    local data = GetCharacterDataByName(charName)
    if not data or not data.Animations then return end

    local animId = data.Animations[animName]
    if not animId then return end

    local anim = Instance.new("Animation")
    anim.AnimationId = animId
    local track = animator:LoadAnimation(anim)

    options = options or {}
    track.Priority = options.priority or Enum.AnimationPriority.Action

    local speed = options.speed or (data.AnimationSpeeds and data.AnimationSpeeds[animName])
    if speed then
        track:AdjustSpeed(speed)
    end

    track:Play(options.fadeIn or 0.05)

    if not options.looped then
        track.Stopped:Once(function()
            track:Destroy()
        end)
    end

    return track
end

return AnimationHandler
