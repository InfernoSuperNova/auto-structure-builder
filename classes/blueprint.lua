BlueprintConfig = {
    SupportHorizontalAttachSpacing = 200,
    SupportFoundationWidth = 75,
    SupportMaxFoundationHeightDisplacement = 100, -- this with the width will determine the max angle of the support, in this case 45 degrees
    SupportMaxSegmentLength = 150,
    SupportStructureMinSegmentLength = 100,
    SupportStructureMinDotToBranch = 0.7,
    SupportStructureMaterial = "StructuralAluminiumHazard",
    MaxNodeDelegateDistance = 150,
    NodeDelegateVerticalOffset = 100,
    MaxHeight = 2000,
    SupportCorrectionForce = 100000,
    MaxAttemptsToBuildDevice = 15,
    DeviceRebuildTickDelay = 25,
    MaxAttemptsToBuildLink = 15,

    stopButtonName = "structure-builder-stop",
    confirmStopButtonName = "structure-builder-confirm-stop",
    cancelStopButtonName = "structure-builder-cancel-stop",
    pauseButtonName = "structure-builder-pause",
}
--- TODO
--- Fail condition (>50% fail) (Necessary?)
--- Side bracing (not necessary now?)
--- Maybe add effect when scaffolding is destroyed? (Cosmetic)
--- Make foundation test material a separate, silent material (not possible?)
--- Synchronize blueprint creation for multiplayer
--- Synchronize blueprint cancellation for multiplayer
--- Synchronize pausing/resuming for multiplayer


Blueprint = {
    Blueprints = {},
    BlueprintsSwap = {},
    IdIterator = 0,
    MasterControl = "bpRoot"
}

function Blueprint:Load()
    AddTextControl("", self.MasterControl, "", ANCHOR_TOP_LEFT, {x = 0, y = 0}, false, "normal")
end

function Blueprint:New(pos, teamId, bp, mirror)



    -- Temporary pls remove
    local minX = math.huge
    local minY = math.huge
    local maxX = -math.huge
    local maxY = -math.huge
    for i = 1, #bp.nodeMesh do
        local node = bp.nodeMesh[i]
        if node.relativePos.x < minX then minX = node.relativePos.x end
        if node.relativePos.y < minY then minY = node.relativePos.y end
        if node.relativePos.x > maxX then maxX = node.relativePos.x end
        if node.relativePos.y > maxY then maxY = node.relativePos.y end
    end
    BetterLog( {
        minX = minX,
        minY = minY,
        maxX = maxX,
        maxY = maxY
    })

    
    bp = DeepCopy(bp)
    local blueprint = {
        id = Blueprint.IdIterator,
        pos = pos,
        teamId = teamId,
        nodeMesh = bp.nodeMesh,
        meta = bp.meta,
        devices = bp.devices,
        assignedNodeIds = {},
        assignedDeviceIds = {},
        delegateNodes = {},
        deviceCost = {metal = 0, energy = 0},
        structureCost = {metal = 0, energy = 0},
        totalCost = {metal = 0, energy = 0},
        mirror = mirror and -1 or 1,
        testNode = SnapToWorld(pos, 2000, SNAP_NODES, teamId, -1, "").NodeIdA

    }
    Blueprint.IdIterator = Blueprint.IdIterator + 1
    setmetatable(blueprint, { __index = BlueprintMetaTable })
    

    local collisionTestResult = blueprint:CheckBlueprintAreaForIntersections()
    if collisionTestResult ~= 0 then 
        return collisionTestResult 
        end
    local bpCollisionTestResult, otherBp = self:CheckNewBlueprintCollidesWithExistingBlueprints(blueprint)
    if bpCollisionTestResult ~= 0 then 
        return bpCollisionTestResult 
    end
   

    blueprint:HighlightHullNodes(White(), 0.06)
    local result = blueprint:GenerateSupportStructure()
    if not result then return Blueprint.FailureCodes.NoFoundationsInRange end
    blueprint:HighlightBorderAndSave()
    blueprint:AddUIElements()

    self.Blueprints[#self.Blueprints + 1] = blueprint
    blueprint:CreateStarterNodes()
    return blueprint
end

function Blueprint:Touch(pos, teamId, bp, mirror)
    bp = DeepCopy(bp)
    local blueprint = {
        pos = pos,
        teamId = teamId,
        nodeMesh = bp.nodeMesh,
        meta = bp.meta,
        devices = bp.devices,
        assignedNodeIds = {},
        assignedDeviceIds = {},
        deviceFailureCount = {},
        devicePendingRebuild = {},
        linkFailureCount = {},
        delegateNodes = {},
        deviceCost = {metal = 0, energy = 0},
        structureCost = {metal = 0, energy = 0},
        totalCost = {metal = 0, energy = 0},
        mirror = mirror and -1 or 1,
        testNode = SnapToWorld(pos, 2000, SNAP_NODES, teamId, -1, "").NodeIdA
    }
    setmetatable(blueprint, { __index = BlueprintMetaTable })
    
    
   
    

    local collisionTestResult = blueprint:CheckBlueprintAreaForIntersections()
    local bpCollisionTestResult, otherBp = self:CheckNewBlueprintCollidesWithExistingBlueprints(blueprint)
    local supportResult = blueprint:GenerateSupportStructure(true)
    if collisionTestResult ~= 0 then 
        blueprint:HighlightExtents(Red(), 0.06)
        blueprint:HighlightHullNodes(Red(), 0.06)
    elseif bpCollisionTestResult ~= 0 then 
        blueprint:HighlightExtents(Red(), 0.06)
        otherBp:HighlightExtents(Red(), 0.06)
        blueprint:HighlightHullNodes(Red(), 0.06)
    elseif not supportResult then
        blueprint:HighlightHullNodes(Red(), 0.06)
    else
        blueprint:HighlightHullNodes(White(), 0.06)
    end


    return blueprint
end
function Blueprint:Update(frame)
    SetControlFrame(0)
    for i = 1, #self.Blueprints do
        local blueprint = self.Blueprints[i]
        blueprint:Update()
    end

    for k = 1, 1 do
        if frame % 5 == 0 then
            for i = 1, #self.Blueprints do
                local blueprint = self.Blueprints[i]
                if blueprint.paused then
                    self.BlueprintsSwap[#self.BlueprintsSwap + 1] = blueprint
                    continue
                end
                local code = blueprint:TryBuild()
                Log("Code: "..self.ReturnCodeToString[code])
                if not blueprint.queueStop and (code == self.ReturnCodes.Working or code == self.ReturnCodes.Waiting or code == self.ReturnCodes.WaitingForResources or code == self.ReturnCodes.WaitingForTechnology or code == self.ReturnCodes.WaitingForDeviceConstruction) then
                    self.BlueprintsSwap[#self.BlueprintsSwap + 1] = blueprint
                elseif code == self.ReturnCodes.Done then
                    BetterLog(blueprint.deviceCost)
                    BetterLog(blueprint.structureCost)
                    BetterLog(blueprint.totalCost)
                    blueprint:Cleanup()
                end
            end
            ClearTable(self.Blueprints)
            local temp = self.Blueprints
            self.Blueprints = self.BlueprintsSwap
            self.BlueprintsSwap = temp
        end
    end
    
    
end
function Blueprint:ConfirmStopBPWithId(id)
    for i = 1, #self.Blueprints do
        local blueprint = self.Blueprints[i]
        if blueprint.id == id then
            blueprint:StopConfirmQuery()
            return
        end
    end
end
function Blueprint:CancelStopBPWithId(id)
    for i = 1, #self.Blueprints do
        local blueprint = self.Blueprints[i]
        if blueprint.id == id then
            blueprint:StopCancel()
            return
        end
    end
end
function Blueprint:StopBPWithId(id)
    for i = 1, #self.Blueprints do
        local blueprint = self.Blueprints[i]
        if blueprint.id == id then
            blueprint:Stop()
            return
        end
    end
end

function Blueprint:TogglePauseWithId(id)
    for i = 1, #self.Blueprints do
        local blueprint = self.Blueprints[i]
        if blueprint.id == id then
            blueprint:TogglePause()
            return
        end
    end
end
function Blueprint:CheckNewBlueprintCollidesWithExistingBlueprints(blueprint)
    for _, existingBlueprint in pairs(self.Blueprints) do
        if self:CheckTwoBlueprintsColliding(blueprint, existingBlueprint) then
            return self.FailureCodes.IntersectsExistingBlueprint, existingBlueprint
        end
    end
    return 0
end 


function Blueprint:CheckTwoBlueprintsColliding(blueprint1, blueprint2)
    local bp1Dimensions = blueprint1.meta
    local bp2Dimensions = blueprint2.meta

    local bp1MinX = bp1Dimensions.minX + blueprint1.pos.x
    local bp1MinY = bp1Dimensions.minY + blueprint1.pos.y
    local bp1MaxX = bp1Dimensions.maxX + blueprint1.pos.x
    local bp1MaxY = bp1Dimensions.maxY + blueprint1.pos.y

    local bp2MinX = bp2Dimensions.minX + blueprint2.pos.x
    local bp2MinY = bp2Dimensions.minY + blueprint2.pos.y
    local bp2MaxX = bp2Dimensions.maxX + blueprint2.pos.x
    local bp2MaxY = bp2Dimensions.maxY + blueprint2.pos.y

    if bp1MinX > bp2MaxX or bp1MaxX < bp2MinX or bp1MinY > bp2MaxY or bp1MaxY < bp2MinY then
        return false
    end
    return true
end

BlueprintMetaTable = {
    pos = { x = 0, y = 0 },
    teamId = 1,
    nodeMesh = {},
    assignedNodeIds = {},
    meta = {},
    devices = {},
    assignedDeviceIds = {},
    deviceFailureCount = {},
    devicePendingRebuild = {},
    linkFailureCount = {},
    delegateNodes = {},
    deviceCost = {metal = 0, energy = 0},
    structureCost = {metal = 0, energy = 0},
    totalCost = {metal = 0, energy = 0},
    mirror = 1,
    testNode = 0,
    id = 0,
    paused = false
}

Blueprint.ReturnCodes = {
    Working = 0,
    Waiting = 1,
    Done = 2,
    Failed = 3,
    WaitingForTechnology = 4,
    WaitingForResources = 5,
    WaitingForDeviceConstruction = 6
}
Blueprint.ReturnCodeToString = {
    [Blueprint.ReturnCodes.Working] = "Working",
    [Blueprint.ReturnCodes.Waiting] = "Waiting",
    [Blueprint.ReturnCodes.Done] = "Done",
    [Blueprint.ReturnCodes.Failed] = "Failed",
    [Blueprint.ReturnCodes.WaitingForTechnology] = "WaitingForTechnology",
    [Blueprint.ReturnCodes.WaitingForResources] = "WaitingForResources",
    [Blueprint.ReturnCodes.WaitingForDeviceConstruction] = "WaitingForDeviceConstruction"
}
Blueprint.FailureCodes = {
    NoFoundationsInRange = 0,
    IntersectsTerrain = 1,
    OutsideOfMap = 2,
    IntersectsExistingStructure = 3,
    IntersectsExistingBlueprint = 4
}
Blueprint.FailureCodeToString = {
    [Blueprint.FailureCodes.NoFoundationsInRange] = "NoFoundationsInRange",
    [Blueprint.FailureCodes.IntersectsTerrain] = "IntersectsTerrain",
    [Blueprint.FailureCodes.OutsideOfMap] = "OutsideOfMap",
    [Blueprint.FailureCodes.IntersectsExistingStructure] = "IntersectsExistingStructure",
    [Blueprint.FailureCodes.IntersectsExistingBlueprint] = "IntersectsExistingBlueprint"
}

function BlueprintMetaTable:TryBuild()
    local code = Blueprint.ReturnCodes.Waiting
    local deviceAttemptBuild = false
    local deviceBuilt = false
    local nodeAttemptedBuild = false
    local nodeBuilt = false
    local linkAttemptedBuild = false
    local linkBuilt = false
    for deviceIndex = 1, #self.devices do
        local device = self.devices[deviceIndex]
        local deviceId = self.assignedDeviceIds[deviceIndex]
        if (not deviceId or not DeviceExists(deviceId)) and deviceId ~= -1 then




            -- Grace period before rebuilding
            if deviceId and not self.devicePendingRebuild[deviceIndex] then
                self.devicePendingRebuild[deviceIndex] = 0
                continue
            elseif self.devicePendingRebuild[deviceIndex] then
                self.devicePendingRebuild[deviceIndex] = self.devicePendingRebuild[deviceIndex] + 1
                if self.devicePendingRebuild[deviceIndex] > BlueprintConfig.DeviceRebuildTickDelay then
                    self.devicePendingRebuild[deviceIndex] = nil
                else
                    continue
                end
            end

            local targetNodeIdA = self.assignedNodeIds[device.idA]
            local targetNodeIdB = self.assignedNodeIds[device.idB]
           

            if targetNodeIdA and targetNodeIdB and NodeExists(targetNodeIdA) and NodeExists(targetNodeIdB) then
                local id = GetDeviceIdOnPlatform(targetNodeIdA, targetNodeIdB)
                if id ~= -1 then 
                    self.assignedDeviceIds[deviceIndex] = id
                    continue 
                    end
                local newDeviceId
                if self.mirror == 1 then
                    newDeviceId = CreateDeviceWithFlags(self.teamId, device.saveName, targetNodeIdA, targetNodeIdB, device.t, CREATEDEVICEFLAG_PANANGLERIGHT, -1)
                else
                    newDeviceId = CreateDeviceWithFlags(self.teamId, device.saveName, targetNodeIdB, targetNodeIdA, 1 - device.t, CREATEDEVICEFLAG_PANANGLELEFT, -1)
                end
                SpawnLine(NodePosition(targetNodeIdA), NodePosition(targetNodeIdB), Red(), 0.06)
                if newDeviceId < 0 then
                    local errorCode = newDeviceId
                    deviceAttemptBuild = true
                    if not self.deviceFailureCount[deviceIndex] then
                        self.deviceFailureCount[deviceIndex] = 1
                    elseif errorCode == CD_PREREQUISITENOTMET then
                        -- tchnology hasn't been placed
                        code = Blueprint.ReturnCodes.WaitingForTechnology
                    elseif errorCode == CD_PREREQUISITECONSTRUCT then
                        -- technology is building
                        code = Blueprint.ReturnCodes.WaitingForTechnology
                    elseif errorCode == CD_PLATFORMCONSTRUCTION then
                        -- waiting for platform to be built
                    elseif errorCode == CD_INSUFFICIENTRESOURCES then
                        code = Blueprint.ReturnCodes.WaitingForResources
                    elseif errorCode == CD_OBSTRUCTION then 
                        self.deviceFailureCount[deviceIndex] = self.deviceFailureCount[deviceIndex] + 1
                    else
                    end
                    if self.deviceFailureCount[deviceIndex] > BlueprintConfig.MaxAttemptsToBuildDevice then
                        self.assignedDeviceIds[deviceIndex] = -1
                    end
                    continue
                else
                    deviceAttemptBuild = true
                    deviceBuilt = true
                    
                    self.assignedDeviceIds[deviceIndex] = newDeviceId
                    local cost = GetDeviceCost(device.saveName)
                    self.totalCost.metal = self.totalCost.metal + cost.metal
                    self.totalCost.energy = self.totalCost.energy + cost.energy
                    self.deviceCost.metal = self.deviceCost.metal + cost.metal
                    self.deviceCost.energy = self.deviceCost.energy + cost.energy
                    break
                end
            end
            
        end
    end

    -- Create nodes and links
    for nodeIndex = 1, #self.nodeMesh do
        local nodeId = self.assignedNodeIds[nodeIndex]
        if not nodeId or not NodeExists(nodeId) or not NodeTeam(nodeId) == self.teamId then continue end
        local node = self.nodeMesh[nodeIndex]
        local linkSuccess = self:LinkAllPossibleNodes(node, nodeId, nodeIndex) -- will build as many links as possible for this node
        if linkSuccess == 0 then -- no links to build
        
        elseif linkSuccess == 1 then    -- attempted to build a link but failed
            linkAttemptedBuild = true
            continue
        elseif linkSuccess == 2 then    -- Ran out of resources
            linkAttemptedBuild = true    
            code = Blueprint.ReturnCodes.WaitingForResources
            continue
        elseif linkSuccess == 3 then    -- Successfully built a link
            linkAttemptedBuild = true
            linkBuilt = true
            break
        end
        local nodeSuccess = self:CreateAttachedNode(node, nodeId) -- will build a single attached node of the lowest index, only if there were no links made this tick
        if nodeSuccess == 0 then

        elseif nodeSuccess == 1 then
            nodeAttemptedBuild = true
            continue
        elseif nodeSuccess == 2 then
            nodeAttemptedBuild = true
            nodeBuilt = true
            break
        end
    end
    if not nodeBuilt and not linkBuilt and not deviceBuilt then
    else
        code = Blueprint.ReturnCodes.Working
    end
    if not nodeAttemptedBuild and not linkAttemptedBuild and not deviceAttemptBuild then
        code = Blueprint.ReturnCodes.Done
        local allDevicesDone = true
        for i = 1, #self.devices do
            local deviceId = self.assignedDeviceIds[i]
            if deviceId == -1 then continue end
            local deviceDone = IsDeviceFullyBuilt(deviceId)
            if not deviceDone then
                allDevicesDone = false
                break
            end
        end
        if not allDevicesDone then
            code = Blueprint.ReturnCodes.WaitingForDeviceConstruction
        end
    end
    
   

    return code
end

function BlueprintMetaTable:Update()
    for i = 1, #self.nodeMesh do
        local node = self.nodeMesh[i]
        local nodeId = self.assignedNodeIds[i]

        if node.final and nodeId then
            local desiredWorldPos = node.pos
            local currentWorldPos = NodePosition(nodeId)
            local desiredToCurrent = {x = desiredWorldPos.x - currentWorldPos.x, y = desiredWorldPos.y - currentWorldPos.y}
            desiredToCurrent.x = desiredToCurrent.x * BlueprintConfig.SupportCorrectionForce
            desiredToCurrent.y = desiredToCurrent.y * BlueprintConfig.SupportCorrectionForce
            dlc2_ApplyForce(nodeId, desiredToCurrent)
            SpawnLine(currentWorldPos, desiredWorldPos, Green(), 0.06)
        end
    end
    self:UpdateUIElements()
end

function BlueprintMetaTable:Cleanup()
    for i = 1, #self.nodeMesh do
        local node = self.nodeMesh[i]
        local nodeId = self.assignedNodeIds[i]
        if node.support and nodeId and NodeExists(nodeId) then
            DestroyProjectile(nodeId)
        end
    end


    for i = 1, #self.delegateNodes do
        DestroyProjectile(self.delegateNodes[i])
    end
    DeleteControl("HUD", self.controlName)
    CancelEffect(self.lineA)
    CancelEffect(self.lineB)
    CancelEffect(self.lineC)
    CancelEffect(self.lineD)
end

function BlueprintMetaTable:StopConfirmQuery()
    SetControlFrame(0)

    ShowControl(self.controlName, BlueprintConfig.stopButtonName, false)
    ShowControl(self.controlName, BlueprintConfig.confirmStopButtonName, true)
    ShowControl(self.controlName, BlueprintConfig.cancelStopButtonName, true)
end

function BlueprintMetaTable:StopCancel()
    SetControlFrame(0)

    ShowControl(self.controlName, BlueprintConfig.stopButtonName, true)
    ShowControl(self.controlName, BlueprintConfig.confirmStopButtonName, false)
    ShowControl(self.controlName, BlueprintConfig.cancelStopButtonName, false)
end

function BlueprintMetaTable:Stop()

    SetControlFrame(0)
    DeleteControl("HUD", self.controlName)
    CancelEffect(self.lineA)
    CancelEffect(self.lineB)
    CancelEffect(self.lineC)
    CancelEffect(self.lineD)
    self.queueStop = true
end

function BlueprintMetaTable:TogglePause()
    SetControlFrame(0)
    self.paused = not self.paused
    if self.paused then
        SetControlText(self.controlName, BlueprintConfig.pauseButtonName, "Resume")
    else
        SetControlText(self.controlName, BlueprintConfig.pauseButtonName, "Pause")
    end
end

function BlueprintMetaTable:LinkAllPossibleNodes(node, nodeId, nodeIndex)
    if not nodeId or not NodeExists(nodeId) or not NodeTeam(nodeId) == self.teamId then return end


    local linkSuccess = 0
    if not self.linkFailureCount[nodeIndex] then
        self.linkFailureCount[nodeIndex] = {}
    end
    local linkFailureCount = self.linkFailureCount[nodeIndex]
    for linkedIndex, material in pairs(node.linkedTo) do

        if not linkFailureCount[linkedIndex] then
            linkFailureCount[linkedIndex] = 0
        end
        if linkFailureCount[linkedIndex] > BlueprintConfig.MaxAttemptsToBuildLink then
            continue
        end
        local linkedId = self.assignedNodeIds[linkedIndex]

        if linkedId and NodeExists(linkedId) and NodeTeam(nodeId) == self.teamId and NodeTeam(linkedId) == self.teamId and (not IsNodeLinkedTo(nodeId, linkedId) or GetLinkMaterialSaveName(nodeId, linkedId) ~= material) then
            if material == BlueprintConfig.SupportStructureMaterial then 
                EnableMaterial("StructuralAluminiumHazard", true, self.teamId % MAX_SIDES)
            end
            CreateLink(self.teamId, material, nodeId, linkedId)
            if material == BlueprintConfig.SupportStructureMaterial then 
                EnableMaterial("StructuralAluminiumHazard", false, self.teamId % MAX_SIDES)
            end
            local pos = NodePosition(nodeId)
            local pos2 = NodePosition(linkedId)
            SpawnLine(pos, pos2, White(), 0.06)


            local result = GetLinkMaterialSaveName(nodeId, linkedId)
            if result == "" or result ~= material then 
                local cost = GetLinkCost(nodeId, NodePosition(linkedId), material, false)
                
                local resources = GetTeamResources(self.teamId)
                local failedBecauseResources = resources.metal < cost.metal or resources.energy < cost.energy

                linkSuccess = 1 
                if not failedBecauseResources then 
                    linkSuccess = 2
                    linkFailureCount[linkedIndex] = linkFailureCount[linkedIndex] + 1
                end
            else 
                local cost = GetLinkCost(nodeId, NodePosition(linkedId), material, false)
                self.totalCost.metal = self.totalCost.metal + cost.metal
                self.totalCost.energy = self.totalCost.energy + cost.energy
                self.structureCost.metal = self.structureCost.metal + cost.metal
                self.structureCost.energy = self.structureCost.energy + cost.energy
                linkSuccess = 3 

                end
        end
    end
    return linkSuccess
end

function BlueprintMetaTable:CreateAttachedNode(node, nodeId)

    local nodeSuccess = 0
    for linkedIndex, material in pairs(node.linkedTo) do
        local linkedId = self.assignedNodeIds[linkedIndex]
        local linkedNode = self.nodeMesh[linkedIndex]
        if not linkedId or not NodeExists(linkedId) or not NodeTeam(linkedId) == self.teamId then

            local pos
            if linkedNode.support then 
                pos = linkedNode.pos 
            else 
                pos = { x = self.pos.x + linkedNode.relativePos.x * self.mirror, y = self.pos.y + linkedNode.relativePos.y } 
            end 
            EnableMaterial("StructuralAluminiumHazard", true, self.teamId % MAX_SIDES)
            local attachedNodeId = CreateNode(self.teamId, BlueprintConfig.SupportStructureMaterial, nodeId, pos)
            CreateLink(self.teamId, material, nodeId, attachedNodeId)
            SpawnLine(NodePosition(nodeId), pos, White(), 0.06)
            EnableMaterial("StructuralAluminiumHazard", false, self.teamId % MAX_SIDES)
            if attachedNodeId < 0 then 
                nodeSuccess = 1
                continue
            else
                nodeSuccess = 2
                local cost = GetLinkCost(nodeId, pos, material, false)
                self.totalCost.metal = self.totalCost.metal + cost.metal
                self.totalCost.energy = self.totalCost.energy + cost.energy
                self.structureCost.metal = self.structureCost.metal + cost.metal
                self.structureCost.energy = self.structureCost.energy + cost.energy
                self:LinkAllPossibleNodes(linkedNode, attachedNodeId, linkedIndex) -- Try and link the new node back to existing nodes
            end
            self.assignedNodeIds[linkedIndex] = attachedNodeId
            break
        end
    end
    return nodeSuccess
end



function BlueprintMetaTable:CreateStarterNodes()
    for i = 1, #self.nodeMesh do
        local virtualNode = self.nodeMesh[i]
        if virtualNode.foundation then
            local closestNode = GetClosestFoundationNodeId(self.teamId, virtualNode.pos)
            local pos = NodePosition(closestNode)
            local posToTest = {x = pos.x - virtualNode.pos.x, y = pos.y - virtualNode.pos.y}
            local distSqr = posToTest.x * posToTest.x + posToTest.y * posToTest.y
            if distSqr > BlueprintConfig.MaxNodeDelegateDistance * BlueprintConfig.MaxNodeDelegateDistance then
                --TODO:  cancel blueprint
            else

                local centerPos = {x = (pos.x + virtualNode.pos.x) / 2, y = (pos.y + virtualNode.pos.y) / 2 - BlueprintConfig.NodeDelegateVerticalOffset}
                EnableMaterial("StructuralAluminiumHazard", true, self.teamId % MAX_SIDES)
                local delegateNode = CreateNode(self.teamId, BlueprintConfig.SupportStructureMaterial, closestNode, centerPos)
                self.delegateNodes[#self.delegateNodes+1] = delegateNode
                local finalNode = CreateNode(self.teamId, BlueprintConfig.SupportStructureMaterial, delegateNode, virtualNode.pos)
                EnableMaterial("StructuralAluminiumHazard", false, self.teamId % MAX_SIDES)
                self.assignedNodeIds[i] = finalNode
                self.structureId = NodeStructureId(finalNode)
            end
        end
    end
end


function BlueprintMetaTable:GetDimensions()
    local minX = math.huge
    local minY = math.huge
    local maxX = -math.huge
    local maxY = -math.huge
    for k, v in pairs(self.nodeMesh) do
        local node = v
        if node.relativePos.x < minX then minX = node.relativePos.x end
        if node.relativePos.y < minY then minY = node.relativePos.y end
        if node.relativePos.x > maxX then maxX = node.relativePos.x end
        if node.relativePos.y > maxY then maxY = node.relativePos.y end
    end
    return {minX = minX, minY = minY, maxX = maxX, maxY = maxY}
end

function BlueprintMetaTable:GenerateSupportStructure(touch)
    local hullNodes = self:GetHullNodes()
    local dimensions = self:GetDimensions()
    local attachY = dimensions.maxY
    local startX = dimensions.minX
    local endX = dimensions.maxX
    

    SupportNodes = {}
    GroundNodes = {}
    --#region find start and end points for supports
    for x = startX, endX, BlueprintConfig.SupportHorizontalAttachSpacing do
        local testPos = {x = x, y = attachY}
        local supportedNode, supportedNodeIndex = self:GetClosestHullNodeToPos(hullNodes, testPos)

        -- Get world position of supported node
        local supportedNodePos = {x = supportedNode.relativePos.x * self.mirror + self.pos.x, y = supportedNode.relativePos.y + self.pos.y}
        local testPos = {x = supportedNodePos.x + BlueprintConfig.SupportFoundationWidth / 2, y = supportedNodePos.y}
        local target = {x = testPos.x, y = testPos.y + BlueprintConfig.MaxHeight}
        local result = CastGroundRay(testPos, target, 0)
        local rayPos = GetRayHitPosition()
        local nodeId = GetClosestFoundationNodeId(self.teamId, rayPos)
        local nodePosition = NodePosition(nodeId)
        local nodePosToRayPos = {x = nodePosition.x - rayPos.x, y = nodePosition.y - rayPos.y}
        local distSqr = nodePosToRayPos.x * nodePosToRayPos.x + nodePosToRayPos.y * nodePosToRayPos.y
        if result > 0 and GetPositionIsFoundation(rayPos, self.teamId, self.testNode) and distSqr < BlueprintConfig.MaxNodeDelegateDistance * BlueprintConfig.MaxNodeDelegateDistance then
            GroundNodes[#GroundNodes + 1] = rayPos
            SupportNodes[#SupportNodes + 1] = {pos = supportedNodePos, targetGroundNodeIndex = #GroundNodes, id = supportedNodeIndex}
        else    
            SupportNodes[#SupportNodes + 1] = {pos = supportedNodePos, targetGroundNodeIndex = -1, id = supportedNodeIndex}
        end
        
        SpawnCircle(supportedNodePos, 50, Red(), 0.06)
    end

    if #GroundNodes == 0 then return false end
    for i = 1, #SupportNodes do
        local supportNode = SupportNodes[i]
        if supportNode.targetGroundNodeIndex == -1 then
            supportNode.targetGroundNodeIndex = self:GetClosestPointToPosIndex(GroundNodes, supportNode.pos)
        end
    end
    --#endregion
    --#region Make ground up
    local SupportsGroundUp = {}
    for i = 1, #SupportNodes do
        local supportNode = SupportNodes[i]
        local groundNode = GroundNodes[supportNode.targetGroundNodeIndex]
        if not SupportsGroundUp[supportNode.targetGroundNodeIndex] then
            SupportsGroundUp[supportNode.targetGroundNodeIndex] = {
                pos = groundNode,
                supportedNodes = {}
            }
        end
        local supportedNodes = SupportsGroundUp[supportNode.targetGroundNodeIndex].supportedNodes
            supportedNodes[#supportedNodes + 1] = {pos = supportNode.pos, index = supportNode.id}
    end
    --#endregion
    local supportsGroundUp2 = {}
    for i = 1, #SupportsGroundUp do
        local support = SupportsGroundUp[i]
        local result = self:EstablishSupportFoundations(support)
        if result then supportsGroundUp2[#supportsGroundUp2 + 1] = support end
    end
    local SupportsGroundUp = supportsGroundUp2
    local supportTable = {}
    for i = 1, #SupportsGroundUp do
        local support = SupportsGroundUp[i]

        self:CreateSegmentedSupport(support, supportTable)
        
    end
    
    -- We have the support structure and nodes, now we just need to link it to the hull

    self:MergeSupportIntoNodeMesh(supportTable)
    return true
end


function BlueprintMetaTable:MergeSupportIntoNodeMesh(supportTable)
    
    local supportTableLength = #supportTable
    local newNodes = {}
    for i = 1, #self.nodeMesh do
        local node = self.nodeMesh[i]
        local newLinkedTo = {}

        for linkedToIndex, material in pairs(node.linkedTo) do
            newLinkedTo[linkedToIndex + supportTableLength] = material
        end
        node.linkedTo = newLinkedTo
        newNodes[i + supportTableLength] = node
    end
    for supportNodeIndex = 1, #supportTable do
        local node = supportTable[supportNodeIndex]
        newNodes[supportNodeIndex] = node
        if node.final then
            --set the support node to link to the original node
            if not node.originalToLink then continue end -- How did we get here?
            
            --set the original node to link to the support node

            local originalLinkIndex = node.originalToLink + supportTableLength
            local originalNode = newNodes[originalLinkIndex]

            
            for nextLinkedToIndex, _ in pairs(originalNode.linkedTo) do
                local newNode = newNodes[nextLinkedToIndex]
                if not newNode.hullNode then continue end

                
                node.linkedTo[nextLinkedToIndex] = BlueprintConfig.SupportStructureMaterial
                newNode.linkedTo[supportNodeIndex] = BlueprintConfig.SupportStructureMaterial
                

            end
            node.linkedTo[originalLinkIndex] = BlueprintConfig.SupportStructureMaterial
            originalNode.linkedTo[supportNodeIndex] = BlueprintConfig.SupportStructureMaterial
        end
    end
    self.nodeMesh = newNodes
    for i = 1, #self.devices do
        local device = self.devices[i]
        device.idA = device.idA + supportTableLength
        device.idB = device.idB + supportTableLength
    end

    
end

function BlueprintMetaTable:EstablishSupportFoundations(support)
    local pos = support.pos
        for i = -1, 1,2 do
            local secondarySupportRayTestPos = 
        {
            x = pos.x + BlueprintConfig.SupportFoundationWidth * i, 
            y = pos.y - BlueprintConfig.SupportMaxFoundationHeightDisplacement
        }
        local secondarySupportRayTarget = 
        {
            x = pos.x + BlueprintConfig.SupportFoundationWidth * i, 
            y = pos.y + BlueprintConfig.SupportMaxFoundationHeightDisplacement
        }
        local secondaryRayResult = CastGroundRay(secondarySupportRayTestPos, secondarySupportRayTarget, 0)
        if secondaryRayResult < 0 then continue end -- try the other side if this one fails
        local secondaryRayPos = GetRayHitPosition()
        if not GetPositionIsFoundation(secondaryRayPos, self.teamId, self.testNode) then continue end

        support.pos2 = secondaryRayPos
        return true
    end
    return false
end


function BlueprintMetaTable:CreateSegmentedSupport(support, outputTable)
    local pos = support.pos
    local pos2 = support.pos2

    local nodeA = {pos = pos, support = true, linkedTo = {}, foundation = true}
    local nodeB = {pos = pos2, support = true, linkedTo = {}, foundation = true}
    outputTable[#outputTable + 1] = nodeA
    nodeA.id = #outputTable
    outputTable[#outputTable + 1] = nodeB
    nodeB.id = #outputTable
    self:CreateSegmentedSupportRecursive(nodeA, nodeB, support.supportedNodes, outputTable)
    
end

function BlueprintMetaTable:CreateSegmentedSupportRecursive(nodeA, nodeB, targetNodes, outputTable)
    local mat = BlueprintConfig.SupportStructureMaterial
    local pos = nodeA.pos
    local pos2 = nodeB.pos
    local centerSupportPos = {x = (pos.x + pos2.x) / 2, y = (pos.y + pos2.y) / 2}
    local target = self:GetAveragePosOfTargetedNodes(targetNodes)
    local centerToTarget = {x = target.x - centerSupportPos.x, y = target.y - centerSupportPos.y}
    local distanceToTarget = math.sqrt(centerToTarget.x * centerToTarget.x + centerToTarget.y * centerToTarget.y)


    local offsetValue = BlueprintConfig.SupportMaxSegmentLength
    if distanceToTarget - BlueprintConfig.SupportMaxSegmentLength < BlueprintConfig.SupportStructureMinSegmentLength then
        offsetValue = BlueprintConfig.SupportStructureMinSegmentLength
    end

    if distanceToTarget < BlueprintConfig.SupportMaxSegmentLength then
        SpawnLine(pos, target, Blue(), 0.06)
        SpawnLine(pos2, target, Blue(), 0.06)


        nodeA.final = true
        nodeB.final = true
        if not targetNodes[1] then return end -- how did this happen?
        nodeA.originalToLink = targetNodes[1].index
        nodeB.originalToLink = targetNodes[1].index
        return
    end
    local dir = {x = centerToTarget.x / distanceToTarget, y = centerToTarget.y / distanceToTarget}
    local perp = {x = -dir.y, y = dir.x}
    local nextCenter = {x = centerSupportPos.x + dir.x * offsetValue, y = centerSupportPos.y + dir.y * offsetValue}
    local halfWidth = BlueprintConfig.SupportFoundationWidth / 2
    local nextPos = {x = nextCenter.x + perp.x * halfWidth, y = nextCenter.y + perp.y * halfWidth}
    local nextPos2 = {x = nextCenter.x - perp.x * halfWidth, y = nextCenter.y - perp.y * halfWidth}
    

    local newNodeA = {pos = nextPos, support = true, linkedTo = {[nodeA.id] = mat, [nodeB.id] = mat}}
    outputTable[#outputTable + 1] = newNodeA
    newNodeA.id = #outputTable
    nodeA.linkedTo[newNodeA.id] = mat
    nodeB.linkedTo[newNodeA.id] = mat
    local newNodeB = {pos = nextPos2, support = true, linkedTo = {[nodeA.id] = mat, [nodeB.id] = mat}}
    outputTable[#outputTable + 1] = newNodeB
    newNodeB.id = #outputTable
    nodeA.linkedTo[newNodeB.id] = mat
    nodeB.linkedTo[newNodeB.id] = mat
    newNodeA.linkedTo[newNodeB.id] = mat
    newNodeB.linkedTo[newNodeA.id] = mat

    SpawnLine(pos, nextPos, Blue(), 0.06)
    SpawnLine(pos2, nextPos2, Blue(), 0.06)
    SpawnLine(pos, nextPos2, Blue(), 0.06)
    SpawnLine(pos2, nextPos, Blue(), 0.06)
    SpawnLine(nextPos, nextPos2, Blue(), 0.06)

    local targetNodeClusters = self:TrySplitTargetNodes(targetNodes, nextPos, nextPos2, dir)

    for i = 1, #targetNodeClusters do
        local targetNodes = targetNodeClusters[i]
        self:CreateSegmentedSupportRecursive(newNodeA, newNodeB, targetNodes, outputTable)
    end
end

function BlueprintMetaTable:TrySplitTargetNodes(targetNodes, pos, pos2, dir)
    if #targetNodes == 1 then return {targetNodes} end
    local centerPos = {x = (pos.x + pos2.x) / 2, y = (pos.y + pos2.y) / 2}
    local targetNodeClusters = {
        {

        }
    }
    for i = 1, #targetNodes do
        local targetNode = targetNodes[i]
        local centerPosToTarget = {x = targetNode.pos.x - centerPos.x, y = targetNode.pos.y - centerPos.y}
        local distToTarget = math.sqrt(centerPosToTarget.x * centerPosToTarget.x + centerPosToTarget.y * centerPosToTarget.y)
        local centerPosToTargetNormalized = {x = centerPosToTarget.x / distToTarget, y = centerPosToTarget.y / distToTarget}
        local dot = centerPosToTargetNormalized.x * dir.x + centerPosToTargetNormalized.y * dir.y
        if dot > BlueprintConfig.SupportStructureMinDotToBranch then
            targetNodeClusters[1][#targetNodeClusters[1] + 1] = targetNode
        else
            targetNodeClusters[#targetNodeClusters + 1] = {targetNode}
        end
    end
    return targetNodeClusters
end

function BlueprintMetaTable:GetAveragePosOfTargetedNodes(supportedNodes)
    local totalX = 0
    local totalY = 0
    for i = 1, #supportedNodes do
        local node = supportedNodes[i]
        totalX = totalX + node.pos.x
        totalY = totalY + node.pos.y
    end
    return {x = totalX / #supportedNodes, y = totalY / #supportedNodes}
end



function BlueprintMetaTable:Highlight()
    for k, v in pairs(self.nodeMesh) do
        SpawnCircle({x = v.relativePos.x * self.mirror + self.pos.x, y = v.relativePos.y + self.pos.y}, 25, White(), 0.06)
        for k2, v2 in pairs (v.linkedTo) do
            local linkedNode = self.nodeMesh[k2]
            if linkedNode then
                SpawnLine({x = linkedNode.relativePos.x * self.mirror + self.pos.x, y = linkedNode.relativePos.y + self.pos.y}, {x = v.relativePos.x * self.mirror + self.pos.x, y = v.relativePos.y + self.pos.y}, White(), 0.06)
            end
        end
    end
end

function BlueprintMetaTable:HighlightHullNodes(color, duration)
    local hullNodes = self:GetHullNodes()
    
    
    for k, v in pairs(hullNodes) do
        local node = v
        local linkedTo = node.linkedTo
        for linkedIndex, _ in pairs(linkedTo) do
            local linkedNode = hullNodes[linkedIndex]
            if linkedNode then
                SpawnLine({x = node.relativePos.x * self.mirror + self.pos.x, y = node.relativePos.y + self.pos.y}, {x = linkedNode.relativePos.x * self.mirror + self.pos.x, y = linkedNode.relativePos.y + self.pos.y}, color, duration)
            end
        end
    end

end

function BlueprintMetaTable:GetHullNodes()
    local hullNodes = {}
    for index = 1, #self.nodeMesh do
        local testingNode = self.nodeMesh[index]
        if hullNodes[index] then continue end
        for linkedIndex, _ in pairs(testingNode.linkedTo) do
            local linkedNode = self.nodeMesh[linkedIndex]
            local result = self:CheckIsLinkHullLink(testingNode, linkedNode)
            if result then
                hullNodes[index] = testingNode
                hullNodes[linkedIndex] = linkedNode
                testingNode.hullNode = true
                linkedNode.hullNode = true
            end
        end
    end
    return hullNodes
end



function BlueprintMetaTable:CheckIsLinkHullLink(nodeA, nodeB)
    local topCovered = false
    local bottomCovered = false

    local nodeAPos = nodeA.relativePos
    local nodeBPos = nodeB.relativePos

    if not nodeAPos or not nodeBPos then return false end
    local link = {x = nodeBPos.x - nodeAPos.x, y = nodeBPos.y - nodeAPos.y}

    for linkedIndex, _ in pairs(nodeA.linkedTo) do
        local linkedNode = self.nodeMesh[linkedIndex]
        if linkedNode == nodeB then continue end
        local linkedNodePos = linkedNode.relativePos
        if not linkedNodePos then continue end
        local nodeAToLinked = {x = linkedNodePos.x - nodeAPos.x, y = linkedNodePos.y - nodeAPos.y}

        if nodeAToLinked.x * link.y - nodeAToLinked.y * link.x > 0 then
            topCovered = true
        else
            bottomCovered = true
        end


    end

    return not (topCovered and bottomCovered)
end

function BlueprintMetaTable:GetClosestHullNodeToPos(hullNodes, testPos)
    local closestNode = nil
    local closestIndex = nil
    local closestDistance = math.huge
    for k, v in pairs(hullNodes) do
        local node = v
        local testPosToNode = {x = node.relativePos.x - testPos.x, y = node.relativePos.y - testPos.y}
        local distSqr = testPosToNode.x * testPosToNode.x + testPosToNode.y * testPosToNode.y
        if distSqr < closestDistance then
            closestNode = node
            closestDistance = distSqr
            closestIndex = k
        end
    end
    return closestNode, closestIndex
end

function BlueprintMetaTable:GetClosestPointToPosIndex(points, pos)
    local closestIndex = nil
    local closestDistance = math.huge
    for k, v in pairs(points) do
        local point = v
        local testPosToPoint = {x = point.x - pos.x, y = point.y - pos.y}
        local distSqr = testPosToPoint.x * testPosToPoint.x + testPosToPoint.y * testPosToPoint.y
        if distSqr < closestDistance then
            closestIndex = k
            closestDistance = distSqr
        end
    end
    return closestIndex
end


function BlueprintMetaTable:CheckBlueprintAreaForIntersections()
    local pos = self.pos
    local minX = self.meta.minX + pos.x
    local minY = self.meta.minY + pos.y
    local maxX = self.meta.maxX + pos.x
    local maxY = self.meta.maxY + pos.y

    local bottomLeft = {x = minX, y = minY}
    local bottomRight = {x = maxX, y = minY}
    local topLeft = {x = minX, y = maxY}
    local topRight = {x = maxX, y = maxY}


    local terrainHit = false
    local structureHit = false


    local result1 = CastRay(bottomLeft, bottomRight, 0, 0)
    local result2 = CastRay(bottomRight, topRight, 0, 0)
    local result3 = CastRay(topRight, topLeft, 0, 0)
    local result4 = CastRay(topLeft, bottomLeft, 0, 0)

    BetterLog(result1)
    BetterLog(result2)
    BetterLog(result3)
    BetterLog(result4)

    if result1 == 1 or result2 == 1 or result3 == 1 or result4 == 1 then
        terrainHit = true
    end
    if result1 == 2 or result2 == 2 or result3 == 2 or result4 == 2 then
        structureHit = true
    end

    
    if terrainHit then
        return Blueprint.FailureCodes.IntersectsTerrain
    end
    if structureHit then
        return Blueprint.FailureCodes.IntersectsExistingStructure
    end
    return 0
end


function BlueprintMetaTable:HighlightExtents(color, duration)

    local pos = self.pos
    local minX = self.meta.minX + pos.x
    local minY = self.meta.minY + pos.y
    local maxX = self.meta.maxX + pos.x
    local maxY = self.meta.maxY + pos.y

    local bottomLeft = {x = minX, y = minY}
    local bottomRight = {x = maxX, y = minY}
    local topLeft = {x = minX, y = maxY}
    local topRight = {x = maxX, y = maxY}

    SpawnLine(bottomLeft, bottomRight, color, duration)
    SpawnLine(bottomRight, topRight, color, duration)
    SpawnLine(topRight, topLeft, color, duration)
    SpawnLine(topLeft, bottomLeft, color, duration)

end

function BlueprintMetaTable:HighlightBorderAndSave()
    local color = Green()
    local duration = math.huge
    local pos = self.pos
    local minX = self.meta.minX + pos.x
    local minY = self.meta.minY + pos.y
    local maxX = self.meta.maxX + pos.x
    local maxY = self.meta.maxY + pos.y

    local bottomLeft = {x = minX, y = minY}
    local bottomRight = {x = maxX, y = minY}
    local topLeft = {x = minX, y = maxY}
    local topRight = {x = maxX, y = maxY}

    local lineA = SpawnLine(bottomLeft, bottomRight, color, duration)
    local lineB = SpawnLine(bottomRight, topRight, color, duration)
    local lineC = SpawnLine(topRight, topLeft, color, duration)
    local lineD = SpawnLine(topLeft, bottomLeft, color, duration)

    self.lineA = lineA
    self.lineB = lineB
    self.lineC = lineC
    self.lineD = lineD
end

function BlueprintMetaTable:AddUIElements()
    if self.teamId ~= GetLocalTeamId() then return end
    SetControlFrame(0)

    local screenPos = WorldToScreen(self.pos)
    self.controlName = "structure-builder-" .. self.id

    AddTextControl("HUD", self.controlName, "", ANCHOR_TOP_LEFT, screenPos, false, "default")
    

    local stopPos = {x = self.pos.x + self.meta.maxX, y = self.pos.y + self.meta.minY}
    local stopScreenPos = WorldToScreen(stopPos)
    stopScreenPos = {x = stopScreenPos.x - screenPos.x, y = stopScreenPos.y - screenPos.y}
    AddTextButtonControl(self.controlName,  BlueprintConfig.stopButtonName, "Stop", ANCHOR_TOP_LEFT, stopScreenPos, false, "Readout")
    SetButtonCallback(self.controlName, BlueprintConfig.stopButtonName, self.id)
    AddTextButtonControl(self.controlName, BlueprintConfig.cancelStopButtonName, "Cancel", ANCHOR_TOP_LEFT, stopScreenPos, false, "Readout")
    SetButtonCallback(self.controlName, BlueprintConfig.cancelStopButtonName, self.id)
    local confirmPos = {x = stopScreenPos.x + 50, y = stopScreenPos.y}
    AddTextButtonControl(self.controlName, BlueprintConfig.confirmStopButtonName, "Confirm", ANCHOR_TOP_LEFT, confirmPos, false, "Readout")
    SetButtonCallback(self.controlName, BlueprintConfig.confirmStopButtonName, self.id)
    
    local pausePos = {x = stopScreenPos.x, y = stopScreenPos.y + 10}
    AddTextButtonControl(self.controlName, BlueprintConfig.pauseButtonName, "Pause", ANCHOR_TOP_LEFT, pausePos, false, "Readout")
    SetButtonCallback(self.controlName, BlueprintConfig.pauseButtonName, self.id)
    
    ShowControl(self.controlName, BlueprintConfig.confirmStopButtonName, false)
    ShowControl(self.controlName, BlueprintConfig.cancelStopButtonName, false)
end

function BlueprintMetaTable:UpdateUIElements()
    local screenPos = WorldToScreen(self.pos)

    SetControlRelativePos("HUD", self.controlName, screenPos)

    local stopPos = {x = self.pos.x + self.meta.maxX, y = self.pos.y + self.meta.minY}
    local stopScreenPos = WorldToScreen(stopPos)

    stopScreenPos = {x = stopScreenPos.x - screenPos.x, y = stopScreenPos.y - screenPos.y}
    SetControlRelativePos(self.controlName, BlueprintConfig.stopButtonName, stopScreenPos)
    SetControlRelativePos(self.controlName, BlueprintConfig.cancelStopButtonName, stopScreenPos)
    local confirmPos = {x = stopScreenPos.x + 50, y = stopScreenPos.y}
    SetControlRelativePos(self.controlName, BlueprintConfig.confirmStopButtonName, confirmPos)
    local pausePos = {x = stopScreenPos.x, y = stopScreenPos.y + 10}
    SetControlRelativePos(self.controlName, BlueprintConfig.pauseButtonName, pausePos)
end