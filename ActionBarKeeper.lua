local AddonName = "ActionBarKeeper"
local ABK = {}
ABK.debugMode = false
ABK.modules = {}
ABK.restoreErrors = {}

local defaults = {
	sets = {}
}

local playerClass
local MAX_ACTION_BUTTONS = 144
local POSSESSION_START = 121
local POSSESSION_END = 132

PARTS_SEPARATOR = '|'

wipe = function (t)
	for k,v in pairs(t) do
		v = nil
		k = nil
	end
end

debug = function (str, ...)
	if not ABK.debugMode then return end
	if ... then str = str:format(...) end
	DEFAULT_CHAT_FRAME:AddMessage(("ABK debug: %s"):format(str))
end

endswith = function (sounrce, suffix)
    return string.sub(sounrce, -#suffix) == suffix
end
function ABK:OnInitialize()
	ActionBarKeeperDB = ActionBarKeeperDB or {}

	for key, value in pairs(defaults) do
		if( ActionBarKeeperDB[key] == nil ) then
			ActionBarKeeperDB[key] = value
		end
	end

	for classToken in pairs(RAID_CLASS_COLORS) do
		ActionBarKeeperDB.sets[classToken] = ActionBarKeeperDB.sets[classToken] or {}
	end

	self.db = ActionBarKeeperDB

	playerClass = select(2, UnitClass("player"))
end

function ABK:OnRegisterCommands()
	SLASH_ABK1 = "/actionbar"
	SLASH_ABK2 = "/ab"
	SlashCmdList["ABK"] = HandleSlashCommand
end

function ABK:OnRegisterModules()
	self:RegisterModule("Spells", Spells)
	self:RegisterModule("Macros", Macros)
end

function ABK:RegisterModule(name, module)
	self.modules[name] = module
	debug(string.format("append module: %s", name))
end


function ABK:SaveProfile(name)
	self.db.sets[playerClass][name] = self.db.sets[playerClass][name] or {}
	local set = self.db.sets[playerClass][name]

	for actionID = 1, MAX_ACTION_BUTTONS do
		if actionID < POSSESSION_START or actionID > POSSESSION_END then
			set[actionID] = nil

			local type, id = GetActionInfo(actionID)
			if type == nil or id == nil then
				debug(string.format("empty action: index - %s", actionID))
			else
				for _, module in pairs(self.modules) do
					local args = module:Save(type, id)
					if args ~= nil then
						args = table.concat(args, PARTS_SEPARATOR)
						debug(string.format("action args: index - %s (%s)", actionID, args))

						set[actionID] = args
						break
					end
				end
			end
		end

		if set[actionID] ~= nil then
			debug(string.format("saved action: index - %s", actionID))
		end
	end

	self:Print(string.format("Saved profile: %s", name))
end

function ABK:RestoreProfile(name)
	debug(string.format("restored by name %s", name))

	local set = self.db.sets[playerClass][name]
	if( not set ) then
		self:Print(string.format("Your class \"%s\" does not have a profile named \"%s\"", playerClass, name))
		return
	elseif( InCombatLockdown() ) then
		self:Print(string.format("Unable to restore profile \"%s\", you are in combat.", name))
		return
	end

	wipe(self.restoreErrors)

	for moduleName, module in pairs(self.modules) do
		debug(string.format("init module: %s", moduleName))
		module.Init()
	end

	-- Save current sound setting
	-- Turn sound off
	local soundToggle = GetCVar("Sound_EnableAllSound")
	SetCVar("Sound_EnableAllSound", 0)

	debug("restoring...")
	ClearCursor()
	for i=1, MAX_ACTION_BUTTONS do
		if( i < POSSESSION_START or i > POSSESSION_END ) then
			if HasAction(i) and GetActionInfo(i) then
				debug(string.format("clear action id - %s", i))
				PickupAction(i)
				ClearCursor()
			end

			if set[i] then
				for _, module in pairs(self.modules) do
					module:Restore(i, strsplit(PARTS_SEPARATOR, set[i]))
				end
			end
		end
	end
	debug("restored")

	SetCVar("Sound_EnableAllSound", soundToggle)

	-- Done!
	if( #(self.restoreErrors) == 0 ) then
		self:Print(string.format("Restored profile %s!", name))
	else
		self:Print(string.format("Restored profile %s, failed to restore %d buttons type /AB errors for more information.", name, #(self.restoreErrors)))
	end
end

function ABK:DeleteProfile(name)
	if self.db.sets[playerClass] == nil or self.db.sets[playerClass][name] == nil then
		self:Print(string.format("Unknown profile %s.", name))
		return
	end

	self.db.sets[playerClass][name] = nil
	self:Print(string.format("Deleted saved profile %s.", name))
end

function ABK:ShowProfiles()
	for profileName in pairs(self.db.sets[playerClass]) do
		DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ff99%s|r: %s", playerClass or "???", profileName))
	end
end

function ABK:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ff99%s|r: ", AddonName) .. msg)
end

function HandleSlashCommand(msg)
	msg = msg or ""
	debug(string.format("handle command - '%s'", msg))

	local cmd, arg = string.split(" ", msg, 2)
	cmd = string.lower(cmd or "")
	arg = string.lower(arg or "")

	if( cmd == "save" and arg ~= "" ) then
		ABK:SaveProfile(arg)
	elseif( cmd == "load" and arg ~= "" ) then
		ABK:RestoreProfile(arg)
	elseif( cmd == "delete" ) then
		ABK:DeleteProfile(arg)
	elseif( cmd == "show" ) then
		ABK:ShowProfiles()
	else
		ABK:Print("Slash commands")
		DEFAULT_CHAT_FRAME:AddMessage("/AB save <profile> - Saves your current action bar setup under the given profile.")
		DEFAULT_CHAT_FRAME:AddMessage("/AB load <profile> - Changes your action bars to the passed profile.")
		DEFAULT_CHAT_FRAME:AddMessage("/AB delete <profile> - Deletes the saved profile.")
		DEFAULT_CHAT_FRAME:AddMessage("/AB show - Show all saved profiles.")
	end
end

debug("create frame")
local frame = CreateFrame("Frame")
local function OnLoaded(self, event, addon)
	if addon ~= AddonName then
		return
	end

	debug("loading")

	debug("begin initialize")
	ABK:OnInitialize()
	ABK:OnRegisterCommands()
	ABK:OnRegisterModules()
	debug("end initialize")

	frame:UnregisterEvent("ADDON_LOADED")
	debug("loaded")
	ABK:Print(string.format("Addon loaded. Slash command: %s", SLASH_ABK2))
end

debug("subscribe load event")
frame:SetScript("OnEvent", OnLoaded)
frame:RegisterEvent("ADDON_LOADED")
