--[[
	Lockon.lua
]]

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local LockOnModule = {}

local isLocked = false
local currentTarget = nil
local lockConnection = nil

local MAX_LOCK_DISTANCE = 50
local SWITCH_DISTANCE = 60
local CAMERA_OFFSET = Vector3.new(0, 2, 0) -- Height offset for camera focus

-- Visual indicator
local lockIndicator = nil

local function CreateLockIndicator()
    if lockIndicator then
        lockIndicator:Destroy()
    end

    local indicator = Instance.new("BillboardGui")
    indicator.Name = "LockOnIndicator"
    indicator.AlwaysOnTop = true
    indicator.Size = UDim2.new(3, 0, 3, 0)
    indicator.StudsOffset = Vector3.new(0, 2, 0)

    local frame = Instance.new("Frame", indicator)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1

    -- Create corner brackets
    local function createBracket(name, position, rotation)
        local bracket = Instance.new("Frame", frame)
        bracket.Name = name
        bracket.Size = UDim2.new(0.3, 0, 0.3, 0)
        bracket.Position = position
        bracket.AnchorPoint = Vector2.new(0.5, 0.5)
        bracket.BackgroundTransparency = 1
        bracket.Rotation = rotation

        local line1 = Instance.new("Frame", bracket)
        line1.Size = UDim2.new(1, 0, 0.1, 0)
        line1.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        line1.BorderSizePixel = 0

        local line2 = Instance.new("Frame", bracket)
        line2.Size = UDim2.new(0.1, 0, 1, 0)
        line2.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        line2.BorderSizePixel = 0
    end

    createBracket("TopLeft", UDim2.new(0, 0, 0, 0), 0)
    createBracket("TopRight", UDim2.new(1, 0, 0, 0), 90)
    createBracket("BottomLeft", UDim2.new(0, 0, 1, 0), 270)
    createBracket("BottomRight", UDim2.new(1, 0, 1, 0), 180)

    lockIndicator = indicator
    return indicator
end

local function IsValidTarget(character)
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    -- Don't lock onto yourself
    if character == Player.Character then
        return false
    end

    return true
end

local function GetNearestTarget()
    local playerChar = Player.Character
    if not playerChar then return nil end

    local playerHRP = playerChar:FindFirstChild("HumanoidRootPart")
    if not playerHRP then return nil end

    local nearestTarget = nil
    local nearestDistance = MAX_LOCK_DISTANCE

    -- Check all players
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= Player and otherPlayer.Character then
            local char = otherPlayer.Character
            if IsValidTarget(char) then
                local hrp = char.HumanoidRootPart
                local distance = (playerHRP.Position - hrp.Position).Magnitude

                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestTarget = char
                end
            end
        end
    end

    -- Check all NPCs
    for _, descendant in pairs(workspace:GetDescendants()) do
        if descendant:IsA("Model") and descendant:FindFirstChild("Humanoid") then
            local isPlayerChar = false
            for _, plr in pairs(Players:GetPlayers()) do
                if plr.Character == descendant then
                    isPlayerChar = true
                    break
                end
            end

            if not isPlayerChar and IsValidTarget(descendant) then
                local hrp = descendant.HumanoidRootPart
                local distance = (playerHRP.Position - hrp.Position).Magnitude

                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestTarget = descendant
                end
            end
        end
    end

    return nearestTarget
end

local function UpdateLockOn()
    if not isLocked or not currentTarget then
        return
    end

    local playerChar = Player.Character
    if not playerChar then
        LockOnModule.Unlock()
        return
    end

    local playerHRP = playerChar:FindFirstChild("HumanoidRootPart")
    local playerHum = playerChar:FindFirstChild("Humanoid")
    if not playerHRP or not playerHum then
        LockOnModule.Unlock()
        return
    end

    -- Check if target is still valid
    if not IsValidTarget(currentTarget) then
        LockOnModule.Unlock()
        return
    end

    local targetHRP = currentTarget:FindFirstChild("HumanoidRootPart")
    if not targetHRP then
        LockOnModule.Unlock()
        return
    end

    -- Check distance
    local distance = (playerHRP.Position - targetHRP.Position).Magnitude
    if distance > SWITCH_DISTANCE then
        LockOnModule.Unlock()
        return
    end

    -- ELDEN RING STYLE: Rotate character to face target
    local targetPos = targetHRP.Position
    local playerPos = playerHRP.Position

    -- Direction to target (only XZ plane)
    local directionToTarget = Vector3.new(
        targetPos.X - playerPos.X,
        0,
        targetPos.Z - playerPos.Z
    )

    if directionToTarget.Magnitude > 0.1 then
        directionToTarget = directionToTarget.Unit

        -- Smoothly rotate player to face target
        local targetCFrame = CFrame.new(playerPos, playerPos + directionToTarget)
        playerHRP.CFrame = CFrame.new(
            playerHRP.Position,
            playerHRP.Position + directionToTarget
        )
    end

    -- ELDEN RING CAMERA: Keep camera behind player while looking at target
    local humanoidRootPart = playerHRP
    local targetFocusPoint = targetHRP.Position + Vector3.new(0, 2, 0) -- Focus slightly above target

    -- Get camera's current offset from the player (based on mouse/camera controls)
    local cameraSubject = Camera.CameraSubject
    if cameraSubject ~= playerHum then
        Camera.CameraSubject = playerHum
    end

    -- Calculate camera position: behind player, looking toward target
    local cameraDistance = (Camera.CFrame.Position - playerPos).Magnitude
    cameraDistance = math.clamp(cameraDistance, 8, 20) -- Clamp camera distance

    -- Get the direction from target to player (camera should be behind player)
    local playerToTarget = (targetPos - playerPos).Unit
    local cameraOffset = -playerToTarget * cameraDistance + Vector3.new(0, 7, 0) -- Behind player + height

    -- Calculate final camera position
    local desiredCameraPos = playerPos + cameraOffset

    -- Make camera look at a point between player and target
    local lookAtPoint = playerPos:Lerp(targetFocusPoint, 0.6) -- 60% toward target

    -- Smooth camera movement
    local currentCamPos = Camera.CFrame.Position
    local smoothCameraPos = currentCamPos:Lerp(desiredCameraPos, 0.2)

    Camera.CFrame = CFrame.new(smoothCameraPos, lookAtPoint)
end

function LockOnModule.Init()
    print("[LockOnModule] Initialized")

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.UserInputType == Enum.UserInputType.MouseButton3 then
            LockOnModule.Toggle()
        end
    end)

    return LockOnModule
end

function LockOnModule.Toggle()
    if isLocked then
        LockOnModule.Unlock()
    else
        LockOnModule.Lock()
    end
end

function LockOnModule.Lock()
    local target = GetNearestTarget()
    if not target then
        print("[LockOn] No valid target found")
        return
    end

    isLocked = true
    currentTarget = target

    -- Set camera to follow player
    local playerHum = Player.Character and Player.Character:FindFirstChild("Humanoid")
    if playerHum then
        Camera.CameraSubject = playerHum
    end

    -- Create visual indicator
    local indicator = CreateLockIndicator()
    indicator.Adornee = currentTarget:FindFirstChild("HumanoidRootPart")
    indicator.Parent = Player.PlayerGui

    -- Start lock-on update loop
    if lockConnection then
        lockConnection:Disconnect()
    end
    lockConnection = RunService.RenderStepped:Connect(UpdateLockOn)

    print("[LockOn] Locked onto:", currentTarget.Name)
end

function LockOnModule.Unlock()
    isLocked = false
    currentTarget = nil

    -- Reset camera subject to player
    local playerHum = Player.Character and Player.Character:FindFirstChild("Humanoid")
    if playerHum then
        Camera.CameraSubject = playerHum
    end

    -- Remove visual indicator
    if lockIndicator then
        lockIndicator:Destroy()
        lockIndicator = nil
    end

    -- Stop lock-on update
    if lockConnection then
        lockConnection:Disconnect()
        lockConnection = nil
    end

    print("[LockOn] Unlocked")
end

function LockOnModule.GetCurrentTarget()
    return currentTarget
end

function LockOnModule.IsLocked()
    return isLocked
end

return LockOnModule