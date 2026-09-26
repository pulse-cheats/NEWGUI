--[[
    ██████╗ ██╗   ██╗██╗     ███████╗███████╗██╗   ██╗██╗
    ██╔═══██╗██║   ██║██║     ██╔════╝██╔════╝██║   ██║██║
    ██║   ██║██║   ██║██║     █████╗  ███████╗██║   ██║██║
    ██║   ██║██║   ██║██║     ██╔══╝  ╚════██║╚██╗ ██╔╝██║
    ╚██████╔╝╚██████╔╝███████╗███████╗╚██████╔╝ ╚████╔╝ ██║
     ╚═════╝  ╚═════╝ ╚══════╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝

    PulseUI v2.0 — Custom UI Library
    github.com/pulse-cheats/NEWGUI
    Theme: white / gray

    ▸ No default tabs — you build everything yourself
    ▸ Smart assets: CreateTab("Home", "Home") finds assets/home.png automatically
    ▸ WindUI-style restore pill when the UI is hidden
    ▸ Works on every executor (graceful asset fallback to text glyphs)

    Toggle UI: RightControl
]]

local PulseUI = {}

--========================================================================--
-- SERVICES + SAFE ENV
--========================================================================--
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local ContentProvider   = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer

local ASSET_URL = "https://raw.githubusercontent.com/pulse-cheats/NEWGUI/main/assets/"

local Theme = {
    Background   = Color3.fromRGB(250, 250, 252),
    Panel        = Color3.fromRGB(242, 242, 245),
    Element      = Color3.fromRGB(233, 233, 237),
    ElementHover = Color3.fromRGB(222, 222, 227),
    Stroke       = Color3.fromRGB(203, 203, 209),
    Text         = Color3.fromRGB(38, 38, 44),
    TextDim      = Color3.fromRGB(125, 125, 133),
    Accent       = Color3.fromRGB(115, 115, 124),
    AccentDark   = Color3.fromRGB(88, 88, 96),
    White        = Color3.fromRGB(255, 255, 255),
}

--========================================================================--
-- UTIL
--========================================================================--
local function new(class, props, parent)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then
                local ok = pcall(function() inst[k] = v end)
                if not ok then inst[k] = v end -- let real errors surface once
            end
        end
    end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(r, parent)
    return new("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function stroke(color, thickness, parent)
    return new("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function tween(inst, props, t, style)
    local ok, tw = pcall(function()
        return TweenService:Create(inst,
            TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    end)
    if ok and tw then tw:Play() end
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

--========================================================================--
-- GUI PARENT (all executors)
--========================================================================--
local function getGuiParent()
    if type(gethui) == "function" then
        local ok, ui = pcall(gethui)
        if ok and ui then return ui end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then return core end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- asset sources, tried in order (covers main AND master branches + CDN)
local ASSET_SOURCES = {
    "https://raw.githubusercontent.com/pulse-cheats/NEWGUI/main/assets/",
    "https://raw.githubusercontent.com/pulse-cheats/NEWGUI/master/assets/",
    "https://cdn.jsdelivr.net/gh/pulse-cheats/NEWGUI@main/assets/",
    "https://cdn.jsdelivr.net/gh/pulse-cheats/NEWGUI@master/assets/",
}

--========================================================================--
-- SMART ASSET LOADER
-- "Home", "HOME", "my tab", "My_Tab" -> assets/home.png / assets/mytab.png
--========================================================================--
local assetCache = {}
local loaderWarned = {}
local assetSupport = (type(writefile) == "function") and (type(getcustomasset) == "function")

local function resolveAssetName(name)
    name = tostring(name or "")
    if name:match("%.png$") then return name end
    if name:match("%.jpg$") then return name end
    local clean = name:gsub("[%s_%-]+", "")
    return clean:lower() .. ".png"
end

-- validates PNG/JPG binary (prevents 404-HTML being treated as an image)
local function isImage(data)
    if type(data) ~= "string" or #data < 16 then return false end
    if data:sub(1, 8) == "\137PNG\13\10\26\10" then return true end
    if data:sub(1, 2) == "\255\216" then return true end
    return false
end

local function loadAssetUrl(name)
    name = resolveAssetName(name)
    if assetCache[name] ~= nil then return assetCache[name] end

    local result = ""

    local ok = pcall(function()
        if type(getcustomasset) ~= "function" or type(writefile) ~= "function" then
            error("nofs")
        end
        pcall(function() makefolder("PulseUI") end)
        pcall(function() makefolder("PulseUI/assets") end)
        local file = "PulseUI/assets/" .. name

        if type(isfile) == "function" and isfile(file) then
            local cached = readfile(file)
            if isImage(cached) then
                result = getcustomasset(file)
            end
            return
        end

        for _, base in ipairs(ASSET_SOURCES) do
            local okD, data = pcall(function() return game:HttpGet(base .. name) end)
            if okD and type(data) == "string" and isImage(data) then
                writefile(file, data)
                result = getcustomasset(file)
                return
            end
        end
    end)

    if not ok and not loaderWarned[name] then
        loaderWarned[name] = true
        if assetSupport == false then
            warn("[PulseUI] executor has no writefile/getcustomasset - icon '" .. name .. "' uses text fallback")
        else
            warn("[PulseUI] could not load asset '" .. name .. "' from any source (check repo/branch)")
        end
    end

    assetCache[name] = result
    return result
end

-- icon with automatic PNG -> text glyph fallback
local function makeIcon(parent, name, glyph, size, glyphSize, color)
    size = size or 20
    color = color or Theme.TextDim

    local holder = new("Frame", {
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
    }, parent)

    local img = new("ImageLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Image = loadAssetUrl(name),
        ImageColor3 = color,
        Visible = false,
    }, holder)

    local label = new("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = glyph or "",
        TextColor3 = color,
        TextSize = glyphSize or (size - 5),
        Font = Enum.Font.GothamBold,
        Visible = true,
    }, holder)

    if img.Image ~= "" then
        spawn(function()
            local ok = pcall(function() ContentProvider:PreloadAsync({ img }) end)
            if ok and img.IsLoaded then
                img.Visible = true
                label.Visible = false
            end
        end)
    end

    return holder
end

local function setIconColor(holder, color)
    for _, c in ipairs(holder:GetChildren()) do
        if c:IsA("ImageLabel") then c.ImageColor3 = color end
        if c:IsA("TextLabel") then c.TextColor3 = color end
    end
end

local function hoverColors(btn, holder, normal, hover)
    btn.MouseEnter:Connect(function()
        if holder then setIconColor(holder, hover) end
    end)
    btn.MouseLeave:Connect(function()
        if holder then setIconColor(holder, normal) end
    end)
end

--========================================================================--
-- WINDOW
--========================================================================--
function PulseUI.CreateWindow(config)
    config = config or {}
    local Window = { Tabs = {} }

    local gui = new("ScreenGui", {
        Name = "PulseUI_" .. tostring(math.random(100000, 999999)),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 9999,
    }, getGuiParent())
    pcall(function() gui.Parent = getGuiParent() end)

    ---------------------------------------------------------------- size
    local winW, winH = 540, 380
    if type(config.Size) == "table" and #config.Size == 2 then
        winW = tonumber(config.Size[1]) or winW
        winH = tonumber(config.Size[2]) or winH
    end
    do
        local ok, vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
        vp = (ok and vp) or Vector2.new(1280, 720)
        local s = math.min(1, vp.X / (winW + 30), vp.Y / (winH + 30))
        winW, winH = math.floor(winW * s), math.floor(winH * s)
    end

    ---------------------------------------------------------------- main
    local main = new("Frame", {
        Size = UDim2.fromOffset(winW, winH),
        Position = UDim2.new(0.5, -winW / 2, 0.5, -winH / 2),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Active = true,
        Visible = true,
    }, gui)
    corner(12, main)
    stroke(Theme.Stroke, 1, main)

    -- soft shadow
    new("ImageLabel", {
        Size = UDim2.new(1, 30, 1, 30),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://5028857084",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 0.93,
        ScaleType = Enum.ScaleType.Slice,
        ZIndex = 0,
    }, main)

    ---------------------------------------------------------------- top bar
    local top = new("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, main)
    corner(12, top)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, top)

    do
        local logo = makeIcon(top, "logo", "P", 24, 15, Theme.Accent)
        logo.Position = UDim2.fromOffset(12, 8)
        logo.ZIndex = 3
    end

    new("TextLabel", {
        Size = UDim2.new(0, 320, 0, 17),
        Position = UDim2.fromOffset(44, 5),
        BackgroundTransparency = 1,
        Text = config.Title or "PulseUI",
        TextColor3 = Theme.Text,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
    }, top)

    if config.SubTitle then
        new("TextLabel", {
            Size = UDim2.new(0, 420, 0, 12),
            Position = UDim2.fromOffset(44, 23),
            BackgroundTransparency = 1,
            Text = config.SubTitle,
            TextColor3 = Theme.TextDim,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
        }, top)
    end

    local function topButton(iconName, glyph, offset, callback)
        local btn = new("TextButton", {
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.new(1, offset, 0.5, -13),
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 4,
        }, top)
        local holder = makeIcon(btn, iconName, glyph, 15, 12, Theme.TextDim)
        btn.MouseEnter:Connect(function() setIconColor(holder, Theme.Text) end)
        btn.MouseLeave:Connect(function() setIconColor(holder, Theme.TextDim) end)
        btn.MouseButton1Click:Connect(callback)
    end

    -- X = hide (pill can restore); settings icon = full close
    topButton("minimize", "—", -10, function()
        main.Visible = false
    end)
    topButton("close", "✕", -40, function()
        gui:Destroy()
    end)

    ---------------------------------------------------------------- sidebar
    local side = new("Frame", {
        Size = UDim2.new(0, 50, 1, -40),
        Position = UDim2.fromOffset(0, 40),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, main)
    new("UIListLayout", {
        Padding = UDim.new(0, 6),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, side)
    new("UIPadding", { PaddingTop = UDim.new(0, 10) }, side)

    ---------------------------------------------------------------- content
    local content = new("Frame", {
        Size = UDim2.new(1, -50, 1, -40),
        Position = UDim2.fromOffset(50, 40),
        BackgroundTransparency = 1,
        ZIndex = 2,
    }, main)

    local tabBar = new("Frame", {
        Size = UDim2.new(1, -16, 0, 32),
        Position = UDim2.fromOffset(8, 5),
        BackgroundTransparency = 1,
        ZIndex = 2,
    }, content)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }, tabBar)

    local pages = new("Frame", {
        Size = UDim2.new(1, -16, 1, -45),
        Position = UDim2.fromOffset(8, 43),
        BackgroundTransparency = 1,
        ZIndex = 2,
    }, content)

    local placeholder = new("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "No tabs yet.\nUse  Window:CreateTab(\"My Tab\", \"home\")",
        TextColor3 = Theme.TextDim,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        ZIndex = 2,
    }, pages)

    local currentTab = nil

    --====================================================================--
    -- CREATE TAB
    --====================================================================--
    function Window:CreateTab(name, iconName, glyph)
        iconName = iconName or name
        glyph = glyph or string.upper(string.sub(tostring(name), 1, 1))

        local sideBtn = new("TextButton", {
            Size = UDim2.fromOffset(34, 34),
            BackgroundColor3 = Theme.Element,
            BackgroundTransparency = 1,
            Text = "",
            LayoutOrder = #Window.Tabs + 1,
            ZIndex = 3,
        }, side)
        corner(9, sideBtn)
        local sHolder = makeIcon(sideBtn, iconName, glyph, 19, 14, Theme.TextDim)

        local tabBtn = new("TextButton", {
            Size = UDim2.new(0, 96, 1, 0),
            BackgroundColor3 = Theme.Element,
            BackgroundTransparency = 1,
            Text = tostring(name),
            TextColor3 = Theme.TextDim,
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            ZIndex = 3,
        }, tabBar)
        corner(8, tabBtn)

        local underline = new("Frame", {
            Size = UDim2.new(1, -20, 0, 2),
            Position = UDim2.new(0, 10, 1, -3),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 3,
        }, tabBtn)
        corner(1, underline)

        local page = new("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Stroke,
            ScrollBarImageTransparency = 0.4,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            ZIndex = 2,
        }, pages)
        new("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, page)
        new("UIPadding", {
            PaddingTop = UDim.new(0, 2),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 2),
            PaddingRight = UDim.new(0, 10),
        }, page)

        local Tab = { Name = name, Page = page }

        function Tab:Select()
            for _, t in ipairs(Window.Tabs) do
                t.Page.Visible = false
                t.Button.BackgroundTransparency = 1
                t.Button.TextColor3 = Theme.TextDim
                t.Underline.BackgroundTransparency = 1
                setIconColor(t.SideHolder, Theme.TextDim)
            end
            page.Visible = true
            placeholder.Visible = false
            tabBtn.BackgroundTransparency = 0.45
            tabBtn.TextColor3 = Theme.Text
            underline.BackgroundTransparency = 0
            setIconColor(sHolder, Theme.Text)
            currentTab = Tab
        end

        sideBtn.MouseEnter:Connect(function() setIconColor(sHolder, Theme.Text) end)
        sideBtn.MouseLeave:Connect(function()
            if currentTab ~= Tab then setIconColor(sHolder, Theme.TextDim) end
        end)
        sideBtn.MouseButton1Click:Connect(function() Tab:Select() end)
        tabBtn.MouseButton1Click:Connect(function() Tab:Select() end)

        local entry = {
            Name = name, Page = page, Button = tabBtn,
            Underline = underline, SideHolder = sHolder,
        }
        Window.Tabs[#Window.Tabs + 1] = entry
        if #Window.Tabs == 1 then Tab:Select() end

        --================================================================--
        -- ELEMENTS
        --================================================================--
        local function order() return #page:GetChildren() end

        local function baseRow(height)
            local row = new("TextButton", {
                Size = UDim2.new(1, -4, 0, height),
                BackgroundColor3 = Theme.Element,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = order(),
            }, page)
            corner(7, row)
            stroke(Theme.Stroke, 1, row)
            row.MouseEnter:Connect(function() tween(row, { BackgroundColor3 = Theme.ElementHover }) end)
            row.MouseLeave:Connect(function() tween(row, { BackgroundColor3 = Theme.Element }) end)
            return row
        end

        function Tab:CreateSection(label)
            return new("TextLabel", {
                Size = UDim2.new(1, -4, 0, 24),
                BackgroundTransparency = 1,
                Text = string.upper(tostring(label)),
                TextColor3 = Theme.TextDim,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = order(),
            }, page)
        end

        function Tab:CreateLabel(text)
            return new("TextLabel", {
                Size = UDim2.new(1, -4, 0, 26),
                BackgroundTransparency = 1,
                Text = tostring(text),
                TextColor3 = Theme.TextDim,
                TextSize = 13,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                LayoutOrder = order(),
            }, page)
        end

        function Tab:CreateButton(text, callback)
            local row = baseRow(36)
            new("TextLabel", {
                Size = UDim2.new(1, -24, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text = tostring(text),
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
            }, row)
            -- arrow
            new("TextLabel", {
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.new(1, -22, 0.5, -7),
                BackgroundTransparency = 1,
                Text = "›",
                TextColor3 = Theme.TextDim,
                TextSize = 16,
                Font = Enum.Font.GothamBold,
                ZIndex = 2,
            }, row)
            row.MouseButton1Click:Connect(function()
                tween(row, { BackgroundColor3 = Theme.AccentDark }, 0.08)
                spawn(function()
                    wait(0.1)
                    tween(row, { BackgroundColor3 = Theme.Element })
                end)
                if callback then
                    local ok, err = pcall(callback)
                    if not ok then warn("[PulseUI] button error: " .. tostring(err)) end
                end
            end)
            return row
        end

        function Tab:CreateToggle(text, default, callback)
            local state = default and true or false
            local row = baseRow(34)

            new("TextLabel", {
                Size = UDim2.new(1, -64, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text = tostring(text),
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
            }, row)

            local pill = new("Frame", {
                Size = UDim2.fromOffset(38, 20),
                Position = UDim2.new(1, -50, 0.5, -10),
                BackgroundColor3 = state and Theme.Accent or Theme.ElementHover,
                BorderSizePixel = 0,
                ZIndex = 3,
            }, row)
            corner(10, pill)
            stroke(Theme.Stroke, 1, pill)

            local knob = new("Frame", {
                Size = UDim2.fromOffset(14, 14),
                Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
                BackgroundColor3 = Theme.White,
                BorderSizePixel = 0,
                ZIndex = 4,
            }, pill)
            corner(7, knob)

            local function set(v)
                state = v and true or false
                tween(pill, { BackgroundColor3 = state and Theme.Accent or Theme.ElementHover }, 0.18)
                tween(knob, {
                    Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
                }, 0.18, Enum.EasingStyle.Back)
                if callback then pcall(callback, state) end
            end

            row.MouseButton1Click:Connect(function() set(not state) end)

            return {
                Set = function(_, v) set(v) end,
                Get = function() return state end,
            }
        end

        function Tab:CreateSlider(text, min, max, default, callback)
            min = tonumber(min) or 0
            max = tonumber(max) or 100
            default = tonumber(default) or min
            local value = default
            local range = math.max(max - min, 1)

            local row = new("Frame", {
                Size = UDim2.new(1, -4, 0, 46),
                BackgroundColor3 = Theme.Element,
                LayoutOrder = order(),
            }, page)
            corner(7, row)
            stroke(Theme.Stroke, 1, row)

            new("TextLabel", {
                Size = UDim2.new(1, -70, 0, 18),
                Position = UDim2.fromOffset(12, 3),
                BackgroundTransparency = 1,
                Text = tostring(text),
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
            }, row)

            local valueLabel = new("TextLabel", {
                Size = UDim2.fromOffset(54, 18),
                Position = UDim2.new(1, -58, 0, 3),
                BackgroundColor3 = Theme.Panel,
                Text = tostring(default),
                TextColor3 = Theme.Text,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                ZIndex = 3,
            }, row)
            corner(5, valueLabel)

            local bar = new("Frame", {
                Size = UDim2.new(1, -24, 0, 5),
                Position = UDim2.fromOffset(12, 31),
                BackgroundColor3 = Theme.ElementHover,
                BorderSizePixel = 0,
                ZIndex = 2,
            }, row)
            corner(3, bar)

            local r0 = clamp((default - min) / range, 0, 1)
            local fill = new("Frame", {
                Size = UDim2.new(r0, 0, 1, 0),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                ZIndex = 2,
            }, bar)
            corner(3, fill)

            local knob = new("Frame", {
                Size = UDim2.fromOffset(13, 13),
                Position = UDim2.new(r0, -7, 0.5, -7),
                BackgroundColor3 = Theme.White,
                BorderSizePixel = 0,
                ZIndex = 3,
            }, bar)
            corner(7, knob)
            stroke(Theme.Stroke, 1, knob)

            local dragging = false

            local function apply(rel)
                rel = clamp(rel, 0, 1)
                value = math.floor(min + range * rel + 0.5)
                fill.Size = UDim2.new(rel, 0, 1, 0)
                knob.Position = UDim2.new(rel, -7, 0.5, -7)
                valueLabel.Text = tostring(value)
            end

            local function setFromX(x)
                local rel = (x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)
                apply(rel)
                if callback then pcall(callback, value) end
            end

            bar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    setFromX(input.Position.X)
                end
            end)
            bar.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch) then
                    setFromX(input.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)

            return {
                Set = function(_, v)
                    value = clamp(tonumber(v) or value, min, max)
                    apply((value - min) / range)
                    if callback then pcall(callback, value) end
                end,
                Get = function() return value end,
            }
        end

        function Tab:CreateDropdown(text, options, default, callback)
            options = options or {}
            local selected = default or options[1]
            local open = false

            local row = baseRow(34)

            new("TextLabel", {
                Size = UDim2.new(0, 150, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text = tostring(text),
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
            }, row)

            local current = new("TextLabel", {
                Size = UDim2.new(0, 140, 1, 0),
                Position = UDim2.new(1, -158, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(selected or "-"),
                TextColor3 = Theme.TextDim,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 2,
            }, row)

            local chev = new("TextLabel", {
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.new(1, -22, 0.5, -7),
                BackgroundTransparency = 1,
                Text = "▾",
                TextColor3 = Theme.TextDim,
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                ZIndex = 2,
            }, row)

            local list = new("Frame", {
                Size = UDim2.new(1, -4, 0, 0),
                BackgroundColor3 = Theme.Panel,
                Visible = false,
                ClipsDescendants = true,
                LayoutOrder = order() + 1,
                ZIndex = 2,
            }, page)
            corner(7, list)
            stroke(Theme.Stroke, 1, list)
            new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)

            for i, opt in ipairs(options) do
                local b = new("TextButton", {
                    Size = UDim2.new(1, 0, 0, 28),
                    BackgroundTransparency = 1,
                    Text = tostring(opt),
                    TextColor3 = Theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    LayoutOrder = i,
                    AutoButtonColor = false,
                    ZIndex = 3,
                }, list)
                b.MouseEnter:Connect(function()
                    b.BackgroundTransparency = 0.85
                    b.BackgroundColor3 = Theme.Element
                end)
                b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
                b.MouseButton1Click:Connect(function()
                    selected = opt
                    current.Text = tostring(opt)
                    current.TextColor3 = Theme.Text
                    open = false
                    list.Size = UDim2.new(1, -4, 0, 0)
                    tween(chev, { Rotation = 0 }, 0.18)
                    spawn(function() wait(0.12) list.Visible = false end)
                    if callback then pcall(callback, opt) end
                end)
            end

            row.MouseButton1Click:Connect(function()
                open = not open
                list.Visible = true
                local h = math.min(#options * 28, 160)
                list.Size = UDim2.new(1, -4, 0, open and h or 0)
                tween(chev, { Rotation = open and 180 or 0 }, 0.18)
                if not open then
                    spawn(function() wait(0.12) list.Visible = false end)
                end
            end)

            return {
                Set = function(_, v) selected = v; current.Text = tostring(v) end,
                Get = function() return selected end,
            }
        end

        function Tab:CreateKeybind(text, default, callback)
            local key = default
            local row = baseRow(34)

            new("TextLabel", {
                Size = UDim2.new(1, -100, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text = tostring(text),
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
            }, row)

            local bind = new("TextLabel", {
                Size = UDim2.fromOffset(74, 20),
                Position = UDim2.new(1, -82, 0.5, -10),
                BackgroundColor3 = Theme.Panel,
                Text = key and key.Name or "None",
                TextColor3 = Theme.Text,
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                ZIndex = 3,
            }, row)
            corner(5, bind)

            local waiting = false
            row.MouseButton1Click:Connect(function()
                if waiting then return end
                waiting = true
                bind.Text = "..."
                local conn
                conn = UserInputService.InputBegan:Connect(function(input, processed)
                    if not waiting then conn:Disconnect() return end
                    if processed then return end
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        key = input.KeyCode
                        bind.Text = key.Name
                        waiting = false
                        conn:Disconnect()
                        if callback then pcall(callback, key) end
                    end
                end)
            end)

            return { Get = function() return key end }
        end

        function Tab:CreateParagraph(title, body)
            local frame = new("Frame", {
                Size = UDim2.new(1, -4, 0, 70),
                BackgroundColor3 = Theme.Element,
                LayoutOrder = order(),
            }, page)
            corner(7, frame)
            stroke(Theme.Stroke, 1, frame)
            new("TextLabel", {
                Size = UDim2.new(1, -20, 0, 18),
                Position = UDim2.fromOffset(10, 5),
                BackgroundTransparency = 1,
                Text = tostring(title),
                TextColor3 = Theme.Text,
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
            }, frame)
            new("TextLabel", {
                Size = UDim2.new(1, -20, 0, 40),
                Position = UDim2.fromOffset(10, 25),
                BackgroundTransparency = 1,
                Text = tostring(body),
                TextColor3 = Theme.TextDim,
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                ZIndex = 2,
            }, frame)
            return frame
        end

        function Tab:CreateInput(text, placeholder, callback)
            local row = new("Frame", {
                Size = UDim2.new(1, -4, 0, 34),
                BackgroundColor3 = Theme.Element,
                LayoutOrder = order(),
            }, page)
            corner(7, row)
            stroke(Theme.Stroke, 1, row)
            new("TextLabel", {
                Size = UDim2.new(0, 110, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text = tostring(text),
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
            }, row)
            local box = new("TextBox", {
                Size = UDim2.new(0, 140, 0, 22),
                Position = UDim2.new(1, -150, 0.5, -11),
                BackgroundColor3 = Theme.Panel,
                Text = "",
                PlaceholderText = tostring(placeholder or "..."),
                PlaceholderColor3 = Theme.TextDim,
                TextColor3 = Theme.Text,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                ClearTextOnFocus = false,
                ZIndex = 3,
            }, row)
            corner(5, box)
            box.FocusLost:Connect(function(enter)
                if callback and box.Text ~= "" then pcall(callback, box.Text, enter) end
            end)
            return {
                Set = function(_, v) box.Text = tostring(v) end,
                Get = function() return box.Text end,
            }
        end

        return Tab
    end

    --====================================================================--
    -- DRAGGING (mouse + touch)
    --====================================================================--
    local function makeDraggable(handle, target)
        local dragging, dragStart, startPos = false, nil, nil
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = target.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                target.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end
    makeDraggable(top, main)

    --====================================================================--
    -- RESTORE PILL (WindUI style, top-center)
    --====================================================================--
    -- WindUI-style floating toggle: circular button, top-center, fades in/out
    local pill = new("TextButton", {
        Name = "ToggleUI",
        Size = UDim2.fromOffset(42, 42),
        Position = UDim2.new(0.5, -21, 0, 10),
        BackgroundColor3 = Theme.Background,
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        BackgroundTransparency = 1, -- animated in
        ZIndex = 100,
    }, gui)
    corner(21, pill) -- full circle
    stroke(Theme.Stroke, 1.5, pill)
    new("ImageLabel", {
        Size = UDim2.new(1, 18, 1, 18),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://5028857084",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 0.9,
        ScaleType = Enum.ScaleType.Slice,
        ZIndex = 99,
    }, pill)

    local pillIcon = makeIcon(pill, "logo", "P", 22, 13, Theme.TextDim)
    pillIcon.Position = UDim2.new(0.5, -11, 0.5, -11)
    pillIcon.ZIndex = 101

    makeDraggable(pill, pill)

    local pillOpen = false
    local function showPill()
        if pillOpen then return end
        pillOpen = true
        pill.Visible = true
        pill.BackgroundTransparency = 1
        for _, c in ipairs(pillIcon:GetChildren()) do
            if c:IsA("ImageLabel") then c.ImageTransparency = 1 end
            if c:IsA("TextLabel") then c.TextTransparency = 1 end
        end
        tween(pill, { BackgroundTransparency = 0 }, 0.25)
        for _, c in ipairs(pillIcon:GetChildren()) do
            if c:IsA("ImageLabel") then tween(c, { ImageTransparency = 0 }, 0.25) end
            if c:IsA("TextLabel") then tween(c, { TextTransparency = 0 }, 0.25) end
        end
    end
    local function hidePill()
        pillOpen = false
        pill.Visible = false
    end

    pill.MouseEnter:Connect(function()
        tween(pill, { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0.5, -23, 0, 8) }, 0.15)
    end)
    pill.MouseLeave:Connect(function()
        tween(pill, { Size = UDim2.fromOffset(42, 42), Position = UDim2.new(0.5, -21, 0, 10) }, 0.15)
    end)
    pill.MouseButton1Click:Connect(function()
        main.Visible = true
        hidePill()
    end)

    -- keep in sync with any visibility change
    spawn(function()
        while gui.Parent ~= nil do
            if main.Visible and pillOpen then
                hidePill()
            elseif not main.Visible and not pillOpen then
                showPill()
            end
            wait(0.1)
        end
    end)

    --====================================================================--
    -- TOGGLE KEY
    --====================================================================--
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.RightControl then
            main.Visible = not main.Visible
        end
    end)

    ---------------------------------------------------------------- api
    Window.Gui = gui
    Window.Main = main
    function Window:Destroy() gui:Destroy() end
    function Window:SetVisible(v)
        main.Visible = v and true or false
    end
    function Window:Toggle() main.Visible = not main.Visible end

    -- open animation
    local finalSize = UDim2.fromOffset(winW, winH)
    main.Size = UDim2.fromOffset(0, 0)
    tween(main, { Size = finalSize }, 0.3, Enum.EasingStyle.Back)

    return Window
end

return PulseUI
