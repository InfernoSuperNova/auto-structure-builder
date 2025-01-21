--virtual nodes, already sorted into order of placement


dofile(path .. "/classes/blueprint.lua")
dofile(path .. "/BetterLog.lua")
dofile(path .. "/savedBlueprints.lua")
dofile("scripts/forts.lua")

AssignedNodeIds =
{

}
-- this function assumes that at least one node in the order exists




NewBlueprint = {
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
        NewBlueprint.nodeMesh[id] = nil
        -- Iterate through and reduce by one all the ids that are greater than the one that was destroyed
        for k, v in pairs(AssignedNodeIds) do
            if v > id then
                AssignedNodeIds[k] = v - 1
            end
        end
        for k, v in pairs(NewBlueprint.nodeMesh) do
            if k > id then
                NewBlueprint.nodeMesh[k - 1] = v
                NewBlueprint.nodeMesh[k] = nil
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
        NewBlueprint.nodeMesh[idA].linkedTo[idB] = saveName
        NewBlueprint.nodeMesh[idB].linkedTo[idA] = saveName
    end
end

function OnLinkDestroyed(teamId, saveName, nodeA, nodeB, breakType)
    local idA = AssignedNodeIds[nodeA]
    local idB = AssignedNodeIds[nodeB]
    if idA and idB then
        NewBlueprint.nodeMesh[idA].linkedTo[idB] = nil
        NewBlueprint.nodeMesh[idB].linkedTo[idA] = nil
    end
end

function OnDeviceCreated(teamId, deviceId, saveName, nodeA, nodeB, t, upgradedId)
    local idA = AssignedNodeIds[nodeA]
    local idB = AssignedNodeIds[nodeB]
    if idA and idB then
        NewBlueprint.devices[#NewBlueprint.devices + 1] = {idA = idA, idB = idB, saveName = saveName, t = t}
    end
end




function OnKey(key, down)
    if key == "k" and down then
        BetterLog(NewBlueprint)
    end
    if key == "l" and down then
        Preview = true
    end
    if key == "l" and not down then
        Preview = false
        local teamId = GetLocalTeamId()
        local pos = ScreenToWorld(GetMousePos())
        local blueprint = Blueprint:New(pos, teamId, CurrentBlueprint, false) -- Change to set which structure to build
    end

end
Preview = false
CurrentBlueprint = Car2
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
    EnableMaterial("StructuralAluminiumHazard", true, teamId % MAX_SIDES)
    local result = CreateNode(teamId, "StructuralAluminiumHazard", dummyNode, pos)
    EnableMaterial( "StructuralAluminiumHazard", false, teamId % MAX_SIDES)
    DestroyLink(teamId, dummyNode, result)
    return result > 0
end


