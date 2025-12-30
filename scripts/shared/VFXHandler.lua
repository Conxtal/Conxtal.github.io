--[[
	VFXHandler.lua
	Handles visual effects - called by CombatClient
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local VFXHandler = {}

local CharacterVFX = {}
local CurrentCharacter = "Arthur"

VFXHandler.DEBUG = false

local function dprint(...)
    if VFXHandler.DEBUG then
        print("[VFXHandler]", ...)
    end
end

--================================================
-- INITIALIZATION
--================================================

function VFXHandler.Init()
    -- Load character VFX modules from ReplicatedStorage/Combat/Data/CharacterVFX
    local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
    local DataFolder = CombatFolder:FindFirstChild("Data")
    local vfxFolder = DataFolder and DataFolder:FindFirstChild("CharacterVFX")

    if vfxFolder then
        for _, child in pairs(vfxFolder:GetChildren()) do
            if child:IsA("ModuleScript") then
                local ok, mod = pcall(require, child)
                if ok and mod then
                    -- Use the module name without "VFX" suffix as key
                    local key = child.Name:gsub("VFX$", "")
                    CharacterVFX[key] = mod
                    dprint("Loaded character VFX:", key)
                else
                    warn("[VFXHandler] Failed to load:", child.Name, mod)
                end
            end
        end
    else
        warn("[VFXHandler] CharacterVFX folder not found at ReplicatedStorage.Combat.Data.CharacterVFX")
    end

    dprint("Initialized")
    return VFXHandler
end

function VFXHandler.SetCharacter(characterName)
    CurrentCharacter = characterName
    dprint("Set character:", characterName)
end

function VFXHandler.GetCharacterVFX(characterName)
    return CharacterVFX[characterName or CurrentCharacter]
end

--================================================
-- EVENT HANDLERS (called by CombatClient)
--================================================

function VFXHandler.OnHit(hitData)
    if not hitData then return end

    dprint("OnHit:", hitData.hitType, "combo:", hitData.combo)

    local isAttacker = hitData.attacker == Player
    local isVictim = hitData.victim == Player
    local position = hitData.position
    local hitType = hitData.hitType
    local combo = hitData.combo
    local blocked = hitData.blocked
    local attackDir = hitData.attackDir
    local victimChar = hitData.victimChar

    -- Get attacker's character VFX
    local attackerCharName = CurrentCharacter
    if hitData.attacker then
        local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
        local State = require(CombatFolder.Modules.StateManager)
        attackerCharName = State.GetCharacter(hitData.attacker) or CurrentCharacter
    end

    local vfx = CharacterVFX[attackerCharName]

    -- Block effects
    if blocked then
        if blocked == "Perfect" then
            VFXHandler.PerfectBlock(position)
        elseif blocked == "Break" then
            VFXHandler.BlockBreak(position)
        else
            VFXHandler.BlockHit(position)
        end
    else
        -- Hit effects
        if vfx and vfx.OnHit then
            vfx.OnHit(position, combo, hitType, attackDir, victimChar)
        else
            VFXHandler.DefaultHit(position, hitType)
        end
    end

    -- Camera shake
    if isAttacker or isVictim then
        local intensity = 0.3
        if hitType == "Final" then intensity = 0.8
        elseif hitType == "Uptilt" then intensity = 0.6
        elseif blocked == "Perfect" then intensity = 0.5
        end
        VFXHandler.CameraShake(intensity)
    end

    -- Screen flash if victim
    if isVictim and not blocked then
        VFXHandler.ScreenFlash(Color3.new(1, 0.2, 0.2), 0.15)
    end

    -- Damage number
    if isAttacker and hitData.damage and hitData.damage > 0 then
        VFXHandler.DamageNumber(position, hitData.damage, hitType == "Final")
    end
end

function VFXHandler.OnM1(player, combo, data)
    local char = player and player.Character
    if not char then return end

    dprint("OnM1:", combo)

    local charName = (data and data.character) or CurrentCharacter
    local vfx = CharacterVFX[charName]

    if vfx and vfx.OnM1 then
        vfx.OnM1(char, combo, data)
    end
end

function VFXHandler.OnUptilt(player, data)
    local char = player and player.Character
    if not char then return end

    dprint("OnUptilt")

    local charName = (data and data.character) or CurrentCharacter
    local vfx = CharacterVFX[charName]

    if vfx and vfx.OnUptilt then
        vfx.OnUptilt(char, data)
    end
end

function VFXHandler.OnDash(character, direction, data)
    if not character then return end

    dprint("OnDash")

    local charName = (data and data.character) or CurrentCharacter
    local vfx = CharacterVFX[charName]

    if vfx and vfx.OnDash then
        vfx.OnDash(character, direction, data)
    else
        VFXHandler.DefaultDashTrail(character)
    end
end

function VFXHandler.OnBlockStart(character, data)
    if not character then return end

    local charName = (data and data.character) or CurrentCharacter
    local vfx = CharacterVFX[charName]

    if vfx and vfx.OnBlockStart then
        vfx.OnBlockStart(character, data)
    end
end

function VFXHandler.OnBlockEnd(character, data)
    if not character then return end

    local charName = (data and data.character) or CurrentCharacter
    local vfx = CharacterVFX[charName]

    if vfx and vfx.OnBlockEnd then
        vfx.OnBlockEnd(character, data)
    end
end

function VFXHandler.OnAbility(player, abilityName, data)
    local char = player and player.Character
    if not char then return end

    dprint("OnAbility:", abilityName)

    local charName = (data and data.character) or CurrentCharacter
    local vfx = CharacterVFX[charName]

    if vfx then
        if vfx[abilityName] then
            vfx[abilityName](char, data)
        elseif vfx.OnAbility then
            vfx.OnAbility(char, abilityName, data)
        end
    end
end

function VFXHandler.OnPassiveVFX(character, vfxName, data)
    if not character then return end

    local player = Players:GetPlayerFromCharacter(character)
    local charName = CurrentCharacter

    if player then
        local CombatFolder = ReplicatedStorage:WaitForChild("Combat")
        local State = require(CombatFolder.Modules.StateManager)
        charName = State.GetCharacter(player) or CurrentCharacter
    end

    local vfx = CharacterVFX[charName]

    if vfx and vfx[vfxName] then
        vfx[vfxName](character, data)
    end
end

--================================================
-- GENERIC VFX
--================================================

function VFXHandler.CameraShake(intensity, duration)
    duration = duration or 0.15
    local camera = workspace.CurrentCamera
    if not camera then return end

    local startTime = tick()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        if elapsed > duration then
            conn:Disconnect()
            return
        end

        local decay = 1 - (elapsed / duration)
        local offset = Vector3.new(
            (math.random() - 0.5) * intensity * decay,
            (math.random() - 0.5) * intensity * decay,
            0
        )
        camera.CFrame = camera.CFrame * CFrame.new(offset)
    end)
end

function VFXHandler.ScreenFlash(color, duration)
    local playerGui = Player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("HitFlash")
    if existing then existing:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "HitFlash"
    gui.IgnoreGuiInset = true
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = color
    frame.BackgroundTransparency = 0.7
    frame.BorderSizePixel = 0
    frame.Parent = gui

    TweenService:Create(frame, TweenInfo.new(duration), {
        BackgroundTransparency = 1
    }):Play()

    task.delay(duration, function()
        gui:Destroy()
    end)
end

function VFXHandler.DamageNumber(position, damage, isCrit)
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.Position = position + Vector3.new(math.random(-1, 1), 2, math.random(-1, 1))
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Parent = workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.Adornee = part
    billboard.AlwaysOnTop = true
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = tostring(math.floor(damage))
    label.TextColor3 = isCrit and Color3.new(1, 0.8, 0) or Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.5
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = billboard

    local startPos = part.Position
    local endPos = startPos + Vector3.new(0, 3, 0)
    local dur = 0.6
    local startTime = tick()

    local conn
    conn = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        local progress = elapsed / dur

        if progress >= 1 then
            conn:Disconnect()
            part:Destroy()
            return
        end

        part.Position = startPos:Lerp(endPos, progress)
        label.TextTransparency = progress
        label.TextStrokeTransparency = 0.5 + (progress * 0.5)
    end)
end

function VFXHandler.BlockHit(position)
    local part = Instance.new("Part")
    part.Size = Vector3.new(2, 2, 0.2)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = Color3.new(1, 1, 1)
    part.Transparency = 0.3
    part.Parent = workspace

    TweenService:Create(part, TweenInfo.new(0.15), {
        Size = Vector3.new(4, 4, 0.2),
        Transparency = 1
    }):Play()

    task.delay(0.15, function()
        part:Destroy()
    end)
end

function VFXHandler.PerfectBlock(position)
    local ring = Instance.new("Part")
    ring.Size = Vector3.new(1, 1, 0.1)
    ring.Position = position
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.Color = Color3.new(1, 0.9, 0.3)
    ring.Transparency = 0
    ring.Parent = workspace

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = "rbxassetid://3270017"
    mesh.Scale = Vector3.new(1, 1, 1)
    mesh.Parent = ring

    TweenService:Create(mesh, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Scale = Vector3.new(5, 5, 5)
    }):Play()

    TweenService:Create(ring, TweenInfo.new(0.25), {
        Transparency = 1
    }):Play()

    VFXHandler.ScreenFlash(Color3.new(1, 1, 0.8), 0.1)

    task.delay(0.25, function()
        ring:Destroy()
    end)
end

function VFXHandler.BlockBreak(position)
    for i = 1, 8 do
        local shard = Instance.new("Part")
        shard.Size = Vector3.new(0.3, 0.5, 0.1)
        shard.Position = position
        shard.Anchored = true
        shard.CanCollide = false
        shard.Material = Enum.Material.Glass
        shard.Color = Color3.new(0.8, 0.8, 1)
        shard.Transparency = 0.3
        shard.Parent = workspace

        local angle = (i / 8) * math.pi * 2
        local dir = Vector3.new(math.cos(angle), math.random() * 0.5 + 0.5, math.sin(angle))
        local endPos = position + dir * 3

        TweenService:Create(shard, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = endPos,
            Transparency = 1,
            Orientation = Vector3.new(math.random(360), math.random(360), math.random(360))
        }):Play()

        task.delay(0.4, function()
            shard:Destroy()
        end)
    end

    VFXHandler.ScreenFlash(Color3.new(1, 0.5, 0.5), 0.15)
end

function VFXHandler.DefaultHit(position, hitType)
    local size = hitType == "Final" and 2.5 or 1.5
    local color = hitType == "Final" and Color3.new(1, 0.8, 0.3) or Color3.new(1, 1, 1)

    local part = Instance.new("Part")
    part.Size = Vector3.new(size, size, size)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.Shape = Enum.PartType.Ball
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Transparency = 0.3
    part.Parent = workspace

    TweenService:Create(part, TweenInfo.new(0.2), {
        Size = Vector3.new(size * 2, size * 2, size * 2),
        Transparency = 1
    }):Play()

    task.delay(0.2, function()
        part:Destroy()
    end)
end

function VFXHandler.DefaultDashTrail(character, color)
    color = color or Color3.new(1, 1, 1)

    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 0.9 then
            local clone = part:Clone()
            clone:ClearAllChildren()
            clone.Anchored = true
            clone.CanCollide = false
            clone.CastShadow = false
            clone.Material = Enum.Material.Neon
            clone.Color = color
            clone.Transparency = 0.5
            clone.Parent = workspace

            TweenService:Create(clone, TweenInfo.new(0.3), {
                Transparency = 1
            }):Play()

            task.delay(0.3, function()
                clone:Destroy()
            end)
        end
    end
end

return VFXHandler
