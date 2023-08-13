Spells = Spells or {}

local SPELL_TAG = "spell"
local RACE_TAG = "Racial"

local SpellBookCache = {}
local RacialAbilities = {
    ["Human"] = "Perception",
    ["Dwarf"] = "Stoneform",
    ["NightElf"] = "Shadowmeld",
    ["Gnome"] = "Escape Artist",
    ["Draenei"] = "Gift of the Naaru",

    ["Orc"] = "Blood Fury",
    ["Troll"] = "Berserking",
    ["Tauren"] = "War Stomp",
    -- Undead --> Scourge
    ["Scourge"] = "Will of the Forsaken",
    ["BloodElf"] = "Arcane Torrent",
}

local function getSpellIndex(name, rank)
    name = string.lower(name)
    if rank and rank ~= "" then
        name = name .. rank
    end

    return name
end

local function getRacialAbility()
	local playerRace = select(2, UnitRace("player"))
    if not RacialAbilities[playerRace] then
        debug(string.format("unknown race: %s", playerRace))
        return nil
    end

    debug(string.format("get race spell: %s", RacialAbilities[playerRace]))
    return SpellBookCache[getSpellIndex(RacialAbilities[playerRace], RACE_TAG)]
end

function Spells:Save(type, bookIndex)
	if type ~= SPELL_TAG then
		return nil
	end

	if bookIndex <= 0 then
        debug(string.format("unknown spell: index - %s", bookIndex))
		return nil
	end

    local spellName, spellRank = GetSpellInfo(bookIndex, BOOKTYPE_SPELL)
    if spellName == nil then
        debug(string.format("unknown spell: index - %s", bookIndex))
        return nil
    end

    return { type, spellName, spellRank or "" }
end

function Spells:Restore(actionId, ...)
	debug(string.format("restore action: index - %s", actionId))

	local type, spellName, spellRank = ...
	if type ~= SPELL_TAG then
        debug("restore action not spell")
		return
	end

    spellName = string.lower(spellName)
    local spellIndex = getSpellIndex(spellName, spellRank)
    local bookIndex = SpellBookCache[spellIndex]
    if not bookIndex or bookIndex <= 0 then
        if endswith(spellIndex, RACE_TAG) then
            bookIndex = getRacialAbility()
        end

        if not bookIndex or bookIndex <= 0 then
            debug(string.format("unknown spell: %s (%s)", spellName, spellRank))
            return
        end
    end

    debug(string.format("pickup action: index - %s, %s (%s)", actionId, spellName, spellRank))
    PickupSpell(bookIndex, BOOKTYPE_SPELL)
    PlaceAction (actionId)
    debug(string.format("place action: index - %s", actionId))
end

function Spells:Init()
	local totalTabs = GetNumSpellTabs()
	debug(string.format("start caching: spellbook tabs - %s", totalTabs))

	wipe(SpellBookCache)

	for bookTabId = 1, totalTabs do
		local tabName, _, offset, numSlots = GetSpellTabInfo(bookTabId)
		debug(string.format("caching tab: %s [%s]", tabName, numSlots))

		for bookIndex = offset + 1, offset + numSlots do
			local spellName, spellRank = GetSpellInfo(bookIndex, BOOKTYPE_SPELL)

            if spellName == nil then
                debug(string.format("unknown spell: index - %s", bookIndex))
            else
                SpellBookCache[getSpellIndex(spellName, spellRank)] = bookIndex

                debug(string.format("append: %s (%s)", spellName, spellRank))
            end
		end
	end

	debug("end caching")
end
