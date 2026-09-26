--[[ PulseUI — example / test script
     Paste into your executor and execute. ]]

local PulseUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/pulse-cheats/NEWGUI/main/PulseUI.lua"))()

local Window = PulseUI.CreateWindow({
    Title = "Pulse Hub",
    SubTitle = "v1.1  •  by pulse-cheats",
})

-- Tabs (icon name, fallback glyph)
local Main    = Window:CreateTab("Main",   "home.png",     "⌂")
local Combat  = Window:CreateTab("Combat", "play.png",     "▶")
local Visuals = Window:CreateTab("Visuals","search.png",   "◈")
local Settings= Window:CreateTab("Settings","settings.png","⚙")

-- ============ MAIN ============
Main:CreateSection("Character")
Main:CreateSlider("WalkSpeed", 16, 500, 16, function(v)
    local char = game.Players.LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        char:FindFirstChildOfClass("Humanoid").WalkSpeed = v
    end
end)
Main:CreateSlider("JumpPower", 50, 500, 50, function(v)
    local char = game.Players.LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        char:FindFirstChildOfClass("Humanoid").JumpPower = v
    end
end)
Main:CreateToggle("Infinite Jump", false, function(v)
    _G.InfiniteJump = v
end)
Main:CreateButton("Reset Character", function()
    game.Players.LocalPlayer.Character:BreakJoints()
end)

Main:CreateSection("Misc")
Main:CreateButton("Rejoin Server", function()
    game:GetService("TeleportService"):Teleport(game.PlaceId)
end)
Main:CreateDropdown("Speed Mode", {"Normal", "Fast", "Insane"}, "Normal", function(v)
    print("Speed mode:", v)
end)

-- ============ COMBAT ============
Combat:CreateSection("Target")
Combat:CreateToggle("Aimbot", false, function(v) print("Aimbot:", v) end)
Combat:CreateToggle("Silent Aim", false, function(v) print("SilentAim:", v) end)
Combat:CreateKeybind("Aim Key", Enum.KeyCode.E, function(k) print("Aim key:", k.Name) end)

-- ============ VISUALS ============
Visuals:CreateSection("ESP")
Visuals:CreateToggle("Player ESP", false, function(v) print("ESP:", v) end)
Visuals:CreateToggle("Box ESP", false, function(v) print("Box:", v) end)
Visuals:CreateSlider("ESP Transparency", 0, 100, 50, function(v) print("ESP alpha:", v) end)

-- ============ SETTINGS ============
Settings:CreateSection("Interface")
Settings:CreateKeybind("Toggle UI", Enum.KeyCode.RightControl, function(k) print("UI key:", k.Name) end)
Settings:CreateParagraph("About PulseUI",
    "Custom UI library by pulse-cheats. Assets load from github.com/pulse-cheats/NEWGUI.")
Settings:CreateButton("Unload UI", function()
    Window:Destroy()
end)

print("[PulseUI] example loaded — press RightControl to toggle the UI")
