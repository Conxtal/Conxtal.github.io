--[[
	VFX for Arthur character
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BASICFX = ReplicatedStorage.VFX.BASIC_COMBAT_VFX
local ARTHURVFX = ReplicatedStorage.VFX.ArthurFX

local Arthur = {}

Arthur.Colors = {
    Primary = Color3.fromRGB(100, 180, 255),
    PrimaryBright = Color3.fromRGB(150, 220, 255),
    Awakening = Color3.fromRGB(255, 100, 50),
    Electric = Color3.fromRGB(255, 255, 100),
}

--================================================
-- HELPERS
--================================================

local function CreatePart(props)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false 
    part.CastShadow = false
    part.Material = props.Material or Enum.Material.Neon
    part.Color = props.Color or Color3.new(1, 1, 1)
    part.Size = props.Size or Vector3.new(1, 1, 1)
    part.Transparency = props.Transparency or 0

    if props.Position then part.Position = props.Position end
    if props.CFrame then part.CFrame = props.CFrame end
    if props.Shape then part.Shape = props.Shape end

    part.Parent = props.Parent or workspace
    return part
end

local function TweenDestroy(part, duration, properties)
    TweenService:Create(part, TweenInfo.new(duration), properties):Play()
    task.delay(duration, function()
        part:Destroy()
    end)
end

--================================================
-- M1 VFX
--================================================

function Arthur.OnM1(character, combo, data)
    
end

--================================================
-- HIT VFX
--================================================

function Arthur.OnHit(position, combo, hitType, attackDir, victimChar)
    local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
    local basicFolder = vfxFolder and vfxFolder:FindFirstChild("BASIC_COMBAT_VFX")

    if hitType == "Light" then
        local hitVFXTemplate = basicFolder and basicFolder:FindFirstChild("HitVFX")
        if hitVFXTemplate then
            local vfx = hitVFXTemplate:Clone()
            vfx.CFrame = CFrame.new(position, position + (attackDir or Vector3.new(0, 0, 1)))
            vfx.Parent = workspace

            for _, child in pairs(vfx:GetDescendants()) do
                if child:IsA("ParticleEmitter") then
                    child:Emit(child:GetAttribute("EmitCount") or 10)
                end
            end

            task.delay(1.5, function()
                vfx:Destroy()
            end)
        end

    elseif hitType == "Final" then
        local finalVFXTemplate = basicFolder and basicFolder:FindFirstChild("HeavyHit")
        if finalVFXTemplate then
            local vfx = finalVFXTemplate:Clone()
            vfx.CFrame = CFrame.new(position, position + (attackDir or Vector3.new(0, 0, 1)))
            vfx.Parent = workspace

            for _, child in pairs(vfx:GetDescendants()) do
                if child:IsA("ParticleEmitter") then
                    child:Emit(child:GetAttribute("EmitCount") or 20)
                end
            end

            task.delay(2, function()
                vfx:Destroy()
            end)
        end
    end
end

--================================================
-- UPTILT VFX
--================================================

function Arthur.OnUptilt(character, data)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local slash = CreatePart({
        Size = Vector3.new(0.3, 4, 0.1),
        CFrame = hrp.CFrame * CFrame.new(0, 2, -2),
        Color = Arthur.Colors.PrimaryBright,
        Transparency = 0.3,
    })

    TweenDestroy(slash, 0.15, {
        Size = Vector3.new(0.5, 6, 0.1),
        Transparency = 1,
    })
end

--================================================
-- DASH VFX
--================================================

function Arthur.OnDash(character, direction, data)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    
    local DashFX = BASICFX.DashFX:Clone()
    
    if not hrp then return end

    local color = Arthur.Colors.Primary
    
    
    -- Afterimage
    
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local clone = part:Clone()
            clone:ClearAllChildren()
            clone.Anchored = true
            clone.CanCollide = false
            clone.CastShadow = false
            clone.Material = Enum.Material.Neon
            clone.Color = color
            clone.Transparency = 0.6
            clone.Parent = workspace
            TweenDestroy(clone, 0.25, { Transparency = 1 })
        end
    end

    if DashFX then
        DashFX.Parent = workspace
        DashFX.CFrame = hrp.CFrame * CFrame.new(0, 0, -2)

        for _, child in pairs(DashFX:GetDescendants()) do
            if child:IsA("ParticleEmitter") then
                child:Emit(child:GetAttribute("EmitCount"))
            end
        end
    end
    
    
end

--================================================
-- BLOCK VFX
--================================================

function Arthur.OnBlockStart(character, data)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
    local basicFolder = vfxFolder and vfxFolder:FindFirstChild("BASIC_COMBAT_VFX")
    local blockVFX = basicFolder and basicFolder:FindFirstChild("Blocking")

    if blockVFX then
        local vfx = blockVFX:Clone()
        vfx.Name = "ActiveBlockVFX"
        vfx.Anchored = false
        vfx.CanCollide = false
        vfx.CFrame = hrp.CFrame
        vfx.Parent = hrp

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = hrp
        weld.Part1 = vfx
        weld.Parent = vfx

        -- Enable all particle emitters
        for _, child in pairs(vfx:GetDescendants()) do
            if child:IsA("ParticleEmitter") then
                child.Enabled = true
            end
        end
    end
end

function Arthur.OnBlockEnd(character, data)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local vfx = hrp:FindFirstChild("ActiveBlockVFX")
    if vfx then
        -- Disable emitters, let particles fade naturally
        for _, child in pairs(vfx:GetDescendants()) do
            if child:IsA("ParticleEmitter") then
                child.Enabled = false
            end
        end

        task.delay(2, function()
            vfx:Destroy()
        end)
    end
end

--================================================
-- ABILITIES (stubs)
--================================================

function Arthur.DragonStep(character, data)
end

function Arthur.EtherSlash(character, data)
end

function Arthur.BurstNova(character, data)
end

function Arthur.StaticEdge(character, data)
end

--================================================
-- PASSIVE VFX
--================================================

function Arthur.CombatFocusMax(character, data)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    print("CombatFocusMax VFX triggered!")

    local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
    local arthurFX = vfxFolder and vfxFolder:FindFirstChild("ArthurFX")
    local focusVFX = arthurFX and arthurFX:FindFirstChild("ManaAura")

    if focusVFX then
        local vfx = focusVFX:Clone()
        vfx.Name = "ManaAura"
        vfx.Anchored = false
        vfx.CanCollide = false
        vfx.CFrame = hrp.CFrame
        vfx.Parent = hrp

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = hrp
        weld.Part1 = vfx
        weld.Parent = vfx
    end
end

function Arthur.CombatFocusEnd(character, data)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    print("CombatFocusEnd - Removing VFX")

    local vfx = hrp:FindFirstChild("ManaAura")
    if vfx then
        -- Disable emitters first for smooth fadeout
        for _, child in pairs(vfx:GetDescendants()) do
            if child:IsA("ParticleEmitter") then
                child.Enabled = false
            end
        end

        -- Destroy after particles fade
        task.delay(1, function()
            if vfx and vfx.Parent then
                vfx:Destroy()
            end
        end)
    end
end

function Arthur.AwakeningActivate(character, data)
end

return Arthur
