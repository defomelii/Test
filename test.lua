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
if IsLobby then
    placeSuffix = " [Lobby]"
elseif IsGame then
    placeSuffix = " [Game]"
end

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

if IsLobby then
    if Tabs.Client then Window:SelectTab(Tabs.Client) end
    
    local ClientSection = Tabs.Client:AddSection("Visual Unlocking")

    local isToonActivated = false
    local isSkinActivated = false

    local MainGui
    local CharacterFrame
    local SkinFrame
    local characterScrollingFrame
    local skinHolder

    local toonConnection
    local skinFrameConnection
    local towerValueConnection
    local confirmConnection

    local buttonConnections = {}
    local allSkins = {}
    local modelCache = {}
    local PlaySoundFunc = function() end

    local SkinChangeEvent = nil
    local CreateTowerClone = nil

    local function getMainGui()
        MainGui = MainGui or PlayerGui:FindFirstChild("MainGui")
        return MainGui
    end

    local function getCharacterScrollingFrame()
        local mainGui = getMainGui()
        if not mainGui then return nil end
        CharacterFrame = mainGui:FindFirstChild("CharacterFrame")
        if not CharacterFrame then return nil end
        return CharacterFrame:FindFirstChild("ScrollingFrame")
    end

    local function getSkinFrameParts()
        local mainGui = getMainGui()
        if not mainGui then return false end
        CharacterFrame = mainGui:FindFirstChild("CharacterFrame")
        SkinFrame = mainGui:FindFirstChild("SkinFrame")
        if not CharacterFrame or not SkinFrame then return false end
        skinHolder = SkinFrame:FindFirstChild("SkinHolderFrame")
        return skinHolder ~= nil
    end

    local function forceButtonVisible(button)
        if not button:IsA("GuiButton") or button.Name == "Template" then return end
        button.Visible = true
        button.Active = true
        if buttonConnections[button] then buttonConnections[button]:Disconnect() end
        buttonConnections[button] = button:GetPropertyChangedSignal("Visible"):Connect(function()
            if isToonActivated and button.Parent and not button.Visible then
                button.Visible = true
            end
        end)
    end

    local function forceShowAllToons()
        characterScrollingFrame = getCharacterScrollingFrame()
        if not characterScrollingFrame then return end
        for _, child in ipairs(characterScrollingFrame:GetChildren()) do
            forceButtonVisible(child)
        end
    end

    local function activateToonUnlocker()
        if isToonActivated then return end
        isToonActivated = true
        forceShowAllToons()
        if not characterScrollingFrame then
            isToonActivated = false
            Fluent:Notify({ Title = "Error", Content = "Character scrolling frame not found", Duration = 4 })
            return
        end
        if toonConnection then toonConnection:Disconnect() end
        toonConnection = characterScrollingFrame.ChildAdded:Connect(function(child)
            task.defer(function() forceButtonVisible(child) end)
        end)
        Fluent:Notify({ Title = "Toon Visuals", Content = "All toon buttons are being forced visible", Duration = 3 })
    end

    local function findSkinFolder()
        local sharedData = ReplicatedStorage:FindFirstChild("SharedData")
        if sharedData then
            local skinData = sharedData:FindFirstChild("SkinData")
            if skinData then return skinData end
        end
        return ReplicatedStorage:FindFirstChild("SkinData") or ReplicatedStorage:FindFirstChild("Skins") or ReplicatedStorage:FindFirstChild("SkinModules")
    end

    local function loadSkins()
        local folder = findSkinFolder()
        if not folder then return false end
        table.clear(allSkins)
        for _, characterFolder in ipairs(folder:GetChildren()) do
            if characterFolder:IsA("Folder") then
                for _, skinModule in ipairs(characterFolder:GetChildren()) do
                    if skinModule:IsA("ModuleScript") then
                        table.insert(allSkins, { name = skinModule.Name, character = characterFolder.Name })
                    end
                end
            end
        end
        return #allSkins > 0
    end

    local function getCurrentCharacter()
        if not CharacterFrame then return nil end
        local describeFrame = CharacterFrame:FindFirstChild("DescribeFrame")
        if not describeFrame then return nil end
        local value = describeFrame:GetAttribute("TowerValue")
        if not value or value == "None" then return nil end
        return value
    end

    local function clearGeneratedSkinButtons()
        if not skinHolder then return end
        for _, child in ipairs(skinHolder:GetChildren()) do
            if child:IsA("GuiButton") and child.Name ~= "Template" and child.Name ~= "Default" then
                child:Destroy()
            end
        end
    end

    local function preloadSkin(character, skin)
        if not CreateTowerClone then return nil end
        if not modelCache[character] then modelCache[character] = {} end
        if modelCache[character][skin] then return modelCache[character][skin] end
        local success, model = pcall(function() return CreateTowerClone:InvokeServer(character, skin) end)
        if success and model then
            modelCache[character][skin] = model:Clone()
            return modelCache[character][skin]
        end
        return nil
    end

    local function previewSkin(character, skin)
        local model = modelCache[character] and modelCache[character][skin]
        if not model then model = preloadSkin(character, skin) end
        if model then
            local workspaceChar = workspace:FindFirstChild("Character")
            if workspaceChar then
                workspaceChar:ClearAllChildren()
            else
                workspaceChar = Instance.new("Model")
                workspaceChar.Name = "Character"
                workspaceChar.Parent = workspace
            end
            local display = model:Clone()
            display.Parent = workspaceChar
            local MasteryPosition = workspace:FindFirstChild("MasteryPosition")
            if MasteryPosition then
                local Humanoid = display:WaitForChild("Humanoid")
                local idleAnim = Humanoid:LoadAnimation(display.Animations.Idle)
                local offset = CFrame.new(0, display.PrimaryPart.Size.Y / 2 + Humanoid.HipHeight, 0)
                display.PrimaryPart.Anchored = true
                display:PivotTo(MasteryPosition.CFrame * offset)
                idleAnim:Play()
            end
            return true
        end
        return false
    end

    local function equipSkin(character, skin)
        if SkinChangeEvent then SkinChangeEvent:FireServer(skin, character) end
        if SkinFrame then SkinFrame.Visible = false end
        local mainGui = getMainGui()
        if mainGui then
            local menu = mainGui:FindFirstChild("Menu")
            local info = mainGui:FindFirstChild("Info")
            if menu then menu.Visible = true end
            if info then info.Visible = true end
        end
    end

    local function createSkinButtons()
        if not getSkinFrameParts() then return end
        local currentCharacter = getCurrentCharacter()
        if not currentCharacter then return end
        local template = skinHolder:FindFirstChild("Template")
        if not template then return end
        clearGeneratedSkinButtons()
        local defaultButton = skinHolder:FindFirstChild("Default")
        if defaultButton then
            defaultButton.Visible = true
            defaultButton.Active = true
            defaultButton.LayoutOrder = 0
        end
        local order = 1
        for _, skinInfo in ipairs(allSkins) do
            if skinInfo.character == currentCharacter then
                local button = template:Clone()
                button.Name = skinInfo.name
                button.Visible = true
                button.Active = true
                button.LayoutOrder = order
                button:SetAttribute("TowerValue", currentCharacter)
                local label = button:FindFirstChild("CharacterName")
                if label then label.Text = skinInfo.name end
                button.Activated:Connect(function()
                    task.spawn(function()
                        preloadSkin(currentCharacter, skinInfo.name)
                        previewSkin(currentCharacter, skinInfo.name)
                        local confirmBtn = SkinFrame:FindFirstChild("ConfirmSkin")
                        if confirmBtn then
                            if confirmConnection then confirmConnection:Disconnect() end
                            confirmBtn.Visible = true
                            confirmConnection = confirmBtn.Activated:Connect(function()
                                equipSkin(currentCharacter, skinInfo.name)
                            end)
                        end
                    end)
                end)
                button.Parent = skinHolder
                order += 1
            end
        end
    end

    local function activateSkinPreviewer()
        if isSkinActivated then return end
        if not getSkinFrameParts() then
            Fluent:Notify({ Title = "Error", Content = "Skin UI not found", Duration = 4 })
            return
        end
        local Events = ReplicatedStorage:FindFirstChild("Events")
        if Events then
            SkinChangeEvent = Events:FindFirstChild("SkinChangeEvent")
            CreateTowerClone = Events:FindFirstChild("CreateTowerClone")
        end
        local mainGui = getMainGui()
        if mainGui then
            local Modules = mainGui:FindFirstChild("Modules")
            if Modules then
                local PlaySoundModule = Modules:FindFirstChild("PlaySound")
                if PlaySoundModule then
                    pcall(function() PlaySoundFunc = require(PlaySoundModule).Play end)
                end
            end
        end
        if not loadSkins() then
            Fluent:Notify({ Title = "Error", Content = "No skin folder/modules found", Duration = 4 })
            return
        end
        isSkinActivated = true
        if skinFrameConnection then skinFrameConnection:Disconnect() end
        skinFrameConnection = SkinFrame:GetPropertyChangedSignal("Visible"):Connect(function()
            if isSkinActivated and SkinFrame.Visible then task.defer(createSkinButtons) end
        end)
        local describeFrame = CharacterFrame:FindFirstChild("DescribeFrame")
        if describeFrame then
            if towerValueConnection then towerValueConnection:Disconnect() end
            towerValueConnection = describeFrame:GetAttributeChangedSignal("TowerValue"):Connect(function()
                if isSkinActivated and SkinFrame.Visible then task.defer(createSkinButtons) end
            end)
        end
        if SkinFrame.Visible then createSkinButtons() end
        Fluent:Notify({ Title = "Skin Visuals", Content = "Skin preview and equip enabled", Duration = 3 })
    end

    ClientSection:AddButton({ Title = "Activate Toon Visuals", Description = "Forces toon buttons visible on the client", Callback = activateToonUnlocker })
    ClientSection:AddButton({ Title = "Activate Skin Visuals", Description = "Adds skin buttons with preview & equip", Callback = activateSkinPreviewer })
end

if IsGame then
    Window:SelectTab(Tabs.ESP)
    
    local GeneratorSection = Tabs.ESP:AddSection("Generator ESP")
    local MonsterSection = Tabs.ESP:AddSection("Monster ESP")
    local ItemSection = Tabs.ESP:AddSection("Item ESP")
    local PlayerSection = Tabs.Player:AddSection("Speed Modifier")
    local NoclipSection = Tabs.Player:AddSection("Noclip")
    local AutoSkillcheckSection = Tabs.Player:AddSection("Auto Skillcheck")

    -- ESP variables
    local GeneratorESPEnabled = false
    local MonsterESPEnabled = false
    local ItemESPEnabled = false
    local MonsterNametagsEnabled = true
    local ItemNametagsEnabled = true
    local ESPTransparency = 0.5
    
    local GeneratorColor = Color3.fromRGB(0, 255, 255)
    local MonsterColor = Color3.fromRGB(255, 50, 50)
    local MonsterNametagColor = Color3.fromRGB(255, 100, 100)
    local ItemColor = Color3.fromRGB(255, 255, 0)
    local ItemNametagColor = Color3.fromRGB(255, 255, 100)
    local ResearchColor = Color3.fromRGB(0, 255, 0)
    local ResearchNametagColor = Color3.fromRGB(100, 255, 100)

    local ActiveHighlights = {}
    local ActiveBillboards = {}
    local NoclipEnabled = false
    local NoclipConnection = nil
    local DisabledColliders = {}
    local AutoSkillcheckEnabled = false
    local AutoBarnabyEnabled = false

    local AssetsFolder = workspace:FindFirstChild("GigiHubAssets")
    if not AssetsFolder then
        AssetsFolder = Instance.new("Folder")
        AssetsFolder.Name = "GigiHubAssets"
        AssetsFolder.Parent = workspace
    end

    -- ESP helper functions
    local function getCleanMonsterName(model)
        return string.gsub(model.Name, "Monster", "")
    end

    local function getHighestPoint(model)
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
        
        if humanoidRootPart then
            local rootY = humanoidRootPart.Position.Y
            local hipHeight = humanoid and humanoid.HipHeight or 3
            return rootY + hipHeight + 1
        end
        
        local highestY = -math.huge
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "HumanoidRootPart" then
                local topCenter = (part.CFrame * CFrame.new(0, part.Size.Y/2, 0)).Position
                if topCenter.Y > highestY then highestY = topCenter.Y end
            end
        end
        
        if highestY == -math.huge then
            return model:GetPivot().Position.Y + 3
        end
        
        return math.min(highestY, model:GetPivot().Position.Y + 10)
    end

    local function createNameTag(model, name, color)
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "NameTag"
        billboard.Adornee = model
        billboard.Size = UDim2.new(6, 0, 1.5, 0)
        billboard.AlwaysOnTop = true
        billboard.MaxDistance = math.huge
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = name
        textLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        textLabel.TextStrokeTransparency = 0
        textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        textLabel.Font = Enum.Font.FredokaOne
        textLabel.TextSize = 32
        textLabel.Parent = billboard
        billboard.Parent = AssetsFolder
        
        local highestPoint = getHighestPoint(model)
        local modelPivot = model:GetPivot().Position
        billboard.StudsOffset = Vector3.new(0, highestPoint - modelPivot.Y + 1, 0)
        
        return billboard
    end

    local function updateBillboardPositions()
        for i = #ActiveBillboards, 1, -1 do
            local billboard = ActiveBillboards[i]
            if billboard and billboard.Parent and billboard.Adornee and billboard.Adornee.Parent then
                local model = billboard.Adornee
                local highestPoint = getHighestPoint(model)
                local modelPivot = model:GetPivot().Position
                billboard.StudsOffset = Vector3.new(0, highestPoint - modelPivot.Y + 1, 0)
            else
                if billboard and billboard.Parent then billboard:Destroy() end
                table.remove(ActiveBillboards, i)
            end
        end
    end

    local function createHighlight(object, color)
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Highlight"
        highlight.FillColor = color
        highlight.FillTransparency = ESPTransparency
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.Adornee = object
        highlight.Parent = AssetsFolder
        return highlight
    end

    local function cleanupESP()
        for _, highlight in ipairs(ActiveHighlights) do
            if highlight and highlight.Parent then highlight:Destroy() end
        end
        table.clear(ActiveHighlights)
        for _, billboard in ipairs(ActiveBillboards) do
            if billboard and billboard.Parent then billboard:Destroy() end
        end
        table.clear(ActiveBillboards)
    end

    local function getItemName(model)
        if model.Name == "ResearchCapsule" then
            local prompt = model:FindFirstChild("Prompt")
            if prompt then
                local monsterValue = prompt:FindFirstChild("Monster")
                if monsterValue and monsterValue:IsA("StringValue") then
                    return "Research - " .. string.gsub(monsterValue.Value, "Monster", "")
                end
            end
        end
        return model.Name
    end

    local function processESP()
        local currentRoom = workspace:FindFirstChild("CurrentRoom")
        if not currentRoom then return end
        for _, model in ipairs(currentRoom:GetChildren()) do
            if model:IsA("Model") then
                if GeneratorESPEnabled then
                    local generators = model:FindFirstChild("Generators")
                    if generators then
                        for _, generator in ipairs(generators:GetChildren()) do
                            if generator:IsA("Model") then
                                local hasHighlight = false
                                for _, hl in ipairs(ActiveHighlights) do
                                    if hl and hl.Adornee == generator then hasHighlight = true break end
                                end
                                if not hasHighlight then
                                    table.insert(ActiveHighlights, createHighlight(generator, GeneratorColor))
                                end
                            end
                        end
                    end
                end
                if MonsterESPEnabled then
                    local monsters = model:FindFirstChild("Monsters")
                    if monsters then
                        for _, monster in ipairs(monsters:GetChildren()) do
                            if monster:IsA("Model") then
                                local hasHighlight = false
                                for _, hl in ipairs(ActiveHighlights) do
                                    if hl and hl.Adornee == monster then hasHighlight = true break end
                                end
                                if not hasHighlight then
                                    table.insert(ActiveHighlights, createHighlight(monster, MonsterColor))
                                    if MonsterNametagsEnabled then
                                        table.insert(ActiveBillboards, createNameTag(monster, getCleanMonsterName(monster), MonsterNametagColor))
                                    end
                                end
                            end
                        end
                    end
                end
                if ItemESPEnabled then
                    local items = model:FindFirstChild("Items")
                    if items then
                        for _, item in ipairs(items:GetChildren()) do
                            if item:IsA("Model") then
                                local hasHighlight = false
                                for _, hl in ipairs(ActiveHighlights) do
                                    if hl and hl.Adornee == item then hasHighlight = true break end
                                end
                                if not hasHighlight then
                                    local itemName = getItemName(item)
                                    local highlightColor = ItemColor
                                    local nameColor = ItemNametagColor
                                    if item.Name == "ResearchCapsule" then
                                        highlightColor = ResearchColor
                                        nameColor = ResearchNametagColor
                                    end
                                    table.insert(ActiveHighlights, createHighlight(item, highlightColor))
                                    if ItemNametagsEnabled then
                                        table.insert(ActiveBillboards, createNameTag(item, itemName, nameColor))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local function fullRefresh()
        cleanupESP()
        processESP()
    end

    local function updateHighlightTransparency()
        for _, highlight in ipairs(ActiveHighlights) do
            if highlight and highlight.Parent then
                highlight.FillTransparency = ESPTransparency
            end
        end
    end

    local function monitorFolder(folder)
        if not folder then return end
        folder.ChildAdded:Connect(function(item)
            if item:IsA("Model") then task.wait(0.1) processESP() end
        end)
        folder.ChildRemoved:Connect(function(item)
            if item:IsA("Model") then fullRefresh() end
        end)
    end

    local function monitorModel(model)
        if not model then return end
        model.ChildAdded:Connect(function(folder)
            if folder.Name == "Generators" or folder.Name == "Monsters" or folder.Name == "Items" then
                task.wait(0.1) processESP() monitorFolder(folder)
            end
        end)
        model.ChildRemoved:Connect(function(folder)
            if folder.Name == "Generators" or folder.Name == "Monsters" or folder.Name == "Items" then fullRefresh() end
        end)
        for _, folderName in ipairs({"Generators", "Monsters", "Items"}) do
            local folder = model:FindFirstChild(folderName)
            if folder then monitorFolder(folder) end
        end
    end

    local function monitorCurrentRoom(currentRoom)
        if not currentRoom then return end
        currentRoom.ChildAdded:Connect(function(model)
            if model:IsA("Model") then task.wait(0.1) processESP() monitorModel(model) end
        end)
        currentRoom.ChildRemoved:Connect(function(model)
            if model:IsA("Model") then fullRefresh() end
        end)
        for _, model in ipairs(currentRoom:GetChildren()) do
            if model:IsA("Model") then monitorModel(model) end
        end
    end

    local function shouldDisableCollider(object)
        if object:IsA("BasePart") and (object.Name == "NoClip" or object.Name == "CylinderCollider" or object.Name == "NoClip_Collider") then
            return true
        end
        if object:IsA("Model") and (object.Name == "Wall" or object.Name == "ShortWall" or object.Name == "WindowWall") then
            return true
        end
        return false
    end

    local function disableCollidersInObject(object)
        if shouldDisableCollider(object) then
            if object:IsA("BasePart") and object.CanCollide then
                object.CanCollide = false
                table.insert(DisabledColliders, object)
            elseif object:IsA("Model") then
                for _, child in ipairs(object:GetDescendants()) do
                    if child:IsA("BasePart") and child.CanCollide then
                        child.CanCollide = false
                        table.insert(DisabledColliders, child)
                    end
                end
            end
        end
    end

    local function findAndDisableColliders()
        for _, descendant in ipairs(workspace:GetDescendants()) do
            disableCollidersInObject(descendant)
        end
    end

    local function enableNoclip()
        if NoclipConnection then NoclipConnection:Disconnect() end
        table.clear(DisabledColliders)
        findAndDisableColliders()
        NoclipConnection = RunService.Stepped:Connect(function()
            if not NoclipEnabled then return end
            findAndDisableColliders()
        end)
        workspace.DescendantAdded:Connect(function(descendant)
            if NoclipEnabled then
                task.wait(0.1)
                disableCollidersInObject(descendant)
            end
        end)
    end

    local function disableNoclip()
        if NoclipConnection then
            NoclipConnection:Disconnect()
            NoclipConnection = nil
        end
        for _, part in ipairs(DisabledColliders) do
            if part and part.Parent then
                part.CanCollide = true
            end
        end
        table.clear(DisabledColliders)
    end

    -- ================== AUTO SKILLCHECK SYSTEM (WITH DEBUG) ==================
    local function debugPrint(msg)
        -- Use a GUI notification that's visible on screen
        local success, err = pcall(function()
            Fluent:Notify({ Title = "Debug", Content = msg, Duration = 2 })
        end)
        if not success then
            print("[GigiHub Debug] " .. msg)
        end
    end

    local function autoCompleteHorizontal()
        local mainGui = PlayerGui:FindFirstChild("MainGui")
        if not mainGui then return end
        local menu = mainGui:FindFirstChild("Menu")
        if not menu then return end

        local skillCheckFrame = menu:FindFirstChild("SkillCheckFrame")
        if not skillCheckFrame then return end
        if not skillCheckFrame.Visible then return end

        debugPrint("Horizontal skillcheck detected!")

        local marker = skillCheckFrame:FindFirstChild("Marker")
        local goldArea = skillCheckFrame:FindFirstChild("GoldArea")
        local requiredArea = skillCheckFrame:FindFirstChild("RequiredArea")
        local calibrate = menu:FindFirstChild("Calibrate")

        if not marker then debugPrint("Marker missing") return end
        if not goldArea then debugPrint("GoldArea missing") return end
        if not calibrate then debugPrint("Calibrate missing") return end

        local tweens = TweenService:GetTweensOn(marker)
        for _, tween in ipairs(tweens) do
            tween:Destroy()
        end
        debugPrint("Destroyed " .. #tweens .. " tweens on marker")

        if requiredArea then
            goldArea.Size = UDim2.new(1, 0, 1, 0)
            goldArea.Position = UDim2.new(0, 0, 0, 0)
        end

        marker.Position = UDim2.new(0.5, 0, marker.Position.Y.Scale, 0)

        if calibrate.Visible then
            debugPrint("Firing Calibrate button")
            calibrate.Activated:Fire()
            task.spawn(function()
                local fakeInput = {
                    KeyCode = Enum.KeyCode.Space,
                    UserInputType = Enum.UserInputType.Keyboard,
                    UserInputState = Enum.UserInputState.Begin
                }
                UserInputService.InputBegan:Fire(fakeInput, false)
            end)
            debugPrint("Skillcheck auto-completed!")
        else
            debugPrint("Calibrate not visible")
        end
    end

    local function autoCompleteCircle()
        for _, gui in ipairs(PlayerGui:GetChildren()) do
            if gui.Name == "CircleSkillCheckGui" then
                local frame = gui:FindFirstChild("SkillCheckFrame")
                if frame and frame.Visible then
                    debugPrint("Circle skillcheck detected!")
                    local container = frame:FindFirstChild("Container")
                    if container then
                        local tapButton = container:FindFirstChild("CircleClickHandler")
                        if tapButton and tapButton.Visible then
                            local shrinkingCircle = container:FindFirstChild("ShrinkingCircle")
                            if shrinkingCircle then
                                local tweens = TweenService:GetTweensOn(shrinkingCircle)
                                for _, tween in ipairs(tweens) do
                                    tween:Destroy()
                                end
                                local yellowCircle = container:FindFirstChild("YellowCircle")
                                if yellowCircle then
                                    shrinkingCircle.Size = yellowCircle.Size
                                else
                                    shrinkingCircle.Size = UDim2.new(0, 0, 0, 0)
                                end
                            end
                            tapButton.Activated:Fire()
                            task.wait(0.02)
                            UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard, UserInputState = Enum.UserInputState.Begin}, false)
                            debugPrint("Circle skillcheck auto-completed!")
                            return
                        end
                    end
                end
            end
        end
    end

    local function autoCompleteTreadmill()
        for _, gui in ipairs(PlayerGui:GetChildren()) do
            if gui.Name == "TreadmillTapSkillCheckGui" then
                local frame = gui:FindFirstChild("TapSkillCheckFrame")
                if frame and frame.Visible then
                    debugPrint("Treadmill skillcheck detected!")
                    local container = frame:FindFirstChild("Container")
                    if container then
                        local tapButton = container:FindFirstChild("TapButton")
                        if tapButton and tapButton.Visible then
                            for i = 1, 12 do
                                tapButton.Activated:Fire()
                                task.wait(0.01)
                            end
                            for i = 1, 12 do
                                UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard, UserInputState = Enum.UserInputState.Begin}, false)
                                task.wait(0.01)
                                UserInputService.InputEnded:Fire({KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard, UserInputState = Enum.UserInputState.End}, false)
                                task.wait(0.01)
                            end
                            debugPrint("Treadmill skillcheck auto-completed!")
                            return
                        end
                    end
                end
            end
        end
    end

    local function autoPlayBarnaby()
        for _, gui in ipairs(PlayerGui:GetChildren()) do
            if gui:GetAttribute("BarnabyArcadeSession") then
                local gameWindow = gui:FindFirstChild("GameWindow")
                if gameWindow and gameWindow:FindFirstChild("Mobile") then
                    gameWindow.Mobile.MouseButton1Down:Fire()
                end
            end
        end
    end

    RunService.RenderStepped:Connect(function()
        if AutoSkillcheckEnabled then
            autoCompleteHorizontal()
            autoCompleteCircle()
            autoCompleteTreadmill()
        end
        if AutoBarnabyEnabled then
            autoPlayBarnaby()
        end
    end)

    workspace.ChildAdded:Connect(function(child)
        if child.Name == "CurrentRoom" then task.wait(0.1) processESP() monitorCurrentRoom(child) end
    end)
    workspace.ChildRemoved:Connect(function(child)
        if child.Name == "CurrentRoom" then cleanupESP() end
    end)

    local existingRoom = workspace:FindFirstChild("CurrentRoom")
    if existingRoom then monitorCurrentRoom(existingRoom) task.wait(0.1) processESP() end

    RunService.Heartbeat:Connect(function()
        if #ActiveBillboards > 0 then updateBillboardPositions() end
    end)
    RunService.RenderStepped:Connect(function()
        if #ActiveBillboards > 0 then updateBillboardPositions() end
    end)

    GeneratorSection:AddToggle("GeneratorESP", { Title = "Enable Generator ESP", Description = "Highlights all generators", Default = false, Callback = function(value) GeneratorESPEnabled = value fullRefresh() end })
    GeneratorSection:AddColorpicker("GeneratorColor", { Title = "Generator Color", Default = GeneratorColor, Callback = function(value) GeneratorColor = value fullRefresh() end })

    MonsterSection:AddToggle("MonsterESP", { Title = "Enable Monster ESP", Description = "Highlights all monsters", Default = false, Callback = function(value) MonsterESPEnabled = value fullRefresh() end })
    MonsterSection:AddToggle("MonsterNametags", { Title = "Show Nametags", Description = "Show nametags above monsters", Default = true, Callback = function(value) MonsterNametagsEnabled = value fullRefresh() end })
    MonsterSection:AddColorpicker("MonsterColor", { Title = "Highlight Color", Default = MonsterColor, Callback = function(value) MonsterColor = value fullRefresh() end })
    MonsterSection:AddColorpicker("MonsterNametagColor", { Title = "Nametag Color", Default = MonsterNametagColor, Callback = function(value) MonsterNametagColor = value fullRefresh() end })

    ItemSection:AddToggle("ItemESP", { Title = "Enable Item ESP", Description = "Highlights all items", Default = false, Callback = function(value) ItemESPEnabled = value fullRefresh() end })
    ItemSection:AddToggle("ItemNametags", { Title = "Show Nametags", Description = "Show nametags above items", Default = true, Callback = function(value) ItemNametagsEnabled = value fullRefresh() end })
    ItemSection:AddColorpicker("ItemColor", { Title = "Highlight Color", Default = ItemColor, Callback = function(value) ItemColor = value fullRefresh() end })
    ItemSection:AddColorpicker("ItemNametagColor", { Title = "Nametag Color", Default = ItemNametagColor, Callback = function(value) ItemNametagColor = value fullRefresh() end })
    ItemSection:AddColorpicker("ResearchColor", { Title = "Research Capsule Color", Default = ResearchColor, Callback = function(value) ResearchColor = value fullRefresh() end })
    ItemSection:AddColorpicker("ResearchNametagColor", { Title = "Research Nametag Color", Default = ResearchNametagColor, Callback = function(value) ResearchNametagColor = value fullRefresh() end })

    local ESPSettingsSection = Tabs.ESP:AddSection("ESP Settings")
    ESPSettingsSection:AddSlider("ESPTransparency", {
        Title = "ESP Transparency",
        Description = "Adjust highlight transparency",
        Default = 0.5,
        Min = 0,
        Max = 1,
        Rounding = 1,
        Callback = function(value)
            ESPTransparency = value
            updateHighlightTransparency()
        end
    })

    -- Speed modifier
    local WalkSpeedMultiplier = 0
    local RunSpeedMultiplier = 0
    local SpeedEnabled = false
    local SpeedConnection = nil
    local isSprinting = false

    local function getCharacter()
        return LocalPlayer.Character
    end

    local function getHumanoid()
        local char = getCharacter()
        if char then return char:FindFirstChildOfClass("Humanoid") end
        return nil
    end

    local function getStats()
        local char = getCharacter()
        if not char then return nil end
        local inGamePlayers = workspace:FindFirstChild("InGamePlayers")
        if not inGamePlayers then return nil end
        local playerModel = inGamePlayers:FindFirstChild(char.Name)
        if not playerModel then return nil end
        return playerModel:FindFirstChild("Stats")
    end

    local function getBaseSpeeds()
        local baseWalk = 16
        local baseRun = 20
        local stats = getStats()
        if stats then
            local walkSpeedValue = stats:FindFirstChild("WalkSpeed")
            local runSpeedValue = stats:FindFirstChild("RunSpeed")
            if walkSpeedValue and walkSpeedValue:IsA("NumberValue") then baseWalk = walkSpeedValue.Value end
            if runSpeedValue and runSpeedValue:IsA("NumberValue") then baseRun = runSpeedValue.Value end
        end
        return baseWalk, baseRun
    end

    local function applySpeed()
        local humanoid = getHumanoid()
        if not humanoid then return end
        if not SpeedEnabled then return end
        local stats = getStats()
        if not stats then return end
        local baseWalk, baseRun = getBaseSpeeds()
        local sprintingValue = stats:FindFirstChild("Sprinting")
        if sprintingValue and sprintingValue:IsA("BoolValue") then isSprinting = sprintingValue.Value end
        if isSprinting then
            humanoid.WalkSpeed = baseRun * (1 + RunSpeedMultiplier)
        else
            humanoid.WalkSpeed = baseWalk * (1 + WalkSpeedMultiplier)
        end
    end

    local function resetSpeed()
        local humanoid = getHumanoid()
        if not humanoid then return end
        local stats = getStats()
        if not stats then return end
        local walkSpeedValue = stats:FindFirstChild("WalkSpeed")
        local runSpeedValue = stats:FindFirstChild("RunSpeed")
        local sprintingValue = stats:FindFirstChild("Sprinting")
        local sprinting = false
        if sprintingValue and sprintingValue:IsA("BoolValue") then sprinting = sprintingValue.Value end
        if sprinting and runSpeedValue and runSpeedValue:IsA("NumberValue") then
            humanoid.WalkSpeed = runSpeedValue.Value
        elseif walkSpeedValue and walkSpeedValue:IsA("NumberValue") then
            humanoid.WalkSpeed = walkSpeedValue.Value
        end
    end

    local function startSpeedLoop()
        if SpeedConnection then SpeedConnection:Disconnect() end
        SpeedConnection = RunService.Heartbeat:Connect(function()
            if SpeedEnabled then applySpeed() end
        end)
    end

    local function stopSpeedLoop()
        if SpeedConnection then SpeedConnection:Disconnect() SpeedConnection = nil end
    end

    LocalPlayer.CharacterAdded:Connect(function(char)
        isSprinting = false
        if SpeedEnabled then task.wait(0.5) startSpeedLoop() end
    end)

    PlayerSection:AddToggle("SpeedToggle", { Title = "Enable Speed Modifier", Description = "Toggle speed modification on/off", Default = false, Callback = function(value)
        SpeedEnabled = value
        if value then startSpeedLoop() else stopSpeedLoop() resetSpeed() end
    end })

    local baseWalk, baseRun = getBaseSpeeds()

    PlayerSection:AddSlider("WalkSpeed", {
        Title = "Walk Speed",
        Description = "Base: " .. string.format("%.1f", baseWalk),
        Default = baseWalk,
        Min = 0,
        Max = baseWalk * 10,
        Rounding = 0,
        Callback = function(value)
            WalkSpeedMultiplier = (value - baseWalk) / baseWalk
        end
    })

    PlayerSection:AddSlider("RunSpeed", {
        Title = "Run Speed",
        Description = "Base: " .. string.format("%.1f", baseRun),
        Default = baseRun,
        Min = 0,
        Max = baseRun * 10,
        Rounding = 0,
        Callback = function(value)
            RunSpeedMultiplier = (value - baseRun) / baseRun
        end
    })

    NoclipSection:AddToggle("NoclipToggle", { Title = "Enable Noclip", Description = "Walk through specific walls and colliders", Default = false, Callback = function(value)
        NoclipEnabled = value
        if value then
            enableNoclip()
        else
            disableNoclip()
        end
    end })

    AutoSkillcheckSection:AddToggle("AutoSkillcheckToggle", { 
        Title = "Auto Complete Skillchecks", 
        Description = "Instantly passes all minigames (horizontal, circle, treadmill)", 
        Default = false, 
        Callback = function(value)
            AutoSkillcheckEnabled = value
        end 
    })

    AutoSkillcheckSection:AddToggle("AutoBarnabyToggle", { 
        Title = "Auto Play Barnaby", 
        Description = "Spams jump to survive and collect coins in Barnaby", 
        Default = false, 
        Callback = function(value)
            AutoBarnabyEnabled = value
        end 
    })
end

if not IsLobby and not IsGame then
    if Tabs.Client then Window:SelectTab(Tabs.Client) end
    local UnknownSection = Tabs.Client:AddSection("Unknown Place")
    UnknownSection:AddParagraph({ Title = "Unknown Place", Content = "This script is designed for specific places. Place ID: " .. tostring(CurrentPlaceId) })
end

Fluent:Notify({ Title = "Loaded", Content = "Gigi's World HUB loaded for " .. placeSuffix, Duration = 3 })
