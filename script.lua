


dofile(path .. "/classes/blueprint.lua")
dofile(path .. "/BetterLog.lua")
dofile(path .. "/savedBlueprints.lua")
dofile(path .. "/hudManager.lua")
dofile("scripts/forts.lua")

AssignedNodeIds =
{

}
-- this function assumes that at least one node in the order exists




BlueprintTemplate = {
    meta = {
        minX = 0,
        minY = 0,
        maxX = 0,
        maxY = 0,
        totalCost = {
            metal = 0,
            energy = 0
        },
        structureCost = {
            metal = 0,
            energy = 0
        },
        deviceCost = {
            metal = 0,
            energy = 0
        }
    },
    nodeMesh = {},
    devices = {},
}




-- Construction algorithim, comment out the recording algorithm to use this one

RootPos = {x = 0, y = 0}

--Recording algorithm, comment out the construction algorithm to use this one
local ran = false
-- function OnNodeCreated(nodeId, teamId, pos, foundation, selectable, extrusion)
--     if not ran then RootPos = pos end
--     ran = true
--     local newNode = {
--         relativePos = {x = pos.x - RootPos.x, y = pos.y - RootPos.y},
--         linkedTo = {

--         }
--     }
--     AssignedNodeIds[nodeId] = #NewBlueprint.nodeMesh + 1
--     NewBlueprint.nodeMesh[#NewBlueprint.nodeMesh + 1] = newNode
    
-- end

function OnNodeDestroyed(nodeId, selectable)

    if AssignedNodeIds[nodeId] then
        local id = AssignedNodeIds[nodeId]
        AssignedNodeIds[nodeId] = nil
        BlueprintTemplate.nodeMesh[id] = nil
        -- Iterate through and reduce by one all the ids that are greater than the one that was destroyed
        for k, v in pairs(AssignedNodeIds) do
            if v > id then
                AssignedNodeIds[k] = v - 1
            end
        end
        for k, v in pairs(BlueprintTemplate.nodeMesh) do
            if k > id then
                BlueprintTemplate.nodeMesh[k - 1] = v
                BlueprintTemplate.nodeMesh[k] = nil
            end
            local linkedToCopy = DeepCopy(v.linkedTo)
            for linkedNodeId, material in pairs(linkedToCopy) do
                if linkedNodeId == id then 
                    v.linkedTo[linkedNodeId] = nil
                end
                if linkedNodeId > id then

                    v.linkedTo[linkedNodeId] = nil
                    v.linkedTo[linkedNodeId - 1] = material
                end
            end
        end
    end
end

function OnLinkCreated(teamId, saveName, nodeA, nodeB, pos1, pos2, extrusion)
    local idA = AssignedNodeIds[nodeA]
    local idB = AssignedNodeIds[nodeB]
    
    if idA and idB then
        BlueprintTemplate.nodeMesh[idA].linkedTo[idB] = saveName
        BlueprintTemplate.nodeMesh[idB].linkedTo[idA] = saveName
        local cost = GetLinkCost(nodeA, pos2, saveName, false)
        local structureCost = BlueprintTemplate.meta.structureCost
        local totalCost = BlueprintTemplate.meta.totalCost
        structureCost.metal = structureCost.metal + cost.metal
        structureCost.energy = structureCost.energy + cost.energy
        totalCost.metal = totalCost.metal + cost.metal
        totalCost.energy = totalCost.energy + cost.energy
    end

end

function OnLinkDestroyed(teamId, saveName, nodeA, nodeB, breakType)
    local idA = AssignedNodeIds[nodeA]
    local idB = AssignedNodeIds[nodeB]
    if idA and idB then
        BlueprintTemplate.nodeMesh[idA].linkedTo[idB] = nil
        BlueprintTemplate.nodeMesh[idB].linkedTo[idA] = nil
        local cost = GetLinkCost(nodeA, pos2, saveName, false)
        local structureCost = BlueprintTemplate.meta.structureCost
        local totalCost = BlueprintTemplate.meta.totalCost
        structureCost.metal = structureCost.metal - cost.metal
        structureCost.energy = structureCost.energy - cost.energy
        totalCost.metal = totalCost.metal - cost.metal
        totalCost.energy = totalCost.energy - cost.energy
    end

end

function OnDeviceCreated(teamId, deviceId, saveName, nodeA, nodeB, t, upgradedId)
    local idA = AssignedNodeIds[nodeA]
    local idB = AssignedNodeIds[nodeB]
    if idA and idB then
        BlueprintTemplate.devices[#BlueprintTemplate.devices + 1] = {idA = idA, idB = idB, saveName = saveName, t = t}
        local cost = GetDeviceCost(saveName)
        local deviceCost = BlueprintTemplate.meta.deviceCost
        local totalCost = BlueprintTemplate.meta.totalCost
        deviceCost.metal = deviceCost.metal + cost.metal
        deviceCost.energy = deviceCost.energy + cost.energy
        totalCost.metal = totalCost.metal + cost.metal
        totalCost.energy = totalCost.energy + cost.energy
    end

end

function OnDeviceDeleted(teamId, deviceId, saveName, nodeA, nodeB, t)

    for i = 1, #BlueprintTemplate.devices do
        if BlueprintTemplate.devices[i].idA == nodeA and BlueprintTemplate.devices[i].idB == nodeB then
            table.remove(BlueprintTemplate.devices, i)
            local cost = GetDeviceCost(saveName)
            local deviceCost = BlueprintTemplate.meta.deviceCost
            local totalCost = BlueprintTemplate.meta.totalCost
            deviceCost.metal = deviceCost.metal - cost.metal
            deviceCost.energy = deviceCost.energy - cost.energy
            totalCost.metal = totalCost.metal - cost.metal
            totalCost.energy = totalCost.energy - cost.energy
            break
        end
    end


end


function Load()
    SetControlFrame(0)
    LoadControl(path .. "/selectionui.lua", "")
end


function OnKey(key, down)
    if key == "k" and down then
        local minX = 0
        local minY = 0
        local maxX = 0
        local maxY = 0
        for k, v in pairs(BlueprintTemplate.nodeMesh) do
            if v.relativePos.x < minX then
                minX = v.relativePos.x
            end
            if v.relativePos.y < minY then
                minY = v.relativePos.y
            end
            if v.relativePos.x > maxX then
                maxX = v.relativePos.x
            end
            if v.relativePos.y > maxY then
                maxY = v.relativePos.y
            end
        end
        BlueprintTemplate.meta.minX = minX
        BlueprintTemplate.meta.minY = minY
        BlueprintTemplate.meta.maxX = maxX
        BlueprintTemplate.meta.maxY = maxY

        BetterLog(BlueprintTemplate)
    end
    if key == "l" and down then
        Preview = true
    end
    if key == "l" and not down then
        Preview = false
        local teamId = GetLocalTeamId()
        local pos = ScreenToWorld(GetMousePos())
        local blueprint = Blueprint:New(pos, teamId, CurrentBlueprint, false) -- Change to set which structure to build

        if type(blueprint) == "number" then
            BetterLog("Error: Blueprint failure: " .. Blueprint.FailureCodeToString[blueprint])
        end
    end

end
Preview = false
CurrentBlueprint = SavedBlueprints.Car2
function Update(frame)

    
    if Preview then 
        local teamId = GetLocalTeamId()
        local pos = ScreenToWorld(GetMousePos())

        Blueprint:Touch(pos, teamId, CurrentBlueprint, false)
    end
    Blueprint:Update(frame)
end


function ClearTable(t)
    for k, v in pairs(t) do
        t[k] = nil
    end
end

function GetPositionIsFoundation(pos, teamId, dummyNode)
    local pos = {x = pos.x, y = pos.y + 1}
    EnableMaterial("FoundationTest", true, teamId % MAX_SIDES)
    local result = CreateNode(teamId, "FoundationTest", dummyNode, pos)
    EnableMaterial( "FoundationTest", false, teamId % MAX_SIDES)
    DestroyLink(teamId, dummyNode, result)
    return result > 0
end

function OnControlActivated(name, code, doubleClick)

    if name == BlueprintConfig.stopButtonName then
        Blueprint:ConfirmStopBPWithId(code)
    end
    if name == BlueprintConfig.confirmStopButtonName then
        Blueprint:StopBPWithId(code)
    end
    if name == BlueprintConfig.cancelStopButtonName then
        Blueprint:CancelStopBPWithId(code)
    end
    if name == BlueprintConfig.pauseButtonName then
        Blueprint:TogglePauseWithId(code)
    end
end



