local ADDON_NAME, Addon = ...

-- Count tracked items present in bags (all stacks)
function Addon:CountTrackedInBagsSelected()
    local total = 0
    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots or 0 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and self:IsTracked(id) and self:IsAllowed(id) then
                local info = C_Container.GetContainerItemInfo(bag, slot)
                total = total + ((info and info.stackCount) or 1)
            end
        end
    end
    return total
end

-- Return distinct tracked+enabled IDs present in bags (dedup by ID), unsorted
function Addon:CollectTrackedIDsInBags(limit)
    limit = limit or 30
    local seen, ids = {}, {}
    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots or 0 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and not seen[id] and self:IsTracked(id) and self:IsAllowed(id) then
                local tog = self:GetItemToggles(id)
                if tog.open then
                    ids[#ids+1] = id
                    seen[id] = true
                    if #ids >= limit then return ids end
                end
            end
        end
    end
    return ids
end
