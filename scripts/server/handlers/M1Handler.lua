--[[
	M1Handler.lua
	Handles GROUND M1 combos ONLY

	Clean, focused responsibility.
	Uses ModuleLoader for all dependencies.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Loader = require(ReplicatedStorage.Combat.ModuleLoader)

local M1Handler = {}

-- Dependencies (loaded through ModuleLoader)
local State, Cooldown, Hitbox, Config
local PassiveHandler, BlockHandler, CombatLockHandler
local ComboManager
local CharacterRegistry
local Remotes

local ActiveAttacks = {}
local LastRequest = {}

-- ====================================
-- INIT
-- ====================================

function M1Handler.Init(remotes, charRegistry)
	Remotes = remotes
	CharacterRegistry = charRegistry

	-- Load dependencies through ModuleLoader
	State = Loader.GetCore("StateManager")
	Cooldown = Loader.GetCore("CooldownManager")
	Hitbox = Loader.GetCore("HitboxHandler")
	Config = Loader.GetCore("Config")

	-- Load ComboManager
	ComboManager = require(script.Parent.ComboManager)

	print("[M1Handler] Initialized")
	return M1Handler
end

function M1Handler.SetDependencies(passive, block, combatLock)
	PassiveHandler = passive
	BlockHandler = block
	CombatLockHandler = combatLock
end

-- Setup event connections
function M1Handler.Connect()
	-- Get AerialM1Handler for routing
	local AerialM1Handler = require(script.Parent.AerialM1Handler)
	local AerialCombo = Loader.GetCore("AerialComboSystem")

	-- Listen to attack remote - route based on airborne state
	Remotes.Attack.OnServerEvent:Connect(function(player)
		local char = player.Character
		local hum = char and char:FindFirstChild("Humanoid")

		-- Check if player is airborne
		local isAirborne = (hum and hum.FloorMaterial == Enum.Material.Air) or
		                   State.GetState(player) == State.States.AIRBORNE or
		                   AerialCombo.IsInAir(player)

		if isAirborne then
			-- Route to aerial M1 handler
			AerialM1Handler.OnAerialAttack(player)
		else
			-- Route to ground M1 handler
			M1Handler.OnGroundAttack(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		ActiveAttacks[player] = nil
		LastRequest[player] = nil
	end)
end

-- ====================================
-- GROUND M1 ATTACK
-- ====================================

function M1Handler.OnGroundAttack(player)
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

	-- Get character data
	local charName = State.GetCharacter(player)
	local charData = CharacterRegistry.Get(charName)
	if not charData or not charData.M1 then return end

	local m1Data = charData.M1

	-- State checks
	if State.IsStunned(player) or State.IsBlocking(player) or
	   State.IsDashing(player) or State.IsGuardBroken(player) then
		return
	end

	-- Cooldown check
	if not Cooldown.IsReady(player, Cooldown.Actions.M1) then
		return
	end

	-- Get combo from ComboManager
	local combo = ComboManager.GetGroundCombo(player)
	local timeSinceAttack = ComboManager.TimeSinceLastAttack(player)

	-- Reset combo if window expired
	if timeSinceAttack > m1Data.ComboWindow then
		combo = 0
		ComboManager.ResetGroundCombo(player)
	end

	-- Check max combo
	if combo >= m1Data.MaxCombo then
		return
	end

	-- Increment combo
	combo = combo + 1
	ComboManager.SetGroundCombo(player, combo)
	ComboManager.UpdateLastAttack(player)

	-- Get hit data
	local hitData = m1Data.Hits[combo]
	if not hitData then
		ComboManager.ResetGroundCombo(player)
		return
	end

	-- Execute attack
	M1Handler.ExecuteGroundM1(player, charData, hitData, combo, m1Data)
end

-- ====================================
-- EXECUTION
-- ====================================

function M1Handler.ExecuteGroundM1(player, charData, hitData, combo, m1Data)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Set cooldown
	local totalTime = hitData.startup + hitData.active + hitData.recovery
	Cooldown.Set(player, Cooldown.Actions.M1, totalTime)

	State.SetState(player, State.States.ATTACKING)

	-- Notify clients
	Remotes.State:FireAllClients(player, "M1", combo, {
		character = charData.Name,
		isFinal = combo >= m1Data.MaxCombo,
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
	local hitboxSize = m1Data.HitboxSize or Vector3.new(4, 4, 5)
	local hitboxOffset = m1Data.HitboxOffset or Vector3.new(0, 0, -3)

	local hasHit = {}
	local activeStart = tick()

	while tick() - activeStart < hitData.active do
		if ActiveAttacks[player] ~= attackId then return end

		local origin = hrp.CFrame * CFrame.new(hitboxOffset)

		Hitbox.Box(origin, hitboxSize, {char}, function(victimPlayer, victimChar, victimHum, victimHrp)
			if hasHit[victimChar] then return end
			hasHit[victimChar] = true

			M1Handler.ApplyHit(player, victimPlayer, victimChar, victimHum, victimHrp, {
				damage = damage,
				knockback = knockback,
				postureDamage = postureDamage,
				lift = hitData.lift or 0,
				combo = combo,
				isFinal = combo >= m1Data.MaxCombo,
				hitstun = m1Data.Hitstun,
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

	-- Handle combo reset
	if combo >= m1Data.MaxCombo then
		ComboManager.ResetGroundCombo(player)
		Cooldown.Set(player, Cooldown.Actions.M1, Config.Combat.ComboResetCooldown or 1.5)

		task.delay(0.5, function()
			if CombatLockHandler then
				CombatLockHandler.ForceUnlock(player)
			end
		end)
	else
		task.delay(m1Data.ComboWindow, function()
			if ComboManager.GetGroundCombo(player) == combo then
				ComboManager.ResetGroundCombo(player)
			end
		end)
	end
end

-- ====================================
-- HIT APPLICATION
-- ====================================

function M1Handler.ApplyHit(attacker, victimPlayer, victimChar, victimHum, victimHrp, hitInfo)
	local attackerChar = attacker.Character
	local attackerHrp = attackerChar and attackerChar:FindFirstChild("HumanoidRootPart")
	if not attackerHrp then return end

	local damage = hitInfo.damage
	local knockback = hitInfo.knockback
	local postureDamage = hitInfo.postureDamage
	local lift = hitInfo.lift or 0
	local isFinal = hitInfo.isFinal
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

		-- Combat lock (only if not final)
		if not isFinal and CombatLockHandler then
			local lockDuration = hitstun + 0.2
			CombatLockHandler.LockPlayers(attacker, victimPlayer, lockDuration)
		end

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

	-- Apply knockback
	if actualKnockback > 0 and not (blocked == "Deflect") then
		local kbDir = attackerHrp.CFrame.LookVector
		local kbVelocity = Vector3.new(kbDir.X, 0, kbDir.Z).Unit * actualKnockback

		if lift > 0 then
			kbVelocity = kbVelocity + Vector3.new(0, lift, 0)
		end

		victimHrp.AssemblyLinearVelocity = kbVelocity
	end

	-- Apply hitstun
	if not blocked and victimPlayer then
		local vd = State.Get(victimPlayer)
		if vd then
			State.SetState(victimPlayer, State.States.STUNNED)

			task.delay(hitstun, function()
				if victimPlayer and State.IsStunned(victimPlayer) then
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
		hitType = isFinal and "Final" or "Light",
		blocked = blocked,
		attackDir = attackerHrp.CFrame.LookVector,
	})
end

-- ====================================
-- CLEANUP
-- ====================================

function M1Handler.Cancel(player)
	ActiveAttacks[player] = nil
end

return M1Handler
