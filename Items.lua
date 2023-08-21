Items = Items or {}

local ITEM_TAG = "item"

function Items:Save(type, itemID)
	if type ~= ITEM_TAG then
		return nil
	end

	if itemID <= 0 then
        debug(string.format("unknown item: index - %s", itemID))
		return nil
	end

    local itemName = GetItemInfo(itemID)
    if itemName == nil then
        debug(string.format("not found item: index - %s", itemID))
		return nil
    end

    return { type, itemID, itemName }
end

function Items:Load(actionId, ...)
	debug(string.format("restore action: index - %s", actionId))

	local type, itemID, itemName = ...
	if type ~= ITEM_TAG then
        debug("restore action not item")
		return
	end

    debug(string.format("pickup action: index - %s, %s (%s)", actionId, itemName, itemID))
    PickupItem(itemID)
    PlaceAction (actionId)
    debug(string.format("place action: index - %s", actionId))
end

function Items:Recached()
	debug("skipped caching: items")
end