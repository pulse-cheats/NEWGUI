--[[
    PulseUI v1.2 - Custom UI Library
    GitHub: github.com/pulse-cheats/NEWGUI
    Theme:  white / gray

    - NO default tabs. You create your own.
    - Works on all executors (asset icons are optional, text fallback always works).
    - Toggle UI: RightControl
]]

-- error wrapper so failures are visible in console
local ok, PulseUI = pcall(function()

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer

-- safest parent across executors
local function getGuiParent()
    if type(gethui) == "function" then
        local ok, ui = pcall(gethui)
        if ok and ui then return ui end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then return core end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local GUI_PARENT = getGuiParent()

local ASSET_URL = "https://raw.githubusercontent.com/pulse-cheats/NEWGUI/main/assets/"

local Theme = {
    Background   = Color3.fromRGB(248, 248, 250),
    Panel        = Color3.fromRGB(240, 240, 243),
    Element      = Color3.fromRGB(232, 232, 236),
    ElementHover = Color3.fromRGB(220, 220, 225),
    Stroke       = Color3.fromRGB(200, 200, 206),
    Text         = Color3.fromRGB(40, 40, 46),
    TextDim      = Color3.fromRGB(120, 120, 128),
    Accent       = Color3.fromRGB(120, 120, 128),
    AccentDark   = Color3.fromRGB(90, 90, 98),
    White        = Color3.fromRGB(255, 255, 255),
}

local PulseUI = {}

--========================================================================--
-- UTIL
--========================================================================--

local function safe(fn, ...)
    local args = {...}
    return function(...)
        local r = { pcall(fn, ...) }
        return r
    end
end

local function new(class, props, parent)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then
                pcall(function() inst[k] = v end)
            end
        end
    end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(radius, parent)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function stroke(color, thickness, parent)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function tween(inst, props, t)
    local ok, tw = pcall(function()
        return TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    end)
    if ok and tw then tw:Play() end
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

--========================================================================--
-- ASSETS (optional - graceful fallback to text glyphs)
--========================================================================--

local assetCache = {}

-- smart name resolution: "Home", "HOME", "home icon", "My_Tab" -> assets/<name>.png
-- tries in order: exact, lowercase, lowercase-with-underscores, lowercase-no-spaces
local function resolveAssetName(name)
    name = tostring(name or "")
    if name:match("%.png$") or name:match("%.jpg$") then return name end
    local clean = name:gsub("%s+", "")
    local lower = clean:lower()
    return lower .. ".png"
end

local function loadAssetUrl(name)
    -- accepts "Home", "HOME_ICON", "home.png" etc. -> tries assets/<resolved>
    name = resolveAssetName(name)
    if assetCache[name] ~= nil then return assetCache[name] end
    local result = ""
    local ok, res = pcall(function()
        if type(getcustomasset) ~= "function" or type(writefile) ~= "function" then return "" end
        pcall(function() makefolder("PulseUI") end)
        pcall(function() makefolder("PulseUI/assets") end)
        local file = "PulseUI/assets/" .. name
        if not (type(isfile) == "function" and isfile(file)) then
            writefile(file, game:HttpGet(ASSET_URL .. name))
        end
        return getcustomasset(file)
    end)
    if ok and type(res) == "string" and res ~= "" then
        result = res
    end
    assetCache[name] = result
    return result
end

-- icon: tries PNG, falls back to a text glyph
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
        TextSize = glyphSize or (size - 4),
        Font = Enum.Font.GothamBold,
        Visible = true,
    }, holder)

    if img.Image ~= "" then
        task.spawn(function()
            local ok = pcall(function()
                game:GetService("ContentProvider"):PreloadAsync({ img })
            end)
            if ok and img.IsLoaded then
                img.Visible = true
                label.Visible = false
            end
        end)
    end

    return holder, img, label
end

local function setIconColor(holder, color)
    for _, c in ipairs(holder:GetChildren()) do
        if c:IsA("ImageLabel") then c.ImageColor3 = color end
        if c:IsA("TextLabel") then c.TextColor3 = color end
    end
end

--========================================================================--
-- WINDOW
--========================================================================--

function PulseUI.CreateWindow(config)
    config = config or {}

    local Window = {}
    Window.Tabs = {}

    local gui = new("ScreenGui", {
        Name = "PulseUI_" .. tostring(math.random(100000, 999999)),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    }, GUI_PARENT)

    -- window size: default 560x400, override with config.Size = {width, height}
    local winW, winH = 560, 400
    if type(config.Size) == "table" and #config.Size == 2 then
        winW, winH = tonumber(config.Size[1]) or winW, tonumber(config.Size[2]) or winH
    end

    -- auto-scale down on small screens (mobile)
    local okvp, vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    vp = (okvp and vp) or Vector2.new(1280, 720)
    local scale = math.min(1, vp.X / (winW + 40), vp.Y / (winH + 40))
    winW, winH = math.floor(winW * scale), math.floor(winH * scale)

    local main = new("Frame", {
        Size = UDim2.fromOffset(winW, winH),
        Position = UDim2.new(0.5, -winW / 2, 0.5, -winH / 2),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Active = true,
    }, gui)
    corner(10, main)
    stroke(Theme.Stroke, 1.5, main)

    -- top bar
    local top = new("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
    }, main)
    corner(10, top)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
    }, top)

    local logo, _, _ = makeIcon(top, "logo.png", "P", 26, 16, Theme.Accent)
    logo.Position = UDim2.fromOffset(12, 8)

    new("TextLabel", {
        Size = UDim2.new(0, 400, 0, 18),
        Position = UDim2.fromOffset(48, 6),
        BackgroundTransparency = 1,
        Text = config.Title or "PulseUI",
        TextColor3 = Theme.Text,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, top)

    if config.SubTitle then
        new("TextLabel", {
            Size = UDim2.new(0, 400, 0, 12),
            Position = UDim2.fromOffset(48, 25),
            BackgroundTransparency = 1,
            Text = config.SubTitle,
            TextColor3 = Theme.TextDim,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, top)
    end

    local function topButton(iconName, glyph, offset, callback)
        local btn = new("TextButton", {
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.new(1, offset, 0.5, -13),
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundTransparency = 1,
            Text = "",
        }, top)
        local holder = makeIcon(btn, iconName, glyph, 16, 13, Theme.TextDim)
        btn.MouseEnter:Connect(function() setIconColor(holder, Theme.Text) end)
        btn.MouseLeave:Connect(function() setIconColor(holder, Theme.TextDim) end)
        btn.MouseButton1Click:Connect(callback)
    end

    topButton("close.png", "X", -10, function() gui:Destroy() end)
    topButton("minimize.png", "_", -42, function() main.Visible = not main.Visible end)

    -- sidebar
    local side = new("Frame", {
        Size = UDim2.new(0, 54, 1, -42),
        Position = UDim2.fromOffset(0, 42),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
    }, main)
    new("UIListLayout", {
        Padding = UDim.new(0, 6),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, side)
    new("UIPadding", { PaddingTop = UDim.new(0, 10) }, side)

    -- content
    local content = new("Frame", {
        Size = UDim2.new(1, -54, 1, -42),
        Position = UDim2.fromOffset(54, 42),
        BackgroundTransparency = 1,
    }, main)

    -- tab bar (empty until user creates tabs)
    local tabBar = new("Frame", {
        Size = UDim2.new(1, -16, 0, 34),
        Position = UDim2.fromOffset(8, 6),
        BackgroundTransparency = 1,
    }, content)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }, tabBar)

    local pages = new("Frame", {
        Size = UDim2.new(1, -16, 1, -48),
        Position = UDim2.fromOffset(8, 46),
        BackgroundTransparency = 1,
    }, content)

    -- placeholder when no tabs exist
    local placeholder = new("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "Create your first tab:\nWindow:CreateTab(\"Main\", \"home.png\")",
        TextColor3 = Theme.TextDim,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        Visible = true,
    }, pages)

    --====================================================================--
    -- CREATE TAB (user-driven - no defaults)
    --====================================================================--

    function Window:CreateTab(name, iconName, glyph)
        local tabData = {}
        tabData.Name = name

        -- sidebar icon button
        local sideBtn = new("TextButton", {
            Size = UDim2.fromOffset(36, 36),
            BackgroundColor3 = Theme.Element,
            BackgroundTransparency = 1,
            Text = "",
            LayoutOrder = #Window.Tabs + 1,
        }, side)
        corner(8, sideBtn)
        local sHolder = makeIcon(sideBtn, iconName or "settings.png", glyph or "#", 20, 15, Theme.TextDim)

        -- top tab button
        local tabBtn = new("TextButton", {
            Size = UDim2.new(0, 100, 1, 0),
            BackgroundColor3 = Theme.Element,
            BackgroundTransparency = 1,
            Text = name,
            TextColor3 = Theme.TextDim,
            TextSize = 13,
            Font = Enum.Font.GothamMedium,
        }, tabBar)
        corner(6, tabBtn)

        local underline = new("Frame", {
            Size = UDim2.new(1, -16, 0, 2),
            Position = UDim2.new(0, 8, 1, -1),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, tabBtn)

        -- page
        local page = new("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Stroke,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
        }, pages)
        new("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, page)
        new("UIPadding", {
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 12),
            PaddingLeft = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 12),
        }, page)

        local Tab = {}
        Tab.Name = name
        Tab.Page = page

        function Tab:Select()
            for _, t in ipairs(Window.Tabs) do
                t.Page.Visible = false
                t.Button.BackgroundTransparency = 1
                t.Button.TextColor3 = Theme.TextDim
                t.Underline.BackgroundTransparency = 1
                setIconColor(t.SideHolder, Theme.TextDim)
                t.SideBtn.BackgroundTransparency = 1
            end
            page.Visible = true
            placeholder.Visible = false
            tabBtn.BackgroundTransparency = 0.4
            tabBtn.TextColor3 = Theme.Text
            underline.BackgroundTransparency = 0
            sideBtn.BackgroundTransparency = 0.4
            setIconColor(sHolder, Theme.Text)
        end

        sideBtn.MouseButton1Click:Connect(function() Tab:Select() end)
        tabBtn.MouseButton1Click:Connect(function() Tab:Select() end)

        tabData.Page = page
        tabData.Button = tabBtn
        tabData.Underline = underline
        tabData.SideBtn = sideBtn
        tabData.SideHolder = sHolder

        Window.Tabs[#Window.Tabs + 1] = tabData

        -- first tab auto-selects
        if #Window.Tabs == 1 then Tab:Select() end

        --================================================================--
        -- ELEMENTS
        --================================================================--

        local function order() return #page:GetChildren() end

        function Tab:CreateSection(label)
            return new("TextLabel", {
                Size = UDim2.new(1, -4, 0, 26),
                BackgroundTransparency = 1,
                Text = string.upper(tostring(label)),
                TextColor3 = Theme.TextDim,
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = order(),
            }, page)
        end

        function Tab:CreateLabel(text)
            return new("TextLabel", {
                Size = UDim2.new(1, -4, 0, 28),
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
            local btn = new("TextButton", {
                Size = UDim2.new(1, -4, 0, 38),
                BackgroundColor3 = Theme.Element,
                Text = tostring(text),
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                LayoutOrder = order(),
            }, page)
            corner(6, btn)
            stroke(Theme.Stroke, 1, btn)

            btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = Theme.ElementHover }) end)
            btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = Theme.Element }) end)
            btn.MouseButton1Click:Connect(function()
                tween(btn, { BackgroundColor3 = Theme.AccentDark }, 0.08)
                spawn(function()
                    wait(0.09)
                    tween(btn, { BackgroundColor3 = Theme.Element })
                end)
                if callback then
                    local ok, err = pcall(callback)
                    if not ok then warn("[PulseUI] button error: " .. tostring(err)) end
                end
            end)
            return btn
        end

        function Tab:CreateToggle(text, default, callback)
            local state = default and true or false

            local row = new("TextButton", {
                Size = UDim2.new(1, -4, 0, 36),
                BackgroundColor3 = Theme.Element,
                Text = "",
                LayoutOrder = order(),
            }, page)
            corner(6, row)
            stroke(Theme.Stroke, 1, row)

            new("TextLabel", {
                Size = UDim2.new(1, -64, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text = tostring(text),
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)

            local pill = new("Frame", {
                Size = UDim2.fromOffset(42, 22),
                Position = UDim2.new(1, -54, 0.5, -11),
                BackgroundColor3 = state and Theme.Accent or Theme.ElementHover,
                BorderSizePixel = 0,
            }, row)
            corner(11, pill)

            local knob = new("Frame", {
                Size = UDim2.fromOffset(16, 16),
                Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
                BackgroundColor3 = Theme.White,
                BorderSizePixel = 0,
            }, pill)
            corner(8, knob)

            local function set(v)
                state = v and true or false
                tween(pill, { BackgroundColor3 = state and Theme.Accent or Theme.ElementHover }, 0.2)
                tween(knob, {
                    Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
                }, 0.2)
                if callback then pcall(callback, state) end
            end

            row.MouseButton1Click:Connect(function() set(not state) end)

            return {
                Set = function(_, v) set(v) end,
                Get = function() return state end,
            }
        end

        function Tab:CreateSlider(text, min, max, default, callback)
            min = min or 0
            max = max or 100
            default = default or min
            local value = default

            local row = new("Frame", {
                Size = UDim2.new(1, -4, 0, 50),
                BackgroundColor3 = Theme.Element,
                LayoutOrder = order(),
            }, page)
            corner(6, row)
            stroke(Theme.Stroke, 1, row)

            new("TextLabel", {
                Size = UDim2.new(1, -70, 0, 20),
                Position = UDim2.fromOffset(12, 3),
                BackgroundTransparency = 1,
                Text = tostring(text),
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)

            local valueLabel = new("TextLabel", {
                Size = UDim2.fromOffset(56, 20),
                Position = UDim2.new(1, -60, 0, 3),
                BackgroundTransparency = 1,
                Text = tostring(default),
                TextColor3 = Theme.Accent,
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Right,
            }, row)

            local bar = new("Frame", {
                Size = UDim2.new(1, -24, 0, 6),
                Position = UDim2.fromOffset(12, 34),
                BackgroundColor3 = Theme.ElementHover,
                BorderSizePixel = 0,
            }, row)
            corner(3, bar)

            local ratio0 = clamp((default - min) / math.max(max - min, 1), 0, 1)

            local fill = new("Frame", {
                Size = UDim2.new(ratio0, 0, 1, 0),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
            }, bar)
            corner(3, fill)

            local knob = new("Frame", {
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.new(ratio0, -7, 0.5, -7),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                ZIndex = 2,
            }, bar)
            corner(7, knob)

            local dragging = false

            local function setFromX(x)
                local rel = clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
                value = math.floor(min + (max - min) * rel + 0.5)
                fill.Size = UDim2.new(rel, 0, 1, 0)
                knob.Position = UDim2.new(rel, -7, 0.5, -7)
                valueLabel.Text = tostring(value)
                if callback then pcall(callback, value) end
            end

            bar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    setFromX(input.Position.X)
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
                    value = clamp(v, min, max)
                    local rel = clamp((value - min) / math.max(max - min, 1), 0, 1)
                    fill.Size = UDim2.new(rel, 0, 1, 0)
                    knob.Position = UDim2.new(rel, -7, 0.5, -7)
                    valueLabel.Text = tostring(value)
                    if callback then pcall(callback, value) end
                end,
                Get = function() return value end,
            }
        end

        function Tab:CreateDropdown(text, options, default, callback)
            options = options or {}
            local selected = default or options[1]
            local open = false

            local row = new("TextButton", {
                Size = UDim2.new(1, -4, 0, 36),
                BackgroundColor3 = Theme.Element,
                Text = "",
                LayoutOrder = order(),
            }, page)
            corner(6, row)
            stroke(Theme.Stroke, 1, row)

            new("TextLabel", {
                Size = UDim2.new(0, 150, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text = tostring(text),
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)

            local current = new("TextLabel", {
                Size = UDim2.new(0, 130, 1, 0),
                Position = UDim2.new(1, -160, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(selected),
                TextColor3 = Theme.Accent,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Right,
            }, row)

            local chev = new("TextLabel", {
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.new(1, -26, 0.5, -8),
                BackgroundTransparency = 1,
                Text = "v",
                TextColor3 = Theme.TextDim,
                TextSize = 14,
                Font = Enum.Font.GothamBold,
            }, row)

            local list = new("Frame", {
                Size = UDim2.new(1, -4, 0, 0),
                BackgroundColor3 = Theme.Panel,
                Visible = false,
                ClipsDescendants = true,
                LayoutOrder = order() + 1,
            }, page)
            corner(6, list)
            stroke(Theme.Stroke, 1, list)
            new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)

            for i, opt in ipairs(options) do
                local b = new("TextButton", {
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundTransparency = 1,
                    Text = tostring(opt),
                    TextColor3 = Theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    LayoutOrder = i,
                }, list)
                b.MouseEnter:Connect(function()
                    b.BackgroundTransparency = 0.85
                    b.BackgroundColor3 = Theme.Element
                end)
                b.MouseLeave:Connect(function()
                    b.BackgroundTransparency = 1
                end)
                b.MouseButton1Click:Connect(function()
                    selected = opt
                    current.Text = tostring(opt)
                    open = false
                    list.Visible = false
                    list.Size = UDim2.new(1, -4, 0, 0)
                    chev.Text = "v"
                    chev.Rotation = 0
                    if callback then pcall(callback, opt) end
                end)
            end

            row.MouseButton1Click:Connect(function()
                open = not open
                list.Visible = true
                list.Size = UDim2.new(1, -4, 0, open and (#options * 30) or 0)
                chev.Rotation = open and 180 or 0
                if not open then
                    spawn(function() wait(0.15) list.Visible = false end)
                end
            end)

            return {
                Set = function(_, v) selected = v; current.Text = tostring(v) end,
                Get = function() return selected end,
            }
        end

        function Tab:CreateKeybind(text, default, callback)
            local key = default

            local row = new("TextButton", {
                Size = UDim2.new(1, -4, 0, 36),
                BackgroundColor3 = Theme.Element,
                Text = "",
                LayoutOrder = order(),
            }, page)
            corner(6, row)
            stroke(Theme.Stroke, 1, row)

            new("TextLabel", {
                Size = UDim2.new(1, -110, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text = tostring(text),
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)

            local bind = new("TextLabel", {
                Size = UDim2.fromOffset(80, 22),
                Position = UDim2.new(1, -88, 0.5, -11),
                BackgroundColor3 = Theme.ElementHover,
                Text = key and key.Name or "None",
                TextColor3 = Theme.Accent,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
            }, row)
            corner(4, bind)

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

            return {
                Get = function() return key end,
            }
        end

        function Tab:CreateParagraph(title, body)
            local frame = new("Frame", {
                Size = UDim2.new(1, -4, 0, 76),
                BackgroundColor3 = Theme.Element,
                LayoutOrder = order(),
            }, page)
            corner(6, frame)
            stroke(Theme.Stroke, 1, frame)
            new("TextLabel", {
                Size = UDim2.new(1, -20, 0, 22),
                Position = UDim2.fromOffset(10, 6),
                BackgroundTransparency = 1,
                Text = tostring(title),
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, frame)
            new("TextLabel", {
                Size = UDim2.new(1, -20, 0, 40),
                Position = UDim2.fromOffset(10, 28),
                BackgroundTransparency = 1,
                Text = tostring(body),
                TextColor3 = Theme.TextDim,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
            }, frame)
            return frame
        end

        return Tab
    end

    --====================================================================--
    -- DRAGGING (mouse + touch)
    --====================================================================--
    do
        local dragging, dragStart, startPos = false, nil, nil
        top.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = main.Position
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
                main.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    --====================================================================--
    -- TOGGLE KEY (RightControl)
    --====================================================================--
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.RightControl then
            main.Visible = not main.Visible
        end
    end)

    --====================================================================--
    -- RESTORE PILL (WindUI-style floating button, top-center of screen)
    -- shown whenever the window is hidden
    --====================================================================--
    local pill = new("TextButton", {
        Name = "RestorePill",
        Size = UDim2.fromOffset(46, 30),
        Position = UDim2.new(0.5, -23, 0, 6),
        BackgroundColor3 = Theme.Background,
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        ZIndex = 50,
    }, gui)
    corner(15, pill)
    stroke(Theme.Stroke, 1.5, pill)
    -- small shadow
    new("ImageLabel", {
        Size = UDim2.new(1, 14, 1, 14),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://5028857084",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 0.92,
        ScaleType = Enum.ScaleType.Slice,
        ZIndex = 49,
    }, pill)

    local pillIcon, pillImg, pillGlyph = makeIcon(pill, "logo.png", "P", 20, 12, Theme.TextDim)
    pillIcon.Position = UDim2.new(0.5, -10, 0.5, -10)
    pillIcon.ZIndex = 51

    -- pill drag support
    do
        local dragging, dragStart, startPos = false, nil, nil
        pill.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = pill.Position
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
                pill.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    local function updatePill()
        pill.Visible = not main.Visible
    end
    updatePill()

    -- click pill -> reopen window
    pill.MouseButton1Click:Connect(function()
        main.Visible = true
        updatePill()
    end)

    -- keep pill in sync with visibility changes (RightControl, minimize etc.)
    spawn(function()
        while gui.Parent ~= nil do
            updatePill()
            wait(0.15)
        end
    end)

    -- open animation
    main.Visible = true
    local finalSize = UDim2.fromOffset(winW, winH)
    main.Size = UDim2.fromOffset(0, 0)
    tween(main, { Size = finalSize }, 0.3, Enum.EasingStyle.Back)

    Window.Gui = gui
    Window.Main = main
    function Window:Destroy() gui:Destroy() end
    function Window:SetVisible(v) main.Visible = v end

    return Window
end

return PulseUI

end)

if not ok then
    warn("[PulseUI] Failed to load: " .. tostring(PulseUI))
    return
end

if not PulseUI then
    warn("[PulseUI] Unknown error during load")
    return
end

print("[PulseUI] v1.2 loaded successfully")
return PulseUI
