-- Glitter Extend v5 (light: chat-only detection)
-- Detects Pine Tree / Blue Flower / Bamboo field boosts, waits 14 min, then uses Glitter
-- in that field. Shows timers + Blue Booster cooldown in a small window. Put in Delta -> Autoexecute.

------------------------------ SETTINGS ------------------------------
local FIELDS = {                       -- [word to look for] = exact field name (shown in this order)
    { word = "pine tree",   name = "Pine Tree Forest" },
    { word = "blue flower", name = "Blue Flower Field" },
    { word = "bamboo",      name = "Bamboo Field" },
}
local GLITTER_AFTER_MIN   = 13  -- start trying to use Glitter this many minutes after the boost starts
local BOOST_MIN           = 15  -- how long a field boost lasts (for the "boost left" timer)
local BLUE_BOOSTER_CD_MIN = 45  -- Blue Field Booster cooldown
local WAIT_WINDOW_SEC     = 110 -- keep trying for this long (13:00 -> ~14:50, before the boost ends)
local KEEP_EXTENDING      = false -- Glitter only extends a boost once, so one Glitter per boost
local DEBUG_LOG           = true -- saves every "boost" text it sees to glitter_debug.txt
----------------------------------------------------------------------

if not game:IsLoaded() then game.Loaded:Wait() end
-- Close an old window if the script is run again
pcall(function()
    local old = (gethui and gethui() or game:GetService("CoreGui")):FindFirstChild("GlitterExtendUI")
    if old then old:Destroy() end
end)
pcall(function()
    local old = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("GlitterExtendUI")
    if old then old:Destroy() end
end)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local UIS = game:GetService("UserInputService")
local plr = Players.LocalPlayer

local enabled = true
local status = "Starting..."

local function popup(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "Glitter Extend", Text = text, Duration = 5 })
    end)
end

local logLines = 0
local function log(text)
    if not DEBUG_LOG or logLines > 300 then return end -- max 300 lines so the file never gets huge
    logLines = logLines + 1
    pcall(function()
        local line = os.date("%H:%M:%S") .. "  " .. text .. "\n"
        if logLines == 1 then
            writefile("glitter_debug.txt", line) -- start a fresh file every time the script runs
        else
            appendfile("glitter_debug.txt", line)
        end
    end)
end

local function fmt(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end

------------------------------ WINDOW ------------------------------
local NAVY   = Color3.fromRGB(38, 66, 112)
local DARK   = Color3.fromRGB(24, 26, 33)
local PANEL  = Color3.fromRGB(33, 36, 45)
local TEXT   = Color3.fromRGB(225, 228, 235)
local DIM    = Color3.fromRGB(140, 146, 160)
local GREEN  = Color3.fromRGB(70, 170, 100)
local RED    = Color3.fromRGB(170, 60, 60)

local screen = Instance.new("ScreenGui")
screen.Name = "GlitterExtendUI"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local okParent = pcall(function() screen.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not okParent or not screen.Parent then screen.Parent = plr:WaitForChild("PlayerGui") end

local function corner(obj, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = obj
end

local function label(parent, text, size, color, y, h)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = color or TEXT
    l.TextSize = size or 14
    l.Text = text
    l.Size = UDim2.new(1, -24, 0, h or 20)
    l.Position = UDim2.new(0, 12, 0, y or 0)
    l.Parent = parent
    return l
end

local win = Instance.new("Frame")
win.Size = UDim2.new(0, 290, 0, 292)
win.Position = UDim2.new(1, -310, 0, 120)
win.BackgroundColor3 = DARK
win.BorderSizePixel = 0
win.Parent = screen
corner(win, 8)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 38)
header.BackgroundColor3 = NAVY
header.BorderSizePixel = 0
header.Parent = win
corner(header, 8)
label(header, "Glitter Extend", 17, TEXT, 9)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 34, 0, 30)
minBtn.Position = UDim2.new(1, -40, 0, 4)
minBtn.BackgroundTransparency = 1
minBtn.Text = "▼"
minBtn.TextColor3 = TEXT
minBtn.TextSize = 18
minBtn.Font = Enum.Font.GothamBold
minBtn.Parent = header

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -38)
body.Position = UDim2.new(0, 0, 0, 38)
body.BackgroundTransparency = 1
body.Parent = win

-- ON/OFF toggle row
local toggleRow = Instance.new("Frame")
toggleRow.Size = UDim2.new(1, -16, 0, 36)
toggleRow.Position = UDim2.new(0, 8, 0, 8)
toggleRow.BackgroundColor3 = PANEL
toggleRow.BorderSizePixel = 0
toggleRow.Parent = body
corner(toggleRow, 6)
label(toggleRow, "Auto Glitter", 15, TEXT, 8)

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(0, 64, 0, 26)
toggle.Position = UDim2.new(1, -72, 0, 5)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 14
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.BorderSizePixel = 0
toggle.Parent = toggleRow
corner(toggle, 6)

local function paintToggle()
    toggle.Text = enabled and "ON" or "OFF"
    toggle.BackgroundColor3 = enabled and GREEN or RED
end
paintToggle()
toggle.MouseButton1Click:Connect(function()
    enabled = not enabled
    paintToggle()
    status = enabled and "Turned on" or "Turned off (timers still run)"
end)

-- Info panel
local panel = Instance.new("Frame")
panel.Size = UDim2.new(1, -16, 0, 190)
panel.Position = UDim2.new(0, 8, 0, 52)
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Parent = body
corner(panel, 6)

local boosterLabel = label(panel, "", 14, TEXT, 8)
local fieldLabels = {}
for i, f in ipairs(FIELDS) do
    label(panel, f.name, 13, DIM, 34 + (i - 1) * 38, 16)
    fieldLabels[f.name] = label(panel, "", 14, TEXT, 50 + (i - 1) * 38, 18)
end
local whereLabel = label(panel, "", 13, TEXT, 164, 18)
local statusLabel = label(body, "", 12, DIM, 246, 16)
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd

-- Hide button in the title bar
local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0, 34, 0, 30)
hideBtn.Position = UDim2.new(1, -76, 0, 4)
hideBtn.BackgroundTransparency = 1
hideBtn.Text = "✕"
hideBtn.TextColor3 = TEXT
hideBtn.TextSize = 17
hideBtn.Font = Enum.Font.GothamBold
hideBtn.Parent = header

-- Floating round button to show/hide the window (like Atlas). You can drag it around.
local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.new(0, 50, 0, 50)
floatBtn.Position = UDim2.new(0, 20, 0.5, -25)
floatBtn.BackgroundColor3 = NAVY
floatBtn.BorderSizePixel = 0
floatBtn.Text = "✨"
floatBtn.TextSize = 24
floatBtn.Font = Enum.Font.GothamBold
floatBtn.TextColor3 = TEXT
floatBtn.AutoButtonColor = true
floatBtn.Parent = screen
corner(floatBtn, 25)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 140, 220)
stroke.Thickness = 2
stroke.Parent = floatBtn

local function setShown(show)
    win.Visible = show
end
hideBtn.MouseButton1Click:Connect(function() setShown(false) end)

do
    local pressing, moved, startPos, startInput = false, false, nil, nil
    floatBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            pressing, moved, startPos, startInput = true, false, floatBtn.Position, input.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End and pressing then
                    pressing = false
                    if not moved then setShown(not win.Visible) end -- a tap toggles, a drag just moves it
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if pressing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startInput
            if d.Magnitude > 8 then moved = true end
            if moved then
                floatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end)
end

-- Minimise / drag
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    win.Size = minimized and UDim2.new(0, 290, 0, 38) or UDim2.new(0, 290, 0, 292)
    minBtn.Text = minimized and "▲" or "▼"
end)

do
    local dragging, startPos, startInput
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startInput = true, win.Position, input.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startInput
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

------------------------------ GAME HOOKS ------------------------------
local events = RS:WaitForChild("Events", 30)
local useItem = events and events:FindFirstChild("PlayerActivesCommand")
local zones = workspace:WaitForChild("FlowerZones", 30)
if not useItem then status = "ERROR: item remote not found" end
if not zones then status = "ERROR: fields not found" end

local function inField(fieldName)
    local zone = zones and zones:FindFirstChild(fieldName)
    local char = plr.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (zone and root) then return false end
    local rel = zone.CFrame:PointToObjectSpace(root.Position)
    local half = zone.Size / 2
    return math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and math.abs(rel.Y) <= 40
end

local function currentField()
    if not zones then return nil end
    for _, zone in ipairs(zones:GetChildren()) do
        if zone:IsA("BasePart") and inField(zone.Name) then return zone.Name end
    end
    return nil
end

------------------------------ TIMERS ------------------------------
local boostStart = {}  -- fieldName -> when the current boost started (or was last extended)
local glitterAt = {}   -- fieldName -> when Glitter is due
local lastSeen = {}    -- fieldName -> last time a boost text for it was seen
local extended = {}    -- fieldName -> true once this boost got its Glitter
local inFieldFor = {}  -- fieldName -> how many checks in a row you've been inside it
local boosterReadyAt = nil
local lastLog = 0

local function onBoost(fieldName, source)
    local now = os.clock()
    local prev = lastSeen[fieldName]
    lastSeen[fieldName] = now
    if prev and now - prev < 60 then return end -- same boost still showing, not a new one
    boostStart[fieldName] = now
    extended[fieldName] = nil
    glitterAt[fieldName] = now + GLITTER_AFTER_MIN * 60
    boosterReadyAt = now + BLUE_BOOSTER_CD_MIN * 60 -- a blue field got boosted = Blue Booster was used
    status = "Boost detected: " .. fieldName .. " (" .. source .. ")"
    popup("Boost detected: " .. fieldName)
    log("BOOST DETECTED -> " .. fieldName .. " (from " .. source .. ")")
end

------------------------------ DETECTION ------------------------------
-- Boosts show up in chat as messages like [Activated "Pine Tree Forest Boost" x1].
-- Only chat is watched now - watching every text on screen was too heavy for the cloud phone.
local function checkText(text, source)
    if type(text) ~= "string" or text == "" then return end
    text = string.gsub(text, "<[^>]->", "") -- remove the colour/font tags
    local lower = string.lower(text)
    if not string.find(lower, "boost") then return end
    if os.clock() - lastLog > 2 then
        lastLog = os.clock()
        log("[" .. source .. "] " .. text)
    end
    for _, f in ipairs(FIELDS) do
        if string.find(lower, f.word, 1, true) then onBoost(f.name, source) end
    end
end

pcall(function()
    TextChatService.MessageReceived:Connect(function(msg) checkText(msg.Text, "chat") end)
end)

log("---- script started ----")
popup("Loaded - window is on the right")
status = (useItem and zones) and "Watching for boosts" or status

------------------------------ MAIN LOOP ------------------------------
task.spawn(function()
    while true do
        local now = os.clock()

        -- Glitter
        if enabled and useItem then
            for _, f in ipairs(FIELDS) do
                local name, dueAt = f.name, glitterAt[f.name]
                inFieldFor[name] = inField(name) and ((inFieldFor[name] or 0) + 1) or 0
                if dueAt and now >= dueAt then
                    if inFieldFor[name] >= 3 then -- inside the field for ~3 seconds, not just walking through
                        local ok = pcall(function() useItem:FireServer({ ["Name"] = "Glitter" }) end)
                        status = ok and ("Used Glitter in " .. name) or "Failed to use Glitter"
                        popup(status)
                        log("GLITTER USED in " .. name .. " ok=" .. tostring(ok))
                        lastSeen[name] = os.clock()
                        boostStart[name] = os.clock()
                        extended[name] = true
                        glitterAt[name] = KEEP_EXTENDING and (os.clock() + GLITTER_AFTER_MIN * 60) or nil
                    elseif now >= dueAt + WAIT_WINDOW_SEC then
                        status = "Missed Glitter: not in " .. name
                        log("MISSED - not in " .. name)
                        glitterAt[name] = nil
                    end
                end
            end
        end

        -- Window text
        if boosterReadyAt and boosterReadyAt > now then
            boosterLabel.Text = "Blue Booster: ready in " .. fmt(boosterReadyAt - now)
            boosterLabel.TextColor3 = TEXT
        else
            boosterLabel.Text = boosterReadyAt and "Blue Booster: READY" or "Blue Booster: waiting for first use"
            boosterLabel.TextColor3 = boosterReadyAt and GREEN or DIM
        end

        for _, f in ipairs(FIELDS) do
            local name = f.name
            local started = boostStart[name]
            local left = started and (started + BOOST_MIN * 60 - now) or 0
            if started and left > 0 then
                local g = glitterAt[name]
                local gtext = g and ("  |  Glitter in " .. fmt(g - now)) or (extended[name] and "  |  Extended" or "")
                if not enabled and g then gtext = "  |  Glitter OFF" end
                fieldLabels[name].Text = "Boost " .. fmt(left) .. gtext
                fieldLabels[name].TextColor3 = GREEN
            else
                fieldLabels[name].Text = "No boost"
                fieldLabels[name].TextColor3 = DIM
                if started then boostStart[name] = nil; extended[name] = nil end
            end
        end
        local here = currentField()
        whereLabel.Text = "You're in: " .. (here or "not in a field")
        whereLabel.TextColor3 = here and TEXT or DIM
        statusLabel.Text = status

        task.wait(1)
    end
end)
