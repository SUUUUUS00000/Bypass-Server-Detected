local config = {
    leashXZ = 9.6,
    leashY = 14.5,
    maxChoke = 0.38,
}

local cloneref = cloneref or function(o) return o end
local sethiddenproperty = sethiddenproperty or set_hidden_property
local isnetworkowner = isnetworkowner or function() return true end

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local NetworkClient = cloneref(game:GetService("NetworkClient"))

local localPlayer = Players.LocalPlayer

local character = nil
local root = nil
local humanoid = nil

local anchorPos = nil
local chokeTimer = 0
local burstTimer = 0
local isBursting = false
local lastSleeping = nil
local lastLimit = nil

local function setNetworkLimit(limit: number)
    if lastLimit == limit then return end
    lastLimit = limit
    pcall(NetworkClient.SetOutgoingKBPSLimit, NetworkClient, limit)
end

local function setSleeping(sleeping: boolean)
    if lastSleeping == sleeping or not root or not sethiddenproperty then return end
    lastSleeping = sleeping
    sethiddenproperty(root, "NetworkIsSleeping", sleeping)
end

local function resetState()
    if not root then return end
    anchorPos = root.Position
    chokeTimer = 0
    burstTimer = 0
    isBursting = false
    setSleeping(false)
    setNetworkLimit(0)
end

local function setupCharacter(char)
    character = char
    root = char:WaitForChild("HumanoidRootPart", 3) or char:FindFirstChild("Torso")
    humanoid = char:WaitForChild("Humanoid", 3)

    if root then
        resetState()
    end
end

localPlayer.CharacterAdded:Connect(setupCharacter)
if localPlayer.Character then
    setupCharacter(localPlayer.Character)
end

RunService.PostSimulation:Connect(function(dt)
    if not root or not humanoid or humanoid.Health <= 0 then
        return
    end

    if not isnetworkowner(root) then
        return
    end

    if not anchorPos then
        anchorPos = root.Position
        return
    end

    local pos = root.Position
    local offset = pos - anchorPos
    local distXZ = Vector2.new(offset.X, offset.Z).Magnitude
    local distY = math.abs(offset.Y)

    local ping = localPlayer:GetNetworkPing() * 2
    local burstDuration = math.clamp(ping * 1.15, 0.08, 0.18)
    local chokeDuration = math.clamp(config.maxChoke - (ping * 0.4), 0.26, 0.38)

    if isBursting then
        burstTimer += dt
        setSleeping(false)
        setNetworkLimit(0)

        if burstTimer >= burstDuration then
            isBursting = false
            burstTimer = 0
            chokeTimer = 0
            anchorPos = pos
        end
    else
        chokeTimer += dt

        local shouldBurst = distXZ >= config.leashXZ 
            or distY >= config.leashY 
            or chokeTimer >= chokeDuration

        if shouldBurst then
            isBursting = true
            burstTimer = 0

            local vel = root.AssemblyLinearVelocity
            local hVel = Vector2.new(vel.X, vel.Z)
            local maxSpeed = humanoid.WalkSpeed * 1.15

            if hVel.Magnitude > maxSpeed and hVel.Magnitude > 0 then
                local clampedVel = hVel.Unit * maxSpeed
                root.AssemblyLinearVelocity = Vector3.new(clampedVel.X, vel.Y, clampedVel.Y)
            end

            setSleeping(false)
            setNetworkLimit(0)
        else
            setSleeping(true)
            setNetworkLimit(1)
        end
    end
end)
