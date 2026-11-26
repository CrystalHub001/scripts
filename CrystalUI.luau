--// Crystal UI Library v4.0 (WindUI-style API) | Themes: Purple (default) • Dark • Dark Blue • Rainbow
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ContextActionService = game:GetService("ContextActionService")

local CrystalUI = {}
CrystalUI.__index = CrystalUI
CrystalUI.Version = "4.0"

--==================================================================
-- Theme (สเลทเข้มแบบ Maru Hub, Purple/Pink = สี accent ที่เปลี่ยนสดได้)
--==================================================================
local Presets = {
    Purple = {
        Bg = Color3.fromRGB(19, 11, 33), Sidebar = Color3.fromRGB(26, 15, 45), Card = Color3.fromRGB(36, 22, 62),
        CardHover = Color3.fromRGB(52, 32, 88), InputBg = Color3.fromRGB(24, 14, 42),
        Purple = Color3.fromRGB(168, 85, 247), Pink = Color3.fromRGB(236, 72, 153),
        Text = Color3.fromRGB(245, 238, 255), Muted = Color3.fromRGB(162, 140, 196), Stroke = Color3.fromRGB(64, 42, 102),
    },
    Dark = {
        Bg = Color3.fromRGB(15, 15, 17), Sidebar = Color3.fromRGB(21, 21, 24), Card = Color3.fromRGB(28, 28, 32),
        CardHover = Color3.fromRGB(40, 40, 46), InputBg = Color3.fromRGB(20, 20, 23),
        Purple = Color3.fromRGB(236, 236, 240), Pink = Color3.fromRGB(160, 160, 170),
        Text = Color3.fromRGB(240, 240, 244), Muted = Color3.fromRGB(140, 140, 150), Stroke = Color3.fromRGB(52, 52, 60),
    },
    ["Dark Blue"] = {
        Bg = Color3.fromRGB(9, 14, 32), Sidebar = Color3.fromRGB(13, 20, 43), Card = Color3.fromRGB(19, 29, 58),
        CardHover = Color3.fromRGB(28, 42, 80), InputBg = Color3.fromRGB(12, 19, 40),
        Purple = Color3.fromRGB(59, 130, 246), Pink = Color3.fromRGB(34, 211, 238),
        Text = Color3.fromRGB(232, 240, 255), Muted = Color3.fromRGB(125, 145, 185), Stroke = Color3.fromRGB(36, 54, 96),
    },
    Rainbow = {
        Bg = Color3.fromRGB(14, 14, 20), Sidebar = Color3.fromRGB(20, 20, 28), Card = Color3.fromRGB(27, 27, 38),
        CardHover = Color3.fromRGB(39, 39, 54), InputBg = Color3.fromRGB(19, 19, 27),
        Purple = Color3.fromHSV(0, 0.7, 1), Pink = Color3.fromHSV(0.12, 0.7, 1),
        Text = Color3.fromRGB(244, 244, 250), Muted = Color3.fromRGB(150, 150, 170), Stroke = Color3.fromRGB(52, 52, 72),
    },
}
CrystalUI.ThemeNames = {"Purple", "Dark", "Dark Blue", "Rainbow"}
CrystalUI.CurrentTheme = "Purple" -- ค่าเริ่มต้น

local Theme = {Danger = Color3.fromRGB(239, 68, 68)}
for k, v in pairs(Presets.Purple) do Theme[k] = v end
CrystalUI.Theme = Theme

local RootGui
local ThemeHooks = {}
local Connections = {}
local Listening = 0
local WindowCount = 0

local function Themed(inst, fn)
    fn()
    table.insert(ThemeHooks, {inst = inst, fn = fn})
end

local function Accent(inst, prop, key)
    Themed(inst, function() inst[prop] = Theme[key] end)
end

local function ApplyTheme()
    for i = #ThemeHooks, 1, -1 do
        local h = ThemeHooks[i]
        if RootGui and h.inst:IsDescendantOf(RootGui) then
            pcall(h.fn)
        else
            table.remove(ThemeHooks, i)
        end
    end
end

local THEME_KEYS = {"Bg", "Sidebar", "Card", "CardHover", "InputBg", "Text", "Muted", "Stroke", "Purple", "Pink"}
local function ColorKey(c)
    return math.floor(c.R * 255 + 0.5) * 65536 + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5)
end

-- เปลี่ยนสีทุก element ที่ใช้สีเก่าของธีม ให้เป็นสีใหม่ (ทั้งหน้าต่าง ไม่ใช่แค่ accent)
local function Recolor(old)
    if not RootGui then return end
    local map = {}
    local function add(a, b) local k = ColorKey(a); if map[k] == nil then map[k] = b end end
    for _, k in ipairs(THEME_KEYS) do add(old[k], Theme[k]) end
    add(old.Bg:Lerp(old.Sidebar, 0.8), Theme.Bg:Lerp(Theme.Sidebar, 0.8))
    local function fix(inst, prop)
        if inst:GetAttribute("NoRecolor") then return end
        local n = map[ColorKey(inst[prop])]
        if n then inst[prop] = n end
    end
    for _, d in ipairs(RootGui:GetDescendants()) do
        if d:IsA("GuiObject") then
            fix(d, "BackgroundColor3")
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then fix(d, "TextColor3") end
            if d:IsA("ImageLabel") or d:IsA("ImageButton") then fix(d, "ImageColor3") end
            if d:IsA("ScrollingFrame") then fix(d, "ScrollBarImageColor3") end
            if d:IsA("TextBox") then fix(d, "PlaceholderColor3") end
        elseif d:IsA("UIStroke") then
            fix(d, "Color")
        end
    end
end

function CrystalUI:SetTheme(t)
    local old = table.clone(Theme)
    for k, v in pairs(t or {}) do
        if Theme[k] ~= nil and typeof(v) == "Color3" then Theme[k] = v end
    end
    Recolor(old)
    ApplyTheme()
end

local rainbowConn
function CrystalUI:SetThemePreset(name)
    local p = Presets[name]
    if not p then return false end
    if rainbowConn then rainbowConn:Disconnect() rainbowConn = nil end
    CrystalUI.CurrentTheme = name
    CrystalUI:SetTheme(p)
    if name == "Rainbow" then
        local h, acc = 0, 0
        rainbowConn = game:GetService("RunService").Heartbeat:Connect(function(dt)
            acc += dt
            if acc < 0.15 then return end
            h = (h + acc * 0.12) % 1
            acc = 0
            CrystalUI:SetTheme({Purple = Color3.fromHSV(h, 0.7, 1), Pink = Color3.fromHSV((h + 0.12) % 1, 0.7, 1)})
        end)
        table.insert(Connections, rainbowConn)
    end
    return true
end

--==================================================================
-- Helpers
--==================================================================
local function Connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Connections, c)
    return c
end

local function New(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function Tween(obj, props, t, style, dir)
    if not obj or not obj.Parent then return end
    local anim = TweenService:Create(obj, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    anim:Play()
    return anim
end

local function Corner(parent, r)
    return New("UICorner", {CornerRadius = UDim.new(0, r or 8)}, parent)
end

local function Stroke(parent, color, thickness, trans)
    return New("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
        Transparency = trans or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function AccentGradient(parent, rot)
    local g = New("UIGradient", {Rotation = rot or 0}, parent)
    Themed(g, function() g.Color = ColorSequence.new(Theme.Purple, Theme.Pink) end)
    return g
end

local function Txt(props, parent)
    local p = {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "",
    }
    for k, v in pairs(props) do p[k] = v end
    return New("TextLabel", p, parent)
end

local function Safe(cb, ...)
    if type(cb) ~= "function" then return end
    local ok, err = pcall(cb, ...)
    if not ok then warn("[CrystalUI] callback error: " .. tostring(err)) end
end

local function PointerPos(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        return Vector2.new(input.Position.X, input.Position.Y)
    end
    return UserInputService:GetMouseLocation()
end

local function IsPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function AutoOrder(container)
    local n = 0
    container.ChildAdded:Connect(function(c)
        if c:IsA("GuiObject") then
            n += 1
            c.LayoutOrder = n
        end
    end)
end

local function GetGuiParent()
    local ok, res = pcall(function()
        if gethui then return gethui() end
        return CoreGui
    end)
    if ok and res then
        local valid = pcall(function() return res:GetChildren() end)
        if valid then return res end
    end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

--==================================================================
-- Icons (Footagesus/Icons v2, มี fallback ถ้าโหลดไม่ได้)
--==================================================================
local IconLib
do
    local ok, lib = pcall(function()
        return loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"))()
    end)
    if ok and type(lib) == "table" then
        IconLib = lib
        pcall(function() lib.SetIconsType("lucide") end)
    end
end

local function ResolveIcon(name)
    if not IconLib or type(name) ~= "string" or name == "" then return nil end
    local ok, res = pcall(function() return IconLib.GetIcon(name) end)
    if ok and res then return res end
    return nil
end

local function IconProp(obj)
    return obj:IsA("ImageLabel") and "ImageColor3" or "TextColor3"
end

-- สร้างไอคอน: ใช้รูปจาก lib ถ้าได้, ไม่งั้นใช้ตัวอักษร fallback / สัญลักษณ์ที่ส่งมา
local function MakeIcon(parent, name, size, color, props, fallback)
    size = size or 18
    -- รองรับรูปที่อัปโหลดเอง: ใส่เป็นเลข id หรือ "rbxassetid://..."
    local nameStr = tostring(name or "")
    if nameStr:match("^%d+$") then nameStr = "rbxassetid://" .. nameStr end
    if nameStr:find("^rbxassetid://") then
        local img = New("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(size, size),
            Image = nameStr,
            ScaleType = Enum.ScaleType.Fit,
            ResampleMode = Enum.ResamplerMode.Pixelated, -- พิกเซลอาร์ตคมชัด
        }, parent)
        img:SetAttribute("Custom", true)
        if props then for k, v in pairs(props) do img[k] = v end end
        return img
    end

    local res = ResolveIcon(name)
    local obj
    if res then
        obj = New("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(size, size),
            ImageColor3 = color or Theme.Text,
            ScaleType = Enum.ScaleType.Fit,
        }, parent)
        if type(res) == "table" then
            obj.Image = res.Image or res[1] or ""
            if res.ImageRectSize then obj.ImageRectSize = res.ImageRectSize end
            if res.ImageRectPosition then obj.ImageRectPosition = res.ImageRectPosition end
        else
            obj.Image = tostring(res)
        end
    else
        local glyph = fallback
        if not glyph and type(name) == "string" and name ~= "" and not name:match("^[%w%-:_]+$") then glyph = name end
        if glyph then
            obj = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(size, size),
                Text = glyph,
                TextSize = math.max(10, size - 3),
                Font = Enum.Font.GothamBold,
                TextColor3 = color or Theme.Text,
            }, parent)
        end
    end
    if obj and props then for k, v in pairs(props) do obj[k] = v end end
    return obj
end

--==================================================================
-- Root GUI + Cleanup
--==================================================================
local Env = (getgenv and getgenv()) or _G
if Env.__CrystalUI_Cleanup then pcall(Env.__CrystalUI_Cleanup) end

local GuiParent = GetGuiParent()
local oldGui = GuiParent:FindFirstChild("CrystalUI_WindSystem")
if oldGui then oldGui:Destroy() end

RootGui = New("ScreenGui", {
    Name = "CrystalUI_WindSystem",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, GuiParent)
-- ให้ GUI เต็มจอจริง (ค่าเริ่มต้น CoreUISafe กันพื้นที่ปุ่ม Roblox ด้านบน/ซ้าย ทำให้ลากไม่ทั่วจอ)
pcall(function() RootGui.ScreenInsets = Enum.ScreenInsets.None end)

local SinkCount = 0
local SinkName = "CrystalUI_InputSink"

local function Cleanup()
    pcall(function() ContextActionService:UnbindAction(SinkName) end)
    SinkCount = 0
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
    table.clear(ThemeHooks)
    if RootGui then RootGui:Destroy() end
end
Env.__CrystalUI_Cleanup = Cleanup
function CrystalUI:Destroy() Cleanup() end

local function Alive() return RootGui and RootGui.Parent ~= nil end

local function ScreenSize()
    local cam = workspace.CurrentCamera
    local v = cam and cam.ViewportSize
    if v and v.X > 100 and v.Y > 100 then return v end
    v = RootGui.AbsoluteSize
    if v.X > 100 and v.Y > 100 then return v end
    return Vector2.new(1280, 720)
end

--==================================================================
-- Draggable
--==================================================================
-- กันอินพุตทะลุไปโดนเกม/กล้อง ระหว่างลาก/กดค้างบน UI (กล้องจะได้ไม่หมุนตาม)
local function SinkBegin()
    SinkCount += 1
    if SinkCount == 1 then
        pcall(function()
            ContextActionService:BindActionAtPriority(SinkName, function()
                return Enum.ContextActionResult.Sink
            end, false, Enum.ContextActionPriority.High.Value + 100,
                Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2,
                Enum.UserInputType.MouseMovement, Enum.UserInputType.MouseWheel,
                Enum.UserInputType.Touch)
        end)
    end
    local released = false
    return function()
        if released then return end
        released = true
        SinkCount = math.max(0, SinkCount - 1)
        if SinkCount == 0 then
            pcall(function() ContextActionService:UnbindAction(SinkName) end)
        end
    end
end

local function MakeDraggable(handle, target, canDrag)
    local dragging, moved = false, false
    local dragStart, startPos, startAbs
    local releaseSink

    handle.InputBegan:Connect(function(input)
        if IsPress(input) then
            if canDrag and not canDrag() then return end
            if releaseSink then releaseSink() end
            releaseSink = SinkBegin()
            dragging, moved = true, false
            dragStart = input.Position
            startPos = target.Position
            startAbs = target.AbsolutePosition
        end
    end)

    Connect(UserInputService.InputChanged, function(input)
        if dragging and IsMove(input) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 4 then moved = true end
            -- ไม่จำกัดขอบ: หน้าต่างตามนิ้ว/เมาส์เสมอ จึงลากไปได้ทั่วจอ (รวมทับปุ่ม Roblox ด้านบน)
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + math.round(delta.X),
                startPos.Y.Scale, startPos.Y.Offset + math.round(delta.Y)
            )
        end
    end)

    Connect(UserInputService.InputEnded, function(input)
        if IsPress(input) then
            dragging = false
            if releaseSink then releaseSink() releaseSink = nil end
        end
    end)

    return function() return moved end
end

--==================================================================
-- Config encode / decode
--==================================================================
local function EncodeValue(v)
    if typeof(v) == "Color3" then
        return {__color = {math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5)}}
    end
    return v
end

local function DecodeValue(v)
    if type(v) == "table" and v.__color then
        return Color3.fromRGB(v.__color[1], v.__color[2], v.__color[3])
    end
    return v
end

local function HasFS()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
        and type(isfolder) == "function" and type(makefolder) == "function" and type(listfiles) == "function"
end

--==================================================================
-- Notifications (การ์ดเป็น CanvasGroup เพื่อให้มุมโค้งตัดเนื้อหาข้างในจริง)
--==================================================================
local NotifHolder = New("Frame", {
    Name = "Notifications",
    Size = UDim2.new(0, 300, 1, -24),
    Position = UDim2.new(1, -312, 0, 12),
    BackgroundTransparency = 1,
    ZIndex = 150,
}, RootGui)

New("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, NotifHolder)

local NotifSeq = 0
local NotifSlots = {}
local NotifColors = {
    success = Color3.fromRGB(74, 222, 128),
    warning = Color3.fromRGB(250, 204, 21),
    error = Color3.fromRGB(248, 113, 113),
}

function CrystalUI:Notify(opts)
    if not Alive() then return end
    opts = opts or {}
    local title = opts.Title or "Crystal UI"
    local content = opts.Content or ""
    local duration = opts.Duration or 3.5
    local kindColor = NotifColors[opts.Type]

    local textH = content == "" and 0 or TextService:GetTextSize(content, 12, Enum.Font.Gotham, Vector2.new(262, 1000)).Y
    local h = math.max(52, 34 + textH + 12)

    while #NotifSlots >= 5 do
        local oldest = table.remove(NotifSlots, 1)
        if oldest then oldest:Destroy() end
    end

    NotifSeq += 1
    local Slot = New("Frame", {Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = NotifSeq}, NotifHolder)
    table.insert(NotifSlots, Slot)

    local Card = New("CanvasGroup", {
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(1, 330, 0, 0),
        BackgroundColor3 = Theme.Card,
    }, Slot)
    Corner(Card, 12)
    local st = Stroke(Card, kindColor or Theme.Stroke, 1.1)

    local Accent1 = New("Frame", {Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = kindColor or Color3.new(1, 1, 1), BorderSizePixel = 0}, Card)
    local LifeBar = New("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = kindColor or Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, Card)
    if not kindColor then
        AccentGradient(Accent1, 90)
        AccentGradient(LifeBar, 0)
    end

    Txt({Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(14, 8), Text = title, Font = Enum.Font.GothamBold, TextTruncate = Enum.TextTruncate.AtEnd}, Card)
    Txt({
        Size = UDim2.new(1, -28, 1, -34), Position = UDim2.fromOffset(14, 28), Text = content,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
    }, Card)

    local dismissed = false
    local function Dismiss()
        if dismissed then return end
        dismissed = true
        Tween(Card, {Position = UDim2.new(1, 330, 0, 0)}, 0.24)
        task.delay(0.26, function()
            if Slot.Parent then
                Tween(Slot, {Size = UDim2.new(1, 0, 0, 0)}, 0.16)
                task.delay(0.18, function()
                    local i = table.find(NotifSlots, Slot)
                    if i then table.remove(NotifSlots, i) end
                    Slot:Destroy()
                end)
            end
        end)
    end

    local click = New("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5}, Card)
    click.MouseButton1Click:Connect(Dismiss)

    Tween(Card, {Position = UDim2.new(0, 0, 0, 0)}, 0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    Tween(LifeBar, {Size = UDim2.new(0, 0, 0, 2)}, duration, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
    task.delay(duration, Dismiss)
end

--==================================================================
-- Dialog
--==================================================================
function CrystalUI:Dialog(opts)
    if not Alive() then return end
    opts = opts or {}
    local content = opts.Content or ""
    local textH = content == "" and 0 or TextService:GetTextSize(content, 12, Enum.Font.Gotham, Vector2.new(300, 1000)).Y
    local boxW, boxH = 340, math.max(130, 104 + textH)

    local Overlay = New("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1, Active = true, ZIndex = 200,
    }, RootGui)

    local Box = New("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(boxW - 30, boxH - 15),
        BackgroundColor3 = Theme.Bg,
        GroupTransparency = 1,
        ZIndex = 201,
    }, Overlay)
    Corner(Box, 14)
    Stroke(Box, Theme.Stroke, 1.2)

    Txt({Size = UDim2.new(1, -28, 0, 26), Position = UDim2.fromOffset(16, 14), Text = opts.Title or "Confirm", Font = Enum.Font.GothamBold, TextSize = 15}, Box)
    Txt({
        Size = UDim2.new(1, -32, 0, textH + 2), Position = UDim2.fromOffset(16, 44), Text = content,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
    }, Box)

    local BtnRow = New("Frame", {Size = UDim2.new(1, -32, 0, 34), Position = UDim2.new(0, 16, 1, -50), BackgroundTransparency = 1}, Box)
    New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, BtnRow)

    local closed = false
    local function Close(cb)
        if closed then return end
        closed = true
        Tween(Overlay, {BackgroundTransparency = 1}, 0.18)
        Tween(Box, {GroupTransparency = 1, Size = UDim2.fromOffset(boxW - 30, boxH - 15)}, 0.18)
        task.delay(0.2, function()
            if Overlay.Parent then Overlay:Destroy() end
            Safe(cb)
        end)
    end

    local hideCancel = opts.HideCancel == true
    local function MakeBtn(text, primary, cb)
        local white = primary and not opts.Danger
        local b = New("TextButton", {
            Size = hideCancel and UDim2.new(1, 0, 1, 0) or UDim2.new(0.5, -4, 1, 0),
            BackgroundColor3 = primary and (opts.Danger and Theme.Danger or Color3.fromRGB(240, 242, 247)) or Theme.Card,
            Text = text, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = white and Theme.Bg or Theme.Text,
            AutoButtonColor = false, ZIndex = 202,
        }, BtnRow)
        Corner(b, 9)
        if not primary then Stroke(b, Theme.Stroke, 1) end
        b.MouseButton1Click:Connect(function() Close(cb) end)
    end

    if not hideCancel then MakeBtn(opts.CancelText or "Cancel", false, opts.OnCancel) end
    MakeBtn(opts.ConfirmText or "Confirm", true, opts.OnConfirm)

    Tween(Overlay, {BackgroundTransparency = 0.45}, 0.2)
    Tween(Box, {GroupTransparency = 0, Size = UDim2.fromOffset(boxW, boxH)}, 0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

--==================================================================
-- Window
--==================================================================
function CrystalUI:CreateWindow(opts)
    -- รองรับพารามิเตอร์แบบ WindUI: Title / Icon / Author / Folder / Theme
    opts = table.clone(opts or {})
    opts.Title = opts.Title or opts.Name
    if opts.SubTitle == nil then opts.SubTitle = opts.Author end
    opts.ConfigFolder = opts.ConfigFolder or opts.Folder
    if type(opts.Theme) == "string" and Presets[opts.Theme] then
        CrystalUI:SetThemePreset(opts.Theme)
    end
    local Win = {Flags = {}}
    local Setters, Tabs, MemoryConfigs = {}, {}, {}
    local destroyed = false
    WindowCount += 1

    local function SetFlag(flag, v) if flag then Win.Flags[flag] = v end end
    local function Register(flag, setter) if flag then Setters[flag] = setter end end

    local vp = ScreenSize()
    local req = opts.Size or UDim2.fromOffset(700, 440)
    local initW = math.min(req.X.Scale * vp.X + req.X.Offset, vp.X - 24)
    local initH = math.min(req.Y.Scale * vp.Y + req.Y.Offset, vp.Y - 24)
    local minW = math.min(opts.MinWidth or 420, initW)
    local minH = math.min(opts.MinHeight or 280, initH)
    local maxW, maxH = opts.MaxWidth or 1400, opts.MaxHeight or 900

    local function Limits()
        local v = ScreenSize()
        return math.max(minW, math.min(maxW, v.X - 16)), math.max(minH, math.min(maxH, v.Y - 16))
    end

    local maximized = false
    local restoreSize, restorePos

    -- ใช้ Frame ธรรมดาแทน CanvasGroup เพราะ CanvasGroup เรนเดอร์เป็นเท็กซ์เจอร์ ทำให้ตัวหนังสือเบลอ
    local function CenterPos(w, h)
        return UDim2.new(0.5, -math.floor(w / 2), 0.5, -math.floor(h / 2))
    end
    local StripSolid = Theme.Bg:Lerp(Theme.Sidebar, 0.8)

    local TOP_H, TAB_H, FOOT_H = 40, 44, 30

    local Main = New("Frame", {
        Name = "CrystalWindWindow",
        Size = UDim2.fromOffset(initW - 40, initH - 40),
        Position = CenterPos(initW - 40, initH - 40),
        BackgroundColor3 = Theme.Bg,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        Active = true, -- กันคลิก/ลากทะลุหน้าต่างไปโดนเกม
    }, RootGui)
    Corner(Main, 14)
    Stroke(Main, Theme.Stroke, 1.2)
    -- ฝาเฟดสำหรับเปิด/พับหน้าต่าง (แทน GroupTransparency)
    local FadeCover = New("Frame", {
        Name = "Fade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Bg,
        BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 60,
    }, Main)
    Corner(FadeCover, 14)
    Tween(Main, {Size = UDim2.fromOffset(initW, initH), Position = CenterPos(initW, initH)}, 0.3)
    Tween(FadeCover, {BackgroundTransparency = 1}, 0.3)
    task.delay(0.34, function() if FadeCover.Parent then FadeCover.Visible = false end end)

    ------------------------------------------------------------------
    -- Title bar: โลโก้ + ชื่อ + ชื่อรอง | ปุ่ม − □ × (พับ / ขยาย / ลบ UI)
    ------------------------------------------------------------------
    local Strip = New("Frame", {Size = UDim2.new(1, 0, 0, TOP_H), BackgroundColor3 = StripSolid, BorderSizePixel = 0, Active = true}, Main)
    Corner(Strip, 14)
    New("Frame", {Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 20), BackgroundColor3 = StripSolid, BorderSizePixel = 0}, Strip)
    MakeDraggable(Strip, Main, function() return not maximized end)
    New("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0}, Strip)

    local function Dot(i, icon, glyph)
        local d = New("TextButton", {
            Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10 - (i - 1) * 30, 0.5, 0),
            BackgroundColor3 = Theme.CardHover, BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        }, Strip)
        Corner(d, 6)
        MakeIcon(d, icon, 14, Theme.Muted, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5)}, glyph)
        d.MouseEnter:Connect(function() Tween(d, {BackgroundTransparency = 0.3}, 0.12) end)
        d.MouseLeave:Connect(function() Tween(d, {BackgroundTransparency = 1}, 0.12) end)
        return d
    end
    local RedBtn = Dot(1, "x", "×")          -- ลบ UI
    local YellowBtn = Dot(2, "square", "□")  -- ขยาย/คืนขนาด
    local GreenBtn = Dot(3, "minus", "–")    -- พับ UI

    if opts.Tag then
        local TagFrame = New("Frame", {Size = UDim2.fromOffset(46, 18), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -106, 0.5, 0), BackgroundColor3 = Theme.CardHover}, Strip)
        Corner(TagFrame, 6)
        Stroke(TagFrame, Theme.Stroke, 1)
        Txt({Size = UDim2.fromScale(1, 1), Text = tostring(opts.Tag), Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center}, TagFrame)
    end

    local logo = MakeIcon(Strip, opts.Icon or "gem", 24, Color3.new(1, 1, 1), {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0)})
    if not logo then
        logo = New("Frame", {Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 17, 0.5, -7), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1)}, Strip)
        Corner(logo, 3)
        AccentGradient(logo, 45)
    end
    local TitleHolder = New("Frame", {Size = UDim2.new(1, -200, 1, 0), Position = UDim2.fromOffset(44, 0), BackgroundTransparency = 1, ClipsDescendants = true}, Strip)
    New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, TitleHolder)
    local TitleLbl = Txt({Size = UDim2.new(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X, Text = opts.Title or "Crystal UI", Font = Enum.Font.GothamBold, TextSize = 14, LayoutOrder = 1}, TitleHolder)
    local SubLbl = Txt({Size = UDim2.new(0, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.X, Text = opts.SubTitle or "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.Muted, LayoutOrder = 2}, TitleHolder)
    function Win:SetTitle(t) TitleLbl.Text = tostring(t) end
    function Win:SetSubTitle(t) SubLbl.Text = tostring(t) end

    ------------------------------------------------------------------
    -- ปุ่มลอย Toggle UI (แสดงตลอด)
    ------------------------------------------------------------------
    local Toggler = New("TextButton", {
        Name = "CrystalToggle", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(46, 46),
        Position = UDim2.fromOffset(72, 160), BackgroundColor3 = Theme.Card, Text = "", AutoButtonColor = false, ZIndex = 100,
    }, RootGui)
    Corner(Toggler, 14)
    Stroke(Toggler, Theme.Stroke, 1.5)
    local toggleIconName = opts.ToggleIcon or opts.Icon or "gem"
    local tStr = tostring(toggleIconName)
    local customToggle = tStr:match("^%d+$") or tStr:find("^rbxassetid://")
    MakeIcon(Toggler, toggleIconName, customToggle and 34 or 22, Theme.Text, {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 101,
    }, "✦")
    local togglerMoved = MakeDraggable(Toggler, Toggler)
    -- ดันปุ่ม toggle ให้อยู่ในจอเสมอ (กันหลุดขอบ/โดนปุ่ม Roblox ด้านบน)
    local function ClampToggler()
        if destroyed or not Toggler.Parent then return end
        local sc = RootGui.AbsoluteSize
        if sc.X < 100 or sc.Y < 100 then sc = ScreenSize() end
        local c = Toggler.AbsolutePosition + Toggler.AbsoluteSize / 2
        local cx = math.clamp(c.X, 60, math.max(60, sc.X - 60))
        local cy = math.clamp(c.Y, 80, math.max(80, sc.Y - 60))
        if math.abs(cx - c.X) > 0.5 or math.abs(cy - c.Y) > 0.5 then
            Tween(Toggler, {Position = UDim2.fromOffset(cx, cy)}, 0.2)
        end
    end
    Connect(UserInputService.InputEnded, function(i) if IsPress(i) then task.delay(0.05, ClampToggler) end end)
    task.defer(function()
        local cam = workspace.CurrentCamera
        if cam then Connect(cam:GetPropertyChangedSignal("ViewportSize"), ClampToggler) end
    end)
    task.delay(0.4, ClampToggler)
    Toggler.MouseButton1Down:Connect(function() Tween(Toggler, {Size = UDim2.fromOffset(40, 40)}, 0.08) end)
    Toggler.MouseButton1Up:Connect(function() Tween(Toggler, {Size = UDim2.fromOffset(46, 46)}, 0.14, Enum.EasingStyle.Back) end)

    local hidden, busy, hintShown = false, false, false

    function Win:Recenter()
        if maximized then return end
        local sc = ScreenSize()
        local ap, sz = Main.AbsolutePosition, Main.AbsoluteSize
        if ap.X > sc.X - 40 or ap.X + sz.X < 40 or ap.Y > sc.Y - 30 or ap.Y + sz.Y < 40 then
            Main.Position = CenterPos(sz.X, sz.Y)
        end
    end

    function Win:Hide()
        if hidden or busy or destroyed then return end
        hidden, busy = true, true
        FadeCover.Visible = true
        Tween(FadeCover, {BackgroundTransparency = 0}, 0.18)
        task.delay(0.18, function()
            if destroyed then return end
            Main.Visible = false
            busy = false
        end)
        if not hintShown then
            hintShown = true
            local key = opts.ToggleKey ~= false and ((opts.ToggleKey or Enum.KeyCode.RightShift).Name .. " หรือ") or ""
            CrystalUI:Notify({Title = "UI ถูกพับแล้ว", Content = "กด " .. key .. "ปุ่มลอยเพื่อเปิดอีกครั้ง", Duration = 3})
        end
    end

    function Win:Show()
        if not hidden or busy or destroyed then return end
        hidden, busy = false, true
        Win:Recenter()
        Main.Visible = true
        FadeCover.BackgroundTransparency = 0
        FadeCover.Visible = true
        Tween(FadeCover, {BackgroundTransparency = 1}, 0.22)
        task.delay(0.22, function()
            if FadeCover.Parent then FadeCover.Visible = false end
            busy = false
        end)
    end

    function Win:Toggle() if hidden then Win:Show() else Win:Hide() end end

    function Win:Destroy()
        if destroyed then return end
        destroyed = true
        WindowCount -= 1
        Safe(opts.OnDestroy)
        if Main then Main:Destroy() end
        if Toggler then Toggler:Destroy() end
        if WindowCount <= 0 then Cleanup() end
    end

    function Win:Notify(o) CrystalUI:Notify(o) end

    Toggler.MouseButton1Click:Connect(function()
        if togglerMoved() then return end
        Win:Toggle()
    end)
    GreenBtn.MouseButton1Click:Connect(function() Win:Hide() end)
    RedBtn.MouseButton1Click:Connect(function()
        if opts.ConfirmClose == false then
            Win:Destroy()
        else
            CrystalUI:Dialog({
                Title = "ลบ UI?", Content = "UI จะถูกลบออกทั้งหมด ต้องรันสคริปต์ใหม่ถึงจะเปิดได้อีก",
                ConfirmText = "ลบ UI", CancelText = "ยกเลิก", Danger = true,
                OnConfirm = function() Win:Destroy() end,
            })
        end
    end)

    local toggleKey = opts.ToggleKey
    if toggleKey == nil then toggleKey = Enum.KeyCode.RightShift end
    if toggleKey then
        Connect(UserInputService.InputBegan, function(input, gpe)
            if gpe or Listening > 0 or destroyed then return end
            if input.KeyCode == toggleKey then Win:Toggle() end
        end)
    end

    -- Resize grip (ลากมุมขวาล่าง)
    local resizing, resizeStart, startSize = false, nil, nil
    local releaseResizeSink
    -- มุมจับปรับขนาดแบบเส้นโค้ง (ควอเตอร์วงกลมที่ซ้อนกับมุมโค้งของหน้าต่าง)
    -- วางอยู่นอกหน้าต่าง โค้งเป็นวงเดียวกับมุมโค้งของ Main (รัศมี 14) ห่างออกมา 5px
    local CORNER_R, GAP, THICK = 14, 5, 3
    local ArcR = CORNER_R + GAP
    local ResizeGrip = New("TextButton", {
        Size = UDim2.fromOffset(ArcR + THICK + 8, ArcR + THICK + 8),
        Position = UDim2.new(1, -CORNER_R, 1, -CORNER_R), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, ZIndex = 20,
    }, Main)
    local arcClip = New("Frame", {
        Size = UDim2.fromOffset(ArcR + THICK + 2, ArcR + THICK + 2), BackgroundTransparency = 1,
        ClipsDescendants = true, ZIndex = 21,
    }, ResizeGrip)
    local arcCircle = New("Frame", {
        Size = UDim2.fromOffset(ArcR * 2, ArcR * 2), Position = UDim2.fromOffset(-ArcR, -ArcR),
        BackgroundTransparency = 1, ZIndex = 21,
    }, arcClip)
    Corner(arcCircle, ArcR)
    local arcStroke = Stroke(arcCircle, Theme.Muted, THICK, 0.15)
    ResizeGrip.MouseEnter:Connect(function() Tween(arcStroke, {Color = Theme.Purple, Transparency = 0}, 0.15) end)
    ResizeGrip.MouseLeave:Connect(function() if not resizing then Tween(arcStroke, {Color = Theme.Muted, Transparency = 0.15}, 0.15) end end)
    ResizeGrip.InputBegan:Connect(function(input)
        if IsPress(input) and not maximized then
            resizing, resizeStart, startSize = true, input.Position, Main.AbsoluteSize
            if releaseResizeSink then releaseResizeSink() end
            releaseResizeSink = SinkBegin()
            Tween(arcStroke, {Color = Theme.Pink, Transparency = 0}, 0.12)
        end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if resizing and IsMove(input) then
            local delta = input.Position - resizeStart
            local mw, mh = Limits()
            Main.Size = UDim2.fromOffset(math.clamp(startSize.X + delta.X, minW, mw), math.clamp(startSize.Y + delta.Y, minH, mh))
        end
    end)
    Connect(UserInputService.InputEnded, function(input)
        if IsPress(input) and resizing then
            resizing = false
            if releaseResizeSink then releaseResizeSink() releaseResizeSink = nil end
            Tween(arcStroke, {Color = Theme.Muted, Transparency = 0.15}, 0.2)
        end
    end)

    -- 🟡 ปรับขนาด: ขยายเต็ม/คืนขนาดเดิม
    YellowBtn.MouseButton1Click:Connect(function()
        maximized = not maximized
        ResizeGrip.Visible = not maximized
        if maximized then
            restoreSize, restorePos = Main.Size, Main.Position
            Tween(Main, {Size = UDim2.new(1, -32, 1, -32), Position = UDim2.fromOffset(16, 16)}, 0.26)
        else
            Tween(Main, {Size = restoreSize, Position = restorePos}, 0.26)
        end
    end)

    function Win:SetSize(w, h)
        if maximized then return end
        local mw, mh = Limits()
        local nw, nh = math.clamp(w, minW, mw), math.clamp(h, minH, mh)
        Tween(Main, {Size = UDim2.fromOffset(nw, nh), Position = CenterPos(nw, nh)}, 0.26)
    end

    ------------------------------------------------------------------
    -- แถบแท็บแนวนอนด้านบน + ส่วนท้ายหน้าต่าง (โปรไฟล์ + ป้ายคีย์ลัด)
    ------------------------------------------------------------------
    local TabList = New("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, TAB_H), Position = UDim2.fromOffset(0, TOP_H), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X,
        AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
    }, Main)
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
        VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
    }, TabList)
    New("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, TabList)
    New("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, TOP_H + TAB_H - 1), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0}, Main)

    local Footer = New("Frame", {Size = UDim2.new(1, 0, 0, FOOT_H), Position = UDim2.new(0, 0, 1, -FOOT_H), BackgroundColor3 = StripSolid, BorderSizePixel = 0, Active = true}, Main)
    Corner(Footer, 14)
    New("Frame", {Size = UDim2.new(1, 0, 0, 15), BackgroundColor3 = StripSolid, BorderSizePixel = 0}, Footer)
    New("Frame", {Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0}, Footer)
    local avatar = New("ImageLabel", {Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), BackgroundColor3 = Theme.Card, Image = ""}, Footer)
    Corner(avatar, 10)
    local lp = Players.LocalPlayer
    Txt({Size = UDim2.new(0, 160, 1, 0), Position = UDim2.fromOffset(40, 0), Text = lp and lp.DisplayName or "Player", TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd}, Footer)
    if opts.UserTag then
        Txt({Size = UDim2.new(0, 100, 1, 0), Position = UDim2.fromOffset(204, 0), Text = tostring(opts.UserTag), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Theme.Muted}, Footer)
    end
    if toggleKey then
        local keyText = toggleKey.Name:gsub("(%l)(%u)", "%1 %2")
        local kw = TextService:GetTextSize(keyText, 11, Enum.Font.GothamMedium, Vector2.new(300, 30)).X + 18
        local Badge = New("Frame", {Size = UDim2.fromOffset(kw, 20), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -26, 0.5, 0), BackgroundColor3 = Theme.InputBg}, Footer)
        Corner(Badge, 5)
        Stroke(Badge, Theme.Stroke, 1)
        Txt({Size = UDim2.fromScale(1, 1), Text = keyText, TextSize = 11, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Center}, Badge)
    end
    if lp then
        task.spawn(function()
            local ok, img = pcall(function()
                return Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok and avatar.Parent then avatar.Image = img end
        end)
    end

    local Container = New("Frame", {
        Size = UDim2.new(1, 0, 1, -(TOP_H + TAB_H + FOOT_H)), Position = UDim2.fromOffset(0, TOP_H + TAB_H),
        BackgroundTransparency = 1, ClipsDescendants = true,
    }, Main)

    -- เลย์เอาต์ 2 คอลัมน์ → 1 คอลัมน์อัตโนมัติเมื่อหน้าต่างแคบ
    local function Relayout()
        local tooNarrow = Container.AbsoluteSize.X < 440
        for _, t in ipairs(Tabs) do t.SetNarrow(tooNarrow or t.Columns == 1) end
    end
    Container:GetPropertyChangedSignal("AbsoluteSize"):Connect(Relayout)

    local sideOrder = 0
    -- ในแถบแนวนอน หมวดหมู่กลายเป็นเส้นคั่นบางๆ ระหว่างกลุ่มแท็บ
    function Win:CreateCategory(text)
        sideOrder += 1
        local f = New("Frame", {Size = UDim2.fromOffset(1, 20), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, LayoutOrder = sideOrder, Visible = sideOrder > 1}, TabList)
        return f
    end

    ------------------------------------------------------------------
    -- Tabs → Sections (2 คอลัมน์) → Elements
    ------------------------------------------------------------------
    function Win:CreateTab(name, icon, tabOpts)
        -- Columns: 1 หรือ 2 (ตั้งต่อแท็บได้ ถ้าไม่ใส่จะใช้ค่าของหน้าต่าง opts.Columns, ค่าเริ่มต้น 2)
        if type(icon) == "table" and tabOpts == nil then tabOpts, icon = icon, icon.Icon end
        tabOpts = tabOpts or {}
        local colCount = (tabOpts.Columns or opts.Columns) == 1 and 1 or 2
        sideOrder += 1
        name = tostring(name)
        local textW = TextService:GetTextSize(name, 13, Enum.Font.GothamMedium, Vector2.new(1000, 100)).X
        local labelX = icon and 36 or 14
        local TabBtn = New("TextButton", {
            Size = UDim2.fromOffset(labelX + textW + 16, 34), BackgroundColor3 = Theme.CardHover, BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, LayoutOrder = sideOrder,
        }, TabList)
        Corner(TabBtn, 9)
        local TabStroke = Stroke(TabBtn, Theme.Stroke, 1, 1)
        -- เส้นใต้แท็บที่เลือก (อยู่ติดขอบล่างของแถบแท็บ)
        local Bar = New("Frame", {
            Size = UDim2.new(1, -16, 0, 2), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 5),
            BackgroundColor3 = Theme.Purple, BorderSizePixel = 0, Visible = false,
        }, TabBtn)
        Corner(Bar, 1)
        Accent(Bar, "BackgroundColor3", "Purple")
        local tabIcon = icon and MakeIcon(TabBtn, icon, 18, Theme.Muted, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0)})
        local TabLbl = Txt({
            Size = UDim2.new(0, textW + 2, 1, 0), Position = UDim2.fromOffset(tabIcon and 36 or 14, 0),
            Text = name, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Muted,
        }, TabBtn)

        local PageGroup = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false}, Container)

        local function MakeScroll(props, parent)
            local sf = New("ScrollingFrame", {
                BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
                AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
                ScrollingDirection = Enum.ScrollingDirection.Y,
            }, parent)
            for k, v in pairs(props) do sf[k] = v end
            Accent(sf, "ScrollBarImageColor3", "Purple")
            return sf
        end

        -- จอกว้าง: 2 คอลัมน์ แต่ละคอลัมน์เลื่อนแยกกัน
        local Cols = New("Frame", {Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(11, 0), BackgroundTransparency = 1}, PageGroup)
        New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, Cols)
        local ScrollL = MakeScroll({Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = 1}, Cols)
        local ScrollR = MakeScroll({Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = 2}, Cols)

        -- จอแคบ: คอลัมน์เดียว เลื่อนรวมกัน
        local PageScroll = MakeScroll({Size = UDim2.fromScale(1, 1), Visible = false}, PageGroup)
        local Stack = New("Frame", {Size = UDim2.new(1, -22, 0, 0), Position = UDim2.fromOffset(11, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, PageScroll)
        New("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, Stack)
        New("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 14)}, Stack)

        local Scrolls = {ScrollL, ScrollR, PageScroll}
        -- ให้ Page.ScrollingEnabled = ... (ใช้ใน Slider/ColorPicker) ควบคุมทุก ScrollingFrame ของแท็บนี้
        local Page = setmetatable({}, {__newindex = function(_, k, v)
            if k == "ScrollingEnabled" then
                for _, sf in ipairs(Scrolls) do sf.ScrollingEnabled = v end
            end
        end})

        local function Column(order, parent)
            local c = New("Frame", {Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order}, parent)
            New("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, c)
            New("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 14)}, c)
            AutoOrder(c)
            return c
        end
        local Left, Right = Column(1, ScrollL), Column(2, ScrollR)

        local entry = {Btn = TabBtn, Page = PageGroup, Selected = false, Left = Left, Right = Right, Columns = colCount}
        local isNarrow = nil
        function entry.SetNarrow(narrow)
            -- โหมด 1 คอลัมน์: ซ่อนคอลัมน์ขวาที่ว่าง (ไม่เหลือช่องว่างเปล่า)
            Right.Visible = entry.Columns ~= 1 or #Right:GetChildren() > 2
            if narrow == isNarrow then return end
            isNarrow = narrow
            Cols.Visible = not narrow
            PageScroll.Visible = narrow
            if narrow then
                Left.Size, Right.Size = UDim2.new(1, 0, 0, 0), UDim2.new(1, 0, 0, 0)
                Left.Parent, Right.Parent = Stack, Stack
            else
                Left.Size, Right.Size = UDim2.new(1, -6, 0, 0), UDim2.new(1, -6, 0, 0)
                Left.Parent, Right.Parent = ScrollL, ScrollR
            end
        end
        local function Paint(anim)
            local sel = entry.Selected
            local tc = sel and Theme.Text or Theme.Muted
            local bt = sel and 0 or 1
            local stt = sel and 0.1 or 1
            if sel and anim then
                Bar.Visible = true
                Bar.Size = UDim2.new(0, 0, 0, 2)
                Tween(Bar, {Size = UDim2.new(1, -16, 0, 2)}, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            else
                Bar.Visible = sel
                Bar.Size = UDim2.new(1, -16, 0, 2)
            end
            if anim then
                Tween(TabBtn, {BackgroundTransparency = bt}, 0.16)
                Tween(TabStroke, {Transparency = stt}, 0.16)
                Tween(TabLbl, {TextColor3 = tc}, 0.16)
                if tabIcon and not tabIcon:GetAttribute("Custom") then Tween(tabIcon, {[IconProp(tabIcon)] = tc}, 0.16) end
            else
                TabBtn.BackgroundTransparency = bt
                TabStroke.Transparency = stt
                TabLbl.TextColor3 = tc
                if tabIcon and not tabIcon:GetAttribute("Custom") then tabIcon[IconProp(tabIcon)] = tc end
            end
        end
        entry.Paint = Paint
        Themed(TabBtn, function() Paint(false) end)
        table.insert(Tabs, entry)
        Relayout()

        local Tab = {}
        local function Select()
            for _, t in ipairs(Tabs) do
                t.Selected = false
                t.Page.Visible = false
                t.Paint(true)
            end
            entry.Selected = true
            PageGroup.Position = UDim2.fromOffset(0, 16)
            PageGroup.Visible = true
            Tween(PageGroup, {Position = UDim2.new()}, 0.32, Enum.EasingStyle.Quint)
            Paint(true)
        end
        function Tab:Select() Select() end
        entry.Select = Select
        TabBtn.MouseButton1Click:Connect(Select)
        TabBtn.MouseEnter:Connect(function() if not entry.Selected then Tween(TabBtn, {BackgroundTransparency = 0.6}, 0.12) end end)
        TabBtn.MouseLeave:Connect(function() if not entry.Selected then Tween(TabBtn, {BackgroundTransparency = 1}, 0.12) end end)
        if #Tabs == 1 then Select() end

        --------------------------------------------------------------
        -- Elements (ใช้ได้ทั้งใน Section และเรียกผ่าน Tab ตรงๆ)
        --------------------------------------------------------------
        local function HasDesc(d) return d ~= nil and d ~= "" end
        -- ทำสำเนา options และให้ Title ใช้แทน Name ได้ (สไตล์ WindUI)
        local function N(o)
            if type(o) == "string" then o = {Title = o} end
            o = table.clone(o or {})
            o.Name = o.Name or o.Title
            return o
        end

        local function Elements(content)
            local E = {}

            local function Finish(frame, obj)
                obj.Frame = frame
                function obj:SetVisible(v) frame.Visible = v end
                function obj:Destroy() frame:Destroy() end
                return obj
            end
            local function Wrap(h) return New("Frame", {Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1}, content) end
            local function Box(parent, y, h)
                local b = New("TextButton", {Size = UDim2.new(1, 0, 0, h), Position = UDim2.fromOffset(0, y), BackgroundColor3 = Theme.InputBg, Text = "", AutoButtonColor = false}, parent)
                Corner(b, 7)
                return b, Stroke(b, Theme.Stroke, 1, 0.1)
            end

            function E:CreateLabel(text)
                if type(text) == "table" then text = text.Title or text.Name or text.Desc end
                local l = Txt({Size = UDim2.new(1, 0, 0, 16), Text = text or "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.Muted, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y}, content)
                return Finish(l, {SetText = function(_, t) l.Text = tostring(t) end})
            end

            function E:CreateParagraph(o)
                o = N(o)
                local f = New("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, content)
                New("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, f)
                local title = Txt({Size = UDim2.new(1, 0, 0, 18), Text = o.Title or "", Font = Enum.Font.GothamBold, TextSize = 13, LayoutOrder = 1}, f)
                local body = Txt({
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = o.Content or o.Desc or "", Font = Enum.Font.Gotham,
                    TextSize = 11, TextColor3 = Theme.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2,
                }, f)
                New("Frame", {Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.3, BorderSizePixel = 0, LayoutOrder = 3}, f)
                return Finish(f, {
                    SetTitle = function(_, t) title.Text = tostring(t) end,
                    SetContent = function(_, t) body.Text = tostring(t) end,
                })
            end

            function E:CreateDivider()
                return Finish(New("Frame", {Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.3, BorderSizePixel = 0}, content), {})
            end

            function E:CreateSpace(h)
                return Finish(New("Frame", {Size = UDim2.new(1, 0, 0, h or 6), BackgroundTransparency = 1}, content), {})
            end

            -- ปุ่ม: ค่าเริ่มต้น = ปุ่มขาวตัวอักษรเข้ม | Secondary = true → ปุ่มเข้มมีกรอบ | Icon = "plus" ไอคอนด้านขวา
            function E:CreateButton(o)
                o = N(o)
                local hasDesc = HasDesc(o.Desc)
                local secondary = o.Secondary == true
                local function baseC() return secondary and Theme.Card or Color3.fromRGB(240, 242, 247) end
                local function hoverC() return secondary and Theme.CardHover or Color3.fromRGB(255, 255, 255) end
                local function pressC() return secondary and Theme.InputBg or Color3.fromRGB(205, 210, 222) end
                local fg = secondary and Theme.Text or Theme.Bg
                local btn = New("TextButton", {Size = UDim2.new(1, 0, 0, hasDesc and 46 or 32), BackgroundTransparency = 1, Text = "", AutoButtonColor = false}, content)
                local bg = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = baseC(), BorderSizePixel = 0}, btn)
                Corner(bg, 8)
                if secondary then Stroke(bg, Theme.Stroke, 1, 0) end
                local lbl = Txt({
                    Size = hasDesc and UDim2.new(1, 0, 0, 26) or UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, hasDesc and 4 or 0), Text = o.Name or "Button", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = fg,
                    TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2, TextTruncate = Enum.TextTruncate.AtEnd,
                }, btn)
                if hasDesc then
                    Txt({
                        Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 26), Text = tostring(o.Desc), Font = Enum.Font.Gotham,
                        TextSize = 10, TextColor3 = fg, TextTransparency = 0.35, TextXAlignment = Enum.TextXAlignment.Center,
                        ZIndex = 2, TextTruncate = Enum.TextTruncate.AtEnd,
                    }, btn)
                end
                if o.Icon then
                    New("UIPadding", {PaddingRight = UDim.new(0, 18)}, lbl)
                    MakeIcon(btn, o.Icon, 14, fg, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), ZIndex = 3})
                end
                btn.MouseEnter:Connect(function() Tween(bg, {BackgroundColor3 = hoverC()}, 0.12) end)
                btn.MouseLeave:Connect(function() Tween(bg, {BackgroundColor3 = baseC()}, 0.12) end)
                btn.MouseButton1Down:Connect(function() Tween(bg, {BackgroundColor3 = pressC()}, 0.08) end)
                btn.MouseButton1Up:Connect(function() Tween(bg, {BackgroundColor3 = hoverC()}, 0.1) end)
                btn.MouseButton1Click:Connect(function() Safe(o.Callback) end)
                return Finish(btn, {
                    SetText = function(_, t) lbl.Text = tostring(t) end,
                    Fire = function() Safe(o.Callback) end,
                })
            end

            function E:CreateToggle(o)
                o = N(o)
                local state = (o.Default == true) or (o.Value == true)
                local d = HasDesc(o.Desc)
                local row = New("TextButton", {Size = UDim2.new(1, 0, 0, d and 38 or 26), BackgroundTransparency = 1, Text = "", AutoButtonColor = false}, content)
                Txt({Size = UDim2.new(1, -46, 0, d and 18 or 26), Position = UDim2.fromOffset(0, d and 2 or 0), Text = o.Name or "Toggle", TextTruncate = Enum.TextTruncate.AtEnd}, row)
                if d then
                    Txt({Size = UDim2.new(1, -46, 0, 14), Position = UDim2.fromOffset(0, 20), Text = o.Desc, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.Muted, TextTruncate = Enum.TextTruncate.AtEnd}, row)
                end
                local bg = New("Frame", {Size = UDim2.fromOffset(36, 20), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = Theme.InputBg}, row)
                Corner(bg, 10)
                local bgStroke = Stroke(bg, Theme.Stroke, 1, 0.1)
                local knob = New("Frame", {Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Theme.Muted}, bg)
                Corner(knob, 7)
                local function KnobPos() return state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7) end
                Themed(bg, function()
                    bg.BackgroundColor3 = state and Theme.Purple or Theme.InputBg
                    knob.BackgroundColor3 = state and Theme.Bg or Theme.Muted
                end)
                knob.Position = KnobPos()

                local obj = {}
                local function Set(v, fire)
                    state = v and true or false
                    SetFlag(o.Flag, state)
                    Tween(bg, {BackgroundColor3 = state and Theme.Purple or Theme.InputBg}, 0.2)
                    Tween(bgStroke, {Transparency = state and 1 or 0.1}, 0.2)
                    Tween(knob, {Position = KnobPos(), BackgroundColor3 = state and Theme.Bg or Theme.Muted}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                    if fire ~= false then Safe(o.Callback, state) end
                end
                function obj:Set(v) Set(v, true) end
                function obj:Get() return state end
                SetFlag(o.Flag, state)
                Register(o.Flag, function(v) Set(v, true) end)
                row.MouseButton1Click:Connect(function() Set(not state, true) end)
                return Finish(row, obj)
            end

            function E:CreateSlider(o)
                o = N(o)
                local V = type(o.Value) == "table" and o.Value or {}
                local minV, maxV = o.Min or V.Min or 0, o.Max or V.Max or 100
                if maxV <= minV then maxV = minV + 1 end
                local inc = o.Increment or o.Step or V.Step or 1
                local dec = tostring(inc):match("%.(%d+)")
                dec = dec and #dec or 0
                local suffix = o.Suffix or ""
                local function Snap(n)
                    n = math.clamp(n, minV, maxV)
                    n = minV + math.floor((n - minV) / inc + 0.5) * inc
                    return tonumber(string.format("%." .. dec .. "f", math.clamp(n, minV, maxV)))
                end
                local val = Snap(o.Default or V.Default or (type(o.Value) == "number" and o.Value) or minV)

                local row = Wrap(42)
                Txt({Size = UDim2.new(0.6, 0, 0, 18), Text = o.Name or "Slider", TextTruncate = Enum.TextTruncate.AtEnd}, row)
                local valBox = New("TextBox", {
                    Size = UDim2.new(0.4, 0, 0, 18), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
                    Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Right, ClearTextOnFocus = false, Text = "",
                }, row)
                local barBg = New("Frame", {Size = UDim2.new(1, 0, 0, 6), Position = UDim2.fromOffset(0, 28), BackgroundColor3 = Theme.InputBg}, row)
                Corner(barBg, 3)
                local barFill = New("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1)}, barBg)
                Corner(barFill, 3)
                AccentGradient(barFill, 0)
                local knob = New("Frame", {Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2}, barBg)
                Corner(knob, 6)

                local function Visual(animate)
                    local ratio = (val - minV) / (maxV - minV)
                    valBox.Text = string.format("%." .. dec .. "f", val) .. suffix
                    if animate then
                        Tween(barFill, {Size = UDim2.new(ratio, 0, 1, 0)}, 0.08)
                        Tween(knob, {Position = UDim2.new(ratio, -6, 0.5, -6)}, 0.08)
                    else
                        barFill.Size = UDim2.new(ratio, 0, 1, 0)
                        knob.Position = UDim2.new(ratio, -6, 0.5, -6)
                    end
                end
                Visual(false)
                SetFlag(o.Flag, val)

                local obj = {}
                local function Set(v, fire)
                    val = Snap(v)
                    SetFlag(o.Flag, val)
                    Visual(true)
                    if fire ~= false then Safe(o.Callback, val) end
                end
                function obj:Set(v) Set(v, true) end
                function obj:Get() return val end
                Register(o.Flag, function(v) Set(v, true) end)
                valBox.FocusLost:Connect(function()
                    local n = tonumber(valBox.Text:match("-?%d+%.?%d*"))
                    if n then Set(n, true) else Visual(false) end
                end)

                local hit = New("TextButton", {Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 19), BackgroundTransparency = 1, Text = ""}, row)
                local dragging = false
                local releaseSink
                local function Update(input)
                    local p = PointerPos(input)
                    local pct = math.clamp((p.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
                    local nv = Snap(minV + (maxV - minV) * pct)
                    if nv ~= val then Set(nv, true) end
                end
                hit.InputBegan:Connect(function(input)
                    if IsPress(input) then
                        dragging = true
                        if releaseSink then releaseSink() end
                        releaseSink = SinkBegin()
                        Page.ScrollingEnabled = false
                        Update(input)
                    end
                end)
                Connect(UserInputService.InputEnded, function(input)
                    if IsPress(input) and dragging then
                        dragging = false
                        if releaseSink then releaseSink() releaseSink = nil end
                        Page.ScrollingEnabled = true
                    end
                end)
                Connect(UserInputService.InputChanged, function(input)
                    if dragging and IsMove(input) then Update(input) end
                end)
                return Finish(row, obj)
            end

            function E:CreateInput(o)
                o = N(o)
                local wrap = Wrap(52)
                Txt({Size = UDim2.new(1, 0, 0, 18), Text = o.Name or "Input", TextTruncate = Enum.TextTruncate.AtEnd}, wrap)
                local frame, bStroke = Box(wrap, 22, 28)
                frame:Destroy() -- ใช้ TextBox แทนปุ่ม
                local box = New("TextBox", {
                    Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 22), BackgroundColor3 = Theme.InputBg,
                    Text = tostring(o.Default or o.Value or ""), PlaceholderText = o.Placeholder or "Enter value", Font = Enum.Font.Gotham, TextSize = 12,
                    TextColor3 = Theme.Text, PlaceholderColor3 = Theme.Muted, ClearTextOnFocus = false,
                    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                }, wrap)
                New("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 28)}, box)
                Corner(box, 7)
                bStroke = Stroke(box, Theme.Stroke, 1, 0.1)
                MakeIcon(box, o.Icon or "pencil", 14, Theme.Muted, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 24, 0.5, 0)})
                SetFlag(o.Flag, box.Text)

                local obj = {}
                function obj:Get() return box.Text end
                local setting = false
                function obj:Set(v, fire)
                    setting = true
                    box.Text = tostring(v)
                    setting = false
                    SetFlag(o.Flag, box.Text)
                    if fire then Safe(o.Callback, box.Text, false) end
                end
                Register(o.Flag, function(v) obj:Set(v, true) end)
                box:GetPropertyChangedSignal("Text"):Connect(function()
                    if o.Numeric then
                        local cleaned = (box.Text:gsub("[^%d%.%-]", ""))
                        if cleaned ~= box.Text then box.Text = cleaned return end
                    end
                    SetFlag(o.Flag, box.Text)
                    if o.RealTime and not setting then Safe(o.Callback, box.Text, false) end
                end)
                box.Focused:Connect(function() Tween(bStroke, {Color = Theme.Purple, Transparency = 0}, 0.16) end)
                box.FocusLost:Connect(function(enter)
                    Tween(bStroke, {Color = Theme.Stroke, Transparency = 0.1}, 0.16)
                    if not o.RealTime then Safe(o.Callback, box.Text, enter) end
                end)
                return Finish(wrap, obj)
            end

            function E:CreateDropdown(o)
                o = N(o)
                local options = o.Options or o.Values or {}
                local multi = o.Multi == true
                local chosen, open = {}, false
                local MAXLIST = 140

                local wrap = New("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, ClipsDescendants = true}, content)
                Txt({Size = UDim2.new(1, 0, 0, 18), Text = o.Name or "Dropdown", TextTruncate = Enum.TextTruncate.AtEnd}, wrap)
                local header, hStroke = Box(wrap, 22, 28)
                local chev = MakeIcon(header, "chevron-down", 14, Theme.Muted, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0)}, "▾")
                local cur = Txt({Size = UDim2.new(1, -34, 1, 0), Position = UDim2.fromOffset(10, 0), Font = Enum.Font.Gotham, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd}, header)

                local list = New("ScrollingFrame", {
                    Position = UDim2.fromOffset(0, 56), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
                    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
                }, wrap)
                Accent(list, "ScrollBarImageColor3", "Purple")
                New("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, list)
                AutoOrder(list)

                local buttons, obj = {}, {}
                local function Value()
                    if multi then
                        local r = {}
                        for _, opt in ipairs(options) do if chosen[opt] then r[#r + 1] = opt end end
                        return r
                    end
                    for _, opt in ipairs(options) do if chosen[opt] then return opt end end
                end
                local function Visuals()
                    local names = {}
                    for _, opt in ipairs(options) do
                        local on = chosen[opt] == true
                        if on then names[#names + 1] = tostring(opt) end
                        local b = buttons[opt]
                        if b then
                            b.BackgroundColor3 = on and Theme.CardHover or Theme.InputBg
                            b.TextColor3 = on and Theme.Purple or Theme.Text
                        end
                    end
                    cur.Text = #names == 0 and "Select" or (multi and (#names > 2 and (#names .. " selected") or table.concat(names, ", ")) or names[1])
                end
                local function Layout()
                    local lh = math.min(#options * 30, MAXLIST)
                    list.Size = UDim2.new(1, 0, 0, lh)
                    Tween(wrap, {Size = UDim2.new(1, 0, 0, open and (60 + lh) or 52)}, 0.22)
                    Tween(hStroke, {Color = open and Theme.Purple or Theme.Stroke, Transparency = open and 0 or 0.1}, 0.18)
                    if chev then Tween(chev, {Rotation = open and 180 or 0}, 0.2) end
                end
                local function Pick(item)
                    if multi then
                        chosen[item] = (not chosen[item]) or nil
                    else
                        chosen = {[item] = true}
                        open = false
                        Layout()
                    end
                    SetFlag(o.Flag, Value())
                    Visuals()
                    Safe(o.Callback, Value())
                end
                local function Build()
                    for _, b in pairs(buttons) do b:Destroy() end
                    buttons = {}
                    for _, item in ipairs(options) do
                        local b = New("TextButton", {
                            Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Theme.InputBg, Text = tostring(item),
                            Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.Text, AutoButtonColor = false,
                        }, list)
                        Corner(b, 7)
                        buttons[item] = b
                        b.MouseEnter:Connect(function() Tween(b, {BackgroundColor3 = Theme.CardHover}, 0.12) end)
                        b.MouseLeave:Connect(function() Tween(b, {BackgroundColor3 = chosen[item] and Theme.CardHover or Theme.InputBg}, 0.12) end)
                        b.MouseButton1Click:Connect(function() Pick(item) end)
                    end
                    Visuals()
                    if open then Layout() end
                end

                local dv = o.Default
                if dv == nil then dv = o.Value end
                if multi then
                    if type(dv) == "table" then for _, v in ipairs(dv) do chosen[v] = true end end
                else
                    local dflt = dv or options[1]
                    if dflt ~= nil then chosen[dflt] = true end
                end
                Build()
                SetFlag(o.Flag, Value())

                function obj:Get() return Value() end
                function obj:Set(v, fire)
                    chosen = {}
                    if multi and type(v) == "table" then
                        for _, x in ipairs(v) do chosen[x] = true end
                    elseif v ~= nil then
                        chosen[v] = true
                    end
                    SetFlag(o.Flag, Value())
                    Visuals()
                    if fire ~= false then Safe(o.Callback, Value()) end
                end
                function obj:Refresh(newOptions)
                    options = newOptions or {}
                    local keep = {}
                    for _, opt in ipairs(options) do if chosen[opt] then keep[opt] = true end end
                    chosen = keep
                    Build()
                    SetFlag(o.Flag, Value())
                end
                Register(o.Flag, function(v) obj:Set(v, true) end)
                header.MouseButton1Click:Connect(function()
                    open = not open
                    Layout()
                end)
                return Finish(wrap, obj)
            end

            function E:CreateKeybind(o)
                o = N(o)
                local key = o.Default or o.Value or Enum.KeyCode.F
                if type(key) == "string" then key = Enum.KeyCode[key] or Enum.KeyCode.F end
                local listening = false
                local row = Wrap(26)
                Txt({Size = UDim2.new(1, -70, 1, 0), Text = o.Name or "Keybind", TextTruncate = Enum.TextTruncate.AtEnd}, row)
                local bindBtn = New("TextButton", {
                    Size = UDim2.fromOffset(60, 20), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
                    BackgroundColor3 = Theme.InputBg, Text = key.Name, Font = Enum.Font.GothamMedium, TextSize = 11,
                    TextColor3 = Theme.Muted, AutoButtonColor = false,
                }, row)
                Corner(bindBtn, 6)
                Stroke(bindBtn, Theme.Stroke, 1, 0.1)
                SetFlag(o.Flag, key.Name)

                local obj = {}
                local function SetKey(k, fire)
                    if type(k) == "string" then k = Enum.KeyCode[k] end
                    if typeof(k) ~= "EnumItem" then return end
                    key = k
                    bindBtn.Text = key.Name
                    SetFlag(o.Flag, key.Name)
                    if fire then Safe(o.OnChanged, key) end
                end
                function obj:Set(k) SetKey(k, true) end
                function obj:Get() return key end
                Register(o.Flag, function(v) SetKey(v, true) end)

                local function StopListening()
                    if listening then
                        listening = false
                        Listening = math.max(0, Listening - 1)
                    end
                    Tween(bindBtn, {BackgroundColor3 = Theme.InputBg, TextColor3 = Theme.Muted}, 0.16)
                end
                bindBtn.MouseButton1Click:Connect(function()
                    if listening then return end
                    listening = true
                    Listening += 1
                    bindBtn.Text = "..."
                    Tween(bindBtn, {BackgroundColor3 = Theme.Purple, TextColor3 = Theme.Bg}, 0.15)
                end)
                Connect(UserInputService.InputBegan, function(input, gpe)
                    if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                        if input.KeyCode == Enum.KeyCode.Escape then bindBtn.Text = key.Name else SetKey(input.KeyCode, true) end
                        task.defer(StopListening)
                    elseif listening and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                        local p = input.Position
                        local a, sz = bindBtn.AbsolutePosition, bindBtn.AbsoluteSize
                        local inside = p.X >= a.X and p.X <= a.X + sz.X and p.Y >= a.Y and p.Y <= a.Y + sz.Y
                        if not inside then
                            bindBtn.Text = key.Name
                            StopListening()
                        end
                    elseif not listening and not gpe and input.KeyCode == key then
                        Safe(o.Callback, key)
                    end
                end)
                return Finish(row, obj)
            end

            function E:CreateColorpicker(o)
                o = N(o)
                local presets = {
                    Color3.fromRGB(168, 85, 247), Color3.fromRGB(236, 72, 153), Color3.fromRGB(244, 114, 182),
                    Color3.fromRGB(139, 92, 246), Color3.fromRGB(219, 39, 119), Color3.fromRGB(255, 255, 255),
                }
                local color = o.Default or Theme.Purple
                local h, s, v = color:ToHSV()
                local open = false
                local fullH = 188

                local wrap = New("Frame", {Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, ClipsDescendants = true}, content)
                local header = New("TextButton", {Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "", AutoButtonColor = false}, wrap)
                Txt({Size = UDim2.new(1, -40, 1, 0), Text = o.Name or "Color", TextTruncate = Enum.TextTruncate.AtEnd}, header)
                local swatch = New("Frame", {Size = UDim2.fromOffset(26, 16), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = color}, header)
                Corner(swatch, 5)
                Stroke(swatch, Theme.Text, 1, 0.6)
                swatch:SetAttribute("NoRecolor", true)

                local svBox = New("Frame", {Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromOffset(0, 34), BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0}, wrap)
                Corner(svBox, 8)
                local white = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, svBox)
                Corner(white, 8)
                New("UIGradient", {Transparency = NumberSequence.new(0, 1)}, white)
                local black = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0}, svBox)
                Corner(black, 8)
                New("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0)}, black)
                local svCursor = New("Frame", {Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 3}, svBox)
                Corner(svCursor, 6)
                Stroke(svCursor, Color3.new(1, 1, 1), 2)

                local hueBar = New("Frame", {Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 138), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, wrap)
                Corner(hueBar, 7)
                local keys = {}
                for i = 0, 6 do keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i == 6 and 0 or i / 6, 1, 1)) end
                New("UIGradient", {Color = ColorSequence.new(keys)}, hueBar)
                local hueCursor = New("Frame", {Size = UDim2.fromOffset(4, 20), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3}, hueBar)
                Corner(hueCursor, 2)
                Stroke(hueCursor, Color3.new(0, 0, 0), 1, 0.4)

                local presetRow = New("Frame", {Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 160), BackgroundTransparency = 1}, wrap)
                New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center}, presetRow)

                local obj = {}
                local function Apply(fire)
                    color = Color3.fromHSV(h, s, v)
                    swatch.BackgroundColor3 = color
                    svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                    svCursor.Position = UDim2.fromScale(s, 1 - v)
                    hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
                    SetFlag(o.Flag, color)
                    if fire then Safe(o.Callback, color) end
                end
                Apply(false)
                function obj:Get() return color end
                function obj:Set(c, fire)
                    h, s, v = c:ToHSV()
                    Apply(fire ~= false)
                end
                Register(o.Flag, function(c) obj:Set(c, true) end)

                for _, col in ipairs(presets) do
                    local sw = New("TextButton", {Size = UDim2.fromOffset(18, 18), BackgroundColor3 = col, Text = "", AutoButtonColor = false}, presetRow)
                    sw:SetAttribute("NoRecolor", true)
                    Corner(sw, 9)
                    Stroke(sw, Theme.Text, 1, 0.5)
                    sw.MouseButton1Click:Connect(function() obj:Set(col, true) end)
                end

                local active
                local function Update(input)
                    local p = PointerPos(input)
                    if active == "sv" then
                        s = math.clamp((p.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
                        v = 1 - math.clamp((p.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
                    elseif active == "hue" then
                        h = math.clamp((p.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
                    end
                    Apply(true)
                end
                local releasePickSink
                local function Begin(which, input)
                    if IsPress(input) then
                        active = which
                        if releasePickSink then releasePickSink() end
                        releasePickSink = SinkBegin()
                        Page.ScrollingEnabled = false
                        Update(input)
                    end
                end
                svBox.InputBegan:Connect(function(i) Begin("sv", i) end)
                hueBar.InputBegan:Connect(function(i) Begin("hue", i) end)
                Connect(UserInputService.InputChanged, function(input)
                    if active and IsMove(input) then Update(input) end
                end)
                Connect(UserInputService.InputEnded, function(input)
                    if active and IsPress(input) then
                        active = nil
                        if releasePickSink then releasePickSink() releasePickSink = nil end
                        Page.ScrollingEnabled = true
                    end
                end)
                header.MouseButton1Click:Connect(function()
                    open = not open
                    Tween(wrap, {Size = UDim2.new(1, 0, 0, open and fullH or 26)}, 0.22)
                end)
                return Finish(wrap, obj)
            end

            function E:CreateProgressBar(o)
                o = N(o)
                local pct = math.clamp(o.Default or o.Value or 0, 0, 100)
                local row = Wrap(36)
                Txt({Size = UDim2.new(0.7, 0, 0, 18), Text = o.Name or "Progress", TextSize = 12}, row)
                local pLbl = Txt({Size = UDim2.new(0.3, 0, 0, 18), Position = UDim2.fromScale(0.7, 0), Text = math.floor(pct + 0.5) .. "%", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Right}, row)
                local bg = New("Frame", {Size = UDim2.new(1, 0, 0, 6), Position = UDim2.fromOffset(0, 24), BackgroundColor3 = Theme.InputBg}, row)
                Corner(bg, 3)
                local fill = New("Frame", {Size = UDim2.new(pct / 100, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1)}, bg)
                Corner(fill, 3)
                AccentGradient(fill, 0)
                local numVal = New("NumberValue", {Value = pct}, row)
                numVal.Changed:Connect(function(x) pLbl.Text = math.floor(x + 0.5) .. "%" end)
                local obj = {}
                function obj:Set(nv)
                    pct = math.clamp(nv, 0, 100)
                    SetFlag(o.Flag, pct)
                    Tween(fill, {Size = UDim2.new(pct / 100, 0, 1, 0)}, 0.3)
                    Tween(numVal, {Value = pct}, 0.3)
                end
                function obj:Get() return pct end
                return Finish(row, obj)
            end

            -- ชื่อสั้นแบบ WindUI: Section:Button{} = Section:CreateButton{}
            for _, base in ipairs({"Toggle", "Slider", "Input", "Dropdown", "Keybind", "Colorpicker", "ProgressBar", "Button", "Paragraph", "Divider", "Space", "Label"}) do E[base] = E["Create" .. base] end
            return E
        end

        local secCount, current = 0, nil
        local function NewSection(title, side)
            if side == nil then side = (secCount % 2 == 0) and "Left" or "Right" end
            secCount += 1
            local col = (colCount ~= 1 and tostring(side):lower() == "right") and Right or Left
            local box = New("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Card, BorderSizePixel = 0}, col)
            Corner(box, 10)
            Stroke(box, Theme.Stroke, 1, 0.2)
            New("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, box)

            local head, chev
            local hasTitle = title ~= nil and title ~= ""
            if hasTitle then
                head = New("TextButton", {Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1}, box)
                Txt({Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(12, 0), Text = title, Font = Enum.Font.GothamBold, TextColor3 = Theme.Text, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd}, head)
                chev = MakeIcon(head, "chevron-down", 16, Theme.Muted, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0)}, "▾")
            end
            local content = New("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2}, box)
            New("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, hasTitle and 2 or 12), PaddingBottom = UDim.new(0, 12)}, content)
            New("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, content)
            AutoOrder(content)

            if head then
                local openSec = true
                head.MouseButton1Click:Connect(function()
                    openSec = not openSec
                    content.Visible = openSec
                    if chev then Tween(chev, {Rotation = openSec and 0 or -90}, 0.18) end
                end)
            end

            local sec = Elements(content)
            sec.Frame = box
            current = sec
            return sec
        end

        local Tab = {}
        function Tab:Select() Select() end
        function Tab:CreateSection(title, side) return NewSection(title, side) end
        -- Tab:Section({Title = "Combat", Side = "Left"}) หรือ Tab:Section("Combat", "Left")
        function Tab:Section(o, side)
            if type(o) == "table" then return NewSection(o.Title or o.Name, o.Side or side) end
            return NewSection(o, side)
        end
        function Tab:SetColumns(n)
            entry.Columns = (n == 1) and 1 or 2
            colCount = entry.Columns
            Relayout()
        end
        for _, base in ipairs({"Toggle", "Slider", "Input", "Dropdown", "Keybind", "Colorpicker", "ProgressBar", "Button", "Paragraph", "Divider", "Space", "Label"}) do
            local fn = function(_, ...)
                local s = current or NewSection(nil, "Left")
                return s["Create" .. base](s, ...)
            end
            Tab[base] = fn
            Tab["Create" .. base] = fn
        end
        return Tab
    end

    --==================================================================
    -- API แบบ WindUI (ไม่ต้องมีคำว่า Create)
    --==================================================================
    -- Win:Tab({Title = "Main", Icon = "home", Columns = 2})
    function Win:Tab(o, icon, tabOpts)
        if type(o) == "table" then
            local to = tabOpts or {}
            if o.Columns ~= nil then to = {Columns = o.Columns} end
            return Win:CreateTab(o.Title or o.Name or "Tab", o.Icon, to)
        end
        return Win:CreateTab(o, icon, tabOpts)
    end
    -- Win:Category("Main") หรือ Win:Category({Title = "Main"})
    function Win:Category(o)
        return Win:CreateCategory(type(o) == "table" and (o.Title or o.Name) or o)
    end
    -- Win:SelectTab(1) เลือกแท็บตามลำดับที่สร้าง
    function Win:SelectTab(i)
        local t = Tabs[i]
        if t and t.Select then t.Select() end
    end
    function Win:Dialog(o) CrystalUI:Dialog(o) end
    -- Win:SetTheme("Dark") หรือ Win:SetTheme({Purple = Color3...})
    function Win:SetTheme(t)
        if type(t) == "string" then return CrystalUI:SetThemePreset(t) end
        CrystalUI:SetTheme(t)
    end

    --==================================================================
    -- Config system
    --==================================================================
    local folderName = (tostring(opts.ConfigFolder or opts.Title or "Default"):gsub('[\\/:*?"<>|]', ""))
    local ConfigDir = "CrystalUI/" .. folderName

    local function CleanName(n)
        n = tostring(n or ""):gsub('[\\/:*?"<>|]', "")
        return n ~= "" and n or nil
    end

    local function Serialize()
        local out = {}
        for flag, value in pairs(Win.Flags) do out[flag] = EncodeValue(value) end
        return HttpService:JSONEncode(out)
    end

    function Win:SaveConfig(name)
        name = CleanName(name)
        if not name then return false, "Invalid name" end
        local ok, json = pcall(Serialize)
        if not ok then return false, tostring(json) end
        if HasFS() then
            local wok, err = pcall(function()
                if not isfolder("CrystalUI") then makefolder("CrystalUI") end
                if not isfolder(ConfigDir) then makefolder(ConfigDir) end
                writefile(ConfigDir .. "/" .. name .. ".json", json)
            end)
            if not wok then return false, tostring(err) end
        else
            MemoryConfigs[name] = json
        end
        return true
    end

    function Win:LoadConfig(name)
        name = CleanName(name)
        if not name then return false, "Invalid name" end
        local raw
        if HasFS() then
            local path = ConfigDir .. "/" .. name .. ".json"
            local rok, res = pcall(function() return isfile(path) and readfile(path) or nil end)
            raw = rok and res or nil
        else
            raw = MemoryConfigs[name]
        end
        if not raw then return false, "Config not found" end
        local dok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if not dok or type(decoded) ~= "table" then return false, "Corrupted config" end
        for flag, value in pairs(decoded) do
            local setter = Setters[flag]
            if setter then pcall(setter, DecodeValue(value)) end
        end
        return true
    end

    function Win:DeleteConfig(name)
        name = CleanName(name)
        if not name then return false end
        if HasFS() then
            local path = ConfigDir .. "/" .. name .. ".json"
            pcall(function() if isfile(path) and delfile then delfile(path) end end)
        else
            MemoryConfigs[name] = nil
        end
        return true
    end

    function Win:ListConfigs()
        local names = {}
        if HasFS() then
            pcall(function()
                if isfolder(ConfigDir) then
                    for _, path in ipairs(listfiles(ConfigDir)) do
                        local n = path:match("([^/\\]+)%.json$")
                        if n then names[#names + 1] = n end
                    end
                end
            end)
        else
            for n in pairs(MemoryConfigs) do names[#names + 1] = n end
        end
        table.sort(names)
        return names
    end

    local settingsTab
    function Win:AddSettingsTab(name, tabOpts)
        if settingsTab then return settingsTab end
        local tab = Win:CreateTab(name or "Settings", "settings", tabOpts)
        settingsTab = tab

        tab:CreateSection("Config", "Left")
        if not HasFS() then
            tab:CreateParagraph({Title = "Memory mode", Content = "Executor นี้ไม่รองรับระบบไฟล์ — config จะอยู่ในหน่วยความจำจนกว่าจะปิดเกม"})
        end
        local nameInput = tab:CreateInput({Name = "Config name", Default = "default", Placeholder = "my_config"})
        local dd = tab:CreateDropdown({
            Name = "Saved configs",
            Options = Win:ListConfigs(),
            Callback = function(item) if item then nameInput:Set(item) end end,
        })
        local function Refresh() dd:Refresh(Win:ListConfigs()) end

        tab:CreateButton({Name = "Save Config", Icon = "save", Callback = function()
            local ok, err = Win:SaveConfig(nameInput:Get())
            Refresh()
            CrystalUI:Notify({Title = ok and "Config Saved" or "Save Failed", Content = ok and ("Saved '" .. nameInput:Get() .. "'") or tostring(err), Type = ok and "success" or "error", Duration = 2.5})
        end})
        tab:CreateButton({Name = "Load Config", Secondary = true, Callback = function()
            local ok, err = Win:LoadConfig(nameInput:Get())
            CrystalUI:Notify({Title = ok and "Config Loaded" or "Load Failed", Content = ok and "Applied saved settings." or tostring(err), Type = ok and "success" or "error", Duration = 2.5})
        end})
        tab:CreateButton({Name = "Delete Config", Secondary = true, Icon = "trash-2", Callback = function()
            CrystalUI:Dialog({
                Title = "Delete config?",
                Content = "ต้องการลบ '" .. tostring(nameInput:Get()) .. "' ใช่หรือไม่",
                ConfirmText = "Delete", Danger = true,
                OnConfirm = function()
                    Win:DeleteConfig(nameInput:Get())
                    Refresh()
                    CrystalUI:Notify({Title = "Deleted", Content = "Config removed.", Type = "warning", Duration = 2.5})
                end,
            })
        end})
        tab:CreateButton({Name = "Refresh List", Secondary = true, Icon = "refresh-cw", Callback = Refresh})

        tab:CreateSection("Theme", "Right")
        tab:CreateDropdown({
            Name = "Theme",
            Options = CrystalUI.ThemeNames,
            Default = CrystalUI.CurrentTheme,
            Callback = function(item)
                if item and item ~= CrystalUI.CurrentTheme then
                    CrystalUI:SetThemePreset(item)
                    CrystalUI:Notify({Title = "Theme Updated", Content = "Applied " .. item, Duration = 2})
                end
            end,
        })
        return tab
    end
    -- ชื่อเก่ายังใช้ได้ แต่ทั้งหมดรวมเป็นแท็บ Settings แท็บเดียว
    Win.AddConfigsTab = Win.AddSettingsTab
    Win.AddThemesTab = Win.AddSettingsTab

    return Win
end

return CrystalUI