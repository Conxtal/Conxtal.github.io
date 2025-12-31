--[[
	AerialM1Handler.lua
	Handles AERIAL M1 combos ONLY

	Clean separation from ground M1s.
	Works with AerialComboSystem for state management.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Loader = require(ReplicatedStorage.Combat.ModuleLoader)

local AerialM1Handler = {}

-- Dependencies
local State, Cooldown, Hitbox, Config
local AerialCombo
local PassiveHandler, BlockHandler
local ComboManager
local CharacterRegistry
local Remotes

local ActiveAttacks = {}

-- ====================================
-- INIT
-- ====================================

function AerialM1Handler.Init(remotes, charRegistry)
	Remotes = remotes
	CharacterRegistry = charRegistry

	-- Load core dependencies
	State = Loader.GetCore("StateManager")
	Cooldown = Loader.GetCore("CooldownManager")
	Hitbox = Loader.GetCore("HitboxHandler")
	Config = Loader.GetCore("Config")
	AerialCombo = Loader.GetCore("AerialComboSystem")

	-- Load combo manager
	ComboManager = require(script.Parent.ComboManager)

	print("[AerialM1Handler] Initialized")
	return AerialM1Handler
end

function AerialM1Handler.SetDependencies(passive, block)
	PassiveHandler = passive
	BlockHandler = block
end

-- Setup event connections
function AerialM1Handler.Connect()
	-- AerialM1 is triggered by the same Attack remote but handled differently
	-- The routing happens in a central place based on airborne state
	-- For now, this handler doesn't need its own remote connection
	-- It's called by M1Handler or AttackHandler based on player state
end

-- ====================================
-- AERIAL M1 ATTACK
-- ====================================

function AerialM1Handler.OnAerialAttack(player)
	local data = State.Get(player)
	if not data then return end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChild("Humanoid")
	if not hrp or not hum then return end

	-- Get character data
	local charName = State.GetCharacter(player)
	local charData = CharacterRegistry.Get(charName)
	if not charData or not charData.AerialM1 then return end

	local airData = charData.AerialM1

	-- State checks
	if State.IsStunned(player) or State.IsBlocking(player) or
	   State.IsDashing(player) or State.IsGuardBroken(player) then
		return
	end

	-- Check if can do air combo
	if not AerialCombo.CanAirCombo(player) then
		return
	end

	-- Increment air combo
	if not AerialCombo.IncrementAirCombo(player) then
		return
	end

	local airCombo = AerialCombo.GetAirCombo(player)
	local hitData = airData.Hits[airCombo]
	if not hitData then return end

	-- Execute
	AerialM1Handler.ExecuteAerialM1(player, charData, hitData, airCombo, airData)
end

-- ====================================
-- EXECUTION
-- ====================================

function AerialM1Handler.ExecuteAerialM1(player, charData, hitData, airCombo, airData)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Set cooldown
	local totalTime = hitData.startup + hitData.active + hitData.recovery
	Cooldown.Set(player, Cooldown.Actions.M1, totalTime)

	State.SetState(player, State.States.ATTACKING)

	-- Notify clients
	Remotes.State:FireAllClients(player, "AirM1", airCombo, {
		character = charData.Name,
		isFinal = airCombo >= AerialCombo.GetMaxAirHits(player),
	})

	local attackId = tick()
	ActiveAttacks[player] = attackId

	-- Calculate damage
	local damage = hitData.damage * (charData.Stats.Damage or 1)
	local knockback = hitData.knockback * (charData.Stats.Knockback or 1)
	local postureDamage = hitData.postureDamage or (damage * 0.5)

	-- Apply bonuses
	if PassiveHandler then
		damage = damage * PassiveHandler.GetDamageMultiplier(player)
	end

	local data = State.Get(player)
	if data and data.awakened and charData.Awakening then
		damage = damage * (charData.Awakening.DamageMultiplier or 1)
	end

	-- Startup
	task.wait(hitData.startup)
	if ActiveAttacks[player] ~= attackId then return end

	-- Hitbox
	local hitboxSize = airData.HitboxSize or Vector3.new(5, 5, 6)
	local hitboxOffset = airData.HitboxOffset or Vector3.new(0, 0, -3)

	local hasHit = {}
	local activeStart = tick()

	while tick() - activeStart < hitData.active do
		if ActiveAttacks[player] ~= attackId then return end

		local origin = hrp.CFrame * CFrame.new(hitboxOffset)

		Hitbox.Box(origin, hitboxSize, {char}, function(victimPlayer, victimChar, victimHum, victimHrp)
			if hasHit[victimChar] then return end
			hasHit[victimChar] = true

			AerialM1Handler.ApplyHit(player, victimPlayer, victimChar, victimHum, victimHrp, {
				damage = damage,
				knockback = knockback,
				postureDamage = postureDamage,
				lift = hitData.lift or 0,
				combo = airCombo,
				isFinal = airCombo >= AerialCombo.GetMaxAirHits(player),
				hitstun = airData.Hitstun,
				charData = charData,
			})
		end)

		task.wait()
	end

	if ActiveAttacks[player] ~= attackId then return end

	-- Recovery
	State.SetState(player, State.States.RECOVERY)
	task.wait(hitData.recovery)

	if ActiveAttacks[player] ~= attackId then return end

	if State.IsRecovery(player) then
		State.SetState(player, State.States.IDLE)
	end

	ActiveAttacks[player] = nil

	-- Handle combo end
	if airCombo >= AerialCombo.GetMaxAirHits(player) then
		task.delay(0.5, function()
			AerialCombo.EndAerialState(player)
			ComboManager.ResetAll(player)
		end)
	end
end

-- ====================================
-- HIT APPLICATION
-- ====================================

function AerialM1Handler.ApplyHit(attacker, victimPlayer, victimChar, victimHum, victimHrp, hitInfo)
	local attackerChar = attacker.Character
	local attackerHrp = attackerChar and attackerChar:FindFirstChild("HumanoidRootPart")
	if not attackerHrp then return end

	local damage = hitInfo.damage
	local knockback = hitInfo.knockback
	local postureDamage = hitInfo.postureDamage
	local lift = hitInfo.lift or 0
	local hitstun = hitInfo.hitstun

	local blocked = nil
	local actualDamage = damage
	local actualKnockback = knockback

	-- Player checks
	if victimPlayer then
		local vd = State.Get(victimPlayer)

		if vd and State.HasIFrames(victimPlayer) then
			return
		end

		State.UpdatePressure(victimPlayer)

		if vd and State.IsBlockingActive(victimPlayer) then
			blocked, actualDamage, actualKnockback = BlockHandler.ProcessBlockedHit(attacker, victimPlayer, hitInfo)
		else
			State.DamagePosture(victimPlayer, postureDamage)
		end
	end

	-- Apply damage
	if actualDamage > 0 then
		victimHum:TakeDamage(actualDamage)
	end

	-- Apply knockback (keep in air)
	if actualKnockback > 0 and not (blocked == "Deflect") then
		local kbDir = attackerHrp.CFrame.LookVector
		local kbVelocity = Vector3.new(kbDir.X, 0, kbDir.Z).Unit * actualKnockback

		if lift > 0 then
			kbVelocity = kbVelocity + Vector3.new(0, lift, 0)
		end

		victimHrp.AssemblyLinearVelocity = kbVelocity
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

	-- Passive
	if PassiveHandler and not blocked then
		PassiveHandler.OnHit(attacker, victimPlayer, hitInfo)
	end

	-- Fire event
	Remotes.Hit:FireAllClients({
		attacker = attacker,
		victim = victimPlayer,
		victimChar = victimChar,
		position = victimHrp.Position,
		damage = actualDamage,
		knockback = actualKnockback,
		combo = hitInfo.combo,
		hitType = "Air",
		blocked = blocked,
		attackDir = attackerHrp.CFrame.LookVector,
	})
end

-- ====================================
-- CLEANUP
-- ====================================

function AerialM1Handler.Cancel(player)
	ActiveAttacks[player] = nil
end

return AerialM1Handler
