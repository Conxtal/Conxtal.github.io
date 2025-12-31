--[[
	AnimationHandler_Enhanced.lua
	ENHANCED animation system with smooth transitions, tweening, and Genshin/Sifu-style flow

	FEATURES:
	- Smooth animation blending
	- State-based transition system
	- Root motion tweening
	- Animation queueing for combo flow
	- Automatic cleanup and fade management
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local AnimationHandler = {}

-- ==============================
-- CONSTANTS
-- ==============================

local TRANSITION_TIMES = {
	-- Transition FROM -> TO
	Idle_Attack = 0.08,      -- Quick snap into attack
	Attack_Attack = 0.05,    -- Super fast between combos
	Attack_Idle = 0.15,      -- Smooth return to idle
	Attack_Dash = 0.03,      -- Instant cancel
	Idle_Dash = 0.05,
	Dash_Idle = 0.10,
	Idle_Block = 0.12,
	Block_Idle = 0.15,
	Any_Hit = 0.02,          -- Instant hit reaction
	Default = 0.12,          -- Fallback
}

local STATE_CATEGORIES = {
	Idle = "Idle",
	M1_1 = "Attack", M1_2 = "Attack", M1_3 = "Attack", M1_4 = "Attack",
	Uptilt = "Attack",
	Aerial = "Attack",
	DashForward = "Dash", DashLeft = "Dash", DashRight = "Dash", DashBack = "Dash",
	BlockIdle = "Block",
	HitLight = "Hit", HitHeavy = "Hit", HitLaunch = "Hit",
}

-- ==============================
-- INTERNAL STATE
-- ==============================

local CharacterData = {}          -- [characterName] = data
local LoadedTracks = {}           -- [character] = { [animName] = AnimationTrack }
local Animators = {}              -- [character] = Animator
local CurrentState = {}           -- [character] = current animation state category
local ActiveTrack = {}            -- [character] = currently playing track
local QueuedAnimation = {}        -- [character] = queued anim to play next

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

local function GetStateCategory(animName)
	return STATE_CATEGORIES[animName] or "Other"
end

local function GetTransitionTime(fromState, toState)
	local key = fromState .. "_" .. toState
	return TRANSITION_TIMES[key] or TRANSITION_TIMES.Default
end

-- ==============================
-- ROOT MOTION TWEENING
-- ==============================

local ActiveTweens = {}

local function TweenRootMotion(character, targetCFrame, duration, easingStyle)
	if ActiveTweens[character] then
		ActiveTweens[character]:Cancel()
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	easingStyle = easingStyle or Enum.EasingStyle.Sine
	local tween = TweenService:Create(hrp, TweenInfo.new(duration, easingStyle, Enum.EasingDirection.Out), {
		CFrame = targetCFrame
	})

	ActiveTweens[character] = tween
	tween:Play()

	tween.Completed:Connect(function()
		ActiveTweens[character] = nil
	end)

	return tween
end

function AnimationHandler.StopRootMotion(character)
	if ActiveTweens[character] then
		ActiveTweens[character]:Cancel()
		ActiveTweens[character] = nil
	end
end

-- ==============================
-- INIT
-- ==============================

function AnimationHandler.Init()
	if Player.Character then
		AnimationHandler.SetupCharacter(Player.Character)
	end

	Player.CharacterAdded:Connect(AnimationHandler.SetupCharacter)

	print("[AnimationHandler Enhanced] Initialized")
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
	CurrentState[character] = "Idle"
	ActiveTrack[character] = nil
	QueuedAnimation[character] = nil

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

	AnimationHandler.StopRootMotion(character)

	LoadedTracks[character] = nil
	Animators[character] = nil
	CurrentState[character] = nil
	ActiveTrack[character] = nil
	QueuedAnimation[character] = nil
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

			-- Auto-cleanup on stop
			track.Stopped:Connect(function()
				if ActiveTrack[character] == track then
					ActiveTrack[character] = nil
					-- Check for queued animation
					if QueuedAnimation[character] then
						local queued = QueuedAnimation[character]
						QueuedAnimation[character] = nil
						AnimationHandler.Play(character, queued.name, queued.options)
					end
				end
			end)
		end
	end
end

-- ==============================
-- ENHANCED PLAY FUNCTION
-- ==============================

function AnimationHandler.Play(character, animName, options)
	character = character or Player.Character
	if not character then return end

	local tracks = LoadedTracks[character]
	if not tracks then return end

	local track = tracks[animName]
	if not track then return end

	options = options or {}

	-- Determine state categories
	local fromState = CurrentState[character] or "Idle"
	local toState = GetStateCategory(animName)

	-- Calculate transition time
	local fadeInTime = options.fadeIn
	if not fadeInTime then
		fadeInTime = GetTransitionTime(fromState, toState)
	end

	local fadeOutTime = options.fadeOut or (fadeInTime * 0.8)

	-- STOP PREVIOUS ANIMATIONS with smart fading
	local previousTrack = ActiveTrack[character]
	if previousTrack and previousTrack.IsPlaying and previousTrack ~= track then
		previousTrack:Stop(fadeOutTime)
	end

	-- Stop other conflicting tracks
	if not options.dontStopOthers then
		for _, other in pairs(tracks) do
			if other ~= track and other ~= previousTrack and other.IsPlaying then
				if not other.Looped or options.stopLooped then
					other:Stop(fadeOutTime * 0.5)
				end
			end
		end
	end

	-- APPLY SETTINGS
	track.Looped = options.looped or false
	track.Priority = options.priority or Enum.AnimationPriority.Action

	-- APPLY SPEED (with animation speed modifiers)
	local speed = options.speed
	if speed == nil then
		local charName = GetLocalCharacterName()
		speed = GetAnimSpeed(charName, animName)
	end

	if speed then
		track:AdjustSpeed(speed)
	end

	-- PLAY WITH SMOOTH FADE
	track:Play(fadeInTime)

	-- Update state
	CurrentState[character] = toState
	ActiveTrack[character] = track

	-- ROOT MOTION (optional)
	if options.rootMotion and options.rootMotion.target then
		TweenRootMotion(
			character,
			options.rootMotion.target,
			options.rootMotion.duration or 0.15,
			options.rootMotion.easing
		)
	end

	return track
end

-- ==============================
-- QUEUEING SYSTEM (for combo flow)
-- ==============================

function AnimationHandler.Queue(character, animName, options)
	character = character or Player.Character
	if not character then return end

	QueuedAnimation[character] = {
		name = animName,
		options = options or {}
	}
end

function AnimationHandler.ClearQueue(character)
	character = character or Player.Character
	QueuedAnimation[character] = nil
end

-- ==============================
-- SPECIFIC ACTIONS (Enhanced)
-- ==============================

function AnimationHandler.PlayM1(character, combo)
	return AnimationHandler.Play(character, "M1_" .. combo, {
		priority = Enum.AnimationPriority.Action2,
		fadeIn = 0.05,  -- Super fast combo transitions
	})
end

function AnimationHandler.PlayAirM1(character, combo)
	return AnimationHandler.Play(character, "AirM1_" .. combo, {
		priority = Enum.AnimationPriority.Action3,
		fadeIn = 0.03,  -- Even faster in air
	})
end

function AnimationHandler.PlayUptilt(character)
	return AnimationHandler.Play(character, "Uptilt", {
		priority = Enum.AnimationPriority.Action2,
		fadeIn = 0.08,
	})
end

function AnimationHandler.PlayAerial(character)
	return AnimationHandler.Play(character, "Aerial", {
		priority = Enum.AnimationPriority.Action3,
		fadeIn = 0.05,
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
		fadeIn = 0.03,
	})

	if track then
		task.delay(0.12, function()
			if track.IsPlaying then
				track:Stop(0.08)
			end
		end)
	end

	return track
end

function AnimationHandler.PlayBlock(character)
	return AnimationHandler.Play(character, "BlockIdle", {
		looped = true,
		priority = Enum.AnimationPriority.Action,
		fadeIn = 0.12,
	})
end

function AnimationHandler.PlayHitReaction(character, hitType)
	local anim = "HitLight"
	if hitType == "Final" then anim = "HitHeavy"
	elseif hitType == "Uptilt" then anim = "HitLaunch"
	elseif hitType == "Aerial" then anim = "HitHeavy" end

	return AnimationHandler.Play(character, anim, {
		priority = Enum.AnimationPriority.Action4,
		fadeIn = 0.02,  -- Instant hit reaction
	})
end

function AnimationHandler.PlayAbility(character, ability)
	return AnimationHandler.Play(character, ability, {
		priority = Enum.AnimationPriority.Action2,
		fadeIn = 0.10,
	})
end

function AnimationHandler.Stop(character, animName, fadeTime)
	character = character or Player.Character
	if not character then return end

	local tracks = LoadedTracks[character]
	if not tracks then return end

	local track = tracks[animName]
	if track and track.IsPlaying then
		track:Stop(fadeTime or 0.15)
	end
end

-- ==============================
-- REMOTE PLAYERS (Enhanced)
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

	-- Enhanced fade in times based on state
	local fadeIn = options.fadeIn or 0.08
	track:Play(fadeIn)

	if not options.looped then
		track.Stopped:Once(function()
			track:Destroy()
		end)
	end

	return track
end

return AnimationHandler
