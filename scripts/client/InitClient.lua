--[[
	Client-side combat initialization
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function WaitForRemotes()
    local maxWait = 10
    local waited = 0
    while not ReplicatedStorage:FindFirstChild("Remotes") and waited < maxWait do
        task.wait(0.1)
        waited = waited + 0.1
    end
    return ReplicatedStorage:FindFirstChild("Remotes") ~= nil
end

if not WaitForRemotes() then
    warn("[CombatClient] Remotes folder not found!")
    return
end

print("[CombatClient] Starting...")

local CombatClient = require(script.Parent.CombatClient)
local CombatLock = require(script.Parent.CombatLockClient)
CombatClient.Init()
CombatLock.Init()

print("[CombatClient] Initialized!")
