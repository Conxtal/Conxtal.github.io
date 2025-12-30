-- DashHandler.lua (SERVER) — HARD LOCKED, BUFFERED, AUTHORITATIVE

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DashHandler = {}

local Config, State, Cooldown
local Remotes, CharacterManager, AttackHandler

local Initialized = false
local CanDash = {} -- [player] = boolean

--------------------------------------------------
-- INIT
--------------------------------------------------

function DashHandler.Init(remotes, charManager)
    if Initialized then return end
    Initialized = true

    Remotes = remotes
    CharacterManager = charManager

    local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
    Config = require(CombatFolder.Config)
    State = require(CombatFolder.Modules.StateManager)
    Cooldown = require(CombatFolder.Modules.CooldownManager)

    AttackHandler = require(script.Parent.AttackHandler)

    Remotes.Dash.OnServerEvent:Connect(function(player, direction)
        if typeof(direction) == "Vector3" and direction.Magnitude > 0 then
            direction = direction.Unit
        else
            direction = nil
        end

        DashHandler.OnDash(player, direction)
    end)

    game.Players.PlayerRemoving:Connect(function(player)
        CanDash[player] = nil
    end)

    print("[DashHandler] Initialized (LOCKED)")
    return DashHandler
end

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function SetCharacterVisible(char, visible)
    if not char then return end
    local t = visible and 0 or 1

    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
            obj.Transparency = t
        elseif obj:IsA("Decal") then
            obj.Transparency = t
        end
    end
end

local function ResolveDashIntent(dashDir, hrp)
    local forward = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
    local right = Vector3.new(hrp.CFrame.RightVector.X, 0, hrp.CFrame.RightVector.Z).Unit

    local f = dashDir:Dot(forward)
    local r = dashDir:Dot(right)

    if math.abs(f) > math.abs(r) then
        return f >= 0 and "Forward" or "Back"
    else
        return r >= 0 and "Right" or "Left"
    end
end

local function ApplyDashVelocity(hrp, dir, speed)
    local att = hrp:FindFirstChild("DashAttachment") or Instance.new("Attachment", hrp)
    att.Name = "DashAttachment"

    local lv = hrp:FindFirstChild("DashVelocity")
    if lv then lv:Destroy() end

    lv = Instance.new("LinearVelocity")
    lv.Name = "DashVelocity"
    lv.Attachment0 = att
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.MaxForce = math.huge
    lv.VectorVelocity = dir * speed
    lv.Parent = hrp

    return lv
end

--------------------------------------------------
-- DASH
--------------------------------------------------

function DashHandler.OnDash(player, inputDir)
    -- HARD LOCK
    if CanDash[player] == false then return end
    CanDash[player] = false

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        CanDash[player] = true
        return
    end

    local charName = State.GetCharacter(player)
    local charData = CharacterManager.Get(charName)
    if not charData or not charData.Dash then
        CanDash[player] = true
        return
    end

    local dash = charData.Dash

    if State.IsStunned(player) or State.IsGuardBroken(player) then
        CanDash[player] = true
        return
    end

    if not State.HasStamina(player, dash.StaminaCost) then
        CanDash[player] = true
        return
    end

    -- CONSUME
    State.UseStamina(player, dash.StaminaCost)
    State.SetState(player, State.States.DASHING)
    State.SetIFrames(player, dash.IFrames or dash.Duration)

    if Config.Combat.DashCancelsAttack and AttackHandler then
        AttackHandler.CancelAttack(player)
    end

    -- DIRECTION
    local dir = inputDir and inputDir.Magnitude > 0 and inputDir or hrp.CFrame.LookVector
    dir = Vector3.new(dir.X, 0, dir.Z).Unit

    local intent = ResolveDashIntent(dir, hrp)

    Remotes.State:FireAllClients(player, "Dash", {
        intent = intent,
        invisible = true,
    })

    -- MOVE
    local speed = dash.Distance / dash.Duration
    local vel = ApplyDashVelocity(hrp, dir, speed)

    -- END DASH
    task.delay(dash.Duration, function()
        if vel and vel.Parent then vel:Destroy() end
        hrp.AssemblyLinearVelocity = Vector3.zero
        State.SetState(player, State.States.IDLE)
        SetCharacterVisible(char, true)
    end)

    -- COOLDOWN UNLOCK
    task.delay(dash.Cooldown, function()
        CanDash[player] = true
    end)
end

return DashHandler
