Macros = Macros or {}

local MacrosCache = {}
local MacroIconsCache = {}

local MACRO_TAG = "macro"
local MACRO_EMPTY_NAME = "<empty>"

local PARTS_SEPARATOR_CODE = "&#124;"
local MAX_ACCOUNT_MACROS = 120
local MAX_CHARACTER_MACROS = 18
local MAX_TOTAL_MACROS = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS

local mDebug = function (str, ...)
	if ... then str = str:format(...) end
	DEFAULT_CHAT_FRAME:AddMessage(("ABK debug: %s"):format(str))
end

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
    if macroIndex >= 1 and macroIndex <= MAX_CHARACTER_MACROS then
        return 1
    end

    return 2
end

local function tryCreateMacro(name, body, texture, private)
    mDebug(string.format("create macro: index - %s", name))

    local icon = MacroIconsCache[texture]
    if icon == nil then
        icon = 1
    end

    mDebug(string.format("get macro icon: index - %s (%s)", icon, private or "nil"))

    local macroIndex = CreateMacro(name, icon, body)
    local finish = MAX_CHARACTER_MACROS
    if macroIndex > finish then
        finish = MAX_TOTAL_MACROS
    end

    Macros:CacheMacro(macroIndex, finish)

    return macroIndex
end

function Macros:Save(type, macroIndex)
	if type ~= MACRO_TAG then
		return nil
	end

    mDebug(string.format("get macro: index - %s", macroIndex))

	if macroIndex <= 0 then
        mDebug(string.format("unknown macro: index - %s", macroIndex))
		return nil
	end

    local name, texture, body, _ = GetMacroInfo(macroIndex)
    if body == nil then
        mDebug(string.format("not found macro: index - %s", macroIndex))
		return nil
    end

    mDebug(string.format("save macro: %s (%s)", name, macroIndex))

    name = compress(name)
    body = compress(body)
    texture = compress(getTextureId(texture))

    return { type, name, texture, body, hasPrivateMacros(macroIndex)  }
end

function Macros:Load(actionId, ...)
	mDebug(string.format("restore action: index - %d", actionId))

	local type, name, texture, body, private  = ...
	if type ~= MACRO_TAG then
        mDebug("restore action not macro")
		return
	end

    local macroId = getMacroId(name, body)
    -- Ненадежный, создание нового макроса смещает индекс, т.к. идет сортировка по имени
    local macroIndex = MacrosCache[macroId]

    mDebug(string.format("get macro: id - %s", macroId))

    if not macroIndex then
        name = uncompress(name)
        body = uncompress(body)
        texture = uncompress(texture)

        mDebug(string.format("unknown macro: %s - %s", name, macroId))

        macroIndex = tryCreateMacro(name, body, texture, private)
        if not macroIndex then
            mDebug(string.format("not create macro: %s - %s", name, macroId))
            return nil
        end
    end

    mDebug(string.format("pickup action: index - %s, macro - %s", actionId, macroIndex))
    PickupMacro(macroIndex)
    PlaceAction(actionId)
    mDebug(string.format("place action: index - %s", actionId))
end

function Macros:CacheMacro(start, finish)
    local total = 0
	for macroIndex = start, finish do
		local name, _, body, _ = GetMacroInfo(macroIndex)
		if body then
            total = total + 1

            name = compress(name)
            body = compress(body)

            local macroId = getMacroId(name, body)
            MacrosCache[macroId] = macroIndex
            mDebug(string.format("cached macro: %s - %s", name, macroId))
        end
	end

    return total
end

function Macros:Recached()
	mDebug("start caching: macros")

    wipe(MacrosCache)
    local total = Macros:CacheMacro(1, MAX_TOTAL_MACROS)
	mDebug(string.format("end caching: total - %d", total))

	mDebug("start caching: macros icons")

    wipe(MacroIconsCache)

    total = 0
    local maxIcons = GetNumMacroIcons()
    for iconIndex = 1, maxIcons do
        local texture = GetMacroIconInfo(iconIndex)
        if texture then
            total = total + 1
            MacroIconsCache[getTextureId(texture)] = iconIndex
        end
    end
	mDebug(string.format("end caching: total - %d", total))
end