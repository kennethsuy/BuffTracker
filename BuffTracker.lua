-- Define the table of allowed buffs (modify this list based on your needs)
BuffTrackerDB = BuffTrackerDB or {}
BuffTrackerDB.allowedBuffs = BuffTrackerDB.allowedBuffs or {}
local allowedBuffs = BuffTrackerDB.allowedBuffs

local healthBar = PlayerFrame  -- Change if using an addon frame

-- Create the frame for displaying buffs
local buffFrame = CreateFrame("Frame", "BuffDisplayFrame", UIParent)
buffFrame:SetSize(200, 100)
buffFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)

local buffs = {}
local iconFrames = {}

buffFrame:RegisterEvent("PLAYER_LOGIN")
buffFrame:RegisterEvent("UNIT_AURA")

local function BuffsChanged(newBuffs)
    if not next(newBuffs) and not next(buffs) then
        return false
    end
    for k, v in pairs(newBuffs) do
        if not buffs[k] or buffs[k].expirationTime ~= v.expirationTime then
            return true
        end
    end
    for k in pairs(buffs) do
        if not newBuffs[k] then
            return true
        end
    end
    return false
end

local function OnEvent(self, event, unit)
    if event == "PLAYER_LOGIN" then
        allowedBuffs = BuffTrackerDB.allowedBuffs or {}
        return
    end

    local newBuffs = {}
    local index = 1
    while true do
        local aura = C_UnitAuras.GetBuffDataByIndex("player", index)
        if not aura then break end

        if allowedBuffs[aura.name] then
            newBuffs[aura.name] = {
                spellId = aura.spellId,
                icon = aura.icon,
                duration = aura.duration,
                expirationTime = aura.expirationTime,
                stackCount = aura.applications or 1
            }
        end
        index = index + 1
    end

    if not BuffsChanged(newBuffs) then
        return
    end

    buffs = newBuffs
    buffFrame:Show()

    local xOffset = -54.5
    for buffName, buffData in pairs(buffs) do
        local iconFrame = iconFrames[buffName]
        if not iconFrame then
            iconFrame = CreateFrame("Frame", nil, buffFrame)
            iconFrame:SetSize(28, 28)
            iconFrame.icon = iconFrame:CreateTexture(nil, "BACKGROUND")
            iconFrame.icon:SetAllPoints()
            iconFrame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

            iconFrame.stackCountText = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            iconFrame.stackCountText:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -2, 2)
            iconFrame.stackCountText:SetFont("Fonts\\FRIZQT___.TTF", 12, "OUTLINE")

            iconFrame.cooldown = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate")
            iconFrame.cooldown:SetAllPoints(iconFrame.icon)
            iconFrame.cooldown:SetReverse(true)
            iconFrame.cooldown:SetHideCountdownNumbers(true)

            iconFrame.cooldownInfo = {}

            iconFrames[buffName] = iconFrame
        end

        iconFrame:SetPoint("TOP", buffFrame, "TOP", xOffset, -150)
        iconFrame.icon:SetTexture(buffData.icon)

        if buffData.stackCount and buffData.stackCount > 1 then
            iconFrame.stackCountText:SetText(tostring(buffData.stackCount))
            iconFrame.stackCountText:Show()
        else
            iconFrame.stackCountText:Hide()
        end

        local startTime = buffData.expirationTime - buffData.duration
        local cooldownInfo = iconFrame.cooldownInfo

        if cooldownInfo.startTime ~= startTime or cooldownInfo.duration ~= buffData.duration then
            iconFrame.cooldown:SetCooldown(startTime, buffData.duration)
            cooldownInfo.startTime = startTime
            cooldownInfo.duration = buffData.duration
        end

        iconFrame:Show()
        xOffset = xOffset + 29
    end

    for name, frame in pairs(iconFrames) do
        if not buffs[name] then
            frame:Hide()
        end
    end
end

buffFrame:SetScript("OnEvent", OnEvent)

-- Minimap Button
local minimapButton = CreateFrame("Button", "BuffTrackerMinimapButton", Minimap)
minimapButton:SetSize(25, 25)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)

local icon = minimapButton:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\AddOns\\BuffTracker\\icon.tga")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", minimapButton, "CENTER")
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
minimapButton.icon = icon

minimapButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(56, 56)
border:SetPoint("CENTER",10,-11)

minimapButton:SetHitRectInsets(4, 4, 4, 4)

local function UpdateButtonPosition(angle)
    local radius = 105
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local dragging = false
local angle = math.rad(45)
UpdateButtonPosition(angle)

minimapButton:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then dragging = true end
end)

minimapButton:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then dragging = false end
end)

minimapButton:SetScript("OnUpdate", function(self)
    if dragging then
        local mx, my = GetCursorPosition()
        local cx, cy = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        local dx, dy = mx / scale - cx, my / scale - cy
        angle = math.atan2(dy, dx)
        UpdateButtonPosition(angle)
    end
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Buff Tracker", 1, 1, 1)
    GameTooltip:AddLine("Click to open settings", nil, nil, nil, true)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Config with AceGUI
local AceGUI = LibStub("AceGUI-3.0")
local BuffTrackerConfigWindow

local function ShowBuffTrackerConfig()
    if BuffTrackerConfigWindow then
        BuffTrackerConfigWindow:Release()
        BuffTrackerConfigWindow = nil
        return
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Buff Tracker Settings")
    frame:SetStatusText("Manage tracked buffs")
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        BuffTrackerConfigWindow = nil
    end)
    frame:SetLayout("Flow")
    frame:SetWidth(350)
    frame:SetHeight(300)
    BuffTrackerConfigWindow = frame

    local buffList, dropdownMap = {}, {}
    local i = 1
    for k in pairs(allowedBuffs) do
        table.insert(buffList, k)
    end
    table.sort(buffList)
    for _, name in ipairs(buffList) do
        dropdownMap[i] = name
        i = i + 1
    end

    local buffDropdown = AceGUI:Create("Dropdown")
    buffDropdown:SetLabel("Tracked Buffs")
    buffDropdown:SetList(dropdownMap)
    frame:AddChild(buffDropdown)

    local removeButton = AceGUI:Create("Button")
    removeButton:SetText("Remove Selected Buff")
    removeButton:SetWidth(200)
    removeButton:SetCallback("OnClick", function()
        local selectedIndex = buffDropdown:GetValue()
        local selectedName = dropdownMap[selectedIndex]
        if selectedName and allowedBuffs[selectedName] then
            allowedBuffs[selectedName] = nil
            print("Removed buff:", selectedName)
            ShowBuffTrackerConfig()
        end
    end)
    frame:AddChild(removeButton)

    local addBox = AceGUI:Create("EditBox")
    addBox:SetLabel("Add Buff by Name")
    addBox:SetWidth(200)
    addBox:SetCallback("OnEnterPressed", function(widget, event, text)
        if text and text ~= "" then
            allowedBuffs[text] = true
            print("Added buff to track:", text)
            ShowBuffTrackerConfig()
        end
    end)
    frame:AddChild(addBox)
end

minimapButton:SetScript("OnClick", ShowBuffTrackerConfig)
