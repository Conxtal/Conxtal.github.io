--[[
    CombatLockClient.lua
    Client-side combat lock - SIFU FEEL TUNING
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

local CombatLockClient = {}

-- Lock state
local IsLocked = false
local LockedOpponent = nil      -- Player or Character model (for NPCs)
local LockConnection = nil
local LockEndTime = 0
local IsNPCLock = false
local IsFaceOnly = false        -- If true, only rotate to face, don't follow

-- Constraints
local Constraints = {}

--------------------------------------------------------------------------------
-- TUNABLES (can be overridden by server)
--------------------------------------------------------------------------------
local STANDOFF_DISTANCE = 5       -- Default, server can override
local FOLLOW_RESPONSIVENESS = 80    -- How fast you follow (HIGHER = tighter, more glued)
local ORIENT_RESPONSIVENESS = 70    -- How fast you face opponent
local MAX_FORCE = 300000            -- Very strong lock force for tight follow

--------------------------------------------------------------------------------
-- CONSTRAINT SETUP
--------------------------------------------------------------------------------

local function createAttachment(hrp, name)
    local att = hrp:FindFirstChild(name)
    if att and att:IsA("Attachment") then
        return att
    end
    att = Instance.new("Attachment")
    att.Name = name
    att.Parent = hrp
    return att
end

local function setupLockConstraints(myHrp, opponentHrp, faceOnly)
    -- Clean up old constraints
    CombatLockClient.CleanupConstraints()

    local myAttachment = createAttachment(myHrp, "CombatLockAtt")

    -- AlignOrientation - ALWAYS face opponent
    local orient = Instance.new("AlignOrientation")
    orient.Name = "CombatLockOrient"
    orient.Attachment0 = myAttachment
    orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
    orient.MaxTorque = MAX_FORCE
    orient.Responsiveness = ORIENT_RESPONSIVENESS
    orient.RigidityEnabled = true
    orient.Parent = myHrp

    table.insert(Constraints, orient)

    -- AlignPosition - follow opponent at standoff distance (only if not face-only)
    if not faceOnly then
        local alignPos = Instance.new("AlignPosition")
        alignPos.Name = "CombatLockPos"
        alignPos.Attachment0 = myAttachment
        alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
        alignPos.MaxForce = MAX_FORCE
        alignPos.Responsiveness = FOLLOW_RESPONSIVENESS
        alignPos.RigidityEnabled = false
        alignPos.Parent = myHrp

        table.insert(Constraints, alignPos)
    end

    return orient, Constraints[2]
end

--------------------------------------------------------------------------------
-- LOCK LOOP (RUNS ON RENDERSTEP - SMOOTH)
-- Attacker FOLLOWS victim as they get knocked back, staying at constant distance
--------------------------------------------------------------------------------

local function updateLock()
    if not IsLocked or not LockedOpponent then
        CombatLockClient.ReleaseLock()
        return
    end

    -- Get characters
    local myChar = Player.Character
    local opponentChar

    if IsNPCLock then
        opponentChar = LockedOpponent  -- NPC: LockedOpponent IS the character
    else
        opponentChar = LockedOpponent.Character  -- Player: get their character
    end

    if not myChar or not opponentChar or not opponentChar.Parent then
        CombatLockClient.ReleaseLock()
        return
    end

    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    local opponentHrp = opponentChar:FindFirstChild("HumanoidRootPart")
    if not myHrp or not opponentHrp then
        CombatLockClient.ReleaseLock()
        return
    end

    -- Get positions (flatten to XZ plane)
    local myPos = Vector3.new(myHrp.Position.X, opponentHrp.Position.Y, myHrp.Position.Z)
    local opponentPos = Vector3.new(opponentHrp.Position.X, opponentHrp.Position.Y, opponentHrp.Position.Z)

    -- Calculate direction to opponent
    local direction = (opponentPos - myPos)
    local distance = direction.Magnitude

    -- Guard against zero distance
    if distance < 0.01 then
        direction = Vector3.new(0, 0, 1)
    else
        direction = direction.Unit
    end

    -- Update AlignOrientation to face opponent (always do this)
    if Constraints[1] then
        local lookCFrame = CFrame.lookAt(myPos, opponentPos)
        Constraints[1].CFrame = lookCFrame
    end

    -- Update AlignPosition - FOLLOW victim, stay at constant distance
    -- This makes you follow them as they get knocked back
    if not IsFaceOnly and Constraints[2] then
        -- Target position is STANDOFF_DISTANCE studs away from opponent, facing them
        local targetPos = opponentPos - (direction * STANDOFF_DISTANCE)
        Constraints[2].Position = targetPos
    end

    -- Auto-release if time expired
    if tick() >= LockEndTime then
        CombatLockClient.ReleaseLock()
    end
end

--------------------------------------------------------------------------------
-- LOCK ENGAGEMENT (PLAYER - Full lock with follow)
--------------------------------------------------------------------------------

function CombatLockClient.EngageLock(opponent, duration, standoffDistance)
    -- Update standoff distance if provided
    if standoffDistance then
        STANDOFF_DISTANCE = standoffDistance
    end

    -- Already locked to this opponent - just extend
    if IsLocked and LockedOpponent == opponent and not IsFaceOnly then
        CombatLockClient.ExtendLock(duration)
        return
    end

    -- Release old lock
    CombatLockClient.ReleaseLock()

    IsLocked = true
    LockedOpponent = opponent
    IsNPCLock = false
    IsFaceOnly = false
    LockEndTime = tick() + duration

    -- Setup constraints
    local myChar = Player.Character
    if not myChar then return end
    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end

    local opponentChar = opponent.Character
    if not opponentChar then return end
    local opponentHrp = opponentChar:FindFirstChild("HumanoidRootPart")
    if not opponentHrp then return end

    setupLockConstraints(myHrp, opponentHrp, false)

    -- Start update loop
    if LockConnection then
        LockConnection:Disconnect()
    end
    LockConnection = RunService.RenderStepped:Connect(updateLock)
end

--------------------------------------------------------------------------------
-- LOCK ENGAGEMENT (PLAYER - Face only, no follow)
--------------------------------------------------------------------------------

function CombatLockClient.EngageLockFaceOnly(opponent, duration)
    -- Release old lock
    CombatLockClient.ReleaseLock()

    IsLocked = true
    LockedOpponent = opponent
    IsNPCLock = false
    IsFaceOnly = true
    LockEndTime = tick() + duration

    -- Setup constraints (face only)
    local myChar = Player.Character
    if not myChar then return end
    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end

    local opponentChar = opponent.Character
    if not opponentChar then return end
    local opponentHrp = opponentChar:FindFirstChild("HumanoidRootPart")
    if not opponentHrp then return end

    setupLockConstraints(myHrp, opponentHrp, true)

    -- Start update loop
    if LockConnection then
        LockConnection:Disconnect()
    end
    LockConnection = RunService.RenderStepped:Connect(updateLock)
end

--------------------------------------------------------------------------------
-- LOCK ENGAGEMENT (NPC)
--------------------------------------------------------------------------------

function CombatLockClient.EngageLockToNPC(npcCharacter, duration, standoffDistance)
    -- Update standoff distance if provided
    if standoffDistance then
        STANDOFF_DISTANCE = standoffDistance
    end

    -- Release old lock
    CombatLockClient.ReleaseLock()

    IsLocked = true
    LockedOpponent = npcCharacter  -- Store character model directly
    IsNPCLock = true
    IsFaceOnly = false
    LockEndTime = tick() + duration

    -- Setup constraints
    local myChar = Player.Character
    if not myChar then return end
    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end

    local npcHrp = npcCharacter:FindFirstChild("HumanoidRootPart")
    if not npcHrp then return end

    setupLockConstraints(myHrp, npcHrp, false)

    -- Start update loop
    if LockConnection then
        LockConnection:Disconnect()
    end
    LockConnection = RunService.RenderStepped:Connect(updateLock)
end

--------------------------------------------------------------------------------
-- LOCK RELEASE
--------------------------------------------------------------------------------

function CombatLockClient.ReleaseLock()
    if not IsLocked then return end

    IsLocked = false
    LockedOpponent = nil
    IsNPCLock = false
    IsFaceOnly = false
    LockEndTime = 0

    -- Disconnect update loop
    if LockConnection then
        LockConnection:Disconnect()
        LockConnection = nil
    end

    -- Clean up constraints
    CombatLockClient.CleanupConstraints()
end

--------------------------------------------------------------------------------
-- LOCK EXTENSION
--------------------------------------------------------------------------------

function CombatLockClient.ExtendLock(additionalDuration)
    if not IsLocked then return end
    LockEndTime = LockEndTime + additionalDuration
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

function CombatLockClient.CleanupConstraints()
    for _, constraint in ipairs(Constraints) do
        if constraint and constraint.Parent then
            constraint:Destroy()
        end
    end
    Constraints = {}
end

--------------------------------------------------------------------------------
-- REMOTE LISTENER
--------------------------------------------------------------------------------

function CombatLockClient.Init()
    local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
    local CombatLockRemote = RemotesFolder:WaitForChild("CombatLock")

    CombatLockRemote.OnClientEvent:Connect(function(action, target, duration, standoffDistance)
        if action == "LOCK" then
            -- Full lock: follow + face
            CombatLockClient.EngageLock(target, duration, standoffDistance)

        elseif action == "LOCK_FACE_ONLY" then
            -- Face only: just rotate to face opponent
            CombatLockClient.EngageLockFaceOnly(target, duration)

        elseif action == "LOCK_NPC" then
            -- NPC lock: follow + face
            CombatLockClient.EngageLockToNPC(target, duration, standoffDistance)

        elseif action == "UNLOCK" then
            CombatLockClient.ReleaseLock()

        elseif action == "EXTEND" then
            CombatLockClient.ExtendLock(target)  -- target is duration here
        end
    end)

    -- Cleanup on character death/respawn
    Player.CharacterRemoving:Connect(function()
        CombatLockClient.ReleaseLock()
    end)

    print("[CombatLockClient] Initialized")
end

--------------------------------------------------------------------------------
-- QUERIES
--------------------------------------------------------------------------------

function CombatLockClient.IsLocked()
    return IsLocked
end

function CombatLockClient.GetLockedOpponent()
    return LockedOpponent
end

return CombatLockClient