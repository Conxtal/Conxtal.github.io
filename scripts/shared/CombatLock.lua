--[[
    CombatLockHandler.lua
    Server-authoritative combat lock state - SIFU FEEL
    Location: ServerScriptService/Combat/Handlers/AttackHandler/CombatLock
    
    WHAT THIS DOES:
    - Attacker stays CONSTANTLY at standoff distance from victim
    - BOTH attacker AND victim ALWAYS face each other
    - Works for Players AND NPCs
    - Server handles NPC orientation directly
    - Client handles player physics via remotes
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CombatLockHandler = {}

local CombatLockRemote = nil
local Config = nil

-- Active locks: [player] = { opponent, lockEnd, isNPC, connection }
local ActiveLocks = {}

-- Tuning
local STANDOFF_DISTANCE = 2.5  -- Studs between attacker and victim
local ORIENT_SPEED = 25        -- How fast entities rotate to face each other

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function CombatLockHandler.Init(remotes, config)
    Config = config

    -- Get standoff distance from config if available
    if Config and Config.CombatLock and Config.CombatLock.StandoffDistance then
        STANDOFF_DISTANCE = Config.CombatLock.StandoffDistance
    end

    -- Get/create the CombatLock remote from ReplicatedStorage
    local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
    CombatLockRemote = RemotesFolder:FindFirstChild("CombatLock")

    if not CombatLockRemote then
        CombatLockRemote = Instance.new("RemoteEvent")
        CombatLockRemote.Name = "CombatLock"
        CombatLockRemote.Parent = RemotesFolder
    end

    print("[CombatLockHandler] Initialized")
end

--------------------------------------------------------------------------------
-- LOCK PLAYERS (PvP) - Both face each other
--------------------------------------------------------------------------------

function CombatLockHandler.LockPlayers(attacker, victim, duration)
    if not CombatLockRemote then return end

    -- Validate
    if not attacker or not victim then return end
    if not attacker.Character or not victim.Character then return end
    if not attacker.Character:FindFirstChild("HumanoidRootPart") then return end
    if not victim.Character:FindFirstChild("HumanoidRootPart") then return end

    -- Get lock duration from config or use default
    duration = duration or (Config and Config.CombatLock and Config.CombatLock.DefaultLockDuration) or 0.5

    -- If already locked to same opponent, extend
    if ActiveLocks[attacker] and ActiveLocks[attacker].opponent == victim then
        CombatLockHandler.ExtendLock(attacker, duration)
        return
    end

    -- Clean up old locks
    CombatLockHandler.UnlockPlayer(attacker)
    CombatLockHandler.UnlockPlayer(victim)

    -- Store lock state
    local lockEnd = tick() + duration
    ActiveLocks[attacker] = { opponent = victim, lockEnd = lockEnd, isNPC = false }
    ActiveLocks[victim] = { opponent = attacker, lockEnd = lockEnd, isNPC = false }

    -- Tell BOTH clients to engage lock
    -- Attacker: follow victim + face them
    CombatLockRemote:FireClient(attacker, "LOCK", victim, duration, STANDOFF_DISTANCE)
    -- Victim: face attacker (no follow, just orientation)
    CombatLockRemote:FireClient(victim, "LOCK_FACE_ONLY", attacker, duration)

    -- Auto-unlock after duration
    task.delay(duration, function()
        if ActiveLocks[attacker] and ActiveLocks[attacker].lockEnd <= tick() then
            CombatLockHandler.UnlockPlayer(attacker)
        end
        if ActiveLocks[victim] and ActiveLocks[victim].lockEnd <= tick() then
            CombatLockHandler.UnlockPlayer(victim)
        end
    end)
end

--------------------------------------------------------------------------------
-- LOCK PLAYER TO NPC - Server handles NPC orientation directly
--------------------------------------------------------------------------------

function CombatLockHandler.LockPlayerToNPC(player, npcCharacter, duration)
    if not CombatLockRemote then return end

    -- Validate
    if not player or not npcCharacter then return end
    if not player.Character then return end
    if not player.Character:FindFirstChild("HumanoidRootPart") then return end
    if not npcCharacter:FindFirstChild("HumanoidRootPart") then return end

    duration = duration or (Config and Config.CombatLock and Config.CombatLock.DefaultLockDuration) or 0.5

    -- If already locked to same NPC, extend
    if ActiveLocks[player] and ActiveLocks[player].opponent == npcCharacter then
        CombatLockHandler.ExtendLock(player, duration)
        return
    end

    -- Clean up old lock
    CombatLockHandler.UnlockPlayer(player)

    -- Store lock state
    local lockEnd = tick() + duration

    -- Tell client to engage lock (attacker follows + faces NPC)
    CombatLockRemote:FireClient(player, "LOCK_NPC", npcCharacter, duration, STANDOFF_DISTANCE)

    -- SERVER-SIDE: Make NPC face player constantly
    local playerHrp = player.Character:FindFirstChild("HumanoidRootPart")
    local npcHrp = npcCharacter:FindFirstChild("HumanoidRootPart")

    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        -- Check if lock expired or characters gone
        if tick() > lockEnd then
            connection:Disconnect()
            return
        end

        if not playerHrp or not playerHrp.Parent then
            connection:Disconnect()
            return
        end

        if not npcHrp or not npcHrp.Parent then
            connection:Disconnect()
            return
        end

        -- Make NPC face player (server-side for NPCs)
        local npcPos = npcHrp.Position
        local playerPos = playerHrp.Position

        -- Only rotate on XZ plane
        local targetPos = Vector3.new(playerPos.X, npcPos.Y, playerPos.Z)
        local direction = (targetPos - npcPos)

        if direction.Magnitude > 0.1 then
            local targetCFrame = CFrame.lookAt(npcPos, targetPos)
            -- Smooth rotation
            npcHrp.CFrame = npcHrp.CFrame:Lerp(targetCFrame, math.min(1, ORIENT_SPEED * dt))
        end
    end)

    ActiveLocks[player] = { 
        opponent = npcCharacter, 
        lockEnd = lockEnd, 
        isNPC = true,
        connection = connection  -- Store connection for cleanup
    }

    -- Auto-unlock after duration
    task.delay(duration, function()
        if ActiveLocks[player] and ActiveLocks[player].lockEnd <= tick() then
            CombatLockHandler.UnlockPlayer(player)
        end
    end)
end

-- Alias for AttackHandler compatibility
function CombatLockHandler.LockToNPC(player, npcCharacter, duration)
    return CombatLockHandler.LockPlayerToNPC(player, npcCharacter, duration)
end

--------------------------------------------------------------------------------
-- UNLOCK
--------------------------------------------------------------------------------

function CombatLockHandler.UnlockPlayer(player)
    local lockData = ActiveLocks[player]
    if not lockData then return end

    -- Disconnect server-side NPC facing loop
    if lockData.connection then
        lockData.connection:Disconnect()
    end

    -- Tell client to release
    if CombatLockRemote and player:IsA("Player") and player.Parent then
        CombatLockRemote:FireClient(player, "UNLOCK")
    end

    -- If PvP, also unlock the opponent
    if not lockData.isNPC then
        local opponent = lockData.opponent
        if opponent and ActiveLocks[opponent] and ActiveLocks[opponent].opponent == player then
            if ActiveLocks[opponent].connection then
                ActiveLocks[opponent].connection:Disconnect()
            end
            ActiveLocks[opponent] = nil
            if CombatLockRemote and opponent:IsA("Player") and opponent.Parent then
                CombatLockRemote:FireClient(opponent, "UNLOCK")
            end
        end
    end

    ActiveLocks[player] = nil
end

--------------------------------------------------------------------------------
-- EXTEND LOCK
--------------------------------------------------------------------------------

function CombatLockHandler.ExtendLock(player, additionalDuration)
    local lockData = ActiveLocks[player]
    if not lockData then return end

    local extendAmount = additionalDuration or (Config and Config.CombatLock and Config.CombatLock.ExtendOnHit) or 0.3

    lockData.lockEnd = lockData.lockEnd + extendAmount

    -- Tell client to extend
    if CombatLockRemote and player:IsA("Player") and player.Parent then
        CombatLockRemote:FireClient(player, "EXTEND", extendAmount)
    end

    -- If PvP, extend opponent too
    if not lockData.isNPC then
        local opponent = lockData.opponent
        if opponent and ActiveLocks[opponent] then
            ActiveLocks[opponent].lockEnd = ActiveLocks[opponent].lockEnd + extendAmount
            if CombatLockRemote and opponent:IsA("Player") and opponent.Parent then
                CombatLockRemote:FireClient(opponent, "EXTEND", extendAmount)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- FORCE UNLOCK
--------------------------------------------------------------------------------

function CombatLockHandler.ForceUnlock(player)
    CombatLockHandler.UnlockPlayer(player)
end

--------------------------------------------------------------------------------
-- QUERIES
--------------------------------------------------------------------------------

function CombatLockHandler.IsLocked(player)
    return ActiveLocks[player] ~= nil
end

function CombatLockHandler.GetLockedOpponent(player)
    local lockData = ActiveLocks[player]
    return lockData and lockData.opponent or nil
end

function CombatLockHandler.GetLockTimeRemaining(player)
    local lockData = ActiveLocks[player]
    if not lockData then return 0 end
    return math.max(0, lockData.lockEnd - tick())
end

return CombatLockHandler