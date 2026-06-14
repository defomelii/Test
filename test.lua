local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local CurrentPlaceId = game.PlaceId
local IsLobby = (CurrentPlaceId == 16116270224)
local IsGame = (CurrentPlaceId == 16552821455)

local placeSuffix = ""
if IsLobby then placeSuffix = " [Lobby]" elseif IsGame then placeSuffix = " [Game]" end

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
    Title = "Gigi's World HUB" .. placeSuffix,
    SubTitle = "by Gigi",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {}
if IsLobby then
    Tabs.Client = Window:AddTab({ Title = "Client", Icon = "user" })
elseif IsGame then
    Tabs.ESP = Window:AddTab({ Title = "ESP", Icon = "eye" })
    Tabs.Player = Window:AddTab({ Title = "Player", Icon = "user" })
else
    Tabs.Client = Window:AddTab({ Title = "Client", Icon = "user" })
end
task.wait(0.1)

-- ==================== LOBBY ====================
if IsLobby then
    if Tabs.Client then Window:SelectTab(Tabs.Client) end
    local ClientSection = Tabs.Client:AddSection("Visual Unlocking")
    local isToonActivated, isSkinActivated = false, false
    local MainGui, CharacterFrame, SkinFrame, characterScrollingFrame, skinHolder
    local toonConnection, skinFrameConnection, towerValueConnection, confirmConnection
    local buttonConnections = {}
    local allSkins = {}
    local modelCache = {}
    local PlaySoundFunc = function() end
    local SkinChangeEvent, CreateTowerClone = nil, nil

    local function getMainGui() MainGui = MainGui or PlayerGui:FindFirstChild("MainGui"); return MainGui end
    local function getCharacterScrollingFrame()
        local mg = getMainGui(); if not mg then return nil end
        CharacterFrame = mg:FindFirstChild("CharacterFrame"); if not CharacterFrame then return nil end
        return CharacterFrame:FindFirstChild("ScrollingFrame")
    end
    local function getSkinFrameParts()
        local mg = getMainGui(); if not mg then return false end
        CharacterFrame = mg:FindFirstChild("CharacterFrame"); SkinFrame = mg:FindFirstChild("SkinFrame")
        if not CharacterFrame or not SkinFrame then return false end
        skinHolder = SkinFrame:FindFirstChild("SkinHolderFrame"); return skinHolder ~= nil
    end
    local function forceButtonVisible(button)
        if not button:IsA("GuiButton") or button.Name == "Template" then return end
        button.Visible = true; button.Active = true
        if buttonConnections[button] then buttonConnections[button]:Disconnect() end
        buttonConnections[button] = button:GetPropertyChangedSignal("Visible"):Connect(function()
            if isToonActivated and button.Parent and not button.Visible then button.Visible = true end
        end)
    end
    local function forceShowAllToons()
        characterScrollingFrame = getCharacterScrollingFrame(); if not characterScrollingFrame then return end
        for _, child in ipairs(characterScrollingFrame:GetChildren()) do forceButtonVisible(child) end
    end
    local function activateToonUnlocker()
        if isToonActivated then return end
        isToonActivated = true; forceShowAllToons()
        if not characterScrollingFrame then isToonActivated = false; Fluent:Notify({ Title = "Error", Content = "Character scrolling frame not found", Duration = 4 }) return end
        if toonConnection then toonConnection:Disconnect() end
        toonConnection = characterScrollingFrame.ChildAdded:Connect(function(child) task.defer(function() forceButtonVisible(child) end) end)
        Fluent:Notify({ Title = "Toon Visuals", Content = "All toon buttons visible", Duration = 3 })
    end
    local function findSkinFolder()
        local sd = ReplicatedStorage:FindFirstChild("SharedData")
        if sd then local s = sd:FindFirstChild("SkinData") if s then return s end end
        return ReplicatedStorage:FindFirstChild("SkinData") or ReplicatedStorage:FindFirstChild("Skins") or ReplicatedStorage:FindFirstChild("SkinModules")
    end
    local function loadSkins()
        local folder = findSkinFolder(); if not folder then return false end
        table.clear(allSkins)
        for _, cf in ipairs(folder:GetChildren()) do
            if cf:IsA("Folder") then
                for _, sm in ipairs(cf:GetChildren()) do
                    if sm:IsA("ModuleScript") then table.insert(allSkins, { name = sm.Name, character = cf.Name }) end
                end
            end
        end
        return #allSkins > 0
    end
    local function getCurrentCharacter()
        if not CharacterFrame then return nil end
        local df = CharacterFrame:FindFirstChild("DescribeFrame"); if not df then return nil end
        local val = df:GetAttribute("TowerValue"); if not val or val == "None" then return nil end
        return val
    end
    local function clearGeneratedSkinButtons()
        if not skinHolder then return end
        for _, child in ipairs(skinHolder:GetChildren()) do
            if child:IsA("GuiButton") and child.Name ~= "Template" and child.Name ~= "Default" then child:Destroy() end
        end
    end
    local function preloadSkin(character, skin)
        if not CreateTowerClone then return nil end
        if not modelCache[character] then modelCache[character] = {} end
        if modelCache[character][skin] then return modelCache[character][skin] end
        local success, model = pcall(function() return CreateTowerClone:InvokeServer(character, skin) end)
        if success and model then modelCache[character][skin] = model:Clone(); return modelCache[character][skin] end
        return nil
    end
    local function previewSkin(character, skin)
        local model = modelCache[character] and modelCache[character][skin]
        if not model then model = preloadSkin(character, skin) end
        if model then
            local wc = workspace:FindFirstChild("Character")
            if wc then wc:ClearAllChildren() else wc = Instance.new("Model"); wc.Name = "Character"; wc.Parent = workspace end
            local display = model:Clone(); display.Parent = wc
            local mp = workspace:FindFirstChild("MasteryPosition")
            if mp then
                local hum = display:WaitForChild("Humanoid")
                local idle = hum:LoadAnimation(display.Animations.Idle)
                local offset = CFrame.new(0, display.PrimaryPart.Size.Y/2 + hum.HipHeight, 0)
                display.PrimaryPart.Anchored = true; display:PivotTo(mp.CFrame * offset); idle:Play()
            end
            return true
        end
        return false
    end
    local function equipSkin(character, skin)
        if SkinChangeEvent then SkinChangeEvent:FireServer(skin, character) end
        if SkinFrame then SkinFrame.Visible = false end
        local mg = getMainGui(); if mg then local menu = mg:FindFirstChild("Menu"); local info = mg:FindFirstChild("Info")
        if menu then menu.Visible = true end; if info then info.Visible = true end end
    end
    local function createSkinButtons()
        if not getSkinFrameParts() then return end
        local cur = getCurrentCharacter(); if not cur then return end
        local tpl = skinHolder:FindFirstChild("Template"); if not tpl then return end
        clearGeneratedSkinButtons()
        local def = skinHolder:FindFirstChild("Default"); if def then def.Visible = true; def.Active = true; def.LayoutOrder = 0 end
        local order = 1
        for _, info in ipairs(allSkins) do
            if info.character == cur then
                local btn = tpl:Clone(); btn.Name = info.name; btn.Visible = true; btn.Active = true; btn.LayoutOrder = order
                btn:SetAttribute("TowerValue", cur)
                local lbl = btn:FindFirstChild("CharacterName"); if lbl then lbl.Text = info.name end
                btn.Activated:Connect(function()
                    task.spawn(function()
                        preloadSkin(cur, info.name); previewSkin(cur, info.name)
                        local cbtn = SkinFrame:FindFirstChild("ConfirmSkin")
                        if cbtn then
                            if confirmConnection then confirmConnection:Disconnect() end
                            cbtn.Visible = true
                            confirmConnection = cbtn.Activated:Connect(function() equipSkin(cur, info.name) end)
                        end
                    end)
                end)
                btn.Parent = skinHolder; order = order + 1
            end
        end
    end
    local function activateSkinPreviewer()
        if isSkinActivated then return end
        if not getSkinFrameParts() then Fluent:Notify({ Title = "Error", Content = "Skin UI not found", Duration = 4 }) return end
        local evs = ReplicatedStorage:FindFirstChild("Events")
        if evs then SkinChangeEvent = evs:FindFirstChild("SkinChangeEvent"); CreateTowerClone = evs:FindFirstChild("CreateTowerClone") end
        local mg = getMainGui()
        if mg then
            local mods = mg:FindFirstChild("Modules")
            if mods then
                local ps = mods:FindFirstChild("PlaySound")
                if ps then pcall(function() PlaySoundFunc = require(ps).Play end) end
            end
        end
        if not loadSkins() then Fluent:Notify({ Title = "Error", Content = "No skins found", Duration = 4 }) return end
        isSkinActivated = true
        if skinFrameConnection then skinFrameConnection:Disconnect() end
        skinFrameConnection = SkinFrame:GetPropertyChangedSignal("Visible"):Connect(function()
            if isSkinActivated and SkinFrame.Visible then task.defer(createSkinButtons) end
        end)
        local df = CharacterFrame:FindFirstChild("DescribeFrame")
        if df then
            if towerValueConnection then towerValueConnection:Disconnect() end
            towerValueConnection = df:GetAttributeChangedSignal("TowerValue"):Connect(function()
                if isSkinActivated and SkinFrame.Visible then task.defer(createSkinButtons) end
            end)
        end
        if SkinFrame.Visible then createSkinButtons() end
        Fluent:Notify({ Title = "Skin Visuals", Content = "Skin preview enabled", Duration = 3 })
    end
    ClientSection:AddButton({ Title = "Activate Toon Visuals", Description = "Forces toon buttons visible", Callback = activateToonUnlocker })
    ClientSection:AddButton({ Title = "Activate Skin Visuals", Description = "Skin preview & equip", Callback = activateSkinPreviewer })
end

-- ==================== GAME ====================
if IsGame then
    Window:SelectTab(Tabs.ESP)
    local GeneratorSection = Tabs.ESP:AddSection("Generator ESP")
    local MonsterSection = Tabs.ESP:AddSection("Monster ESP")
    local ItemSection = Tabs.ESP:AddSection("Item ESP")
    local PlayerSection = Tabs.Player:AddSection("Speed Modifier")
    local NoclipSection = Tabs.Player:AddSection("Noclip")
    local AutoSkillcheckSection = Tabs.Player:AddSection("Auto Skillcheck")

    -- ESP variables
    local GeneratorESPEnabled, MonsterESPEnabled, ItemESPEnabled = false, false, false
    local MonsterNametagsEnabled, ItemNametagsEnabled = true, true
    local ESPTransparency = 0.5
    local GeneratorColor = Color3.fromRGB(0, 255, 255)
    local MonsterColor = Color3.fromRGB(255, 50, 50)
    local MonsterNametagColor = Color3.fromRGB(255, 100, 100)
    local ItemColor = Color3.fromRGB(255, 255, 0)
    local ItemNametagColor = Color3.fromRGB(255, 255, 100)
    local ResearchColor = Color3.fromRGB(0, 255, 0)
    local ResearchNametagColor = Color3.fromRGB(100, 255, 100)
    local ActiveHighlights, ActiveBillboards = {}, {}
    local NoclipEnabled, NoclipConnection = false, nil
    local DisabledColliders = {}
    local AutoSkillcheckEnabled, AutoBarnabyEnabled = false, false
    local SkillCheckHooked = false
    local lastJumpTime = 0

    local AssetsFolder = workspace:FindFirstChild("GigiHubAssets") or Instance.new("Folder", workspace)
    AssetsFolder.Name = "GigiHubAssets"

    -- Helper functions
    local function getCleanMonsterName(m) return string.gsub(m.Name, "Monster", "") end
    local function getHighestPoint(model)
        local hum = model:FindFirstChildOfClass("Humanoid")
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.Position.Y + (hum and hum.HipHeight or 3) + 1 end
        local highest = -math.huge
        for _, p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "HumanoidRootPart" then
                local top = (p.CFrame * CFrame.new(0, p.Size.Y/2, 0)).Position
                if top.Y > highest then highest = top.Y end
            end
        end
        if highest == -math.huge then return model:GetPivot().Position.Y + 3 end
        return math.min(highest, model:GetPivot().Position.Y + 10)
    end
    local function createNameTag(model, name, color)
        local bb = Instance.new("BillboardGui")
        bb.Name = "NameTag"; bb.Adornee = model; bb.Size = UDim2.new(6, 0, 1.5, 0); bb.AlwaysOnTop = true; bb.MaxDistance = math.huge
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, 0, 1, 0); tl.BackgroundTransparency = 1; tl.Text = name; tl.TextColor3 = color or Color3.new(1,1,1)
        tl.TextStrokeTransparency = 0; tl.TextStrokeColor3 = Color3.new(0,0,0); tl.Font = Enum.Font.FredokaOne; tl.TextSize = 32
        tl.Parent = bb; bb.Parent = AssetsFolder
        local hp = getHighestPoint(model); local pivot = model:GetPivot().Position
        bb.StudsOffset = Vector3.new(0, hp - pivot.Y + 1, 0)
        return bb
    end
    local function updateBillboardPositions()
        for i = #ActiveBillboards, 1, -1 do
            local bb = ActiveBillboards[i]
            if bb and bb.Parent and bb.Adornee and bb.Adornee.Parent then
                local hp = getHighestPoint(bb.Adornee); local pivot = bb.Adornee:GetPivot().Position
                bb.StudsOffset = Vector3.new(0, hp - pivot.Y + 1, 0)
            else if bb and bb.Parent then bb:Destroy() end; table.remove(ActiveBillboards, i) end
        end
    end
    local function createHighlight(obj, col)
        local hl = Instance.new("Highlight")
        hl.Name = "ESP_Highlight"; hl.FillColor = col; hl.FillTransparency = ESPTransparency
        hl.OutlineColor = Color3.new(1,1,1); hl.OutlineTransparency = 0; hl.Adornee = obj; hl.Parent = AssetsFolder
        return hl
    end
    local function cleanupESP()
        for _, h in ipairs(ActiveHighlights) do if h and h.Parent then h:Destroy() end end
        table.clear(ActiveHighlights)
        for _, b in ipairs(ActiveBillboards) do if b and b.Parent then b:Destroy() end end
        table.clear(ActiveBillboards)
    end
    local function getItemName(model)
        if model.Name == "ResearchCapsule" then
            local prompt = model:FindFirstChild("Prompt")
            if prompt then
                local mv = prompt:FindFirstChild("Monster")
                if mv and mv:IsA("StringValue") then
                    return "Research - " .. string.gsub(mv.Value, "Monster", "")
                end
            end
        end
        return model.Name
    end
    local function processESP()
        local cr = workspace:FindFirstChild("CurrentRoom"); if not cr then return end
        for _, model in ipairs(cr:GetChildren()) do
            if model:IsA("Model") then
                if GeneratorESPEnabled then
                    local gens = model:FindFirstChild("Generators")
                    if gens then for _, g in ipairs(gens:GetChildren()) do if g:IsA("Model") then
                        local found = false
                        for _, hl in ipairs(ActiveHighlights) do if hl and hl.Adornee == g then found = true break end end
                        if not found then table.insert(ActiveHighlights, createHighlight(g, GeneratorColor)) end
                    end end end
                end
                if MonsterESPEnabled then
                    local mons = model:FindFirstChild("Monsters")
                    if mons then for _, m in ipairs(mons:GetChildren()) do if m:IsA("Model") then
                        local found = false
                        for _, hl in ipairs(ActiveHighlights) do if hl and hl.Adornee == m then found = true break end end
                        if not found then
                            table.insert(ActiveHighlights, createHighlight(m, MonsterColor))
                            if MonsterNametagsEnabled then table.insert(ActiveBillboards, createNameTag(m, getCleanMonsterName(m), MonsterNametagColor)) end
                        end
                    end end end
                end
                if ItemESPEnabled then
                    local items = model:FindFirstChild("Items")
                    if items then for _, it in ipairs(items:GetChildren()) do if it:IsA("Model") then
                        local found = false
                        for _, hl in ipairs(ActiveHighlights) do if hl and hl.Adornee == it then found = true break end end
                        if not found then
                            local iname = getItemName(it)
                            local hcol, ncol = ItemColor, ItemNametagColor
                            if it.Name == "ResearchCapsule" then hcol, ncol = ResearchColor, ResearchNametagColor end
                            table.insert(ActiveHighlights, createHighlight(it, hcol))
                            if ItemNametagsEnabled then table.insert(ActiveBillboards, createNameTag(it, iname, ncol)) end
                        end
                    end end end
                end
            end
        end
    end
    local fullRefresh = function() cleanupESP(); processESP() end
    local function updateHighlightTransparency()
        for _, hl in ipairs(ActiveHighlights) do if hl and hl.Parent then hl.FillTransparency = ESPTransparency end end
    end
    local function monitorFolder(f)
        if not f then return end
        f.ChildAdded:Connect(function(item) if item:IsA("Model") then task.wait(0.1); processESP() end end)
        f.ChildRemoved:Connect(function(item) if item:IsA("Model") then fullRefresh() end end)
    end
    local function monitorModel(m)
        if not m then return end
        m.ChildAdded:Connect(function(f)
            if f.Name == "Generators" or f.Name == "Monsters" or f.Name == "Items" then task.wait(0.1); processESP(); monitorFolder(f) end
        end)
        m.ChildRemoved:Connect(function(f)
            if f.Name == "Generators" or f.Name == "Monsters" or f.Name == "Items" then fullRefresh() end
        end)
        for _, fn in ipairs({"Generators","Monsters","Items"}) do local fo = m:FindFirstChild(fn) if fo then monitorFolder(fo) end end
    end
    local function monitorCurrentRoom(cr)
        if not cr then return end
        cr.ChildAdded:Connect(function(m) if m:IsA("Model") then task.wait(0.1); processESP(); monitorModel(m) end end)
        cr.ChildRemoved:Connect(function(m) if m:IsA("Model") then fullRefresh() end end)
        for _, m in ipairs(cr:GetChildren()) do if m:IsA("Model") then monitorModel(m) end end
    end

    -- Noclip (fixed to include all relevant objects)
    local function shouldDisableCollider(obj)
        if obj:IsA("BasePart") then
            if obj.Name == "NoClip" or obj.Name == "CylinderCollider" or obj.Name == "NoClip_Collider" then return true end
        end
        if obj:IsA("Model") then
            local n = obj.Name
            if n == "Wall" or n == "ShortWall" or n == "WindowWall" or n == "RopeWall" or n == "Counter" or n == "New_Crate" then return true end
            for _, d in ipairs(obj:GetDescendants()) do if d:IsA("BasePart") and d.Name == "NoClip_Collider" then return true end end
        end
        return false
    end
    local function disableCollidersInObject(obj)
        if shouldDisableCollider(obj) then
            if obj:IsA("BasePart") and obj.CanCollide then obj.CanCollide = false; table.insert(DisabledColliders, obj)
            elseif obj:IsA("Model") then
                for _, ch in ipairs(obj:GetDescendants()) do
                    if ch:IsA("BasePart") and ch.CanCollide then ch.CanCollide = false; table.insert(DisabledColliders, ch) end
                end
            end
        end
    end
    local function findAndDisableColliders()
        for _, d in ipairs(workspace:GetDescendants()) do disableCollidersInObject(d) end
    end
    local function enableNoclip()
        if NoclipConnection then NoclipConnection:Disconnect() end
        table.clear(DisabledColliders); findAndDisableColliders()
        NoclipConnection = RunService.Stepped:Connect(function() if NoclipEnabled then findAndDisableColliders() end end)
        workspace.DescendantAdded:Connect(function(d) if NoclipEnabled then task.wait(0.1); disableCollidersInObject(d) end end)
    end
    local function disableNoclip()
        if NoclipConnection then NoclipConnection:Disconnect(); NoclipConnection = nil end
        for _, p in ipairs(DisabledColliders) do if p and p.Parent then p.CanCollide = true end end
        table.clear(DisabledColliders)
    end

    -- AUTO SKILLCHECK (UI detection fixed: search ALL PlayerGui descendants)
    local function findInPlayerGui(name)
        for _, d in ipairs(PlayerGui:GetDescendants()) do if d.Name == name then return d end end
        return nil
    end
    local function autoCompleteHorizontal()
        local skillCheckFrame = findInPlayerGui("SkillCheckFrame")
        if not skillCheckFrame or not skillCheckFrame.Visible then return end
        local marker = skillCheckFrame:FindFirstChild("Marker")
        local goldArea = skillCheckFrame:FindFirstChild("GoldArea")
        local requiredArea = skillCheckFrame:FindFirstChild("RequiredArea")
        local calibrate = findInPlayerGui("Calibrate")
        if not (marker and goldArea and calibrate) then return end
        -- Destroy marker tween
        for _, tw in ipairs(TweenService:GetTweensOn(marker)) do tw:Destroy() end
        if requiredArea then goldArea.Size = UDim2.new(1,0,1,0); goldArea.Position = UDim2.new(0,0,0,0) end
        marker.Position = UDim2.new(0.5, 0, marker.Position.Y.Scale, 0)
        if calibrate.Visible then calibrate.Activated:Fire() end
        -- Simulate Space
        UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard, UserInputState = Enum.UserInputState.Begin}, false)
        -- Fake feedback
        local correctSound = PlayerGui:FindFirstChild("ScreenGui") and PlayerGui.ScreenGui:FindFirstChild("Correct")
        if correctSound then correctSound:Stop(); correctSound:Play() end
        Fluent:Notify({ Title = "Skillcheck", Content = "Great Job! (auto)", Duration = 1 })
    end
    local function autoCompleteCircle()
        local circleGui = PlayerGui:FindFirstChild("CircleSkillCheckGui")
        if not circleGui then return end
        local frame = circleGui:FindFirstChild("SkillCheckFrame") or (circleGui:FindFirstChild("Container") and circleGui.Container.Parent)
        if not frame or not frame.Visible then return end
        local container = frame:FindFirstChild("Container")
        if not container then return end
        local tapBtn = container:FindFirstChild("CircleClickHandler")
        if not tapBtn or not tapBtn.Visible then return end
        local shrink = container:FindFirstChild("ShrinkingCircle")
        if shrink then
            for _, tw in ipairs(TweenService:GetTweensOn(shrink)) do tw:Destroy() end
            local yellow = container:FindFirstChild("YellowCircle")
            shrink.Size = yellow and yellow.Size or UDim2.new(0,0,0,0)
        end
        tapBtn.Activated:Fire()
        UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard, UserInputState = Enum.UserInputState.Begin}, false)
    end
    local function autoCompleteTreadmill()
        local tmill = PlayerGui:FindFirstChild("TreadmillTapSkillCheckGui")
        if not tmill then return end
        local frame = tmill:FindFirstChild("TapSkillCheckFrame")
        if not frame or not frame.Visible then return end
        local container = frame:FindFirstChild("Container")
        if not container then return end
        local tapBtn = container:FindFirstChild("TapButton")
        if not tapBtn or not tapBtn.Visible then return end
        for _ = 1, 12 do tapBtn.Activated:Fire(); task.wait(0.01) end
        for _ = 1, 12 do
            UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard, UserInputState = Enum.UserInputState.Begin}, false)
            task.wait(0.01)
            UserInputService.InputEnded:Fire({KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard, UserInputState = Enum.UserInputState.End}, false)
            task.wait(0.01)
        end
    end

    -- AUTO BARNABY (smarter jump logic)
    local prevFishY = nil
    local function autoPlayBarnaby()
        local now = tick()
        if now - lastJumpTime < 0.06 then return end
        for _, gui in ipairs(PlayerGui:GetChildren()) do
            if gui:GetAttribute("BarnabyArcadeSession") then
                local gw = gui:FindFirstChild("GameWindow")
                if not gw then continue end
                local vp = gw:FindFirstChild("ViewportFrame")
                if not vp then continue end
                local wm = vp:FindFirstChild("WorldModel")
                if not wm then continue end
                local fish = nil; local obstacles = {}
                for _, child in ipairs(wm:GetChildren()) do
                    if child:IsA("Model") then
                        if child:FindFirstChild("Barnaby") or child.Name:lower():find("fish") then fish = child
                        elseif child.Name:lower():find("obstacle") or child.Name:lower():find("seaweed") then table.insert(obstacles, child) end
                    end
                end
                if not fish or not fish.PrimaryPart then return end
                local fishY = fish.PrimaryPart.Position.Y
                local fishX = fish.PrimaryPart.Position.X
                local targetGapY = nil; local minDist = math.huge
                for _, obs in ipairs(obstacles) do
                    if obs.PrimaryPart then
                        local dist = obs.PrimaryPart.Position.X - fishX
                        if dist > 0 and dist < minDist then minDist = dist; targetGapY = obs:GetAttribute("GapY") end
                    end
                end
                local shouldJump = false
                if targetGapY then
                    -- jump if below the gap center by more than 4 studs
                    if fishY < targetGapY - 4 then shouldJump = true
                    elseif prevFishY and fishY < prevFishY and fishY < targetGapY then shouldJump = true end -- falling and below gap
                else
                    -- no gap ahead, just keep fish from hitting bottom
                    if fishY < -10 then shouldJump = true end
                end
                prevFishY = fishY
                if shouldJump then
                    lastJumpTime = now
                    local mobile = gw:FindFirstChild("Mobile")
                    if mobile then mobile.MouseButton1Down:Fire() end
                    UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard, UserInputState = Enum.UserInputState.Begin}, false)
                end
            end
        end
    end

    -- Main loop
    RunService.RenderStepped:Connect(function()
        if AutoSkillcheckEnabled then autoCompleteHorizontal(); autoCompleteCircle(); autoCompleteTreadmill() end
        if AutoBarnabyEnabled then autoPlayBarnaby() end
    end)

    workspace.ChildAdded:Connect(function(child) if child.Name == "CurrentRoom" then task.wait(0.1); processESP(); monitorCurrentRoom(child) end end)
    workspace.ChildRemoved:Connect(function(child) if child.Name == "CurrentRoom" then cleanupESP() end end)
    local existingRoom = workspace:FindFirstChild("CurrentRoom")
    if existingRoom then monitorCurrentRoom(existingRoom); task.wait(0.1); processESP() end

    RunService.Heartbeat:Connect(function() if #ActiveBillboards > 0 then updateBillboardPositions() end end)
    RunService.RenderStepped:Connect(function() if #ActiveBillboards > 0 then updateBillboardPositions() end end)

    -- UI toggles
    GeneratorSection:AddToggle("GeneratorESP", { Title = "Enable Generator ESP", Description = "Highlights generators", Default = false, Callback = function(v) GeneratorESPEnabled = v; fullRefresh() end })
    GeneratorSection:AddColorpicker("GeneratorColor", { Title = "Generator Color", Default = GeneratorColor, Callback = function(v) GeneratorColor = v; fullRefresh() end })
    MonsterSection:AddToggle("MonsterESP", { Title = "Enable Monster ESP", Description = "Highlights monsters", Default = false, Callback = function(v) MonsterESPEnabled = v; fullRefresh() end })
    MonsterSection:AddToggle("MonsterNametags", { Title = "Show Nametags", Description = "Nametags above monsters", Default = true, Callback = function(v) MonsterNametagsEnabled = v; fullRefresh() end })
    MonsterSection:AddColorpicker("MonsterColor", { Title = "Highlight Color", Default = MonsterColor, Callback = function(v) MonsterColor = v; fullRefresh() end })
    MonsterSection:AddColorpicker("MonsterNametagColor", { Title = "Nametag Color", Default = MonsterNametagColor, Callback = function(v) MonsterNametagColor = v; fullRefresh() end })
    ItemSection:AddToggle("ItemESP", { Title = "Enable Item ESP", Description = "Highlights items", Default = false, Callback = function(v) ItemESPEnabled = v; fullRefresh() end })
    ItemSection:AddToggle("ItemNametags", { Title = "Show Nametags", Description = "Nametags above items", Default = true, Callback = function(v) ItemNametagsEnabled = v; fullRefresh() end })
    ItemSection:AddColorpicker("ItemColor", { Title = "Highlight Color", Default = ItemColor, Callback = function(v) ItemColor = v; fullRefresh() end })
    ItemSection:AddColorpicker("ItemNametagColor", { Title = "Nametag Color", Default = ItemNametagColor, Callback = function(v) ItemNametagColor = v; fullRefresh() end })
    ItemSection:AddColorpicker("ResearchColor", { Title = "Research Capsule Color", Default = ResearchColor, Callback = function(v) ResearchColor = v; fullRefresh() end })
    ItemSection:AddColorpicker("ResearchNametagColor", { Title = "Research Nametag Color", Default = ResearchNametagColor, Callback = function(v) ResearchNametagColor = v; fullRefresh() end })
    local ESPSettingsSection = Tabs.ESP:AddSection("ESP Settings")
    ESPSettingsSection:AddSlider("ESPTransparency", { Title = "ESP Transparency", Description = "Highlight transparency", Default = 0.5, Min = 0, Max = 1, Rounding = 1, Callback = function(v) ESPTransparency = v; updateHighlightTransparency() end })

    -- Speed modifier
    local WalkSpeedMultiplier, RunSpeedMultiplier = 0, 0
    local SpeedEnabled = false; local SpeedConnection = nil; local isSprinting = false
    local function getCharacter() return LocalPlayer.Character end
    local function getHumanoid() local c = getCharacter() if c then return c:FindFirstChildOfClass("Humanoid") end end
    local function getStats()
        local c = getCharacter(); if not c then return nil end
        local igp = workspace:FindFirstChild("InGamePlayers"); if not igp then return nil end
        local pm = igp:FindFirstChild(c.Name); if not pm then return nil end
        return pm:FindFirstChild("Stats")
    end
    local function getBaseSpeeds()
        local bw, br = 16, 20
        local st = getStats()
        if st then
            local wv = st:FindFirstChild("WalkSpeed"); if wv and wv:IsA("NumberValue") then bw = wv.Value end
            local rv = st:FindFirstChild("RunSpeed"); if rv and rv:IsA("NumberValue") then br = rv.Value end
        end
        return bw, br
    end
    local function applySpeed()
        local hum = getHumanoid(); if not hum or not SpeedEnabled then return end
        local st = getStats(); if not st then return end
        local bw, br = getBaseSpeeds()
        local sv = st:FindFirstChild("Sprinting"); if sv and sv:IsA("BoolValue") then isSprinting = sv.Value end
        hum.WalkSpeed = isSprinting and br*(1+RunSpeedMultiplier) or bw*(1+WalkSpeedMultiplier)
    end
    local function resetSpeed()
        local hum = getHumanoid(); if not hum then return end
        local st = getStats(); if not st then return end
        local wv = st:FindFirstChild("WalkSpeed"); local rv = st:FindFirstChild("RunSpeed")
        local sp = st:FindFirstChild("Sprinting"); local sprinting = sp and sp:IsA("BoolValue") and sp.Value
        if sprinting and rv and rv:IsA("NumberValue") then hum.WalkSpeed = rv.Value
        elseif wv and wv:IsA("NumberValue") then hum.WalkSpeed = wv.Value end
    end
    local function startSpeedLoop() if SpeedConnection then SpeedConnection:Disconnect() end; SpeedConnection = RunService.Heartbeat:Connect(function() if SpeedEnabled then applySpeed() end end) end
    local function stopSpeedLoop() if SpeedConnection then SpeedConnection:Disconnect(); SpeedConnection = nil end end
    LocalPlayer.CharacterAdded:Connect(function() isSprinting = false; if SpeedEnabled then task.wait(0.5); startSpeedLoop() end end)
    PlayerSection:AddToggle("SpeedToggle", { Title = "Enable Speed Modifier", Description = "Toggle speed mod", Default = false, Callback = function(v) SpeedEnabled = v; if v then startSpeedLoop() else stopSpeedLoop(); resetSpeed() end end })
    local baseWalk, baseRun = getBaseSpeeds()
    PlayerSection:AddSlider("WalkSpeed", { Title = "Walk Speed", Description = "Base: "..string.format("%.1f",baseWalk), Default = baseWalk, Min = 0, Max = baseWalk*10, Rounding = 0, Callback = function(v) WalkSpeedMultiplier = (v - baseWalk)/baseWalk end })
    PlayerSection:AddSlider("RunSpeed", { Title = "Run Speed", Description = "Base: "..string.format("%.1f",baseRun), Default = baseRun, Min = 0, Max = baseRun*10, Rounding = 0, Callback = function(v) RunSpeedMultiplier = (v - baseRun)/baseRun end })

    NoclipSection:AddToggle("NoclipToggle", { Title = "Enable Noclip", Description = "Walk through walls & colliders", Default = false, Callback = function(v) NoclipEnabled = v; if v then enableNoclip() else disableNoclip() end end })

    AutoSkillcheckSection:AddToggle("AutoSkillcheckToggle", { Title = "Auto Complete Skillchecks", Description = "Instantly passes all minigames", Default = false, Callback = function(v) AutoSkillcheckEnabled = v end })
    AutoSkillcheckSection:AddToggle("AutoBarnabyToggle", { Title = "Auto Play Barnaby", Description = "Smartly dodges and collects coin DEBUGGGGGGs", Default = false, Callback = function(v) AutoBarnabyEnabled = v end })
end

if not IsLobby and not IsGame then
    if Tabs.Client then Window:SelectTab(Tabs.Client) end
    local UnknownSection = Tabs.Client:AddSection("Unknown Place")
    UnknownSection:AddParagraph({ Title = "Unknown Place", Content = "This script is designed for specific places. Place ID: "..tostring(CurrentPlaceId) })
end

Fluent:Notify({ Title = "Loaded", Content = "Gigi's World HUB loaded for "..placeSuffix, Duration = 3 })
