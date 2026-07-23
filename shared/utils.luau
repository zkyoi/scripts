local utils = {}

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

utils.activeControllers = {}

local localPlayer = Players.LocalPlayer

function utils.disconnect(connection: RBXScriptConnection?): boolean
    if connection and connection.Connected then
        connection:Disconnect()
        return true
    end
    return false
end

--[[function utils.loadTarget(): Instance?
    -- Add: Functionality
end]]

function utils.resetVelocity(part: BasePart): ()
    if not part or not part:IsA("BasePart") then return end
    part.AssemblyLinearVelocity = Vector3.zero
    part.AssemblyAngularVelocity = Vector3.zero
end

function utils.getCFrame(target: (Vector3 | CFrame | Instance)?): CFrame?
    if not target then return nil end
    local targetType = typeof(target)
    if targetType == "CFrame" then
        return target :: CFrame
    elseif targetType == "Vector3" then
        return CFrame.new(target :: Vector3)
    elseif targetType == "Instance" then
        local inst = target :: Instance
        if inst:IsA("Player") then
            local root = utils.getRoot(utils.getChar(inst))
            return root and root.CFrame or nil
        end

        local part = utils.getBasePart(inst)
        if part then
            return part.CFrame
        elseif inst:IsA("Model") then
            return inst:GetPivot()
        end
    end
    return nil
end

function utils.getBasePart(target: Instance?): BasePart?
    if not target then return nil end
    if target:IsA("BasePart") then
        return target
    elseif target:IsA("Model") then
        return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
    elseif target:IsA("Tool") then
        return (target:FindFirstChild("Handle") :: BasePart?) or target:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

function utils.createAttachment(parent: BasePart, name: string?): Attachment
    local attachment = Instance.new("Attachment")
    attachment.Name = name or "UtilAttachment"
    attachment.Parent = parent
    return attachment
end

--[[function utils.teleportVehicle()
    -- Add: Functionality
end]]

function utils.breakJoints(): ()
    local char = utils.char()
    if not char then return end
    char:BreakJoints()
end

function utils.findPlayer(target: string?): Player?
    if not target or target == "" then return nil end
    local partial = string.lower(target)
    local allPlayers = Players:GetPlayers()
    for _, player in allPlayers do
        if player.Name:lower() == partial or player.DisplayName:lower() == partial then
            return player
        end
    end
    if partial == "me" then
        return localPlayer
    elseif partial == "random" then
        local others = {}
        for _, player in allPlayers do
            if player ~= localPlayer then
                table.insert(others, player)
            end
        end
        return #others > 0 and others[math.random(1, #others)] or nil
    end
    local isMatch = function(name: string): boolean
        return string.sub(name:lower(), 1, #partial) == partial
    end
    for _, player in allPlayers do
        if isMatch(player.Name) or isMatch(player.DisplayName) then
            return player
        end
    end
    return nil
end

function utils.getChar(player: Player?): Model?
    return player and (player.Character :: Model?) or nil
end

function utils.getRoot(character: Model?): BasePart?
    return character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?) or nil
end

function utils.getHumanoid(character: Model?): Humanoid?
    return character and (character:FindFirstChildOfClass("Humanoid") :: Humanoid?) or nil
end

function utils.char(): Model?
    return utils.getChar(localPlayer) :: Model?
end

function utils.root(): BasePart?
    return utils.getRoot(utils.char()) :: BasePart?
end

function utils.hum(): Humanoid?
    return utils.getHumanoid(utils.char()) :: Humanoid?
end

function utils.teleportTo(target: Vector3 | CFrame | Instance): boolean
    local root = utils.root()
    local targetCFrame = utils.getCFrame(target)
    if not root or not targetCFrame then return false end
    utils.resetVelocity(root)
    root.CFrame = targetCFrame
    return (root.Position - targetCFrame.Position).Magnitude <= 5
end

function utils.view(target: Instance?): boolean
    local currentCamera = Workspace.CurrentCamera
    if not currentCamera then return false end
    if not target then
        local hum = utils.hum()
        if hum then
            currentCamera.CameraSubject = hum
        end
        return false
    end
    if typeof(target) == "Instance" then
        local inst = target :: Instance
        if inst:IsA("Humanoid") then
            currentCamera.CameraSubject = inst
            return true
        elseif inst:IsA("Player") then
            local char = utils.getChar(target)
            local hum = utils.getHumanoid(char)
            if hum then
                currentCamera.CameraSubject = hum
                return true
            end
        elseif inst:IsA("BasePart") then
            currentCamera.CameraSubject = inst
            return true
        elseif inst:IsA("Model") then
            local hum = utils.getHumanoid(inst)
            if hum then
                currentCamera.CameraSubject = hum
                return true
            elseif inst.PrimaryPart then
                currentCamera.CameraSubject = inst.PrimaryPart
                return true
            end
        end
    end
    return false
end

function utils.unview(): boolean
    return utils.view(localPlayer)
end

function utils.findTool(player: Player, toolName: string): Tool?
    if not player or not toolName or toolName == "" then return nil end
    local checkContainer = function(container: Instance?): Tool?
        if not container then return nil end
        local item = container:FindFirstChild(toolName)
        return (item and item:IsA("Tool")) and (item :: Tool) or nil
    end
    return checkContainer(player and player:FindFirstChildOfClass("Backpack")) or checkContainer(utils.getChar(player))
end

--[[function utils.getClosestPlayer(): Player?
    -- Add: Functionality
end]]

function utils.attachPhysics(objects: (Instance | { Instance })?, initialTarget: Vector3 | CFrame | Instance): table?
    if not objects then return nil end
    local objectsList: { Instance } = typeof(objects) == "Instance" and { objects } or (objects :: { Instance })
    local targetCFrame = utils.getCFrame(initialTarget) or CFrame.identity
    local targetAnchor = Instance.new("Part")
    targetAnchor.Name = "SharedPhysicsAnchor"
    targetAnchor.Anchored = true
    targetAnchor.Transparency = 1
    targetAnchor.CanCollide = false
    targetAnchor.CFrame = targetCFrame
    targetAnchor.Parent = Workspace
    local anchorAttachment = utils.createAttachment(targetAnchor)
    local managedParts = {}
    local activeConstraints = {}
    local originalCollisions = {}
    local controller = {}
    local isStopped = false
    for _, obj in ipairs(objectsList) do
        local basePart = utils.getBasePart(obj)
        if basePart and not basePart.Anchored then
            if utils.activeControllers[basePart] then
                utils.activeControllers[basePart].stop()
            end
            local objectAttachment = utils.createAttachment(basePart)
            local alignPos = Instance.new("AlignPosition")
            alignPos.Mode = Enum.PositionAlignmentMode.TwoAttachment
            alignPos.Attachment0 = objectAttachment
            alignPos.Attachment1 = anchorAttachment
            alignPos.MaxForce = 500000
            alignPos.Responsiveness = 100
            alignPos.Parent = basePart
            local alignOrient = Instance.new("AlignOrientation")
            alignOrient.Mode = Enum.OrientationAlignmentMode.TwoAttachment
            alignOrient.Attachment0 = objectAttachment
            alignOrient.Attachment1 = anchorAttachment
            alignOrient.MaxTorque = 500000
            alignOrient.Responsiveness = 100
            alignOrient.Parent = basePart
            originalCollisions[basePart] = basePart.CanCollide
            basePart.CanCollide = false
            table.insert(managedParts, basePart)
            table.insert(activeConstraints, objectAttachment)
            table.insert(activeConstraints, alignPos)
            table.insert(activeConstraints, alignOrient)
            basePart.Destroying:Once(function()
                if not isStopped then
                    controller.stop()
                end
            end)
        end
    end
    if #managedParts == 0 then
        targetAnchor:Destroy()
        return nil
    end
    local heartbeatConn = RunService.Heartbeat:Connect(function()
        for _, part in ipairs(managedParts) do
            if part and part.Parent then
                part.AssemblyLinearVelocity = Vector3.new(0, 0.01, 0)
            end
        end
    end)
    function controller.update(newTarget: Vector3 | CFrame | Instance)
        if isStopped then return end
        local newCFrame = utils.getCFrame(newTarget)
        if newCFrame then
            targetAnchor.CFrame = newCFrame
        end
    end
    function controller.stop()
        if isStopped then return end
        isStopped = true
        utils.disconnect(heartbeatConn)
        for _, instance in ipairs(activeConstraints) do
            if instance and instance.Parent then
                instance:Destroy()
            end
        end
        targetAnchor:Destroy()
        for _, part in ipairs(managedParts) do
            utils.activeControllers[part] = nil
            if part and part.Parent then
                if originalCollisions[part] ~= nil then
                    part.CanCollide = originalCollisions[part]
                end
                utils.resetVelocity(part)
            end
        end
    end
    for _, part in ipairs(managedParts) do
        utils.activeControllers[part] = controller
    end
    return controller
end

return utils
