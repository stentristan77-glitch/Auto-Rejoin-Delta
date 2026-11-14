-- Glitter Extend MINI (no window, no log - as light as possible)
-- Listens to chat for Pine Tree / Blue Flower / Bamboo boosts,
-- then uses ONE Glitter in that field 13 minutes later (only while you're standing in it).

local FIELDS = {
    { word = "pine tree",   name = "Pine Tree Forest" },
    { word = "blue flower", name = "Blue Flower Field" },
    { word = "bamboo",      name = "Bamboo Field" },
}
local GLITTER_AFTER = 13 * 60  -- seconds after the boost to start trying
local GIVE_UP_AFTER = 110      -- keep trying this long (until ~14:50)

if not game:IsLoaded() then game.Loaded:Wait() end
if _G.GlitterMini then return end -- don't run twice
_G.GlitterMini = true

local plr = game:GetService("Players").LocalPlayer
local useItem = game:GetService("ReplicatedStorage"):WaitForChild("Events", 30)
useItem = useItem and useItem:FindFirstChild("PlayerActivesCommand")
local zones = workspace:WaitForChild("FlowerZones", 30)

local function popup(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Glitter", Text = text, Duration = 5 })
    end)
end

if not (useItem and zones) then popup("Glitter Mini: game parts not found, stopped") return end

local function inField(name)
    local zone = zones:FindFirstChild(name)
    local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not (zone and root) then return false end
    local rel = zone.CFrame:PointToObjectSpace(root.Position)
    return math.abs(rel.X) <= zone.Size.X / 2 and math.abs(rel.Z) <= zone.Size.Z / 2 and math.abs(rel.Y) <= 40
end

local due, lastSeen, inside = {}, {}, {}

game:GetService("TextChatService").MessageReceived:Connect(function(msg)
    local text = string.lower(msg.Text or "")
    if not string.find(text, "boost", 1, true) then return end
    for _, f in ipairs(FIELDS) do
        if string.find(text, f.word, 1, true) then
            local now = os.clock()
            local prev = lastSeen[f.name]
            lastSeen[f.name] = now
            if not prev or now - prev > 60 then
                due[f.name] = now + GLITTER_AFTER
                popup(f.name .. " boosted - Glitter in 13 min")
            end
        end
    end
end)

popup("Glitter Mini running")

task.spawn(function()
while true do
    task.wait(3)
    local now = os.clock()
    for name, t in pairs(due) do
        if now >= t then
            inside[name] = inField(name) and ((inside[name] or 0) + 1) or 0
            if inside[name] >= 2 then -- in the field for 2 checks in a row (~3-6 sec)
                pcall(function() useItem:FireServer({ ["Name"] = "Glitter" }) end)
                lastSeen[name] = os.clock()
                due[name] = nil
                popup("Used Glitter in " .. name)
            elseif now >= t + GIVE_UP_AFTER then
                due[name] = nil
                popup("Missed Glitter: not in " .. name)
            end
        end
    end
end
end)
