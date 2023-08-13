Macros = Macros or {}

local MACRO_TAG = "macro"

local MacrosCache = {}

local PARTS_SEPARATOR_CODE = "&#124;"
local MAX_ACCOUNT_MACROS = 120
local MAX_CHARACTER_MACROS = 18
local MAX_TOTAL_MACROS = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS

debug = function (str, ...)
	if ... then str = str:format(...) end
	DEFAULT_CHAT_FRAME:AddMessage(("ABK debug: %s"):format(str))
end

local function getMacroIndex(body)
    local counter = 1
    local len = string.len(body)
    for i = 1, len, 3 do 
      counter = math.fmod(counter*8161, 4294967279)
        + (string.byte(body,i)*16776193)
        + ((string.byte(body,i+1) or (len-i+256))*8372226)
        + ((string.byte(body,i+2) or (len-i+256))*3932164)
    end

    return math.fmod(counter, 4294967291)
end

local function Compress(text)
	text = string.gsub(text, "\n", "/n")
	text = string.gsub(text, PARTS_SEPARATOR, PARTS_SEPARATOR_CODE)

	return string.trim(text)
end

local function Uncompress(text)
	text = string.gsub(text, "/n", "\n")
	text = string.gsub(text, PARTS_SEPARATOR_CODE, PARTS_SEPARATOR)

	return string.trim(text)
end

function Macros:Save(type, macroIndex)
	if type ~= MACRO_TAG then
		return nil
	end

	if macroIndex <= 0 then
        debug(string.format("unknown macro: index - %s", macroIndex))
		return nil
	end

    local name, texture, body, isLocal = GetMacroInfo(macroIndex)
    if body == nil then
        debug(string.format("not found macro: index - %s", macroIndex))
		return nil
    end

    name = Compress(name)
    body = Compress(body)
    texture = Compress(texture)

    return { type, name, texture, body, isLocal }
end

function Macros:Restore(actionId, ...)
	debug(string.format("restore action: index - %d", actionId))

	local type, name, texture, body, isLocal  = ...
	if type ~= MACRO_TAG then
        debug("restore action not macro")
		return
	end

    name = Uncompress(name)
    body = Uncompress(body)
    texture = Uncompress(texture)

    return nil
    -- -- debug(string.format("pickup action: index - %s, macro - %s", actionId, name))

    -- PickupMacro(self:FindMacro(actionId, name, content or -1))
    -- PlaceAction(actionId)

    -- debug(string.format("place action: index - %s", actionId))
end

function Macros:Init()
	debug("start caching: macros")

    wipe(MacrosCache)

    local total = 0
	for macroIndex = 1, MAX_TOTAL_MACROS do
		local name, _, body, _ = GetMacroInfo(macroIndex)
		if body then
            total = total + 1
            MacrosCache[getMacroIndex(body)] = macroIndex
            debug(string.format("append macro: %s", name or "<empty>"))
        end
	end

	debug(string.format("end caching: total - %d", total))
end