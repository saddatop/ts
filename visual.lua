-- visual_full.lua
-- Полный рабочий скрипт: ESP, CHAMS, TRACE, LOG, HITSOUND + World (No Grass, No Leaves, Clouds, Ambient, Always Day, Remove Fog, Skybox: Default/Black)

local Library = getgenv().TridentLibrary
assert(Library, "Library не был найден! Запустите main.lua сначала.")

local Window = Library:CreateWindow({
    Title = "Trident Survival Visuals",
    Footer = "ESP UI Example",
    Center = true,
    AutoShow = true,
    ToggleKeybind = Enum.KeyCode.RightControl,
})

local VisualTab = Window:AddTab("Visual", "eye", "ESP Visuals Features")
local EspBox = VisualTab:AddLeftGroupbox("ESP", "box")
local ChamsBox = VisualTab:AddRightGroupbox("Chams", "wand")
local WorldBox = VisualTab:AddRightGroupbox("World", "globe")

-- === НАСТРОЙКИ ===
local espSettings = {
    enabled = false,
    box = false,
    boxtype = "Default",
    boxColor = Color3.new(1,1,1),
    name = false,
    nameColor = Color3.new(1,1,1),
    weapon = false,
    weaponColor = Color3.new(1,1,1),
    distance = false,
    distanceColor = Color3.new(1,1,1),
    maxDistance = 5000,
    sleepcheck = false,
    aicheck = false
}

local chamsSettings = {
    hand = false,
    handColor = Color3.new(1, 1, 1),
    handMat = "ForceField",
    item = false,
    itemColor = Color3.new(1, 1, 1),
    itemMat = "ForceField"
}

local traceSettings = {
    enabled = false,
    color = Color3.new(0,0.4,1),
    mode = "Legit"
}

local logSettings = {
    enabled = false,
    types = { ["Kill log"] = true, ["Hit log"] = true }
}

local hitSoundSettings = {
    enabled = false,
    soundType = "Rust"
}

local worldVisuals = {
    noGrass = false,
    noLeaves = false,
    clouds = true,
    cloudsColor = Color3.fromRGB(255,255,255),
    ambient = Color3.fromRGB(40,40,40), -- чуть темнее
    ambientEnabled = false,
    alwaysDay = false,
    removeFog = false,
    skybox = "Default"
}

local cloudsObject = nil
local oldCloudsProps = {}
local oldAmbient = nil
local oldBrightness = nil
local oldOutdoorAmbient = nil
local oldTime = nil
local oldFogProps = {}
local terrain = nil
local lighting = game:GetService("Lighting")
local leavesRemoved = {}

local skyboxes = {
    ["Default"] = {
        SkyboxBk = "rbxassetid://401664839",
        SkyboxDn = "rbxassetid://401664862",
        SkyboxFt = "rbxassetid://401664936",
        SkyboxLf = "rbxassetid://401664881",
        SkyboxRt = "rbxassetid://401664929",
        SkyboxUp = "rbxassetid://401664883"
    },
    ["Black"] = {
        SkyboxBk = "rbxassetid://1232261246",
        SkyboxDn = "rbxassetid://1232261246",
        SkyboxFt = "rbxassetid://1232261246",
        SkyboxLf = "rbxassetid://1232261246",
        SkyboxRt = "rbxassetid://1232261246",
        SkyboxUp = "rbxassetid://1232261246"
    }
}

local function ensureTerrain()
    terrain = workspace:FindFirstChildOfClass("Terrain")
    if not terrain then
        repeat task.wait() until workspace:FindFirstChildOfClass("Terrain")
        terrain = workspace:FindFirstChildOfClass("Terrain")
    end
end

-- === WORLD ФУНКЦИИ ===
local function setGrassEnabled(enabled)
    ensureTerrain()
    if sethiddenproperty then
        sethiddenproperty(terrain, "Decoration", enabled)
    end
end

local function removeLeaves()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:match("Leaves$") then
            obj:Destroy()
        end
    end
end

local function leavesWatcher()
    if worldVisuals.noLeaves then
        removeLeaves()
        if not leavesRemoved.conn then
            leavesRemoved.conn = workspace.DescendantAdded:Connect(function(obj)
                if worldVisuals.noLeaves and obj:IsA("BasePart") and obj.Name:match("Leaves$") then
                    obj:Destroy()
                end
            end)
        end
    else
        if leavesRemoved.conn then
            leavesRemoved.conn:Disconnect()
            leavesRemoved.conn = nil
        end
    end
end

local function setClouds(enabled, color)
    ensureTerrain()
    if not cloudsObject then
        cloudsObject = terrain:FindFirstChildOfClass("Clouds")
    end
    if enabled then
        if not cloudsObject then
            cloudsObject = Instance.new("Clouds")
            cloudsObject.Parent = terrain
        end
        if not oldCloudsProps.color then
            oldCloudsProps.color = cloudsObject.Color
        end
        cloudsObject.Enabled = true
        cloudsObject.Color = color or worldVisuals.cloudsColor
    else
        if cloudsObject then
            cloudsObject.Enabled = false
        end
    end
end

local ambientApplyConn = nil
local function setAmbient(enabled, color)
    if enabled then
        if not oldAmbient then oldAmbient = lighting.Ambient end
        if not oldBrightness then oldBrightness = lighting.Brightness end
        if not oldOutdoorAmbient then oldOutdoorAmbient = lighting.OutdoorAmbient end
        lighting.Ambient = color or worldVisuals.ambient
        lighting.Brightness = 2
        lighting.OutdoorAmbient = color or worldVisuals.ambient
        if ambientApplyConn then ambientApplyConn:Disconnect() end
        ambientApplyConn = lighting.Changed:Connect(function(prop)
            if worldVisuals.ambientEnabled and (prop == "Ambient" or prop == "Brightness" or prop == "OutdoorAmbient") then
                lighting.Ambient = worldVisuals.ambient
                lighting.Brightness = 2
                lighting.OutdoorAmbient = worldVisuals.ambient
            end
        end)
    else
        if ambientApplyConn then ambientApplyConn:Disconnect() end
        ambientApplyConn = nil
        if oldAmbient then lighting.Ambient = oldAmbient end
        if oldBrightness then lighting.Brightness = oldBrightness end
        if oldOutdoorAmbient then lighting.OutdoorAmbient = oldOutdoorAmbient end
        oldAmbient, oldBrightness, oldOutdoorAmbient = nil, nil, nil
    end
end

local alwaysDayConn = nil
local function setAlwaysDay(enabled)
    if enabled then
        if not oldTime then oldTime = lighting.ClockTime end
        lighting.ClockTime = 12
        if alwaysDayConn then alwaysDayConn:Disconnect() end
        alwaysDayConn = lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
            if worldVisuals.alwaysDay and lighting.ClockTime ~= 12 then
                lighting.ClockTime = 12
            end
        end)
    else
        if alwaysDayConn then alwaysDayConn:Disconnect() end
        alwaysDayConn = nil
        if oldTime then
            lighting.ClockTime = oldTime
            oldTime = nil
        end
    end
end

local fogApplyConn = nil
local function setRemoveFog(enabled)
    if enabled then
        if not oldFogProps.start then
            oldFogProps.start = lighting.FogStart
            oldFogProps.endp = lighting.FogEnd
            oldFogProps.color = lighting.FogColor
        end
        lighting.FogStart = 1000000
        lighting.FogEnd = 1000000
        lighting.FogColor = Color3.new(1,1,1)
        if fogApplyConn then fogApplyConn:Disconnect() end
        fogApplyConn = lighting.Changed:Connect(function(prop)
            if worldVisuals.removeFog and (prop == "FogStart" or prop == "FogEnd" or prop == "FogColor") then
                lighting.FogStart = 1000000
                lighting.FogEnd = 1000000
                lighting.FogColor = Color3.new(1,1,1)
            end
        end)
    else
        if fogApplyConn then fogApplyConn:Disconnect() end
        fogApplyConn = nil
        if oldFogProps.start then lighting.FogStart = oldFogProps.start end
        if oldFogProps.endp then lighting.FogEnd = oldFogProps.endp end
        if oldFogProps.color then lighting.FogColor = oldFogProps.color end
        oldFogProps = {}
    end
end

local function setSkybox(name)
    for _,v in pairs(lighting:GetChildren()) do
        if v:IsA("Sky") then v:Destroy() end
    end
    local sb = skyboxes[name]
    if sb then
        local sky = Instance.new("Sky")
        sky.Name = "WorldSkybox"
        for k, v in pairs(sb) do
            sky[k] = v
        end
        sky.Parent = lighting
    end
end

-- === UI ===

EspBox:AddToggle("espEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(val) espSettings.enabled = val end
})
EspBox:AddToggle("espBox", {
    Text = "Box",
    Default = false,
    Callback = function(val) espSettings.box = val end
}):AddColorPicker("boxColor", {
    Default = Color3.new(1,1,1),
    Title = "Box/Corner Color",
    Callback = function(val) espSettings.boxColor = val end
})
EspBox:AddDropdown("espBoxType", {
    Values = {"Default", "Corner"},
    Default = 1,
    Text = "Box Type",
    Callback = function(val) espSettings.boxtype = val end
})
EspBox:AddToggle("espName", {
    Text = "Name",
    Default = false,
    Callback = function(val) espSettings.name = val end
}):AddColorPicker("nameColor", {
    Default = Color3.new(1,1,1),
    Title = "Name Color",
    Callback = function(val) espSettings.nameColor = val end
})
EspBox:AddToggle("espWeapon", {
    Text = "Weapon",
    Default = false,
    Callback = function(val) espSettings.weapon = val end
}):AddColorPicker("weaponColor", {
    Default = Color3.new(1,1,1),
    Title = "Weapon Color",
    Callback = function(val) espSettings.weaponColor = val end
})
EspBox:AddToggle("espDistance", {
    Text = "Show Distance",
    Default = false,
    Callback = function(val) espSettings.distance = val end
}):AddColorPicker("distanceColor", {
    Default = Color3.new(1,1,1),
    Title = "Distance Color",
    Callback = function(val) espSettings.distanceColor = val end
})
EspBox:AddSlider("espMaxDistance", {
    Text = "Max Distance",
    Default = 5000,
    Min = 1,
    Max = 10000,
    Rounding = 0,
    Callback = function(val) espSettings.maxDistance = val end
})
EspBox:AddToggle("espSleep", {
    Text = "Sleep Check",
    Default = false,
    Callback = function(val) espSettings.sleepcheck = val end
})
EspBox:AddToggle("espAICheck", {
    Text = "AI Check",
    Default = false,
    Callback = function(val) espSettings.aicheck = val end
})

ChamsBox:AddToggle("HandChams", {
    Text = "Hand Chams",
    Default = false,
    Callback = function(val) chamsSettings.hand = val end
}):AddColorPicker("HandChamsColor", {
    Default = Color3.new(1, 1, 1),
    Title = "Hand Chams Color",
    Callback = function(val) chamsSettings.handColor = val end
})
ChamsBox:AddDropdown("HandChamsMat", {
    Values = {"ForceField", "Neon"},
    Default = "ForceField",
    Text = "Hand Material",
    Callback = function(val) chamsSettings.handMat = val end
})
ChamsBox:AddToggle("ItemChams", {
    Text = "Item Chams",
    Default = false,
    Callback = function(val) chamsSettings.item = val end
}):AddColorPicker("ItemChamsColor", {
    Default = Color3.new(1, 1, 1),
    Title = "Item Chams Color",
    Callback = function(val) chamsSettings.itemColor = val end
})
ChamsBox:AddDropdown("ItemChamsMat", {
    Values = {"ForceField", "Neon"},
    Default = "ForceField",
    Text = "Item Material",
    Callback = function(val) chamsSettings.itemMat = val end
})

WorldBox:AddLabel("Map Visuals")
WorldBox:AddToggle("NoGrass", {
    Text = "No Grass",
    Default = false,
    Callback = function(val)
        worldVisuals.noGrass = val
        setGrassEnabled(not val)
    end
})
WorldBox:AddToggle("NoLeaves", {
    Text = "No Leaves",
    Default = false,
    Callback = function(val)
        worldVisuals.noLeaves = val
        leavesWatcher()
    end
})
WorldBox:AddToggle("Clouds", {
    Text = "Clouds",
    Default = true,
    Callback = function(val)
        worldVisuals.clouds = val
        setClouds(val, worldVisuals.cloudsColor)
    end
}):AddColorPicker("CloudsColor", {
    Default = worldVisuals.cloudsColor,
    Title = "Clouds Color",
    Callback = function(val)
        worldVisuals.cloudsColor = val
        if worldVisuals.clouds then
            setClouds(true, val)
        end
    end
})
WorldBox:AddToggle("Ambient", {
    Text = "Ambient",
    Default = false,
    Callback = function(val)
        worldVisuals.ambientEnabled = val
        setAmbient(val, worldVisuals.ambient)
    end
}):AddColorPicker("AmbientColor", {
    Default = worldVisuals.ambient,
    Title = "Ambient Color",
    Callback = function(val)
        worldVisuals.ambient = val
        if worldVisuals.ambientEnabled then
            setAmbient(true, val)
        end
    end
})
WorldBox:AddToggle("AlwaysDay", {
    Text = "Always Day",
    Default = false,
    Callback = function(val)
        worldVisuals.alwaysDay = val
        setAlwaysDay(val)
    end
})
WorldBox:AddToggle("RemoveFog", {
    Text = "Remove Fog",
    Default = false,
    Callback = function(val)
        worldVisuals.removeFog = val
        setRemoveFog(val)
    end
})
WorldBox:AddDropdown("SkyboxSelect", {
    Text = "Skybox",
    Values = {"Default", "Black"},
    Default = "Default",
    Callback = function(val)
        worldVisuals.skybox = val
        setSkybox(val)
    end
})

WorldBox:AddLabel("Other Visuals")
WorldBox:AddToggle("BulletTrace", {
    Text = "Bullet Trace",
    Default = false,
    Callback = function(val) traceSettings.enabled = val end
}):AddColorPicker("BulletTraceColor", {
    Default = Color3.new(0,0.4,1),
    Title = "Bullet Trace Color",
    Callback = function(val) traceSettings.color = val end
})
WorldBox:AddDropdown("BulletTraceMode", {
    Values = {"Legit", "Neon"},
    Default = "Legit",
    Text = "Bullet Trace Mode",
    Callback = function(val) traceSettings.mode = val end
})
WorldBox:AddToggle("HitSound", {
    Text = "Hit sound",
    Default = false,
    Callback = function(val) hitSoundSettings.enabled = val end
})
WorldBox:AddDropdown("HitSoundType", {
    Values = {"Rust"},
    Default = "Rust",
    Text = "Hit sound type",
    Callback = function(val) hitSoundSettings.soundType = val end
})
WorldBox:AddToggle("Log", {
    Text = "Log",
    Default = false,
    Callback = function(val) logSettings.enabled = val
        setupLogHooks()
    end
})
WorldBox:AddDropdown("LogTypes", {
    Values = {"Kill log", "Hit log"},
    Multi = true,
    Default = {"Kill log", "Hit log"},
    Text = "Log Types",
    Callback = function(val)
        logSettings.types = {}
        for k, v in pairs(val) do
            logSettings.types[k] = v
        end
    end
})
-- === ВСЯ ЛОГИКА ESP/CHAMS/TRACE/LOG/HITSOUND ===

local camera = workspace.CurrentCamera
local runservice = game:GetService("RunService")
local coregui = game:GetService("CoreGui")
local players = game:GetService("Players")
local localplayer = players.LocalPlayer

local ESPHolder = coregui:FindFirstChild("ESP_UI_FIX") or Instance.new("ScreenGui")
ESPHolder.Name = "ESP_UI_FIX"
ESPHolder.ResetOnSpawn = false
ESPHolder.Parent = coregui

local activeEsp = {}
local originalHandProps = {}
local originalItemProps = {}

local function applyItemChams(obj)
    local id = obj:GetDebugId()
    if obj.Name == "Arrow" or obj.Name == "Bullet" then return end
    if chamsSettings.item then
        if not originalItemProps[id] then
            originalItemProps[id] = {Material=obj.Material, Color=obj.Color}
        end
        obj.Material = Enum.Material[chamsSettings.itemMat]
        obj.Color = chamsSettings.itemColor
    else
        local old = originalItemProps[id]
        if old then
            obj.Material = old.Material
            obj.Color = old.Color
            originalItemProps[id] = nil
        end
    end
end
local function recurseItemChams(obj)
    if obj:IsA("BasePart") or obj:IsA("MeshPart") then
        applyItemChams(obj)
    end
    for _, child in ipairs(obj:GetChildren()) do
        recurseItemChams(child)
    end
end
local function updateIgnoreChams()
    local ignore = workspace:FindFirstChild("Const") and workspace.Const:FindFirstChild("Ignore")
    if not ignore then return end
    for _, obj in ipairs(ignore:GetChildren()) do
        if obj.Name ~= "FPSArms" and obj.Name ~= "LocalCharacter" and obj.Name ~= "Arrow" and obj.Name ~= "Bullet" then
            recurseItemChams(obj)
        end
    end
end
local function updateFPSArmsHandModelChams()
    local ignore = workspace:FindFirstChild("Const") and workspace.Const:FindFirstChild("Ignore")
    local fpsarms = ignore and ignore:FindFirstChild("FPSArms")
    if not fpsarms then return end
    local handModel = fpsarms:FindFirstChild("HandModel")
    if handModel then
        recurseItemChams(handModel)
    end
    fpsarms.ChildAdded:Connect(function(child)
        if child.Name == "HandModel" then
            recurseItemChams(child)
        end
    end)
end
local function updateItemChams()
    updateIgnoreChams()
    updateFPSArmsHandModelChams()
end

runservice.RenderStepped:Connect(function()
    updateItemChams()
end)
workspace.ChildAdded:Connect(function(child)
    if child.Name == "Const" then
        local ignore = child:WaitForChild("Ignore", 5)
        if ignore then
            ignore.ChildAdded:Connect(function(obj)
                updateItemChams()
            end)
        end
    end
end)
workspace.DescendantAdded:Connect(function(child)
    if child and child.Parent and child.Parent.Name == "FPSArms" and child.Name == "HandModel" then
        updateItemChams()
    end
end)

local function updateHandChams()
    local arms = workspace:FindFirstChild("Const")
    arms = arms and arms:FindFirstChild("Ignore")
    arms = arms and arms:FindFirstChild("FPSArms")
    if not arms then return end

    local handNames = {"LeftHand", "RightHand"}
    for _, name in ipairs(handNames) do
        local hand = arms:FindFirstChild(name)
        if hand and hand:IsA("MeshPart") then
            local id = hand:GetDebugId()
            if chamsSettings.hand then
                if not originalHandProps[id] then
                    originalHandProps[id] = {Material=hand.Material, Color=hand.Color}
                end
                hand.Material = Enum.Material[chamsSettings.handMat]
                hand.Color = chamsSettings.handColor
            else
                local old = originalHandProps[id]
                if old then
                    hand.Material = old.Material
                    hand.Color = old.Color
                    originalHandProps[id] = nil
                end
            end
        end
    end

    local fake = arms:FindFirstChild("Fake")
    if fake then
        local fakeNames = {"c_LeftLowerArm", "c_RightLowerArm"}
        for _, name in ipairs(fakeNames) do
            local limb = fake:FindFirstChild(name)
            if limb and limb:IsA("MeshPart") then
                local id = limb:GetDebugId()
                if chamsSettings.hand then
                    if not originalHandProps[id] then
                        originalHandProps[id] = {Material=limb.Material, Color=limb.Color}
                    end
                    limb.Material = Enum.Material[chamsSettings.handMat]
                    limb.Color = chamsSettings.handColor
                else
                    local old = originalHandProps[id]
                    if old then
                        limb.Material = old.Material
                        limb.Color = old.Color
                        originalHandProps[id] = nil
                    end
                end
            end
        end
    end
end

local hitSoundList = {
    "PlayerHit",
    "PlayerHit2",
    "PlayerHit2_Muffled",
    "PlayerHitHeadshot",
    "PlayerHitHeadshot_Muffled",
    "PlayerHit_Muffled"
}
local rustSoundId = "rbxassetid://18805676593"
local originalHitSoundIds = {}
local function updateHitSounds()
    local soundService = game:GetService("SoundService")
    for _, name in ipairs(hitSoundList) do
        local sound = soundService:FindFirstChild(name)
        if sound and sound:IsA("Sound") then
            if hitSoundSettings.enabled and hitSoundSettings.soundType == "Rust" then
                if not originalHitSoundIds[name] then
                    originalHitSoundIds[name] = sound.SoundId
                end
                sound.SoundId = rustSoundId
            else
                if originalHitSoundIds[name] then
                    sound.SoundId = originalHitSoundIds[name]
                    originalHitSoundIds[name] = nil
                end
            end
        end
    end
end

local function removeEspFor(char, esp)
    if esp then
        if esp.Box then esp.Box.Visible = false esp.Box:Remove() end
        if esp.Corners then for _, v in ipairs(esp.Corners) do v.Visible = false v:Remove() end end
        if esp.Name then esp.Name:Remove() end
        if esp.Weapon then esp.Weapon:Remove() end
        if esp.Distance then esp.Distance:Remove() end
    end
end

local function GetPlayerName(plrChar)
    local head = plrChar:FindFirstChild("Head")
    if head and head:FindFirstChild("Nametag") and head.Nametag:FindFirstChild("tag") then
        local tag = head.Nametag.tag
        if tag.Text ~= "" and tag.Text ~= nil then
            return tag.Text
        end
    end
    return "Player"
end

local function SyncHandModelsAttributes()
    local handModels = game:GetService("ReplicatedStorage"):FindFirstChild("HandModels")
    if handModels then
        for _,v in pairs(handModels:GetChildren()) do
            if not v:GetAttribute("name") then
                v:SetAttribute("name", v.Name)
            end
        end
    end
end
SyncHandModelsAttributes()

local function GetWeaponNameSolara(plrChar)
    local hand = plrChar:FindFirstChild("HandModel")
    if hand and hand:GetAttribute("name") then
        return tostring(hand:GetAttribute("name"))
    end
    return nil
end

local function SleepCheck(plrChar)
    if not plrChar:FindFirstChild("AnimationController") then return false end
    for _,track in pairs(plrChar.AnimationController:GetPlayingAnimationTracks()) do
        if track.IsPlaying and track.Animation.AnimationId == "rbxassetid://13280887764" then
            return true
        end
    end
    return false
end

local function WorldToBox(char)
    local head = char:FindFirstChild("Head")
    local leftFoot = char:FindFirstChild("LeftFoot")
    local rightFoot = char:FindFirstChild("RightFoot")
    if not (head and leftFoot and rightFoot) then return end
    local topWorld = head.Position
    local bottomWorld = (leftFoot.Position.Y < rightFoot.Position.Y and leftFoot.Position or rightFoot.Position)
    local isSleeping = SleepCheck(char)
    if isSleeping then
        local torso = char:FindFirstChild("Torso")
        if torso then
            bottomWorld = torso.Position - Vector3.new(0, torso.Size.Y/2, 0)
        end
    end
    local top2d = camera:WorldToViewportPoint(topWorld)
    local bottom2d = camera:WorldToViewportPoint(bottomWorld)
    local scaleFactor = 15 / (top2d.Z * math.tan(math.rad(camera.FieldOfView * 0.5)) * 2) * 100
    local boxW = 2.4 * scaleFactor
    local boxH = 3 * scaleFactor
    if not (boxH > 1 and boxW > 1) then return end
    local left = top2d.X - boxW / 2
    local top = top2d.Y
    local right = top2d.X + boxW / 2
    local bottom = top + boxH
    return left, top, right, bottom, boxW, boxH, isSleeping
end

local veryFarUpdateDelay = 0.25 -- обновление раз в 0.25 сек для игроков >3000
local function CreateEsp(char)
    if activeEsp[char] then return end
    local esp = {}
    esp.Box = Drawing.new("Square")
    esp.Box.Thickness = 1
    esp.Box.Color = espSettings.boxColor
    esp.Box.Filled = false
    esp.Box.Visible = false
    esp.Corners = {}
    for i = 1, 8 do
        local line = Drawing.new("Line")
        line.Thickness = 2
        line.Color = espSettings.boxColor
        line.Visible = false
        esp.Corners[i] = line
    end
    esp.Name = Drawing.new("Text")
    esp.Name.Size = 16
    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.Visible = false
    esp.Weapon = Drawing.new("Text")
    esp.Weapon.Size = 14
    esp.Weapon.Center = true
    esp.Weapon.Outline = true
    esp.Weapon.Visible = false
    esp.Distance = Drawing.new("Text")
    esp.Distance.Size = 12
    esp.Distance.Center = true
    esp.Distance.Outline = true
    esp.Distance.Visible = false
    activeEsp[char] = esp

    local lastUpdate = 0

    esp._conn = runservice.RenderStepped:Connect(function()
        if not char or not char.Parent or not char:FindFirstChild("HumanoidRootPart") then
            esp._conn:Disconnect()
            removeEspFor(char, esp)
            activeEsp[char] = nil
            return
        end

        local hrp = char.HumanoidRootPart
        local dist = (camera.CFrame.Position - hrp.Position).Magnitude

        if not espSettings.enabled or dist > espSettings.maxDistance
        or (espSettings.aicheck and GetPlayerName(char) == "Shylou2644")
        or (espSettings.sleepcheck and SleepCheck(char)) then
            esp.Box.Visible = false
            for _, f in ipairs(esp.Corners) do f.Visible = false end
            esp.Name.Visible = false
            esp.Weapon.Visible = false
            esp.Distance.Visible = false
            return
        end

        -- Если очень далеко (>3000), обновление только раз в 0.25 сек (anti-lag)
        if dist > 3000 then
            if tick() - lastUpdate < veryFarUpdateDelay then return end
            lastUpdate = tick()
        end

        local left, top, right, bottom, boxW, boxH = WorldToBox(char)
        if not left then return end
        local centerX = left + boxW / 2

        if espSettings.box then
            if espSettings.boxtype == "Corner" then
                esp.Box.Visible = false
                local len = boxW * 0.25
                local lenY = boxH * 0.18
                local c = esp.Corners
                c[1].From = Vector2.new(left, top)
                c[1].To = Vector2.new(left + len, top)
                c[2].From = Vector2.new(left, top)
                c[2].To = Vector2.new(left, top + lenY)
                c[3].From = Vector2.new(right, top)
                c[3].To = Vector2.new(right - len, top)
                c[4].From = Vector2.new(right, top)
                c[4].To = Vector2.new(right, top + lenY)
                c[5].From = Vector2.new(left, bottom)
                c[5].To = Vector2.new(left + len, bottom)
                c[6].From = Vector2.new(left, bottom)
                c[6].To = Vector2.new(left, bottom - lenY)
                c[7].From = Vector2.new(right, bottom)
                c[7].To = Vector2.new(right - len, bottom)
                c[8].From = Vector2.new(right, bottom)
                c[8].To = Vector2.new(right, bottom - lenY)
                for i = 1, 8 do
                    c[i].Color = espSettings.boxColor
                    c[i].Visible = true
                end
            else
                for _, f in ipairs(esp.Corners) do f.Visible = false end
                esp.Box.Position = Vector2.new(left, top)
                esp.Box.Size = Vector2.new(boxW, boxH)
                esp.Box.Visible = true
                esp.Box.Color = espSettings.boxColor
            end
        else
            esp.Box.Visible = false
            for _, f in ipairs(esp.Corners) do f.Visible = false end
        end

        local spacing = 1
        local textHeightName = esp.Name.Size
        local textHeightWeap = esp.Weapon.Size
        local textHeightDist = esp.Distance.Size

        local nameY = top - textHeightName - spacing
        local weapY = bottom + spacing
        local distY = weapY + textHeightWeap + spacing

        if espSettings.name then
            esp.Name.Visible = true
            local realName = GetPlayerName(char)
            esp.Name.Text = realName == "Shylou2644" and not espSettings.aicheck and "AI" or realName
            esp.Name.Position = Vector2.new(centerX, nameY)
            esp.Name.Color = espSettings.nameColor
        else
            esp.Name.Visible = false
        end

        if espSettings.weapon then
            esp.Weapon.Visible = true
            esp.Weapon.Text = GetWeaponNameSolara(char) or "None"
            esp.Weapon.Position = Vector2.new(centerX, weapY)
            esp.Weapon.Color = espSettings.weaponColor
        else
            esp.Weapon.Visible = false
        end

        if espSettings.distance then
            esp.Distance.Visible = true
            esp.Distance.Text = string.format("%dm", math.floor(dist))
            esp.Distance.Position = Vector2.new(centerX, espSettings.weapon and distY or weapY)
            esp.Distance.Color = espSettings.distanceColor
        else
            esp.Distance.Visible = false
        end
    end)
end

local function UpdateAllEsps()
    for char, esp in pairs(activeEsp) do
        if not char or not char.Parent or not char:FindFirstChild("HumanoidRootPart") then
            removeEspFor(char, esp)
            activeEsp[char] = nil
        end
    end
    for _, v in pairs(workspace:GetChildren()) do
        if v:FindFirstChild("HumanoidRootPart") and v ~= localplayer.Character then
            if not activeEsp[v] then
                CreateEsp(v)
            end
        end
    end
end

local bulletTraces = {}

local function createBulletTrailDynamic(part)
    local trailPoints = {}
    local trailLines = {}
    local lastPos = part.Position

    local function cleanup()
        for _, line in ipairs(trailLines) do
            line.Visible = false
            line:Remove()
        end
        trailLines = {}
        trailPoints = {}
    end

    local conn
    local function update()
        if not part.Parent or not part:IsDescendantOf(workspace) then
            cleanup()
            if conn then conn:Disconnect() end
            return
        end

        if #trailPoints == 0 or (trailPoints[#trailPoints] - part.Position).Magnitude > 0.01 then
            table.insert(trailPoints, part.Position)
            lastPos = part.Position
        end

        while #trailLines > #trailPoints-1 do
            trailLines[#trailLines].Visible = false
            trailLines[#trailLines]:Remove()
            table.remove(trailLines)
        end

        for i = 1, #trailPoints-1 do
            local a, b = trailPoints[i], trailPoints[i+1]
            local screenA, onscreenA = camera:WorldToViewportPoint(a)
            local screenB, onscreenB = camera:WorldToViewportPoint(b)
            if not trailLines[i] then
                local l = Drawing.new("Line")
                l.Thickness = (traceSettings.mode == "Neon") and 2.8 or 2
                l.Color = traceSettings.color
                trailLines[i] = l
            end
            local line = trailLines[i]
            line.Visible = traceSettings.enabled and onscreenA and onscreenB
            if line.Visible then
                line.From = Vector2.new(screenA.X, screenA.Y)
                line.To = Vector2.new(screenB.X, screenB.Y)
                line.Color = traceSettings.color
                line.Thickness = (traceSettings.mode == "Neon") and 2.8 or 2
            end
        end
    end

    conn = runservice.RenderStepped:Connect(update)
    part.Destroying:Connect(function()
        cleanup()
        if conn then conn:Disconnect() end
    end)
end

local function updateBulletTraces()
    local ignore = workspace:FindFirstChild("Const") and workspace.Const:FindFirstChild("Ignore")
    if not ignore then return end
    for _, obj in ipairs(ignore:GetChildren()) do
        if obj.Name == "Arrow" then
            local trail = obj:FindFirstChildOfClass("Trail")
            if trail and not bulletTraces[trail] then
                bulletTraces[trail] = true
                pcall(function()
                    trail.Color = ColorSequence.new(traceSettings.color)
                    trail.Lifetime = traceSettings.enabled and 100 or 0.1
                    trail.LightEmission = (traceSettings.mode == "Neon") and 1 or 0
                    if trail.Thickness ~= nil then
                        trail.Thickness = (traceSettings.enabled and traceSettings.mode == "Neon") and 0.35 or 0.05
                    end
                end)
            end
        elseif obj.Name == "Bullet" and not bulletTraces[obj] then
            bulletTraces[obj] = true
            createBulletTrailDynamic(obj)
        end
    end
end

workspace.DescendantAdded:Connect(function(child)
    if child.Name == "Arrow" or child.Name == "Bullet" then
        task.wait(0.03)
        updateBulletTraces()
    end
end)

runservice.RenderStepped:Connect(function()
    UpdateAllEsps()
    updateHandChams()
    updateItemChams()
    updateBulletTraces()
    updateHitSounds()
end)

workspace.ChildAdded:Connect(function(v)
    task.delay(1.5, function()
        if v:FindFirstChild("HumanoidRootPart") and v ~= localplayer.Character then
            CreateEsp(v)
        end
    end)
end)

local function parseLogLine(msg)
    local attacker, victim, time, weapon, hp_from, hp_to = msg:match("([%w~_]+)%s*%-%>([%w~_]+)%s+(%d+)s%s*([%w%s_%-]+)%s*([%d%.]+)%s*%-%>([%d%.]+)hp")
    if not attacker then
        attacker, victim, time, weapon, hp_from, hp_to = msg:match("%-%- ([^%s]+)%s*%-%>([^%s]+)%s*(%d+)s%s*([%w%s_%-]+)%s*([%d%.]+)%s*%-%>([%d%.]+)hp")
    end
    if not attacker then
        attacker, victim, time, weapon, hp_from, hp_to = msg:match("([%w~_]+)%s*%-%>([%w~_]+)%s+(%d+)s%s*([%w%s_%-]+)%s*([%d%.]+)%s*%-%>([%d%.]+)")
    end
    return attacker, victim, time, weapon, hp_from, hp_to
end

local LogService = game:GetService("LogService")
local logConn = nil

local function notifyLog(msg)
    local attacker, victim, time, weapon, hp_from, hp_to = parseLogLine(msg)
    if attacker and victim and hp_from and hp_to then
        local hpFrom = tonumber(hp_from)
        local hpTo = tonumber(hp_to)
        local logType
        if hpTo and hpTo <= 0.01 and logSettings.types["Kill log"] then
            logType = "Kill"
        elseif hpTo and hpTo > 0.01 and logSettings.types["Hit log"] then
            logType = "Hit"
        else
            return
        end
        Library:Notify({
            Title = logType .. " log",
            Description = string.format(
                "%s: %s -> %s [%ss] %s %.1f -> %.1f",
                logType, attacker, victim, time or "?", weapon or "?", hpFrom or 0, hpTo or 0
            ),
            Time = 6,
        })
    end
end

function setupLogHooks()
    if logConn then pcall(function() logConn:Disconnect() end) end
    if logSettings.enabled then
        logConn = LogService.MessageOut:Connect(function(msg, msgType)
            notifyLog(msg)
        end)
    end
end

Library:OnUnload(function()
    ESPHolder:Destroy()
    for char, esp in pairs(activeEsp) do
        removeEspFor(char, esp)
    end
    if logConn then pcall(function() logConn:Disconnect() end) end
    local soundService = game:GetService("SoundService")
    for name, oldId in pairs(originalHitSoundIds) do
        local sound = soundService:FindFirstChild(name)
        if sound and sound:IsA("Sound") then
            sound.SoundId = oldId
        end
        originalHitSoundIds[name] = nil
    end
end)
