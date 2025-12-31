--[[
	AttackHandler_V2.lua
	REFACTORED: Cleaner, modular attack handling

	Supports:
	- Ground M1 combos
	- Aerial M1 combos (after uptilt)
	- Combo inheritance (uptilt at M1-3 = 1 air hit remaining)
	- Proper state management
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
local Hitbox = require(CombatFolder.Modules.HitboxHandler)
local State = require(CombatFolder.Modules.StateManager)
local Cooldown = require(CombatFolder.Modules.CooldownManager)
local Config = require(CombatFolder.Config)
local AerialCombo = require(CombatFolder.Modules.AerialComboSystem)

local AttackHandler = {}

-- ==============================
-- STATE
-- ==============================

local Remotes = nil
local CharacterManager = nil
local PassiveHandler = nil
local BlockHandler = nil
local CombatLockHandler = nil

local ActiveAttacks = {}
local LastRequest = {}

-- ==============================
-- INIT
-- ==============================

function AttackHandler.Init(remotes, charManager)
	Remotes = remotes
	CharacterManager = charManager
	PassiveHandler = require(script.Parent.PassiveHandler)
	BlockHandler = require(script.Parent.BlockHandler)
	CombatLockHandler = require(script.Parent.CombatLock)

	Remotes.Attack.OnServerEvent:Connect(function(player)
		AttackHandler.OnAttack(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ActiveAttacks[player] = nil
		LastRequest[player] = nil
		CombatLockHandler.ForceUnlock(player)
		AerialCombo.Cleanup(player)
	end)

	print("[AttackHandler V2] Initialized")
	return AttackHandler
end

-- ==============================
-- MAIN ATTACK HANDLER
-- ==============================

function AttackHandler.OnAttack(player)
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

	-- Check if in air
	local isAirborne = hum.FloorMaterial == Enum.Material.Air or AerialCombo.IsInAir(player)

	if isAirborne then
		AttackHandler.HandleAerialAttack(player, data, char, hrp, hum)
	else
		AttackHandler.HandleGroundAttack(player, data, char, hrp, hum)
	end
end

-- ==============================
-- GROUND M1 COMBOS
-- ==============================

function AttackHandler.HandleGroundAttack(player, data, char, hrp, hum)
	local charName = State.GetCharacter(player)
	local charData = CharacterManager.Get(charName)
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

	-- Combo logic
	local combo = State.GetCombo(player)
	local timeSinceAttack = State.TimeSinceAttack(player)

	-- Reset combo if window expired
	if timeSinceAttack > m1Data.ComboWindow then
		combo = 0
		State.SetCombo(player, 0)
	end

	-- Check if already at max combo
	if combo >= m1Data.MaxCombo then
		return
	end

	combo = combo + 1
	State.SetCombo(player, combo)
	State.SetLastAttack(player)

	local hitData = m1Data.Hits[combo]
	if not hitData then
		State.ResetCombo(player)
		return
	end

	-- Execute attack
	AttackHandler.ExecuteAttack(player, charData, hitData, combo, false)
end

-- ==============================
-- AERIAL M1 COMBOS
-- ==============================

function AttackHandler.HandleAerialAttack(player, data, char, hrp, hum)
	local charName = State.GetCharacter(player)
	local charData = CharacterManager.Get(charName)
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

	-- Execute air attack
	AttackHandler.ExecuteAttack(player, charData, hitData, airCombo, true)
end

-- ==============================
-- UNIFIED ATTACK EXECUTION
-- ==============================

function AttackHandler.ExecuteAttack(player, charData, hitData, combo, isAerial)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Set cooldown
	local totalTime = hitData.startup + hitData.active + hitData.recovery
	Cooldown.Set(player, Cooldown.Actions.M1, totalTime)

	State.SetState(player, State.States.ATTACKING)

	-- Fire to clients
	local attackType = isAerial and "AirM1" or "M1"
	Remotes.State:FireAllClients(player, attackType, combo, {
		character = charData.Name,
		isFinal = isAerial and (combo >= AerialCombo.GetMaxAirHits(player)) or (combo >= charData.M1.MaxCombo),
	})

	local attackId = tick()
	ActiveAttacks[player] = attackId

	-- Calculate damage
	local damage = hitData.damage * (charData.Stats.Damage or 1)
	local knockback = hitData.knockback * (charData.Stats.Knockback or 1)
	local postureDamage = hitData.postureDamage or (damage * 0.5)

	-- Passive bonus
	if PassiveHandler then
		damage = damage * PassiveHandler.GetDamageMultiplier(player)
	end

	-- Awakening bonus
	local data = State.Get(player)
	if data and data.awakened and charData.Awakening then
		damage = damage * (charData.Awakening.DamageMultiplier or 1)
	end

	-- Startup
	task.wait(hitData.startup)
	if ActiveAttacks[player] ~= attackId then return end

	-- Hitbox
	local hitboxData = isAerial and charData.AerialM1 or charData.M1
	local hitboxSize = hitboxData.HitboxSize or Vector3.new(4, 4, 5)
	local hitboxOffset = hitboxData.HitboxOffset or Vector3.new(0, 0, -3)

	local hasHit = {}
	local activeStart = tick()

	while tick() - activeStart < hitData.active do
		if ActiveAttacks[player] ~= attackId then return end

		local origin = hrp.CFrame * CFrame.new(hitboxOffset)

		Hitbox.Box(origin, hitboxSize, {char}, function(victimPlayer, victimChar, victimHum, victimHrp)
			if hasHit[victimChar] then return end
			hasHit[victimChar] = true

			AttackHandler.ApplyHit(player, victimPlayer, victimChar, victimHum, victimHrp, {
				damage = damage,
				knockback = knockback,
				postureDamage = postureDamage,
				lift = hitData.lift or 0,
				combo = combo,
				isFinal = isAerial and (combo >= AerialCombo.GetMaxAirHits(player)) or (combo >= charData.M1.MaxCombo),
				hitstun = isAerial and charData.AerialM1.Hitstun or charData.M1.Hitstun,
				charData = charData,
				isAerial = isAerial,
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
	if not isAerial then
		if combo >= charData.M1.MaxCombo then
			State.ResetCombo(player)
			Cooldown.Set(player, Cooldown.Actions.M1, Config.Combat.ComboResetCooldown or 1.5)

			task.delay(0.5, function()
				CombatLockHandler.ForceUnlock(player)
			end)
		else
			task.delay(charData.M1.ComboWindow, function()
				if State.GetCombo(player) == combo then
					State.ResetCombo(player)
					Cooldown.Set(player, Cooldown.Actions.M1, Config.Combat.ComboResetCooldown or 1.5)
				end
			end)
		end
	else
		-- Air combo finished
		if combo >= AerialCombo.GetMaxAirHits(player) then
			task.delay(0.5, function()
				AerialCombo.EndAerialState(player)
				State.ResetCombo(player)
			end)
		end
	end
end

-- ==============================
-- HIT APPLICATION
-- ==============================

function AttackHandler.ApplyHit(attacker, victimPlayer, victimChar, victimHum, victimHrp, hitInfo)
	local attackerChar = attacker.Character
	local attackerHrp = attackerChar and attackerChar:FindFirstChild("HumanoidRootPart")
	if not attackerHrp then return end

	local damage = hitInfo.damage
	local knockback = hitInfo.knockback
	local postureDamage = hitInfo.postureDamage
	local lift = hitInfo.lift or 0
	local isFinal = hitInfo.isFinal
	local hitstun = hitInfo.hitstun
	local isAerial = hitInfo.isAerial

	local blocked = nil
	local actualDamage = damage
	local actualKnockback = knockback

	-- Player vs Player
	if victimPlayer then
		local vd = State.Get(victimPlayer)

		if vd and State.HasIFrames(victimPlayer) then
			return
		end

		State.UpdatePressure(victimPlayer)

		-- Combat lock (only if not final and not aerial)
		if not isFinal and not isAerial then
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
			local stunState = isAerial and State.States.AIRBORNE or State.States.STUNNED
			State.SetState(victimPlayer, stunState)

			task.delay(hitstun, function()
				if victimPlayer and State.GetState(victimPlayer) == stunState then
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
		knockback = actualKnockback,
		combo = hitInfo.combo,
		hitType = isAerial and "Air" or (isFinal and "Final" or "Light"),
		blocked = blocked,
		attackDir = attackerHrp.CFrame.LookVector,
	})
end

-- ==============================
-- CLEANUP
-- ==============================

function AttackHandler.CancelAttack(player)
	ActiveAttacks[player] = nil
	CombatLockHandler.ForceUnlock(player)
end

return AttackHandler
