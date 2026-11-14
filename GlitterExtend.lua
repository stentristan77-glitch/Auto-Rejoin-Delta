-- Glitter Extend MINI (no window, no log - as light as possible)
-- Listens to chat for Pine Tree / Blue Flower / Bamboo boosts,
-- then uses ONE Glitter in that field 12-14 minutes later (only while you're standing in it).

local FIELDS = {
    { word = "pine tree",   name = "Pine Tree Forest" },
    { word = "blue flower", name = "Blue Flower Field" },
    { word = "bamboo",      name = "Bamboo Field" },
}
local GLITTER_AFTER = 14 * 60  -- from 14:00, use it as soon as you're in the field
local EARLY_AFTER   = 12 * 60  -- 12:00-14:00: use it early if your bag is almost full
local BAG_FULL      = 0.9      -- "almost full" = 90% (Atlas is about to go convert)
local GIVE_UP_AFTER = 50       -- keep trying this long after 14:00 (until ~14:50)

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

-- Bag fullness (pollen / capacity). If the game doesn't have these, the early use is just skipped.
local stats = plr:FindFirstChild("CoreStats") or plr:WaitForChild("CoreStats", 30)
local function bagFull()
    local p = stats and stats:FindFirstChild("Pollen")
    local c = stats and stats:FindFirstChild("Capacity")
    if not (p and c) or c.Value <= 0 then return false end
    return p.Value / c.Value >= BAG_FULL
end

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
                popup(f.name .. " boosted - Glitter at 12-14 min")
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
        local early = now >= t - (GLITTER_AFTER - EARLY_AFTER) -- 12:00 or later
        if early then
            inside[name] = inField(name) and ((inside[name] or 0) + 1) or 0
        end
        if early and now < t and inside[name] >= 1 and bagFull() then
            -- Bag almost full: Atlas is about to leave to convert, so use it now
            pcall(function() useItem:FireServer({ ["Name"] = "Glitter" }) end)
            lastSeen[name] = os.clock()
            due[name] = nil
            popup("Used Glitter in " .. name .. " (early, bag full)")
        elseif now >= t then
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
