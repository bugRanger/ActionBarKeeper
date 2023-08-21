Macros = Macros or {}

local MacrosCache = {}
local MacroIconsCache = {}

local MACRO_TAG = "macro"
local MACRO_EMPTY_NAME = "<empty>"

local PARTS_SEPARATOR_CODE = "&#124;"
local MAX_ACCOUNT_MACROS = 18
local MAX_CHARACTER_MACROS = 18
local MAX_TOTAL_MACROS = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS

-- https://wowwiki-archive.fandom.com/wiki/USERAPI_StringHash
local function getStringHash(body)
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

local function compress(text)
	text = string.gsub(text, "\n", "/n")
    text = string.gsub(text, "\r", "/r")
	text = string.gsub(text, PARTS_SEPARATOR, PARTS_SEPARATOR_CODE)

	return text
end

local function uncompress(text)
	text = string.gsub(text, "/n", "\n")
    text = string.gsub(text, "/r", "\r")
	text = string.gsub(text, PARTS_SEPARATOR_CODE, PARTS_SEPARATOR)

	return text
end

local function getMacroId(name, body)
    name = name or MACRO_EMPTY_NAME
    return getStringHash(name..body)
end

local function getTextureId(texture)
    return gsub(strupper(texture or "INV_Misc_QuestionMark"), "INTERFACE\\ICONS\\", ""):upper();
end

local function hasPrivateMacros(macroIndex)
    if macroIndex >= 1 and macroIndex <= MAX_ACCOUNT_MACROS then
        return nil
    end

    return 1
end

local function cacheMacro(start, finish)
    local total = 0
	for macroIndex = start, finish do
		local name, _, body, _ = GetMacroInfo(macroIndex)
		if body then
            total = total + 1

            local macroId = getMacroId(name, body)
            MacrosCache[macroId] = macroIndex
            debug(string.format("cached macro: %s - %s", name, macroId))
        end
	end

    return total
end

local function cacheMacroIcons()
    local total = 0
    local maxIcons = GetNumMacroIcons()
    for iconIndex = 1, maxIcons do
        local texture = GetMacroIconInfo(iconIndex)
        if texture then
            total = total + 1
            MacroIconsCache[getTextureId(texture)] = iconIndex
            -- debug(string.format("cached macro icon: %s - %s", iconIndex, texture))
        end
    end

    return total
end

local function tryCreateMacro(name, body, texture, index)
    debug(string.format("creating macro: index - %s (%s)", name, index or "nil"))

    local icon = MacroIconsCache[texture]
    if icon == nil then
        icon = 1
    end
    debug(string.format("get macro icon: index - %s", icon))

    local success, macroIndex = pcall(CreateMacro, name, icon, body, nil, hasPrivateMacros(index))
    if not success or macroIndex == nil then
        error(string.format("could not be created macro (%s) because no free slots", name))
        return nil
    end

    debug(string.format("created macro: index - %s (%s)", macroIndex, name or "nil"))

    local finish = MAX_CHARACTER_MACROS
    if macroIndex > finish then
        finish = MAX_TOTAL_MACROS
    end

    cacheMacro(macroIndex, finish)

    return macroIndex
end

function Macros:Save(type, macroIndex)
	if type ~= MACRO_TAG then
		return nil
	end

    debug(string.format("get macro: index - %s", macroIndex))

	if macroIndex <= 0 then
        debug(string.format("unknown macro: index - %s", macroIndex))
		return nil
	end

    local name, texture, body, _ = GetMacroInfo(macroIndex)
    if body == nil then
        debug(string.format("not found macro: index - %s", macroIndex))
		return nil
    end

    debug(string.format("save macro: %s (%s)", name, macroIndex))

    local macroId = getMacroId(name, body)

    name = compress(name)
    body = compress(body)
    texture = compress(getTextureId(texture))

    return { type, macroId, name, texture, body, macroIndex }
end

function Macros:Load(actionId, ...)
	debug(string.format("restore action: index - %d", actionId))

	local type, id, name, texture, body, index  = ...
	if type ~= MACRO_TAG then
        debug("restore action not macro")
		return
	end

    id = tonumber(id)
    index = tonumber(index)

    debug(string.format("get macro: id - %s", id))
    local macroIndex = MacrosCache[id]

    if macroIndex == nil then
        debug(string.format("unknown macro: %s - %s", name, id))

        name = uncompress(name)
        body = uncompress(body)
        texture = uncompress(texture)

        macroIndex = tryCreateMacro(name, body, texture, index)
        if macroIndex == nil then
            debug(string.format("not create macro: %s - %s", name, id))
            return nil
        end
    end

    debug(string.format("pickup action: index - %s, macro - %s", actionId, macroIndex))
    PickupMacro(macroIndex)
    PlaceAction(actionId)
    debug(string.format("place action: index - %s", actionId))
end

function Macros:Recached()
    local total = 0;

	debug("start caching: macros")
    wipe(MacrosCache)
    total = cacheMacro(1, MAX_TOTAL_MACROS)
	debug(string.format("end caching: total - %d", total))

	debug("start caching: macros icons")
    wipe(MacroIconsCache)
    total = cacheMacroIcons()
	debug(string.format("end caching: total - %d", total))
end