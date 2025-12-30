--[[
	HitboxHandler.lua
	Hitbox detection utilities
	Location: ReplicatedStorage/Combat/Modules/HitboxHandler
]]

local HitboxHandler = {}
HitboxHandler.Debug = false

local function GetCharacterFromPart(part)
    local current = part
    while current do
        local humanoid = current:FindFirstChildOfClass("Humanoid")
        local hrp = current:FindFirstChild("HumanoidRootPart")
        if humanoid and hrp then
            return current, humanoid, hrp
        end
        current = current.Parent
    end
    return nil, nil, nil
end

local function GetPlayerFromCharacter(character)
    local Players = game:GetService("Players")
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character == character then
            return player
        end
    end
    return nil
end

local function DebugVisualize(cframe, size, duration)
    if not HitboxHandler.Debug then return end
    local part = Instance.new("Part")
    part.Size = size
    part.CFrame = cframe
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 0.7
    part.Color = Color3.new(1, 0, 0)
    part.Material = Enum.Material.Neon
    part.Parent = workspace
    game:GetService("Debris"):AddItem(part, duration or 0.3)
end

function HitboxHandler.Box(cframe, size, ignore, callback)
    DebugVisualize(cframe, size, 0.3)

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore or {}

    local parts = workspace:GetPartBoundsInBox(cframe, size, params)
    local hit = {}

    for _, part in pairs(parts) do
        local character, humanoid, hrp = GetCharacterFromPart(part)

        -- Check if character is valid AND alive
        if character and humanoid and hrp and not hit[character] and humanoid.Health > 0 then
            hit[character] = true
            local player = GetPlayerFromCharacter(character)
            callback(player, character, humanoid, hrp)
        end
    end
end

function HitboxHandler.Sphere(position, radius, ignore, callback)
    local cframe = CFrame.new(position)
    local size = Vector3.new(radius * 2, radius * 2, radius * 2)
    DebugVisualize(cframe, size, 0.3)

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore or {}

    local parts = workspace:GetPartBoundsInRadius(position, radius, params)
    local hit = {}

    for _, part in pairs(parts) do
        local character, humanoid, hrp = GetCharacterFromPart(part)

        -- Check if character is valid AND alive
        if character and humanoid and hrp and not hit[character] and humanoid.Health > 0 then
            hit[character] = true
            local player = GetPlayerFromCharacter(character)
            callback(player, character, humanoid, hrp)
        end
    end
end

function HitboxHandler.GetTargetsInRange(position, range, ignore)
    local targets = {}

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore or {}

    local parts = workspace:GetPartBoundsInRadius(position, range, params)
    local found = {}

    for _, part in pairs(parts) do
        local character, humanoid, hrp = GetCharacterFromPart(part)

        if character and humanoid and hrp and not found[character] and humanoid.Health > 0 then
            found[character] = true
            local player = GetPlayerFromCharacter(character)
            table.insert(targets, {
                player = player,
                character = character,
                humanoid = humanoid,
                hrp = hrp,
                distance = (position - hrp.Position).Magnitude,
            })
        end
    end

    table.sort(targets, function(a, b)
        return a.distance < b.distance
    end)

    return targets
end

return HitboxHandler
