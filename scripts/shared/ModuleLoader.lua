--[[
	ModuleLoader.lua
	CORE FRAMEWORK: Central module loading system

	Fixes the mess of inconsistent require() paths.
	Everything goes through this loader.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModuleLoader = {}
local LoadedModules = {}

-- ====================================
-- PATHS CONFIGURATION
-- ====================================

local COMBAT_FOLDER = ReplicatedStorage:WaitForChild("Combat", 10)

local PATHS = {
	-- Core Systems
	Core = {
		StateManager = COMBAT_FOLDER.Modules.StateManager,
		CooldownManager = COMBAT_FOLDER.Modules.CooldownManager,
		Config = COMBAT_FOLDER.Config,
		HitboxHandler = COMBAT_FOLDER.Modules.HitboxHandler,
		AerialComboSystem = COMBAT_FOLDER.Modules.AerialComboSystem,
		InputBuffer = COMBAT_FOLDER.Modules.InputBuffer,
	},

	-- Client Handlers
	Client = {
		AnimationHandler = COMBAT_FOLDER.Handlers.AnimationHandler,
		InputHandler = COMBAT_FOLDER.Handlers.InputHandler,
		VFXHandler = COMBAT_FOLDER.Handlers.VFXHandler,
		LockOn = COMBAT_FOLDER.Modules.LockOn,
		CombatLockClient = COMBAT_FOLDER.Handlers.CombatLockClient,
	},

	-- Server Handlers (will be loaded from ServerScriptService)
	Server = {
		-- These are loaded differently - see GetServerHandler()
	},

	-- Character Data
	Characters = {
		Arthur = COMBAT_FOLDER.Characters.Arthur,
		ArthurVFX = COMBAT_FOLDER.Characters.ArthurVFX,
		CharacterRegistry = COMBAT_FOLDER.Handlers.CharacterRegistry,
	},
}

-- ====================================
-- MODULE LOADING
-- ====================================

function ModuleLoader.Get(category, moduleName)
	local cacheKey = category .. "." .. moduleName

	-- Return cached if available
	if LoadedModules[cacheKey] then
		return LoadedModules[cacheKey]
	end

	-- Get path
	local path = PATHS[category] and PATHS[category][moduleName]
	if not path then
		error(string.format("[ModuleLoader] Module not found: %s.%s", category, moduleName))
	end

	-- Load and cache
	local success, module = pcall(require, path)
	if not success then
		error(string.format("[ModuleLoader] Failed to load %s.%s: %s", category, moduleName, module))
	end

	LoadedModules[cacheKey] = module
	return module
end

-- ====================================
-- CONVENIENCE FUNCTIONS
-- ====================================

function ModuleLoader.GetCore(name)
	return ModuleLoader.Get("Core", name)
end

function ModuleLoader.GetClient(name)
	return ModuleLoader.Get("Client", name)
end

function ModuleLoader.GetCharacter(name)
	return ModuleLoader.Get("Characters", name)
end

function ModuleLoader.GetCharacterRegistry()
	return ModuleLoader.Get("Characters", "CharacterRegistry")
end

-- Server handlers are loaded from a different location
function ModuleLoader.GetServerHandler(handlerScript, name)
	local cacheKey = "Server." .. name

	if LoadedModules[cacheKey] then
		return LoadedModules[cacheKey]
	end

	local handler = handlerScript:FindFirstChild(name)
	if not handler then
		error(string.format("[ModuleLoader] Server handler not found: %s", name))
	end

	local success, module = pcall(require, handler)
	if not success then
		error(string.format("[ModuleLoader] Failed to load server handler %s: %s", name, module))
	end

	LoadedModules[cacheKey] = module
	return module
end

-- ====================================
-- UTILITIES
-- ====================================

function ModuleLoader.ClearCache()
	LoadedModules = {}
end

function ModuleLoader.IsLoaded(category, moduleName)
	local cacheKey = category .. "." .. moduleName
	return LoadedModules[cacheKey] ~= nil
end

function ModuleLoader.GetAllLoaded()
	return LoadedModules
end

-- ====================================
-- DEBUGGING
-- ====================================

function ModuleLoader.PrintLoaded()
	print("[ModuleLoader] Loaded modules:")
	for key, _ in pairs(LoadedModules) do
		print("  -", key)
	end
end

return ModuleLoader
