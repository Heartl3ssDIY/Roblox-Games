local ArenaCatalog = {}

ArenaCatalog.ordered = {
    {number = 1, key = "Tenkaichi", displayName = "Tenkaichi", modelName = "Arena_Tenkaichi", description = "Fight beneath tropical skies at the Tenkaichi martial arts tournament. Draft your team and take the ring.", matchReady = true, teleportReady = true},
    {number = 2, key = "ChuninExamHall", displayName = "Chūnin Exam Hall", modelName = "Arena_ChuninExamHall", description = "Fight in the enclosed examination hall beneath its towering balconies.", matchReady = false, teleportReady = true},
    {number = 3, key = "Loguetown", displayName = "Loguetown", modelName = "Arena_Loguetown", description = "Battle in Loguetown's open town square beneath the execution platform.", matchReady = false, teleportReady = true},
    {number = 4, key = "JujutsuHigh", displayName = "Jujutsu High", modelName = "Arena_JujutsuHigh", description = "Train in the open courtyard surrounded by tiled halls, a pagoda and trees.", matchReady = false, teleportReady = true},
    {number = 5, key = "Fujikasane", displayName = "Mount Fujikasane", modelName = "Arena_Fujikasane", description = "Face your opponent between the red pillars beneath purple wisteria.", matchReady = false, teleportReady = true},
    {number = 6, key = "HeavensArena", displayName = "Heavens Arena", modelName = "Arena_HeavensArena", description = "Step onto the fighting floor surrounded by the stadium stands.", matchReady = false, teleportReady = true},
    {number = 7, key = "HyperbolicTimeChamber", displayName = "Hyperbolic Time Chamber", modelName = "Arena_HyperbolicTimeChamber", description = "Battle across the white expanse in front of the chamber's golden hall.", matchReady = false, teleportReady = true},
    {number = 8, key = "Wano", displayName = "Wano", modelName = "Arena_Wano", description = "Fight along the Flower Capital street beneath the castle and cherry blossoms.", matchReady = false, teleportReady = true},
    {number = 9, key = "Marineford", displayName = "Marineford", modelName = "Arena_Marineford", description = "Take the frozen bay, framed by Marineford's fortress and harbour walls.", matchReady = false, teleportReady = true},
}

function ArenaCatalog.get(index)
    return ArenaCatalog.ordered[index]
end

function ArenaCatalog.count()
    return #ArenaCatalog.ordered
end

function ArenaCatalog.find(value)
    if type(value) == "number" then return ArenaCatalog.get(value) end
    for _, arena in ipairs(ArenaCatalog.ordered) do
        if value == arena.key or value == arena.modelName then return arena end
    end
    return nil
end

return ArenaCatalog

