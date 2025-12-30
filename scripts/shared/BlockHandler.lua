--[[
	BlockHandler.lua
	Handles blocking, deflects, and guard breaks
	Location: ServerScriptService/Combat/Handlers/BlockHandler
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
local State = require(CombatFolder.Modules.StateManager)
local Config = require(CombatFolder.Config)

local BlockHandler = {}

local Remotes = nil
local CharacterManager = nil

function BlockHandler.Init(remotes, charManager)
    Remotes = remotes
    CharacterManager = charManager

    Remotes.Block.OnServerEvent:Connect(function(player, isBlocking)
        if isBlocking then
            BlockHandler.StartBlock(player)
        else
            BlockHandler.EndBlock(player)
        end
    end)

    print("[BlockHandler] Initialized")
    return BlockHandler
end

-- ========================================
-- BLOCK START/END
-- ========================================

function BlockHandler.StartBlock(player)
    local data = State.Get(player)
    if not data then return end

    -- Can't block while stunned or guard broken
    if State.IsStunned(player) or State.IsGuardBroken(player) then return end

    State.SetBlocking(player, true)
    State.SetState(player, State.States.BLOCKING)
    Remotes.State:FireAllClients(player, "BlockStart", {})
end

function BlockHandler.EndBlock(player)
    if State.IsBlockingActive(player) then
        State.SetBlocking(player, false)

        if State.GetState(player) == State.States.BLOCKING then
            State.SetState(player, State.States.IDLE)
        end

        Remotes.State:FireAllClients(player, "BlockEnd", {})
    end
end

-- ========================================
-- DEFLECT/BLOCK PROCESSING
-- ========================================

-- Returns: blockType, finalDamage, finalKnockback
function BlockHandler.ProcessBlockedHit(attacker, victim, hitInfo)
    local blockTime = State.GetBlockTime(victim)
    local deflectWindow = Config.Combat.Deflect.Window

    local charName = State.GetCharacter(attacker)
    local charData = CharacterManager.Get(charName)
    if not charData or not charData.Block then 
        return "Normal", hitInfo.damage, hitInfo.knockback 
    end

    local blockData = charData.Block

    -- ========================================
    -- PERFECT DEFLECT
    -- ========================================
    if blockTime <= deflectWindow then
        -- Massive posture damage to ATTACKER
        local guardBroken = State.DamagePosture(attacker, Config.Combat.Deflect.PostureDamage)

        -- Deflect pushback on attacker
        local attackerChar = attacker.Character
        local attackerHrp = attackerChar and attackerChar:FindFirstChild("HumanoidRootPart")
        local victimChar = victim.Character
        local victimHrp = victimChar and victimChar:FindFirstChild("HumanoidRootPart")

        if attackerHrp and victimHrp then
            local pushDir = (attackerHrp.Position - victimHrp.Position).Unit
            local pushback = pushDir * Config.Combat.Deflect.PushbackDistance
            attackerHrp.CFrame = attackerHrp.CFrame + pushback
        end

        -- Fire deflect VFX
        Remotes.State:FireAllClients(victim, "Deflect", {
            attacker = attacker,
            postureDamage = Config.Combat.Deflect.PostureDamage,
        })

        -- Hitstop freeze
        task.wait(Config.Combat.Deflect.HitstopDuration)

        if guardBroken then
            BlockHandler.TriggerGuardBreak(attacker)
        end

        return "Deflect", 0, 0 -- no damage to victim

        -- ========================================
        -- NORMAL BLOCK
        -- ========================================
    else
        -- Victim takes posture damage
        local postureDamage = (hitInfo.postureDamage or hitInfo.damage * 0.5) * blockData.PostureDamageMultiplier
        local guardBroken = State.DamagePosture(victim, postureDamage)

        if guardBroken then
            BlockHandler.TriggerGuardBreak(victim)
            return "Break", hitInfo.damage, hitInfo.knockback -- full damage on break
        end

        -- Reduced damage on normal block
        local reducedDamage = hitInfo.damage * (1 - (blockData.DamageReduction or 0.75))
        local reducedKnockback = hitInfo.knockback * (blockData.KnockbackReduction or 0.3)

        return "Normal", reducedDamage, reducedKnockback
    end
end

-- ========================================
-- GUARD BREAK
-- ========================================

function BlockHandler.TriggerGuardBreak(player)
    State.SetBlocking(player, false)
    State.SetState(player, State.States.GUARD_BROKEN)

    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum then
        hum.WalkSpeed = 0
        hum.JumpPower = 0
    end

    -- Fire guard break VFX
    Remotes.State:FireAllClients(player, "GuardBreak", {})

    -- Recover after stun duration
    task.delay(Config.Combat.GuardBreak.StunDuration, function()
        if State.IsGuardBrokenState(player) then
            State.ClearGuardBreak(player)
            State.SetState(player, State.States.IDLE)

            if hum and hum.Parent then
                hum.WalkSpeed = 16
                hum.JumpPower = 50
            end
        end
    end)
end

return BlockHandler