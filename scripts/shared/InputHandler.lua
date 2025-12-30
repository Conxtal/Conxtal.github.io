--[[
    InputHandler.lua
    Handles player input
]]

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

local CombatFolder = ReplicatedStorage:WaitForChild("Combat")

local AnimationHandler = require(script.Parent.AnimationHandler)

local InputHandler = {}

local Remotes = nil
local LockOnModule = nil

local Keybinds = {
    Attack = Enum.UserInputType.MouseButton1,
    Block = Enum.KeyCode.F,
    Dash = Enum.KeyCode.Q,
    Uptilt = Enum.KeyCode.Space,
    Aerial = Enum.KeyCode.C,  -- Down slam / plunge attack
    Ability1 = Enum.KeyCode.One,
    Ability2 = Enum.KeyCode.Two,
    Ability3 = Enum.KeyCode.Three,
    Ability4 = Enum.KeyCode.Four,
}

function InputHandler.Init(remotes)
    Remotes = remotes

    -- RESTORE LOCK-ON INIT (you lost this)
    LockOnModule = require(script.Parent.Parent.Modules.LockOn)
    LockOnModule.Init()

    -- Keep anim handler init (used by other inputs like block)
    AnimationHandler.Init()

    UserInputService.InputBegan:Connect(InputHandler.OnInputBegan)
    UserInputService.InputEnded:Connect(InputHandler.OnInputEnded)

    print("[InputHandler] Initialized")
    return InputHandler
end

function InputHandler.OnInputBegan(input, gameProcessed)
    if gameProcessed then return end

    if input.UserInputType == Keybinds.Attack then
        Remotes.Attack:FireServer()

    elseif input.KeyCode == Keybinds.Block then
        AnimationHandler.Play("BlockIdle")
        Remotes.Block:FireServer(true)

    elseif input.KeyCode == Keybinds.Dash then
        -- IMPORTANT: do NOT play dash animation here.
        -- Server confirms dash via Remotes.State -> CombatClient.OnState("Dash")
        local moveDir = InputHandler.GetMoveDirection()
        Remotes.Dash:FireServer(moveDir)

    elseif input.KeyCode == Keybinds.Uptilt then
        Remotes.Uptilt:FireServer()

    elseif input.KeyCode == Keybinds.Aerial then
        if Remotes.Aerial then
            Remotes.Aerial:FireServer()
        end

    elseif input.KeyCode == Keybinds.Ability1 then
        Remotes.Ability:FireServer(1)

    elseif input.KeyCode == Keybinds.Ability2 then
        Remotes.Ability:FireServer(2)

    elseif input.KeyCode == Keybinds.Ability3 then
        Remotes.Ability:FireServer(3)

    elseif input.KeyCode == Keybinds.Ability4 then
        Remotes.Ability:FireServer(4)
    end
end

function InputHandler.OnInputEnded(input, gameProcessed)
    if input.KeyCode == Keybinds.Block then
        AnimationHandler.Stop("BlockIdle")
        Remotes.Block:FireServer(false)
    end
end

function InputHandler.GetMoveDirection()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return Vector3.zero end

    local camera = workspace.CurrentCamera
    local moveDir = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveDir = moveDir + camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveDir = moveDir - camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveDir = moveDir - camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveDir = moveDir + camera.CFrame.RightVector
    end

    moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)

    if moveDir.Magnitude > 0 then
        return moveDir.Unit
    end

    return hrp.CFrame.LookVector
end

return InputHandler
