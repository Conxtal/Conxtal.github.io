--[[
	UptiltHandler_V2.lua
	REFACTORED: Cleaner uptilt handling with aerial state initialization

	Features:
	- Launches enemies airborne
	- Starts aerial combo state
	- Tracks ground combo for air hit inheritance
	- Can only uptilt before combo 3
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
local Hitbox = require(CombatFolder.Modules.HitboxHandler)
local State = require(CombatFolder.Modules.StateManager)
local Cooldown = require(CombatFolder.Modules.CooldownManager)
local Config = require(CombatFolder.Config)
local AerialCombo = require(CombatFolder.Modules.AerialComboSystem)

local UptiltHandler = {}

local Remotes = nil
local CharacterManager = nil
local PassiveHandler = nil
local BlockHandler = nil
local ActiveUptilts = {}
local LastRequest = {}

-- ==============================
-- INIT
-- ==============================

function UptiltHandler.Init(remotes, charManager)
	Remotes = remotes
	CharacterManager = charManager
	PassiveHandler = require(script.Parent.PassiveHandler)
	BlockHandler = require(script.Parent.BlockHandler)

	Remotes.Uptilt.OnServerEvent:Connect(function(player)
		UptiltHandler.OnUptilt(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ActiveUptilts[player] = nil
		LastRequest[player] = nil
		AerialCombo.Cleanup(player)
	end)

	print("[UptiltHandler V2] Initialized")
	return UptiltHandler
end

-- ==============================
-- MAIN HANDLER
-- ==============================

function UptiltHandler.OnUptilt(player)
	-- Throttle
	local now = tick()
	if now - (LastRequest[player] or 0) < 0.05 then return end
	LastRequest[player] = now

	local data = State.Get(player)
	if not data then return end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChild("Humanoid")
	if not hrp or not hum then return end

	local charName = State.GetCharacter(player)
	local charData = CharacterManager.Get(charName)
	if not charData or not charData.Uptilt then return end

	local uptiltData = charData.Uptilt

	-- State checks
	if State.IsStunned(player) or State.IsBlocking(player) or
	   State.IsDashing(player) or State.IsGuardBroken(player) then
		return
	end

	-- Cooldown check
	if not Cooldown.IsReady(player, "Uptilt") then
		return
	end

	-- IMPORTANT: Can only uptilt before combo 3
	-- This means: M1-1, M1-2 = can uptilt
	-- M1-3, M1-4 = cannot uptilt
	local groundCombo = State.GetCombo(player)
	if uptiltData.MaxComboToUse and groundCombo > uptiltData.MaxComboToUse then
		return
	end

	-- Stamina check
	local staminaCost = uptiltData.StaminaCost or 0
	if staminaCost > 0 and not State.HasStamina(player, staminaCost) then
		return
	end

	-- Use stamina
	if staminaCost > 0 then
		State.UseStamina(player, staminaCost)
	end

	-- START AERIAL STATE (this is the key part!)
	-- If they uptilt at M1-1: they get 3 air hits
	-- If they uptilt at M1-2: they get 2 air hits
	-- If they uptilt at M1-3: they get 1 air hit (but can't due to MaxComboToUse)
	local maxAirHits = AerialCombo.StartAerialState(player, groundCombo)

	print(string.format("[Uptilt] Player %s started aerial state. Ground combo: %d, Max air hits: %d",
		player.Name, groundCombo, maxAirHits))

	-- Set state
	State.SetState(player, State.States.ATTACKING)

	-- Set cooldown
	local totalDuration = uptiltData.Startup + uptiltData.Active + uptiltData.Recovery
	Cooldown.Set(player, "Uptilt", totalDuration + (uptiltData.Cooldown or 0.5))

	-- Fire to clients
	Remotes.State:FireAllClients(player, "Uptilt", {
		character = charName,
		groundCombo = groundCombo,
		airHitsRemaining = maxAirHits,
	})

	local attackId = tick()
	ActiveUptilts[player] = attackId

	-- Calculate damage with bonuses
	local damage = uptiltData.Damage * (charData.Stats.Damage or 1)
	local launchVelocity = uptiltData.LaunchVelocity
	local forwardPush = uptiltData.ForwardPush or 0
	local postureDamage = uptiltData.PostureDamage or (damage * 0.8)

	-- Passive bonus
	if PassiveHandler then
		damage = damage * PassiveHandler.GetDamageMultiplier(player)
	end

	-- Awakening bonus
	if data.awakened and charData.Awakening then
		damage = damage * (charData.Awakening.DamageMultiplier or 1)
		launchVelocity = launchVelocity * 1.15
	end

	-- Startup
	task.wait(uptiltData.Startup)
	if ActiveUptilts[player] ~= attackId then return end

	-- Hitbox
	local hitboxSize = uptiltData.HitboxSize or Vector3.new(4, 6, 4)
	local hitboxOffset = uptiltData.HitboxOffset or Vector3.new(0, 2, -3)

	local hasHit = {}
	local activeStart = tick()

	while tick() - activeStart < uptiltData.Active do
		if ActiveUptilts[player] ~= attackId then return end

		local origin = hrp.CFrame * CFrame.new(hitboxOffset)

		Hitbox.Box(origin, hitboxSize, {char}, function(victimPlayer, victimChar, victimHum, victimHrp)
			if hasHit[victimChar] then return end
			hasHit[victimChar] = true

			UptiltHandler.ApplyHit(player, victimPlayer, victimChar, victimHum, victimHrp, {
				damage = damage,
				launchVelocity = launchVelocity,
				forwardPush = forwardPush,
				postureDamage = postureDamage,
				hitstun = uptiltData.Hitstun,
				charData = charData,
			})
		end)

		task.wait()
	end

	if ActiveUptilts[player] ~= attackId then return end

	-- Recovery
	State.SetState(player, State.States.RECOVERY)

	local recoveryTime = (next(hasHit) ~= nil) and uptiltData.RecoveryOnHit or uptiltData.Recovery
	task.wait(recoveryTime)

	if ActiveUptilts[player] ~= attackId then return end

	if State.IsRecovery(player) then
		State.SetState(player, State.States.IDLE)
	end

	ActiveUptilts[player] = nil
end

-- ==============================
-- HIT APPLICATION
-- ==============================

function UptiltHandler.ApplyHit(attacker, victimPlayer, victimChar, victimHum, victimHrp, hitInfo)
	local attackerChar = attacker.Character
	local attackerHrp = attackerChar and attackerChar:FindFirstChild("HumanoidRootPart")
	if not attackerHrp then return end

	local damage = hitInfo.damage
	local launchVelocity = hitInfo.launchVelocity
	local forwardPush = hitInfo.forwardPush
	local postureDamage = hitInfo.postureDamage
	local hitstun = hitInfo.hitstun

	local blocked = nil
	local actualDamage = damage

	-- Player vs Player
	if victimPlayer then
		local vd = State.Get(victimPlayer)

		if vd and State.HasIFrames(victimPlayer) then
			return
		end

		State.UpdatePressure(victimPlayer)

		if vd and State.IsBlockingActive(victimPlayer) then
			blocked, actualDamage = BlockHandler.ProcessBlockedHit(attacker, victimPlayer, hitInfo)
			if blocked then
				launchVelocity = launchVelocity * 0.3
				forwardPush = forwardPush * 0.3
			end
		else
			State.DamagePosture(victimPlayer, postureDamage)
		end
	end

	-- Apply damage
	if actualDamage > 0 then
		victimHum:TakeDamage(actualDamage)
	end

	-- Apply launch
	if launchVelocity > 0 and not (blocked == "Deflect") then
		local launchDir = attackerHrp.CFrame.LookVector
		local launchVel = Vector3.new(
			launchDir.X * forwardPush,
			launchVelocity,
			launchDir.Z * forwardPush
		)
		victimHrp.AssemblyLinearVelocity = launchVel
	end

	-- Apply airborne state
	if not blocked and victimPlayer then
		local vd = State.Get(victimPlayer)
		if vd then
			State.SetState(victimPlayer, State.States.AIRBORNE)

			task.delay(hitstun, function()
				if victimPlayer and State.GetState(victimPlayer) == State.States.AIRBORNE then
					State.SetState(victimPlayer, State.States.IDLE)
				end
			end)
		end
	end

	-- Passive handler
	if PassiveHandler and not blocked then
		PassiveHandler.OnHit(attacker, victimPlayer, hitInfo)
	end

	-- Fire hit event
	Remotes.Hit:FireAllClients({
		attacker = attacker,
		victim = victimPlayer,
		victimChar = victimChar,
		position = victimHrp.Position,
		damage = actualDamage,
		knockback = launchVelocity,
		hitType = "Uptilt",
		blocked = blocked,
		attackDir = attackerHrp.CFrame.LookVector,
	})
end

-- ==============================
-- CLEANUP
-- ==============================

function UptiltHandler.CancelUptilt(player)
	ActiveUptilts[player] = nil
	AerialCombo.EndAerialState(player)
end

return UptiltHandler
