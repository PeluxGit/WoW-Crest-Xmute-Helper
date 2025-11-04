-- bags.lua
-- Helpers for scanning the player's bags for tracked items
local ADDON_NAME, Addon = ...

-- Count tracked items present in bags (all stacks)
-- Returns the total quantity across all stacks for items that are both tracked and allowed
function Addon:CountTrackedInBagsSelected()
    local total = 0
    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots and slots > 0 then
            for slot = 1, slots do
                local id = C_Container.GetContainerItemID(bag, slot)
                if id and self:IsTracked(id) and self:IsAllowed(id) then
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    -- Validate info exists before accessing stackCount
                    if info then
                        total = total + (info.stackCount or 1)
                    end
                end
            end
        end
    end
    return total
end

-- Return distinct tracked+enabled IDs present in bags (dedup by ID), unsorted
-- limit: stops after collecting up to this many distinct IDs (default 30)
function Addon:CollectTrackedIDsInBags(limit)
    limit = limit or 30
    local seen, ids = {}, {}
    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots and slots > 0 then
            for slot = 1, slots do
                local id = C_Container.GetContainerItemID(bag, slot)
                if id and not seen[id] and self:IsTracked(id) and self:IsAllowed(id) then
                    local tog = self:GetItemToggles(id)
                    if tog.open then
                        ids[#ids + 1] = id
                        seen[id] = true
                        if #ids >= limit then return ids end
                    end
                end
            end
        end
    end
    return ids
end
