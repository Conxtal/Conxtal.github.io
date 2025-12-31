--[[
	AerialHandler.lua
	Handles Aerial down slam attacks (plunge attacks)
	Location: ServerScriptService/Combat/Handlers/AerialHandler

	MECHANICS:
	- Can only be used while airborne
	- Slams down with AOE damage
	- Creates ground impact VFX
	- Similar to Genshin Impact plunge attacks
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
local Hitbox = require(CombatFolder.Modules.HitboxHandler)
local State = require(CombatFolder.Modules.StateManager)
local Cooldown = require(CombatFolder.Modules.CooldownManager)
local Config = require(CombatFolder.Config)

local AerialHandler = {}

local Remotes = nil
local CharacterManager = nil
local PassiveHandler = nil
local BlockHandler = nil
local ActiveAerials = {}
local LastRequest = {}

function AerialHandler.Init(remotes, charManager)
	Remotes = remotes
	CharacterManager = charManager
	PassiveHandler = require(script.Parent.PassiveHandler)
	BlockHandler = require(script.Parent.BlockHandler)

	-- Create Aerial remote if it doesn't exist
	local aerialRemote = Remotes.Aerial
	if not aerialRemote then
		local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
		if remotesFolder then
			aerialRemote = remotesFolder:FindFirstChild("Aerial")
			if not aerialRemote then
				aerialRemote = Instance.new("RemoteEvent")
				aerialRemote.Name = "Aerial"
				aerialRemote.Parent = remotesFolder
			end
			Remotes.Aerial = aerialRemote
		end
	end

	if Remotes.Aerial then
		Remotes.Aerial.OnServerEvent:Connect(function(player)
			AerialHandler.OnAerial(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		ActiveAerials[player] = nil
		LastRequest[player] = nil
	end)

	print("[AerialHandler] Initialized")
	return AerialHandler
end

function AerialHandler.OnAerial(player)
	-- Server-side request throttling
	local now = tick()
	local lastReq = LastRequest[player] or 0
	if now - lastReq < 0.05 then return end
	LastRequest[player] = now

	local data = State.Get(player)
	if not data then return end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChild("Humanoid")
	if not hrp or not hum then return end

	local charName = State.GetCharacter(player)
	local charData = CharacterManager.Get(charName)
	if not charData or not charData.Aerial then return end

	local aerialData = charData.Aerial

	-- State checks
	if State.IsStunned(player) or State.IsBlocking(player) or State.IsDashing(player) or State.IsGuardBroken(player) then
		return
	end

	-- MUST be airborne to use aerial attack
	local isAirborne = hum.FloorMaterial == Enum.Material.Air or State.GetState(player) == State.States.AIRBORNE
	if not isAirborne then
		return
	end

	-- Cooldown check
	if not Cooldown.IsReady(player, "Aerial") then
		return
	end

	-- Check stamina if needed
	local staminaCost = aerialData.StaminaCost or 0
	if staminaCost > 0 and not State.HasStamina(player, staminaCost) then
		return
	end

	-- Use stamina
	if staminaCost > 0 then
		State.UseStamina(player, staminaCost)
	end

	-- Reset combo
	State.ResetCombo(player)

	-- Set state
	State.SetState(player, State.States.ATTACKING)

	-- Set cooldown
	Cooldown.Set(player, "Aerial", aerialData.Cooldown or 1.0)

	-- Fire to clients
	Remotes.State:FireAllClients(player, "Aerial", {
		character = charName,
	})

	local attackId = tick()
	ActiveAerials[player] = attackId

	-- Calculate damage with bonuses
	local damage = aerialData.Damage * (charData.Stats.Damage or 1)
	local slamForce = aerialData.SlamForce or 150
	local radius = aerialData.Radius or 8
	local postureDamage = aerialData.PostureDamage or (damage * 1.0)

	-- Apply passive damage bonus
	if PassiveHandler then
		local passiveBonus = PassiveHandler.GetDamageMultiplier(player)
		damage = damage * passiveBonus
	end

	if data.awakened and charData.Awakening then
		damage = damage * (charData.Awakening.DamageMultiplier or 1)
		radius = radius * 1.2
	end

	-- Apply downward force
	hrp.AssemblyLinearVelocity = Vector3.new(0, -slamForce, 0)

	-- Wait for ground impact
	local maxWaitTime = 2.0
	local startTime = tick()
	local hasLanded = false

	while not hasLanded and (tick() - startTime) < maxWaitTime do
		if ActiveAerials[player] ~= attackId then return end

		-- Check if grounded
		if hum.FloorMaterial ~= Enum.Material.Air then
			hasLanded = true
			break
		end

		task.wait()
	end

	if not hasLanded or ActiveAerials[player] ~= attackId then
		State.SetState(player, State.States.IDLE)
		ActiveAerials[player] = nil
		return
	end

	-- Impact!
	local impactPos = hrp.Position

	-- Create AOE hitbox
	local hasHit = {}

	-- Radial damage from impact point
	local hitboxOrigin = CFrame.new(impactPos)
	local hitboxSize = Vector3.new(radius * 2, 6, radius * 2)

	Hitbox.Box(hitboxOrigin, hitboxSize, {char}, function(victimPlayer, victimChar, victimHum, victimHrp)
		if hasHit[victimChar] then return end
		hasHit[victimChar] = true

		-- Calculate distance-based damage falloff
		local distance = (victimHrp.Position - impactPos).Magnitude
		local falloff = math.max(0.5, 1 - (distance / radius))
		local finalDamage = damage * falloff

		AerialHandler.ApplyHit(player, victimPlayer, victimChar, victimHum, victimHrp, {
			damage = finalDamage,
			knockback = aerialData.Knockback or 80,
			postureDamage = postureDamage * falloff,
			impactPos = impactPos,
			hitstun = aerialData.Hitstun or 0.4,
			charData = charData,
		})
	end)

	-- Recovery
	State.SetState(player, State.States.RECOVERY)
	task.wait(aerialData.Recovery or 0.3)

	if ActiveAerials[player] ~= attackId then return end

	if State.IsRecovery(player) then
		State.SetState(player, State.States.IDLE)
	end

	ActiveAerials[player] = nil
end

function AerialHandler.ApplyHit(attacker, victimPlayer, victimChar, victimHum, victimHrp, hitInfo)
	local attackerChar = attacker.Character
	local attackerHrp = attackerChar and attackerChar:FindFirstChild("HumanoidRootPart")
	if not attackerHrp then return end

	local damage = hitInfo.damage
	local knockback = hitInfo.knockback
	local postureDamage = hitInfo.postureDamage
	local impactPos = hitInfo.impactPos
	local hitstun = hitInfo.hitstun
	local charData = hitInfo.charData

	local blocked = nil
	local actualDamage = damage
	local actualKnockback = knockback

	-- Check for player vs player
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

	-- Apply radial knockback (away from impact)
	if actualKnockback > 0 and not (blocked == "Deflect") then
		local knockbackDir = (victimHrp.Position - impactPos).Unit
		local kbVelocity = Vector3.new(
			knockbackDir.X * actualKnockback,
			actualKnockback * 0.5,  -- Some upward force
			knockbackDir.Z * actualKnockback
		)
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

	-- Call PassiveHandler
	if PassiveHandler and not blocked then
		PassiveHandler.OnHit(attacker, victimPlayer, hitInfo)
	end

	-- Fire hit event to clients
	Remotes.Hit:FireAllClients({
		attacker = attacker,
		victim = victimPlayer,
		victimChar = victimChar,
		position = victimHrp.Position,
		damage = actualDamage,
		knockback = actualKnockback,
		hitType = "Aerial",
		blocked = blocked,
		impactPos = impactPos,
	})
end

function AerialHandler.CancelAerial(player)
	ActiveAerials[player] = nil
end

return AerialHandler
