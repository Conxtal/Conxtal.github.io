--[[
	AttackHandler.lua
	Handles M1 combo attacks with posture system + combat lock
	Location: ServerScriptService/Combat/Handlers/AttackHandler
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
local Hitbox = require(CombatFolder.Modules.HitboxHandler)
local State = require(CombatFolder.Modules.StateManager)
local Cooldown = require(CombatFolder.Modules.CooldownManager)
local Config = require(CombatFolder.Config)

local AttackModule = {}

local Remotes = nil
local CharacterManager = nil
local PassiveHandler = nil
local BlockHandler = nil
local CombatLockHandler = nil
local ActiveAttacks = {}
local LastRequest = {}

function AttackModule.Init(remotes, charManager)
    Remotes = remotes
    CharacterManager = charManager
    PassiveHandler = require(script.Parent.PassiveHandler)
    BlockHandler = require(script.Parent.BlockHandler)
    CombatLockHandler = require(script.CombatLock)

    Remotes.Attack.OnServerEvent:Connect(function(player)
        AttackModule.OnAttack(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        ActiveAttacks[player] = nil
        LastRequest[player] = nil
        CombatLockHandler.ForceUnlock(player)
    end)

    print("[AttackHandler] Initialized")
    return AttackModule
end

function AttackModule.OnAttack(player)
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
    if not charData or not charData.M1 then return end

    local m1Data = charData.M1

    -- State checks
    if State.IsStunned(player) or State.IsBlocking(player) or State.IsDashing(player) or State.IsGuardBroken(player) then
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

    -- Set cooldown for this attack
    local totalAttackTime = hitData.startup + hitData.active + hitData.recovery
    Cooldown.Set(player, Cooldown.Actions.M1, totalAttackTime)

    State.SetState(player, State.States.ATTACKING)

    -- Fire to clients
    Remotes.State:FireAllClients(player, "M1", combo, {
        character = charName,
        isFinal = combo >= m1Data.MaxCombo,
    })

    local attackId = tick()
    ActiveAttacks[player] = attackId

    -- Calculate damage with passive bonus
    local damage = hitData.damage * (charData.Stats.Damage or 1)
    local knockback = hitData.knockback * (charData.Stats.Knockback or 1)
    local postureDamage = hitData.postureDamage or (damage * 0.5)

    -- Apply passive damage bonus
    if PassiveHandler then
        local passiveBonus = PassiveHandler.GetDamageMultiplier(player)
        damage = damage * passiveBonus
    end

    if data.awakened and charData.Awakening then
        damage = damage * (charData.Awakening.DamageMultiplier or 1)
    end

    -- Startup
    task.wait(hitData.startup)
    if ActiveAttacks[player] ~= attackId then return end

    -- Hitbox
    local hitboxSize = m1Data.HitboxSize or Vector3.new(4, 4, 5)
    local hitboxOffset = m1Data.HitboxOffset or Vector3.new(0, 0, -3)

    if data.awakened and charData.Awakening and charData.Awakening.M1RangeMultiplier then
        hitboxSize = hitboxSize * charData.Awakening.M1RangeMultiplier
    end

    local hasHit = {}
    local activeStart = tick()

    while tick() - activeStart < hitData.active do
        if ActiveAttacks[player] ~= attackId then return end

        local origin = hrp.CFrame * CFrame.new(hitboxOffset)

        Hitbox.Box(origin, hitboxSize, {char}, function(victimPlayer, victimChar, victimHum, victimHrp)
            if hasHit[victimChar] then return end
            hasHit[victimChar] = true

            AttackModule.ApplyHit(player, victimPlayer, victimChar, victimHum, victimHrp, {
                damage = damage,
                knockback = knockback,
                postureDamage = postureDamage,
                lift = hitData.lift,
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
        State.ResetCombo(player)
        Cooldown.Set(player, Cooldown.Actions.M1, Config.Combat.ComboResetCooldown or 1.5)

        -- Unlock combat after final hit
        task.delay(0.5, function()
            CombatLockHandler.ForceUnlock(player)
        end)
    else
        task.delay(m1Data.ComboWindow, function()
            if State.GetCombo(player) == combo then
                State.ResetCombo(player)
                Cooldown.Set(player, Cooldown.Actions.M1, Config.Combat.ComboResetCooldown or 1.5)
            end
        end)
    end
end

function AttackModule.ApplyHit(attacker, victimPlayer, victimChar, victimHum, victimHrp, hitInfo)
    local attackerChar = attacker.Character
    local attackerHrp = attackerChar and attackerChar:FindFirstChild("HumanoidRootPart")
    if not attackerHrp then return end

    local damage = hitInfo.damage
    local knockback = hitInfo.knockback
    local postureDamage = hitInfo.postureDamage
    local lift = hitInfo.lift or 0
    local combo = hitInfo.combo
    local isFinal = hitInfo.isFinal
    local hitstun = hitInfo.hitstun
    local charData = hitInfo.charData

    local hitType = isFinal and "Final" or "Light"
    local blocked = nil
    local actualDamage = damage
    local actualKnockback = knockback

    -- COMBAT LOCK: Only on non-final hits
    -- Final hit = no follow, let them fly!
    if not isFinal then
        local lockDuration = hitstun + 0.2

        if victimPlayer then
            -- Player vs Player
            local vd = State.Get(victimPlayer)

            if vd and State.HasIFrames(victimPlayer) then
                return
            end

            State.UpdatePressure(victimPlayer)
            CombatLockHandler.LockPlayers(attacker, victimPlayer, lockDuration)

            if vd and State.IsBlockingActive(victimPlayer) then
                blocked, actualDamage, actualKnockback = BlockHandler.ProcessBlockedHit(attacker, victimPlayer, hitInfo)
            else
                State.DamagePosture(victimPlayer, postureDamage)
            end
        else
            -- Player vs NPC
            CombatLockHandler.LockToNPC(attacker, victimChar, lockDuration)
        end
    else
        -- FINAL HIT: No lock, but still do state checks
        CombatLockHandler.ForceUnlock(attacker)

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

    -- Apply hitstun (player only)
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
        combo = combo,
        hitType = hitType,
        blocked = blocked,
        attackDir = attackerHrp.CFrame.LookVector,
    })
end

function AttackModule.CancelAttack(player)
    ActiveAttacks[player] = nil
    CombatLockHandler.ForceUnlock(player)
end

return AttackModule