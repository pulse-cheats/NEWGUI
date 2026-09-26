--[[
    ██████╗ ██╗   ██╗██╗     ███████╗███████╗██╗   ██╗██╗
    ██╔═══██╗██║   ██║██║     ██╔════╝██╔════╝██║   ██║██║
    ██║   ██║██║   ██║██║     █████╗  ███████╗██║   ██║██║
    ██║   ██║██║   ██║██║     ██╔══╝  ╚════██║╚██╗ ██╔╝██║
    ╚██████╔╝╚██████╔╝███████╗███████╗╚██████╔╝ ╚████╔╝ ██║
     ╚═════╝  ╚═════╝ ╚══════╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝

    PulseUI v1.1  —  custom UI library
    GitHub: github.com/pulse-cheats/NEWGUI
    Assets: raw.githubusercontent.com/pulse-cheats/NEWGUI/main/assets/
    Theme : white / gray
]]

print("[PulseUI] loading v1.1 ...")

local PulseUI = {}

-- // Services ---------------------------------------------------------
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local ContentProvider   = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- // Config -----------------------------------------------------------
local REPO_URL   = "https://raw.githubusercontent.com/pulse-cheats/NEWGUI/main/"
local ASSET_URL  = REPO_URL .. "assets/"
local ASSET_DIR  = "PulseUI/assets/"

local Theme = {
    Background   = Color3.fromRGB(248, 248, 250),
    Panel        = Color3.fromRGB(240, 240, 243),
    Element      = Color3.fromRGB(232, 232, 236),
    ElementHover = Color3.fromRGB(220, 220, 225),
    Stroke       = Color3.fromRGB(200, 200, 206),
    Text         = Color3.fromRGB(40,  40,  46),
    TextDim      = Color3.fromRGB(120, 120, 128),
    Accent       = Color3.fromRGB(120, 120, 128),
    AccentDark   = Color3.fromRGB(90,  90,  98),
    White        = Color3.fromRGB(255, 255, 255),
}

-- // Asset loader -----------------------------------------------------
-- Downloads asset from GitHub once, caches it locally, converts it into
-- a Roblox-usable path with getcustomasset. Falls back gracefully.
local assetCache   = {}
local assetEnabled = (type(getcustomasset) == "function") and (type(writefile) == "function")

local function resolvePath(name)
    if assetCache[name] ~= nil then return assetCache[name] end

    local path = ""

    if assetEnabled then
        local ok, res = pcall(function()
            if type(makefolder) == "function" then
                pcall(makefolder, "PulseUI")
                pcall(makefolder, "PulseUI/assets")
            end
            local file = ASSET_DIR .. name
            if not (type(isfile) == "function" and isfile(file)) then
                local data = game:HttpGet(ASSET_URL .. name, true)
                writefile(file, data)
            end
            return getcustomasset(file)
        end)
        if ok and type(res) == "string" and res ~= "" then
            path = res
        end
    end

    assetCache[name] = path
    return path
end

-- // Helpers ----------------------------------------------------------
local function new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    inst.Parent = parent or (props and props.Parent)
    return inst
end

local function corner(r, parent)
    new("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function stroke(color, thickness, parent)
    new("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function tween(inst, props, time, style)
    local t = TweenService:Create(inst,
        TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad), props)
    t:Play()
    return t
end

-- // Icon helper (image + text fallback) ------------------------------
-- glyph is shown until (or unless) the PNG is loaded.
local function makeIcon(parent, name, glyph, size, textSize, color)
    size = size or 22
    textSize = textSize or 16
    color = color or Theme.TextDim

    local img = new("ImageLabel", {
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Image = resolvePath(name),
        ImageColor3 = color,
        ImageTransparency = 0,
        Visible = false,
    }, parent)

    local glyphLabel = new("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = glyph or "",
        TextColor3 = color,
        TextSize = textSize,
        Font = Enum.Font.GothamBold,
    }, parent)

    if img.Image ~= "" then
        task.spawn(function()
            local ok = pcall(function() ContentProvider:PreloadAsync({ img }) end)
            if ok and img.IsLoaded then
                img.Visible = true
                glyphLabel.Visible = false
            end
        end)
    end

    return img, glyphLabel
end

-- // Window -----------------------------------------------------------
function PulseUI.CreateWindow(config)
    config = config or {}
    local Window = { Tabs = {}, Flags = {} }

    local gui = new("ScreenGui", {
        Name = "PulseUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)

    local main = new("Frame", {
        Name = "Main",
        Size = UDim2.fromOffset(760, 520),
        Position = UDim2.new(0.5, -380, 0.5, -260),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Visible = false,
    }, gui)
    corner(10, main)
    stroke(Theme.Stroke, 1.5, main)

    -- soft shadow layer
    new("ImageLabel", {
        Size = UDim2.fromScale(1.15, 1.22),
        Position = UDim2.fromScale(-0.075, -0.11),
        BackgroundTransparency = 1,
        Image = "rbxassetid://5028857084",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 0.93,
        ScaleType = Enum.ScaleType.Slice,
        ZIndex = 0,
    }, main)

    -- ---- top bar
    local top = new("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, main)
    corner(10, top)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, top)

    makeIcon(top, "logo.png", "◆", 26, 18, Theme.Accent).Position = UDim2.fromOffset(12, 9)

    new("TextLabel", {
        Size = UDim2.new(0, 300, 0, 20),
        Position = UDim2.fromOffset(48, 5),
        BackgroundTransparency = 1,
        Text = config.Title or "PulseUI",
        TextColor3 = Theme.Text,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
    }, top)

    if config.SubTitle then
        new("TextLabel", {
            Size = UDim2.new(0, 400, 0, 14),
            Position = UDim2.fromOffset(48, 24),
            BackgroundTransparency = 1,
            Text = config.SubTitle,
            TextColor3 = Theme.TextDim,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
        }, top)
    end

    local function topBtn(name, glyph, offsetX, cb)
        local holder = new("TextButton", {
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.new(1, offsetX, 0.5, -13),
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 3,
        }, top)
        makeIcon(holder, name, glyph, 16, 14, Theme.TextDim)
        holder.MouseEnter:Connect(function()
            for _, c in ipairs(holder:GetChildren()) do
                if c:IsA("ImageLabel") then tween(c, { ImageColor3 = Theme.Text }, 0.12) end
                if c:IsA("TextLabel") and c.Visible then tween(c, { TextColor3 = Theme.Text }, 0.12) end
            end
        end)
        holder.MouseLeave:Connect(function()
            for _, c in ipairs(holder:GetChildren()) do
                if c:IsA("ImageLabel") then tween(c, { ImageColor3 = Theme.TextDim }, 0.12) end
                if c:IsA("TextLabel") and c.Visible then tween(c, { TextColor3 = Theme.TextDim }, 0.12) end
            end
        end)
        holder.MouseButton1Click:Connect(cb)
        return holder
    end

    topBtn("close.png",    "✕", -10, function() gui:Destroy() end)
    topBtn("minimize.png", "—", -42, function() main.Visible = not main.Visible end)

    -- ---- sidebar rail
    local side = new("Frame", {
        Size = UDim2.new(0, 56, 1, -44),
        Position = UDim2.fromOffset(0, 44),
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

    -- ---- content
    local content = new("Frame", {
        Size = UDim2.new(1, -56, 1, -44),
        Position = UDim2.fromOffset(56, 44),
        BackgroundTransparency = 1,
    }, main)

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

    -- ---- tab factory
    function Window:CreateTab(name, iconName, glyph)
        iconName = iconName or "settings.png"
        glyph = glyph or "•"

        local sideBtn = new("TextButton", {
            Size = UDim2.fromOffset(36, 36),
            BackgroundColor3 = Theme.Element,
            BackgroundTransparency = 1,
            Text = "",
            LayoutOrder = #Window.Tabs + 1,
            ZIndex = 3,
        }, side)
        corner(8, sideBtn)
        makeIcon(sideBtn, iconName, glyph, 20, 15, Theme.TextDim)

        local tabBtn = new("TextButton", {
            Size = UDim2.new(0, 118, 1, 0),
            BackgroundColor3 = Theme.Element,
            BackgroundTransparency = 1,
            Text = name,
            TextColor3 = Theme.TextDim,
            TextSize = 13,
            Font = Enum.Font.GothamMedium,
            LayoutOrder = #Window.Tabs + 1,
        }, tabBar)
        corner(6, tabBtn)

        local page = new("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Accent,
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

        local underline = new("Frame", {
            Size = UDim2.new(1, -16, 0, 2),
            Position = UDim2.new(0, 8, 1, -1),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, tabBtn)
        corner(1, underline)

        local entry = {
            Page = page, Button = tabBtn, Underline = underline, SideBtn = sideBtn,
        }

        local Tab = {}

        function Tab:Select()
            for _, t in ipairs(Window.Tabs) do
                t.Page.Visible = false
                t.Button.BackgroundTransparency = 1
                t.Button.TextColor3 = Theme.TextDim
                t.Underline.BackgroundTransparency = 1
                t.SideBtn.BackgroundTransparency = 1
            end
            page.Visible = true
            tabBtn.BackgroundTransparency = 0.4
            tabBtn.TextColor3 = Theme.Text
            underline.BackgroundTransparency = 0
            sideBtn.BackgroundTransparency = 0.4
        end

        sideBtn.MouseButton1Click:Connect(function() Tab:Select() end)
        tabBtn.MouseButton1Click:Connect(function() Tab:Select() end)

        Window.Tabs[#Window.Tabs + 1] = entry
        if #Window.Tabs == 1 then Tab:Select() end

        -- ============ ELEMENTS ============

        local function order() return #page:GetChildren() end

        function Tab:CreateSection(label)
            return new("TextLabel", {
                Size = UDim2.new(1, -4, 0, 26),
                BackgroundTransparency = 1,
                Text = string.upper(label),
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
                Text = text,
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
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                LayoutOrder = order(),
            }, page)
            corner(6, btn)
            stroke(Theme.Stroke, 1, btn)
            btn.MouseEnter:Connect(function()
                tween(btn, { BackgroundColor3 = Theme.ElementHover })
            end)
            btn.MouseLeave:Connect(function()
                tween(btn, { BackgroundColor3 = Theme.Element })
            end)
            btn.MouseButton1Click:Connect(function()
                tween(btn, { BackgroundColor3 = Theme.AccentDark }, 0.08)
                task.delay(0.09, function()
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
                Text = text,
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
                state = v
                tween(pill, { BackgroundColor3 = v and Theme.Accent or Theme.ElementHover }, 0.2)
                tween(knob, {
                    Position = v and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
                }, 0.2)
                if callback then pcall(callback, v) end
            end

            row.MouseButton1Click:Connect(function() set(not state) end)

            local obj = {}
            function obj:Set(v) set(v) end
            function obj:Get() return state end
            return obj
        end

        function Tab:CreateSlider(text, min, max, default, callback)
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
                Text = text,
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

            local ratio0 = math.clamp((default - min) / math.max(max - min, 1), 0, 1)

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
                local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
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

            local obj = {}
            function obj:Set(v)
                value = math.clamp(v, min, max)
                local rel = math.clamp((value - min) / math.max(max - min, 1), 0, 1)
                fill.Size = UDim2.new(rel, 0, 1, 0)
                knob.Position = UDim2.new(rel, -7, 0.5, -7)
                valueLabel.Text = tostring(value)
                if callback then pcall(callback, value) end
            end
            function obj:Get() return value end
            return obj
        end

        function Tab:CreateDropdown(text, options, default, callback)
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
                Text = text,
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

            local chev = makeIcon(row, "chevron.png", "▾", 14, 13, Theme.TextDim)
            chev.Position = UDim2.new(1, -24, 0.5, -7)
            chev.AnchorPoint = Vector2.new(0.5, 0.5)
            chev.Position = UDim2.new(1, -20, 0.5, 0)

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

            local optButtons = {}
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
                    tween(b, { BackgroundTransparency = 0.85, BackgroundColor3 = Theme.Element })
                end)
                b.MouseLeave:Connect(function()
                    tween(b, { BackgroundTransparency = 1 })
                end)
                b.MouseButton1Click:Connect(function()
                    selected = opt
                    current.Text = tostring(opt)
                    open = false
                    list.Visible = false
                    list.Size = UDim2.new(1, -4, 0, 0)
                    tween(chev, { Rotation = 0 }, 0.2)
                    if callback then pcall(callback, opt) end
                end)
                optButtons[i] = b
            end

            row.MouseButton1Click:Connect(function()
                open = not open
                list.Visible = true
                list.Size = UDim2.new(1, -4, 0, open and (#options * 30) or 0)
                tween(chev, { Rotation = open and 180 or 0 }, 0.2)
                if not open then
                    task.delay(0.15, function() list.Visible = false end)
                end
            end)

            local obj = {}
            function obj:Set(v) selected = v; current.Text = tostring(v) end
            function obj:Get() return selected end
            return obj
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
                Text = text,
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

            local obj = {}
            function obj:Get() return key end
            return obj
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
                Text = title,
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, frame)
            new("TextLabel", {
                Size = UDim2.new(1, -20, 0, 40),
                Position = UDim2.fromOffset(10, 28),
                BackgroundTransparency = 1,
                Text = body,
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

    -- ---- dragging (mouse + touch)
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

    -- ---- toggle key
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.RightControl then
            main.Visible = not main.Visible
        end
    end)

    -- ---- open animation
    main.Visible = true
    local finalSize = UDim2.fromOffset(760, 520)
    main.Size = UDim2.fromOffset(0, 0)
    tween(main, { Size = finalSize }, 0.35, Enum.EasingStyle.Back)

    Window.Gui = gui
    Window.Main = main
    function Window:Destroy() gui:Destroy() end
    function Window:SetVisible(v) main.Visible = v end

    print("[PulseUI] window created \"" .. (config.Title or "PulseUI") .. "\"")
    return Window
end

return PulseUI
