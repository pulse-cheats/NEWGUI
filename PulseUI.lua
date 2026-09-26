--[[
    ██████╗ ██╗   ██╗██╗     ███████╗███████╗██╗   ██╗██╗
    ██╔═══██╗██║   ██║██║     ██╔════╝██╔════╝██║   ██║██║
    ██║   ██║██║   ██║██║     █████╗  ███████╗██║   ██║██║
    ██║   ██║██║   ██║██║     ██╔══╝  ╚════██║╚██╗ ██╔╝██║
    ╚██████╔╝╚██████╔╝███████╗███████╗╚██████╔╝ ╚████╔╝ ██║
     ╚═════╝  ╚═════╝ ╚══════╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝

    PulseUI - Custom UI Library
    by pulse-cheats
    GitHub: https://github.com/pulse-cheats/NEWGUI
    Assets: raw.githubusercontent.com/pulse-cheats/NEWGUI/main/assets/
]]

local PulseUI = {}
PulseUI.__index = PulseUI

-- // Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- // Config
local ASSET_BASE = "https://raw.githubusercontent.com/pulse-cheats/NEWGUI/main/assets/"
local Theme = {
    Background    = Color3.fromRGB(14, 14, 16),
    Panel         = Color3.fromRGB(22, 22, 25),
    Element       = Color3.fromRGB(30, 30, 34),
    ElementHover  = Color3.fromRGB(38, 38, 43),
    Stroke        = Color3.fromRGB(45, 45, 50),
    Text          = Color3.fromRGB(235, 235, 235),
    TextDim       = Color3.fromRGB(140, 140, 145),
    Accent        = Color3.fromRGB(170, 255, 60),   -- lime green
    AccentDark    = Color3.fromRGB(120, 190, 40),
}

-- // Asset Loader
local AssetCache = {}

local function LoadAsset(name)
    if AssetCache[name] then return AssetCache[name] end
    local ok, result = pcall(function()
        return game:LoadCustomAsset and game:LoadCustomAsset(ASSET_BASE .. name) or ASSET_BASE .. name
    end)
    -- Fallback: use the URL directly (works in most executors with custom asset support)
    local url = ASSET_BASE .. name
    AssetCache[name] = url
    return url
end

local function Create(className, props, children)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    for _, child in ipairs(children or {}) do child.Parent = inst end
    inst.Parent = props and props.Parent or nil
    return inst
end

local function Corner(r, parent)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = parent
    return c
end

local function Stroke(color, thickness, parent)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

-- //====================================================================//
-- //                          WINDOW CREATION                           //
-- //====================================================================//

function PulseUI.CreateWindow(config)
    config = config or {}
    local Window = {}
    Window.Tabs = {}
    Window.Flags = {}

    local ScreenGui = Create("ScreenGui", {
        Name = "PulseUI_" .. tostring(math.random(1e6)),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = PlayerGui,
    })

    -- Root frame
    local Main = Create("Frame", {
        Name = "Main",
        Size = UDim2.fromOffset(760, 520),
        Position = UDim2.new(0.5, -380, 0.5, -260),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = ScreenGui,
    })
    Corner(10, Main)
    local mainStroke = Stroke(Theme.Accent, 1.5, Main)

    -- Glow
    Create("ImageLabel", {
        Size = UDim2.fromScale(1.25, 1.35),
        Position = UDim2.fromScale(-0.125, -0.175),
        BackgroundTransparency = 1,
        Image = "rbxassetid://5028857084",
        ImageColor3 = Theme.Accent,
        ImageTransparency = 0.88,
        ScaleType = Enum.ScaleType.Slice,
        Parent = Main,
    })

    -- Draggable
    local TopBar = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Parent = Main,
    })
    Corner(10, TopBar)

    -- Logo
    Create("ImageLabel", {
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.fromOffset(10, 7),
        BackgroundTransparency = 1,
        Image = LoadAsset("logo.png"),
        Parent = TopBar,
    })

    -- Title
    local TitleLabel = Create("TextLabel", {
        Size = UDim2.new(0, 300, 1, 0),
        Position = UDim2.fromOffset(48, 0),
        BackgroundTransparency = 1,
        Text = config.Title or "PulseUI",
        TextColor3 = Theme.Text,
        TextSize = 17,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar,
    })
    if config.SubTitle then
        Create("TextLabel", {
            Size = UDim2.new(0, 300, 0, 14),
            Position = UDim2.fromOffset(48, 28),
            BackgroundTransparency = 1,
            Text = config.SubTitle,
            TextColor3 = Theme.TextDim,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = TopBar,
        })
    end

    -- Close / Minimize
    local function TopButton(iconName, posX, callback)
        local btn = Create("ImageButton", {
            Size = UDim2.fromOffset(28, 28),
            Position = UDim2.new(1, posX, 0.5, -14),
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundTransparency = 1,
            Image = LoadAsset(iconName),
            Parent = TopBar,
        })
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    TopButton("close.png", -8, function()
        ScreenGui:Destroy()
    end)
    TopButton("minimize.png", -42, function()
        Main.Visible = not Main.Visible
    end)

    -- Sidebar (icon rail)
    local Sidebar = Create("Frame", {
        Size = UDim2.new(0, 56, 1, -44),
        Position = UDim2.fromOffset(0, 44),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Parent = Main,
    })
    local SideList = Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Sidebar,
    })
    Create("UIPadding", { PaddingTop = UDim.new(0, 12), Parent = Sidebar })

    -- Content area
    local Content = Create("Frame", {
        Size = UDim2.new(1, -56, 1, -44),
        Position = UDim2.fromOffset(56, 44),
        BackgroundTransparency = 1,
        Parent = Main,
    })

    -- Tab buttons on top of content
    local TabBar = Create("Frame", {
        Size = UDim2.new(1, -16, 0, 36),
        Position = UDim2.fromOffset(8, 4),
        BackgroundTransparency = 1,
        Parent = Content,
    })
    local TabList = Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        Parent = TabBar,
    })

    local TabContainer = Create("Frame", {
        Size = UDim2.new(1, -16, 1, -48),
        Position = UDim2.fromOffset(8, 44),
        BackgroundTransparency = 1,
        Parent = Content,
    })

    -- // Tab creation
    function Window:CreateTab(name, icon)
        icon = icon or "settings.png"
        local Tab = { Name = name }

        -- Sidebar icon
        local sideBtn = Create("ImageButton", {
            Size = UDim2.fromOffset(36, 36),
            BackgroundColor3 = Theme.Element,
            BackgroundTransparency = 1,
            Image = LoadAsset(icon),
            LayoutOrder = #Window.Tabs + 1,
            Parent = Sidebar,
        })

        -- Top tab button
        local tabBtn = Create("TextButton", {
            Size = UDim2.new(0, 120, 1, 0),
            BackgroundColor3 = Theme.Element,
            BackgroundTransparency = 1,
            Text = name,
            TextColor3 = Theme.TextDim,
            TextSize = 14,
            Font = Enum.Font.GothamMedium,
            LayoutOrder = #Window.Tabs + 1,
            Parent = TabBar,
        })
        Corner(6, tabBtn)

        -- Tab page
        local page = Create("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            Parent = TabContainer,
        })
        Create("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = page,
        })
        Create("UIPadding", {
            PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10),
            Parent = page,
        })

        local underline = Create("Frame", {
            Size = UDim2.new(1, -20, 0, 2),
            Position = UDim2.new(0, 10, 1, -1),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = tabBtn,
        })

        function Tab:Select()
            for _, t in ipairs(Window.Tabs) do
                t.Page.Visible = false
                t.Button.BackgroundTransparency = 1
                t.Button.TextColor3 = Theme.TextDim
                t.Underline.BackgroundTransparency = 1
                t.SideBtn.BackgroundTransparency = 1
            end
            page.Visible = true
            tabBtn.BackgroundTransparency = 0.75
            tabBtn.TextColor3 = Theme.Accent
            underline.BackgroundTransparency = 0
            sideBtn.BackgroundTransparency = 0.75
        end

        sideBtn.MouseButton1Click:Connect(function() Tab:Select() end)
        tabBtn.MouseButton1Click:Connect(function() Tab:Select() end)

        Window.Tabs[#Window.Tabs + 1] = { Page = page, Button = tabBtn, Underline = underline, SideBtn = sideBtn, Select = Tab.Select }
        if #Window.Tabs == 1 then Tab:Select() end

        -- //======================== ELEMENTS ========================//

        function Tab:CreateSection(label)
            local sec = Create("TextLabel", {
                Size = UDim2.new(1, -4, 0, 26),
                BackgroundTransparency = 1,
                Text = string.upper(label),
                TextColor3 = Theme.TextDim,
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = #page:GetChildren(),
                Parent = page,
            })
            return sec
        end

        function Tab:CreateButton(text, callback)
            local btn = Create("TextButton", {
                Size = UDim2.new(1, -4, 0, 38),
                BackgroundColor3 = Theme.Element,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 14,
                Font = Enum.Font.GothamMedium,
                LayoutOrder = #page:GetChildren(),
                Parent = page,
            })
            Corner(6, btn)
            Stroke(Theme.Stroke, 1, btn)
            btn.MouseEnter:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.ElementHover }):Play()
            end)
            btn.MouseLeave:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.Element }):Play()
            end)
            btn.MouseButton1Click:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = Theme.AccentDark }):Play()
                task.wait(0.08)
                TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.Element }):Play()
                if callback then callback() end
            end)
            return btn
        end

        function Tab:CreateToggle(text, default, callback)
            default = default or false
            local state = default
            local row = Create("TextButton", {
                Size = UDim2.new(1, -4, 0, 36),
                BackgroundColor3 = Theme.Element,
                Text = "",
                LayoutOrder = #page:GetChildren(),
                Parent = page,
            })
            Corner(6, row)
            Stroke(Theme.Stroke, 1, row)
            Create("TextLabel", {
                Size = UDim2.new(1, -60, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 14,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            local pill = Create("Frame", {
                Size = UDim2.fromOffset(42, 22),
                Position = UDim2.new(1, -54, 0.5, -11),
                BackgroundColor3 = state and Theme.Accent or Theme.ElementHover,
                BorderSizePixel = 0,
                Parent = row,
            })
            Corner(11, pill)
            local knob = Create("Frame", {
                Size = UDim2.fromOffset(16, 16),
                Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
                BackgroundColor3 = state and Theme.Background or Theme.TextDim,
                BorderSizePixel = 0,
                Parent = pill,
            })
            Corner(8, knob)

            local function set(v)
                state = v
                TweenService:Create(pill, TweenInfo.new(0.2), { BackgroundColor3 = v and Theme.Accent or Theme.ElementHover }):Play()
                TweenService:Create(knob, TweenInfo.new(0.2), {
                    Position = v and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
                    BackgroundColor3 = v and Theme.Background or Theme.TextDim,
                }):Play()
                if callback then callback(v) end
            end
            row.MouseButton1Click:Connect(function() set(not state) end)
            local obj = {}
            function obj:Set(v) set(v) end
            function obj:Get() return state end
            return obj
        end

        function Tab:CreateSlider(text, min, max, default, callback)
            local dragging = false
            local row = Create("Frame", {
                Size = UDim2.new(1, -4, 0, 48),
                BackgroundColor3 = Theme.Element,
                LayoutOrder = #page:GetChildren(),
                Parent = page,
            })
            Corner(6, row)
            Stroke(Theme.Stroke, 1, row)
            Create("TextLabel", {
                Size = UDim2.new(1, -70, 0, 20),
                Position = UDim2.fromOffset(12, 2),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 14,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            local valueLabel = Create("TextLabel", {
                Size = UDim2.fromOffset(50, 20),
                Position = UDim2.new(1, -58, 0, 2),
                BackgroundTransparency = 1,
                Text = tostring(default),
                TextColor3 = Theme.Accent,
                TextSize = 14,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = row,
            })
            local bar = Create("Frame", {
                Size = UDim2.new(1, -24, 0, 6),
                Position = UDim2.fromOffset(12, 32),
                BackgroundColor3 = Theme.ElementHover,
                BorderSizePixel = 0,
                Parent = row,
            })
            Corner(3, bar)
            local fill = Create("Frame", {
                Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Parent = bar,
            })
            Corner(3, fill)
            local knobCircle = Create("Frame", {
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.new((default - min) / (max - min), -7, 0.5, -7),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Parent = bar,
            })
            Corner(7, knobCircle)

            local value = default
            local function setFromX(x)
                local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                value = math.floor(min + (max - min) * rel)
                fill.Size = UDim2.new(rel, 0, 1, 0)
                knobCircle.Position = UDim2.new(rel, -7, 0.5, -7)
                valueLabel.Text = tostring(value)
                if callback then callback(value) end
            end
            bar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    setFromX(input.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    setFromX(input.Position.X)
                end
            end)
            local obj = {}
            function obj:Set(v) value = v; setFromX(0) end -- simplified
            function obj:Get() return value end
            return obj
        end

        function Tab:CreateDropdown(text, options, default, callback)
            local selected = default or options[1]
            local open = false
            local row = Create("TextButton", {
                Size = UDim2.new(1, -4, 0, 36),
                BackgroundColor3 = Theme.Element,
                Text = "",
                LayoutOrder = #page:GetChildren(),
                Parent = page,
            })
            Corner(6, row)
            Stroke(Theme.Stroke, 1, row)
            Create("TextLabel", {
                Size = UDim2.new(0, 160, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 14,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            local current = Create("TextLabel", {
                Size = UDim2.new(0, 120, 1, 0),
                Position = UDim2.new(1, -140, 0, 0),
                BackgroundTransparency = 1,
                Text = selected,
                TextColor3 = Theme.Accent,
                TextSize = 13,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = row,
            })
            local chevron = Create("ImageLabel", {
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.new(1, -24, 0.5, -7),
                BackgroundTransparency = 1,
                Image = LoadAsset("chevron.png"),
                Parent = row,
            })
            local list = Create("Frame", {
                Size = UDim2.new(1, -4, 0, 0),
                BackgroundColor3 = Theme.Panel,
                Visible = false,
                LayoutOrder = #page:GetChildren() + 1,
                Parent = page,
            })
            Corner(6, list)
            Stroke(Theme.Stroke, 1, list)
            local listLayout = Create("UIListLayout", { Parent = list })
            for _, opt in ipairs(options) do
                local optBtn = Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundTransparency = 1,
                    Text = opt,
                    TextColor3 = Theme.Text,
                    TextSize = 13,
                    Font = Enum.Font.Gotham,
                    Parent = list,
                })
                optBtn.MouseButton1Click:Connect(function()
                    selected = opt
                    current.Text = opt
                    open = false
                    list.Visible = false
                    TweenService:Create(chevron, TweenInfo.new(0.2), { Rotation = 0 }):Play()
                    if callback then callback(opt) end
                end)
            end
            row.MouseButton1Click:Connect(function()
                open = not open
                list.Visible = open
                TweenService:Create(chevron, TweenInfo.new(0.2), { Rotation = open and 180 or 0 }):Play()
                list.Size = UDim2.new(1, -4, 0, open and (#options * 30) or 0)
            end)
            local obj = {}
            function obj:Set(v) selected = v; current.Text = v end
            function obj:Get() return selected end
            return obj
        end

        function Tab:CreateLabel(text)
            return Create("TextLabel", {
                Size = UDim2.new(1, -4, 0, 30),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Theme.TextDim,
                TextSize = 14,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = #page:GetChildren(),
                Parent = page,
            })
        end

        function Tab:CreateKeybind(text, default, callback)
            local key = default
            local row = Create("TextButton", {
                Size = UDim2.new(1, -4, 0, 36),
                BackgroundColor3 = Theme.Element,
                Text = "",
                LayoutOrder = #page:GetChildren(),
                Parent = page,
            })
            Corner(6, row)
            Stroke(Theme.Stroke, 1, row)
            Create("TextLabel", {
                Size = UDim2.new(1, -100, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 14,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            local bindLabel = Create("TextLabel", {
                Size = UDim2.fromOffset(70, 22),
                Position = UDim2.new(1, -78, 0.5, -11),
                BackgroundColor3 = Theme.ElementHover,
                Text = key and key.Name or "None",
                TextColor3 = Theme.Accent,
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                Parent = row,
            })
            Corner(4, bindLabel)
            local waiting = false
            row.MouseButton1Click:Connect(function()
                waiting = true
                bindLabel.Text = "..."
                local conn
                conn = UserInputService.InputBegan:Connect(function(input, gp)
                    if not waiting then conn:Disconnect() return end
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        key = input.KeyCode
                        bindLabel.Text = key.Name
                        waiting = false
                        conn:Disconnect()
                        if callback then callback(key) end
                    end
                end)
            end)
            return { Get = function() return key end }
        end

        return Tab
    end

    -- // Draggable topbar
    do
        local dragging, dragStart, startPos
        TopBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = Main.Position
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    -- Toggle visibility with RightControl
    UserInputService.InputBegan:Connect(function(input, gp)
        if not gp and input.KeyCode == Enum.KeyCode.RightControl then
            Main.Visible = not Main.Visible
        end
    end)

    -- Open animation
    Main.Size = UDim2.fromOffset(0, 0)
    TweenService:Create(Main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(760, 520)
    }):Play()

    Window:Destroy = function() ScreenGui:Destroy() end
    return Window
end

return PulseUI
