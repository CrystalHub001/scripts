--// Crystal UI Library v2.0 | Wind Style & Resizable (Purple & Pink Edition)
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local CrystalUI = {}
CrystalUI.__index = CrystalUI
CrystalUI.Version = "2.0"

--==================================================================
-- Theme (เปลี่ยนสีได้สดผ่าน CrystalUI:SetTheme)
--==================================================================
local Theme = {
    Bg = Color3.fromRGB(15, 11, 24),
    Sidebar = Color3.fromRGB(20, 15, 32),
    Card = Color3.fromRGB(27, 20, 44),
    CardHover = Color3.fromRGB(36, 27, 58),
    InputBg = Color3.fromRGB(18, 13, 29),
    Purple = Color3.fromRGB(168, 85, 247),
    Pink = Color3.fromRGB(236, 72, 153),
    Text = Color3.fromRGB(248, 244, 255),
    Muted = Color3.fromRGB(165, 148, 190),
    Stroke = Color3.fromRGB(78, 46, 118),
}
CrystalUI.Theme = Theme

local RootGui -- ประกาศก่อนเพื่อให้ฟังก์ชันด้านล่างใช้ได้
local ThemeHooks = {}
local Connections = {}
local Listening = 0 -- นับจำนวน Keybind ที่กำลังรอรับปุ่ม (กัน ToggleKey ทำงานซ้อน)

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
            table.remove(ThemeHooks, i) -- ล้าง hook ของ instance ที่ถูกทำลายแล้ว
        end
    end
end

function CrystalUI:SetTheme(t)
    for k, v in pairs(t or {}) do
        if k == "Purple" or k == "Pink" then Theme[k] = v end
    end
    ApplyTheme()
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

-- ตำแหน่งเมาส์/นิ้ว (ใช้ร่วมกับ IgnoreGuiInset = true)
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

-- เรียงลำดับ element ตามลำดับการสร้างเสมอ
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
-- Root GUI + Cleanup (รันซ้ำได้โดยไม่มี connection ค้าง)
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

local function Cleanup()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
    table.clear(ThemeHooks)
    if RootGui then RootGui:Destroy() end
end
Env.__CrystalUI_Cleanup = Cleanup
function CrystalUI:Destroy() Cleanup() end

--==================================================================
-- Draggable (เมาส์ + ทัช, กันลากหลุดจอ, บอกได้ว่าเป็น drag หรือ click)
--==================================================================
local function MakeDraggable(handle, target, canDrag)
    local dragging, moved = false, false
    local dragStart, startPos, startAbs

    handle.InputBegan:Connect(function(input)
        if IsPress(input) then
            if canDrag and not canDrag() then return end
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
            local screen = RootGui.AbsoluteSize
            local size = target.AbsoluteSize
            local keepX, keepY = math.min(80, size.X), math.min(40, size.Y)
            local nx = math.clamp(startAbs.X + delta.X, -size.X + keepX, screen.X - keepX)
            local ny = math.clamp(startAbs.Y + delta.Y, 0, screen.Y - keepY)
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + (nx - startAbs.X),
                startPos.Y.Scale, startPos.Y.Offset + (ny - startAbs.Y)
            )
        end
    end)

    Connect(UserInputService.InputEnded, function(input)
        if IsPress(input) then dragging = false end
    end)

    return function() return moved end
end

--==================================================================
-- Config encode / decode (รองรับ Color3, ตาราง)
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
-- Notifications (แก้บั๊ก: เดิม tween Position ไม่ได้เพราะ UIListLayout คุมอยู่)
--==================================================================
local NotifHolder = New("Frame", {
    Name = "Notifications",
    Size = UDim2.new(0, 300, 1, -24),
    Position = UDim2.new(1, -312, 0, 12),
    BackgroundTransparency = 1,
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
    opts = opts or {}
    local title = opts.Title or "Crystal UI"
    local content = opts.Content or ""
    local duration = opts.Duration or 3.5
    local kindColor = NotifColors[opts.Type]

    local textH = content == "" and 0 or TextService:GetTextSize(content, 12, Enum.Font.Gotham, Vector2.new(262, 1000)).Y
    local h = math.max(52, 34 + textH + 12)

    -- จำกัดจำนวนแจ้งเตือนพร้อมกัน
    while #NotifSlots >= 5 do
        local oldest = table.remove(NotifSlots, 1)
        if oldest then oldest:Destroy() end
    end

    NotifSeq += 1
    local Slot = New("Frame", {Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = NotifSeq}, NotifHolder)
    table.insert(NotifSlots, Slot)

    local Card = New("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(1, 330, 0, 0),
        BackgroundColor3 = Theme.Card,
        ClipsDescendants = true,
    }, Slot)
    Corner(Card, 10)
    local st = Stroke(Card, kindColor or Theme.Pink, 1.1)

    local Accent1 = New("Frame", {Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = kindColor or Color3.new(1, 1, 1), BorderSizePixel = 0}, Card)
    local LifeBar = New("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = kindColor or Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, Card)
    if not kindColor then
        AccentGradient(st, 45)
        AccentGradient(Accent1, 90)
        AccentGradient(LifeBar, 0)
    end

    Txt({Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 8), Text = title, Font = Enum.Font.GothamBold, TextTruncate = Enum.TextTruncate.AtEnd}, Card)
    Txt({
        Size = UDim2.new(1, -24, 1, -34), Position = UDim2.fromOffset(12, 28), Text = content,
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
-- Dialog (ใช้ CanvasGroup ให้ fade ทั้งกล่อง, ปุ่มยืดตามขนาด)
--==================================================================
function CrystalUI:Dialog(opts)
    opts = opts or {}
    local content = opts.Content or ""
    local textH = content == "" and 0 or TextService:GetTextSize(content, 12, Enum.Font.Gotham, Vector2.new(300, 1000)).Y
    local boxW, boxH = 340, math.max(130, 104 + textH)

    local Overlay = New("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1, Active = true, ZIndex = 50,
    }, RootGui)

    local Box = New("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(boxW - 30, boxH - 15),
        BackgroundColor3 = Theme.Bg,
        GroupTransparency = 1,
        ZIndex = 51,
    }, Overlay)
    Corner(Box, 12)
    AccentGradient(Stroke(Box, Theme.Pink, 1.2), 0)

    Txt({Size = UDim2.new(1, -28, 0, 26), Position = UDim2.fromOffset(14, 12), Text = opts.Title or "Confirm", Font = Enum.Font.GothamBold, TextSize = 15}, Box)
    Txt({
        Size = UDim2.new(1, -28, 0, textH + 2), Position = UDim2.fromOffset(14, 42), Text = content,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
    }, Box)

    local BtnRow = New("Frame", {Size = UDim2.new(1, -28, 0, 34), Position = UDim2.new(0, 14, 1, -48), BackgroundTransparency = 1}, Box)
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
        local b = New("TextButton", {
            Size = hideCancel and UDim2.new(1, 0, 1, 0) or UDim2.new(0.5, -4, 1, 0),
            BackgroundColor3 = primary and Color3.new(1, 1, 1) or Theme.Card,
            Text = text, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Text,
            AutoButtonColor = false, ZIndex = 52,
        }, BtnRow)
        Corner(b, 8)
        if primary then AccentGradient(b, 0) end
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
    opts = opts or {}
    local Win = {Flags = {}}
    local Setters = {}
    local Tabs = {}
    local MemoryConfigs = {}

    local function SetFlag(flag, v) if flag then Win.Flags[flag] = v end end
    local function Register(flag, setter) if flag then Setters[flag] = setter end end

    -- ขนาดเริ่มต้นไม่เกินหน้าจอ (รองรับมือถือ)
    local vp = RootGui.AbsoluteSize
    if vp.X < 100 or vp.Y < 100 then vp = Vector2.new(1280, 720) end
    local req = opts.Size or UDim2.fromOffset(580, 390)
    local initW = math.min(req.X.Offset, vp.X - 24)
    local initH = math.min(req.Y.Offset, vp.Y - 24)
    local minW = math.min(opts.MinWidth or 440, initW)
    local minH = math.min(opts.MinHeight or 300, initH)
    local maxW, maxH = opts.MaxWidth or 1400, opts.MaxHeight or 900

    local function Limits()
        local v = RootGui.AbsoluteSize
        return math.max(minW, math.min(maxW, v.X - 16)), math.max(minH, math.min(maxH, v.Y - 16))
    end

    local maximized = false
    local restoreSize, restorePos

    local Main = New("Frame", {
        Name = "CrystalWindWindow",
        Size = UDim2.fromOffset(initW - 40, initH - 40),
        Position = UDim2.new(0.5, -(initW - 40) / 2, 0.5, -(initH - 40) / 2),
        BackgroundColor3 = Theme.Bg,
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, RootGui)
    Corner(Main, 12)
    local mainStroke = Stroke(Main, Theme.Pink, 1.2)
    mainStroke.Transparency = 1
    AccentGradient(mainStroke, 35)

    Tween(Main, {Size = UDim2.fromOffset(initW, initH), Position = UDim2.new(0.5, -initW / 2, 0.5, -initH / 2), BackgroundTransparency = 0}, 0.3)
    Tween(mainStroke, {Transparency = 0}, 0.25)

    -- Topbar
    local Topbar = New("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0}, Main)
    MakeDraggable(Topbar, Main, function() return not maximized end)
    New("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.4, BorderSizePixel = 0}, Topbar)

    local Gem = New("Frame", {Size = UDim2.fromOffset(13, 13), Position = UDim2.new(0, 16, 0.5, -6), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1)}, Topbar)
    Corner(Gem, 3)
    AccentGradient(Gem, 45)

    local TitleLbl = Txt({Size = UDim2.new(1, -210, 0, 18), Position = UDim2.fromOffset(38, 6), Text = opts.Title or "Crystal UI", Font = Enum.Font.GothamBold, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd}, Topbar)
    local SubLbl = Txt({Size = UDim2.new(1, -210, 0, 14), Position = UDim2.fromOffset(38, 24), Text = opts.SubTitle or "Wind Style • Purple & Pink", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.Muted, TextTruncate = Enum.TextTruncate.AtEnd}, Topbar)

    local Controls = New("Frame", {Size = UDim2.new(0, 150, 1, 0), Position = UDim2.new(1, -158, 0, 0), BackgroundTransparency = 1}, Topbar)
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }, Controls)

    if opts.Tag then
        local TagFrame = New("Frame", {Size = UDim2.fromOffset(50, 22), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 1}, Controls)
        Corner(TagFrame, 6)
        AccentGradient(TagFrame, 0)
        Txt({Size = UDim2.fromScale(1, 1), Text = tostring(opts.Tag), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center}, TagFrame)
    end

    local function CtrlButton(text, size, order)
        local b = New("TextButton", {
            Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Theme.Card, Text = text,
            Font = Enum.Font.GothamBold, TextSize = size, TextColor3 = Theme.Muted, AutoButtonColor = false, LayoutOrder = order,
        }, Controls)
        Corner(b, 6)
        return b
    end
    local MaxBtn = CtrlButton("□", 13, 2)
    local CloseBtn = CtrlButton("×", 16, 3)

    MaxBtn.MouseEnter:Connect(function() Tween(MaxBtn, {BackgroundColor3 = Theme.Purple, TextColor3 = Color3.new(1, 1, 1)}, 0.14) end)
    MaxBtn.MouseLeave:Connect(function() Tween(MaxBtn, {BackgroundColor3 = Theme.Card, TextColor3 = Theme.Muted}, 0.14) end)
    CloseBtn.MouseEnter:Connect(function() Tween(CloseBtn, {BackgroundColor3 = Theme.Pink, TextColor3 = Color3.new(1, 1, 1)}, 0.14) end)
    CloseBtn.MouseLeave:Connect(function() Tween(CloseBtn, {BackgroundColor3 = Theme.Card, TextColor3 = Theme.Muted}, 0.14) end)

    -- ปุ่มลอยเปิด UI
    local OpenBubble = New("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0),
        Position = UDim2.new(0, 42, 0.5, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        Text = "✦", Font = Enum.Font.GothamBold, TextSize = 19, TextColor3 = Color3.new(1, 1, 1),
        Visible = false, AutoButtonColor = false,
    }, RootGui)
    Corner(OpenBubble, 12)
    AccentGradient(OpenBubble, 45)
    local bubbleMoved = MakeDraggable(OpenBubble, OpenBubble)

    local hidden, busy = false, false

    function Win:Hide()
        if hidden or busy then return end
        hidden, busy = true, true
        Tween(Main, {BackgroundTransparency = 1}, 0.18)
        task.delay(0.18, function()
            Main.Visible = false
            OpenBubble.Visible = true
            Tween(OpenBubble, {Size = UDim2.fromOffset(44, 44)}, 0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            busy = false
        end)
    end

    function Win:Show()
        if not hidden or busy then return end
        hidden, busy = false, true
        Tween(OpenBubble, {Size = UDim2.fromOffset(0, 0)}, 0.16)
        task.delay(0.16, function()
            OpenBubble.Visible = false
            Main.Visible = true
            Tween(Main, {BackgroundTransparency = 0}, 0.24)
            busy = false
        end)
    end

    function Win:Toggle()
        if hidden then Win:Show() else Win:Hide() end
    end

    function Win:Destroy()
        Main:Destroy()
        OpenBubble:Destroy()
    end

    function Win:SetTitle(t) TitleLbl.Text = tostring(t) end
    function Win:SetSubTitle(t) SubLbl.Text = tostring(t) end
    function Win:Notify(o) CrystalUI:Notify(o) end

    CloseBtn.MouseButton1Click:Connect(function() Win:Hide() end)
    OpenBubble.MouseButton1Click:Connect(function()
        if bubbleMoved() then return end -- ลากอยู่ ไม่ใช่การกด
        Win:Show()
    end)

    -- ปุ่มลัดเปิด/ปิด UI (ตั้ง ToggleKey = false เพื่อปิดฟีเจอร์นี้)
    local toggleKey = opts.ToggleKey
    if toggleKey == nil then toggleKey = Enum.KeyCode.RightShift end
    if toggleKey then
        Connect(UserInputService.InputBegan, function(input, gpe)
            if gpe or Listening > 0 then return end
            if input.KeyCode == toggleKey then Win:Toggle() end
        end)
    end

    -- Resize grip
    local ResizeGrip = New("TextButton", {
        Name = "ResizeGrip", Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -20, 1, -20),
        BackgroundTransparency = 1, Text = "◢", Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 20,
    }, Main)
    Accent(ResizeGrip, "TextColor3", "Pink")

    local resizing = false
    local resizeStart, startSize
    ResizeGrip.InputBegan:Connect(function(input)
        if IsPress(input) and not maximized then
            resizing = true
            resizeStart = input.Position
            startSize = Main.AbsoluteSize
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
        if IsPress(input) then resizing = false end
    end)

    MaxBtn.MouseButton1Click:Connect(function()
        maximized = not maximized
        ResizeGrip.Visible = not maximized
        if maximized then
            restoreSize, restorePos = Main.Size, Main.Position
            MaxBtn.Text = "❐"
            Tween(Main, {Size = UDim2.new(1, -32, 1, -32), Position = UDim2.fromOffset(16, 16)}, 0.26)
        else
            MaxBtn.Text = "□"
            Tween(Main, {Size = restoreSize, Position = restorePos}, 0.26)
        end
    end)

    function Win:SetSize(w, h)
        if maximized then return end
        local mw, mh = Limits()
        local nw, nh = math.clamp(w, minW, mw), math.clamp(h, minH, mh)
        Tween(Main, {Size = UDim2.fromOffset(nw, nh), Position = UDim2.new(0.5, -nw / 2, 0.5, -nh / 2)}, 0.26)
    end

    -- Sidebar
    local SidebarWidth = opts.SidebarWidth or 148
    local Sidebar = New("ScrollingFrame", {
        Size = UDim2.new(0, SidebarWidth, 1, -44), Position = UDim2.fromOffset(0, 44),
        BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0, ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
    }, Main)
    New("Frame", {Size = UDim2.new(0, 1, 1, -44), Position = UDim2.fromOffset(SidebarWidth, 44), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.4, BorderSizePixel = 0}, Main)
    New("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center}, Sidebar)
    New("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, Sidebar)

    local Container = New("Frame", {
        Size = UDim2.new(1, -(SidebarWidth + 1), 1, -44), Position = UDim2.fromOffset(SidebarWidth + 1, 44),
        BackgroundTransparency = 1, ClipsDescendants = true,
    }, Main)

    ------------------------------------------------------------------
    -- Tabs
    ------------------------------------------------------------------
    function Win:CreateTab(name, icon)
        local TabBtn = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Theme.Card, BackgroundTransparency = 1,
            Text = (icon and (icon .. "  ") or "") .. name, Font = Enum.Font.GothamSemibold, TextSize = 12,
            TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
            LayoutOrder = #Tabs + 1,
        }, Sidebar)
        New("UIPadding", {PaddingLeft = UDim.new(0, 16)}, TabBtn)
        Corner(TabBtn, 7)

        local Marker = New("Frame", {Size = UDim2.fromOffset(3, 6), Position = UDim2.new(0, -10, 0.5, -3), BackgroundColor3 = Theme.Pink, BackgroundTransparency = 1}, TabBtn)
        Corner(Marker, 2)
        Accent(Marker, "BackgroundColor3", "Pink")

        local Page = New("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false,
        }, Container)
        Accent(Page, "ScrollBarImageColor3", "Purple")
        New("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center}, Page)
        New("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, Page)
        AutoOrder(Page)

        local entry = {Btn = TabBtn, Marker = Marker, Page = Page, Selected = false}
        table.insert(Tabs, entry)

        local Tab = {}

        local function Select()
            for _, t in ipairs(Tabs) do
                t.Selected = false
                t.Page.Visible = false
                Tween(t.Btn, {BackgroundTransparency = 1, TextColor3 = Theme.Muted}, 0.16)
                Tween(t.Marker, {BackgroundTransparency = 1, Size = UDim2.fromOffset(3, 6), Position = UDim2.new(0, -10, 0.5, -3)}, 0.16)
            end
            entry.Selected = true
            Page.Position = UDim2.fromOffset(12, 0)
            Page.Visible = true
            Tween(Page, {Position = UDim2.new()}, 0.2)
            Tween(TabBtn, {BackgroundTransparency = 0, TextColor3 = Theme.Text}, 0.16)
            Tween(Marker, {BackgroundTransparency = 0, Size = UDim2.fromOffset(3, 18), Position = UDim2.new(0, -10, 0.5, -9)}, 0.2)
        end
        function Tab:Select() Select() end

        TabBtn.MouseButton1Click:Connect(Select)
        TabBtn.MouseEnter:Connect(function() if not entry.Selected then Tween(TabBtn, {BackgroundTransparency = 0.6}, 0.12) end end)
        TabBtn.MouseLeave:Connect(function() if not entry.Selected then Tween(TabBtn, {BackgroundTransparency = 1}, 0.12) end end)
        if #Tabs == 1 then Select() end

        --------------------------------------------------------------
        -- Element helpers
        --------------------------------------------------------------
        local function Card(h, isButton)
            local props = {Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = Theme.Card, BorderSizePixel = 0}
            local f
            if isButton then
                props.Text = ""
                props.AutoButtonColor = false
                f = New("TextButton", props, Page)
            else
                f = New("Frame", props, Page)
            end
            Corner(f, 8)
            return f, Stroke(f, Theme.Stroke, 1)
        end

        local function Hover(frame, st, color)
            frame.MouseEnter:Connect(function()
                Tween(frame, {BackgroundColor3 = Theme.CardHover}, 0.14)
                Tween(st, {Color = Theme[color or "Purple"]}, 0.14)
            end)
            frame.MouseLeave:Connect(function()
                Tween(frame, {BackgroundColor3 = Theme.Card}, 0.14)
                Tween(st, {Color = Theme.Stroke}, 0.14)
            end)
        end

        local function Finish(frame, obj)
            obj.Frame = frame
            function obj:SetVisible(v) frame.Visible = v end
            function obj:Destroy() frame:Destroy() end
            return obj
        end

        --------------------------------------------------------------
        -- Elements
        --------------------------------------------------------------
        function Tab:CreateSection(text)
            local lbl = Txt({Size = UDim2.new(1, 0, 0, 20), Text = string.upper(text), Font = Enum.Font.GothamBold, TextSize = 11}, Page)
            Accent(lbl, "TextColor3", "Purple")
            return Finish(lbl, {SetText = function(_, t) lbl.Text = string.upper(t) end})
        end

        function Tab:CreateParagraph(o)
            o = o or {}
            local f = New("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Card, BorderSizePixel = 0}, Page)
            Corner(f, 8)
            Stroke(f, Theme.Stroke, 1)
            New("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, f)
            New("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, f)
            local title = Txt({Size = UDim2.new(1, 0, 0, 18), Text = o.Title or "", Font = Enum.Font.GothamBold, LayoutOrder = 1}, f)
            local body = Txt({
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = o.Content or "",
                Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.Muted, TextWrapped = true,
                TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2,
            }, f)
            return Finish(f, {
                SetTitle = function(_, t) title.Text = tostring(t) end,
                SetContent = function(_, t) body.Text = tostring(t) end,
            })
        end

        function Tab:CreateDivider()
            local line = New("Frame", {Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, Page)
            AccentGradient(line, 0)
            return Finish(line, {})
        end

        function Tab:CreateSpace(height)
            local sp = New("Frame", {Size = UDim2.new(1, 0, 0, height or 8), BackgroundTransparency = 1}, Page)
            return Finish(sp, {})
        end

        function Tab:CreateButton(o)
            o = o or {}
            local btn, st = Card(38, true)
            local lbl = Txt({Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(12, 0), Text = o.Name or "Button"}, btn)
            local arrow = Txt({Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -28, 0, 0), Text = "›", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Center}, btn)

            local hovering = false
            btn.MouseEnter:Connect(function()
                hovering = true
                Tween(btn, {BackgroundColor3 = Theme.CardHover}, 0.14)
                Tween(st, {Color = Theme.Pink}, 0.14)
                Tween(arrow, {TextColor3 = Theme.Pink}, 0.14)
            end)
            btn.MouseLeave:Connect(function()
                hovering = false
                Tween(btn, {BackgroundColor3 = Theme.Card}, 0.14)
                Tween(st, {Color = Theme.Stroke}, 0.14)
                Tween(arrow, {TextColor3 = Theme.Muted}, 0.14)
            end)
            btn.MouseButton1Down:Connect(function() Tween(btn, {BackgroundColor3 = Theme.Card:Lerp(Theme.Purple, 0.3)}, 0.08) end)
            btn.MouseButton1Up:Connect(function() Tween(btn, {BackgroundColor3 = hovering and Theme.CardHover or Theme.Card}, 0.12) end)
            btn.MouseButton1Click:Connect(function() Safe(o.Callback) end)

            return Finish(btn, {
                SetText = function(_, t) lbl.Text = tostring(t) end,
                Fire = function() Safe(o.Callback) end,
            })
        end

        function Tab:CreateToggle(o)
            o = o or {}
            local state = o.Default == true
            local row, st = Card(38, true)
            Txt({Size = UDim2.new(1, -68, 1, 0), Position = UDim2.fromOffset(12, 0), Text = o.Name or "Toggle"}, row)
            local bg = New("Frame", {Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -52, 0.5, -10), BackgroundColor3 = Theme.InputBg}, row)
            Corner(bg, 10)
            local knob = New("Frame", {Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1)}, bg)
            Corner(knob, 7)

            local function KnobPos() return state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7) end
            Themed(bg, function() bg.BackgroundColor3 = state and Theme.Pink or Theme.InputBg end)
            knob.Position = KnobPos()

            local obj = {}
            local function Set(v, fire)
                state = v and true or false
                SetFlag(o.Flag, state)
                Tween(bg, {BackgroundColor3 = state and Theme.Pink or Theme.InputBg}, 0.2)
                Tween(knob, {Position = KnobPos()}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                if fire ~= false then Safe(o.Callback, state) end
            end
            function obj:Set(v) Set(v, true) end
            function obj:Get() return state end

            SetFlag(o.Flag, state)
            Register(o.Flag, function(v) Set(v, true) end)
            Hover(row, st, "Purple")
            row.MouseButton1Click:Connect(function() Set(not state, true) end)
            return Finish(row, obj)
        end

        function Tab:CreateSlider(o)
            o = o or {}
            local minV, maxV = o.Min or 0, o.Max or 100
            if maxV <= minV then maxV = minV + 1 end
            local inc = o.Increment or 1
            local dec = tostring(inc):match("%.(%d+)")
            dec = dec and #dec or 0
            local suffix = o.Suffix or ""

            local function Snap(n)
                n = math.clamp(n, minV, maxV)
                n = minV + math.floor((n - minV) / inc + 0.5) * inc
                n = math.clamp(n, minV, maxV)
                return tonumber(string.format("%." .. dec .. "f", n))
            end
            local val = Snap(o.Default or minV)

            local frame, st = Card(52)
            Txt({Size = UDim2.new(0.7, -12, 0, 22), Position = UDim2.fromOffset(12, 5), Text = o.Name or "Slider"}, frame)
            local valLbl = Txt({Size = UDim2.new(0.3, -12, 0, 22), Position = UDim2.new(0.7, 0, 0, 5), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right}, frame)
            Accent(valLbl, "TextColor3", "Pink")

            local barBg = New("Frame", {Size = UDim2.new(1, -24, 0, 6), Position = UDim2.fromOffset(12, 36), BackgroundColor3 = Theme.InputBg}, frame)
            Corner(barBg, 3)
            local barFill = New("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1)}, barBg)
            Corner(barFill, 3)
            AccentGradient(barFill, 0)
            local knob = New("Frame", {Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2}, barBg)
            Corner(knob, 6)

            local function Visual(animate)
                local ratio = (val - minV) / (maxV - minV)
                valLbl.Text = string.format("%." .. dec .. "f", val) .. suffix
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

            -- hitbox ใหญ่ขึ้นสำหรับนิ้วมือ
            local hit = New("TextButton", {Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 26), BackgroundTransparency = 1, Text = ""}, frame)
            local dragging = false
            local function Update(input)
                local p = PointerPos(input)
                local pct = math.clamp((p.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
                local newVal = Snap(minV + (maxV - minV) * pct)
                if newVal ~= val then Set(newVal, true) end
            end
            hit.InputBegan:Connect(function(input)
                if IsPress(input) then
                    dragging = true
                    Page.ScrollingEnabled = false
                    Tween(st, {Color = Theme.Pink}, 0.12)
                    Update(input)
                end
            end)
            Connect(UserInputService.InputEnded, function(input)
                if IsPress(input) and dragging then
                    dragging = false
                    Page.ScrollingEnabled = true
                    Tween(st, {Color = Theme.Stroke}, 0.14)
                end
            end)
            Connect(UserInputService.InputChanged, function(input)
                if dragging and IsMove(input) then Update(input) end
            end)
            return Finish(frame, obj)
        end

        function Tab:CreateInput(o)
            o = o or {}
            local frame, fStroke = Card(40)
            Txt({Size = UDim2.new(0.45, -12, 1, 0), Position = UDim2.fromOffset(12, 0), Text = o.Name or "Input"}, frame)
            local box = New("TextBox", {
                Size = UDim2.new(0.55, -12, 0, 26), Position = UDim2.new(0.45, 0, 0.5, -13), BackgroundColor3 = Theme.InputBg,
                Text = tostring(o.Default or ""), PlaceholderText = o.Placeholder or "Type here...", Font = Enum.Font.Gotham,
                TextSize = 12, TextColor3 = Theme.Text, PlaceholderColor3 = Theme.Muted, ClearTextOnFocus = false,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, frame)
            Corner(box, 6)
            local bStroke = Stroke(box, Theme.Purple, 1)
            SetFlag(o.Flag, box.Text)

            local obj = {}
            function obj:Get() return box.Text end
            function obj:Set(v, fire)
                box.Text = tostring(v)
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
                if o.RealTime then Safe(o.Callback, box.Text, false) end
            end)
            box.Focused:Connect(function() Tween(bStroke, {Color = Theme.Pink}, 0.16) Tween(fStroke, {Color = Theme.Purple}, 0.16) end)
            box.FocusLost:Connect(function(enterPressed)
                Tween(bStroke, {Color = Theme.Purple}, 0.16)
                Tween(fStroke, {Color = Theme.Stroke}, 0.16)
                if not o.RealTime then Safe(o.Callback, box.Text, enterPressed) end
            end)
            return Finish(frame, obj)
        end

        function Tab:CreateDropdown(o)
            o = o or {}
            local options = o.Options or {}
            local multi = o.Multi == true
            local chosen = {}
            local open = false
            local MAXLIST = 150

            local wrap, st = Card(40)
            wrap.ClipsDescendants = true
            local header = New("TextButton", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = "", AutoButtonColor = false}, wrap)
            Txt({Size = UDim2.new(0.5, -12, 1, 0), Position = UDim2.fromOffset(12, 0), Text = o.Name or "Dropdown"}, header)
            local cur = Txt({
                Size = UDim2.new(0.5, -24, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), Font = Enum.Font.GothamBold, TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
            }, header)
            Accent(cur, "TextColor3", "Pink")

            local list = New("ScrollingFrame", {
                Position = UDim2.fromOffset(8, 44), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
                AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
            }, wrap)
            Accent(list, "ScrollBarImageColor3", "Purple")
            New("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, list)
            AutoOrder(list)

            local buttons = {}
            local obj = {}

            local function Value()
                if multi then
                    local r = {}
                    for _, opt in ipairs(options) do if chosen[opt] then r[#r + 1] = opt end end
                    return r
                end
                for _, opt in ipairs(options) do if chosen[opt] then return opt end end
                return nil
            end

            local function Visuals()
                local names = {}
                for _, opt in ipairs(options) do
                    local on = chosen[opt] == true
                    if on then names[#names + 1] = tostring(opt) end
                    local b = buttons[opt]
                    if b then
                        b.BackgroundColor3 = on and Theme.CardHover or Theme.InputBg
                        b.TextColor3 = on and Theme.Pink or Theme.Text
                    end
                end
                local txt = #names == 0 and "Select" or (multi and (#names > 2 and (#names .. " selected") or table.concat(names, ", ")) or names[1])
                cur.Text = txt .. " ▾"
            end

            local function Layout()
                local lh = math.min(#options * 30, MAXLIST)
                list.Size = UDim2.new(1, -16, 0, lh)
                Tween(wrap, {Size = UDim2.new(1, 0, 0, open and (52 + lh) or 40)}, 0.22)
                Tween(st, {Color = open and Theme.Pink or Theme.Stroke}, 0.18)
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
                    Corner(b, 6)
                    buttons[item] = b
                    b.MouseEnter:Connect(function() Tween(b, {BackgroundColor3 = Theme.Purple}, 0.12) end)
                    b.MouseLeave:Connect(function() Tween(b, {BackgroundColor3 = chosen[item] and Theme.CardHover or Theme.InputBg}, 0.12) end)
                    b.MouseButton1Click:Connect(function() Pick(item) end)
                end
                Visuals()
                if open then Layout() end
            end

            if multi then
                if type(o.Default) == "table" then for _, v in ipairs(o.Default) do chosen[v] = true end end
            else
                local d = o.Default or options[1]
                if d ~= nil then chosen[d] = true end
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

        function Tab:CreateKeybind(o)
            o = o or {}
            local key = o.Default or Enum.KeyCode.F
            local listening = false

            local frame, st = Card(38)
            Txt({Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(12, 0), Text = o.Name or "Keybind"}, frame)
            local bindBtn = New("TextButton", {
                Size = UDim2.fromOffset(86, 26), Position = UDim2.new(1, -98, 0.5, -13), BackgroundColor3 = Theme.InputBg,
                Text = key.Name, Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false,
            }, frame)
            Accent(bindBtn, "TextColor3", "Pink")
            Corner(bindBtn, 6)
            Stroke(bindBtn, Theme.Purple, 1)
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
                Tween(bindBtn, {BackgroundColor3 = Theme.InputBg, TextColor3 = Theme.Pink}, 0.16)
            end

            bindBtn.MouseButton1Click:Connect(function()
                if listening then return end
                listening = true
                Listening += 1
                bindBtn.Text = "..."
                Tween(bindBtn, {BackgroundColor3 = Theme.Purple, TextColor3 = Color3.new(1, 1, 1)}, 0.15)
            end)

            Connect(UserInputService.InputBegan, function(input, gpe)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    if input.KeyCode == Enum.KeyCode.Escape then
                        bindBtn.Text = key.Name -- ยกเลิกการตั้งปุ่ม
                    else
                        SetKey(input.KeyCode, true)
                    end
                    -- ปล่อยสถานะ listening หลังเฟรมนี้ เพื่อไม่ให้ปุ่มที่เพิ่งตั้งไปทริกเกอร์ callback
                    task.defer(StopListening)
                elseif not listening and not gpe and input.KeyCode == key then
                    Tween(st, {Color = Theme.Pink}, 0.1)
                    task.delay(0.12, function() Tween(st, {Color = Theme.Stroke}, 0.18) end)
                    Safe(o.Callback, key)
                end
            end)
            return Finish(frame, obj)
        end

        function Tab:CreateColorpicker(o)
            o = o or {}
            local presets = {
                Color3.fromRGB(168, 85, 247), Color3.fromRGB(236, 72, 153), Color3.fromRGB(244, 114, 182),
                Color3.fromRGB(139, 92, 246), Color3.fromRGB(219, 39, 119), Color3.fromRGB(255, 255, 255),
            }
            local color = o.Default or Theme.Purple
            local h, s, v = color:ToHSV()
            local open = false

            local wrap, st = Card(40)
            wrap.ClipsDescendants = true
            local header = New("TextButton", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = "", AutoButtonColor = false}, wrap)
            Txt({Size = UDim2.new(0.6, -12, 1, 0), Position = UDim2.fromOffset(12, 0), Text = o.Name or "Color"}, header)
            local swatch = New("Frame", {Size = UDim2.fromOffset(34, 18), Position = UDim2.new(1, -46, 0.5, -9), BackgroundColor3 = color}, header)
            Corner(swatch, 5)
            Stroke(swatch, Theme.Text, 1, 0.5)

            -- กล่อง Saturation/Value
            local svBox = New("Frame", {Size = UDim2.new(1, -24, 0, 110), Position = UDim2.fromOffset(12, 50), BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0}, wrap)
            Corner(svBox, 6)
            local white = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, svBox)
            Corner(white, 6)
            New("UIGradient", {Transparency = NumberSequence.new(0, 1)}, white)
            local black = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0}, svBox)
            Corner(black, 6)
            New("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0)}, black)
            local svCursor = New("Frame", {Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 3}, svBox)
            Corner(svCursor, 6)
            Stroke(svCursor, Color3.new(1, 1, 1), 2)

            -- แถบ Hue
            local hueBar = New("Frame", {Size = UDim2.new(1, -24, 0, 14), Position = UDim2.fromOffset(12, 170), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, wrap)
            Corner(hueBar, 7)
            local keys = {}
            for i = 0, 6 do keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i == 6 and 0 or i / 6, 1, 1)) end
            New("UIGradient", {Color = ColorSequence.new(keys)}, hueBar)
            local hueCursor = New("Frame", {Size = UDim2.fromOffset(4, 20), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3}, hueBar)
            Corner(hueCursor, 2)
            Stroke(hueCursor, Color3.new(0, 0, 0), 1, 0.4)

            -- Presets
            local presetRow = New("Frame", {Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 194), BackgroundTransparency = 1}, wrap)
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
                Corner(sw, 9)
                Stroke(sw, Theme.Text, 1)
                sw.MouseEnter:Connect(function() Tween(sw, {Size = UDim2.fromOffset(22, 22)}, 0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out) end)
                sw.MouseLeave:Connect(function() Tween(sw, {Size = UDim2.fromOffset(18, 18)}, 0.14) end)
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
            local function Begin(which, input)
                if IsPress(input) then
                    active = which
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
                    Page.ScrollingEnabled = true
                end
            end)

            header.MouseButton1Click:Connect(function()
                open = not open
                Tween(wrap, {Size = UDim2.new(1, 0, 0, open and 226 or 40)}, 0.22)
                Tween(st, {Color = open and Theme.Pink or Theme.Stroke}, 0.18)
            end)
            return Finish(wrap, obj)
        end

        function Tab:CreateProgressBar(o)
            o = o or {}
            local pct = math.clamp(o.Default or 0, 0, 100)

            local frame = Card(48)
            Txt({Size = UDim2.new(0.7, -12, 0, 20), Position = UDim2.fromOffset(12, 4), Text = o.Name or "Progress", TextSize = 12}, frame)
            local pLbl = Txt({Size = UDim2.new(0.3, -12, 0, 20), Position = UDim2.new(0.7, 0, 0, 4), Text = math.floor(pct + 0.5) .. "%", Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right}, frame)
            Accent(pLbl, "TextColor3", "Pink")

            local bg = New("Frame", {Size = UDim2.new(1, -24, 0, 8), Position = UDim2.fromOffset(12, 30), BackgroundColor3 = Theme.InputBg}, frame)
            Corner(bg, 4)
            local fill = New("Frame", {Size = UDim2.new(pct / 100, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1)}, bg)
            Corner(fill, 4)
            AccentGradient(fill, 0)

            -- แก้บั๊ก: เดิม NumberValue ไม่มี Parent ทำให้ Tween() ข้ามไปเสมอ ตัวเลข % เลยไม่เคยวิ่ง
            local numVal = New("NumberValue", {Value = pct}, frame)
            numVal.Changed:Connect(function(x) pLbl.Text = math.floor(x + 0.5) .. "%" end)

            local obj = {}
            function obj:Set(newVal)
                pct = math.clamp(newVal, 0, 100)
                SetFlag(o.Flag, pct)
                Tween(fill, {Size = UDim2.new(pct / 100, 0, 1, 0)}, 0.3)
                Tween(numVal, {Value = pct}, 0.3)
            end
            function obj:Get() return pct end
            return Finish(frame, obj)
        end

        return Tab
    end

    --==================================================================
    -- Config system (บันทึกลงไฟล์จริงถ้า executor รองรับ, ไม่งั้นเก็บในหน่วยความจำ)
    --==================================================================
    local folderName = tostring(opts.ConfigFolder or opts.Title or "Default"):gsub("[^%w_%- ]", "")
    local ConfigDir = "CrystalUI/" .. folderName

    local function CleanName(n)
        n = tostring(n or ""):gsub("[^%w_%- ]", "")
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

    function Win:AddConfigsTab(name)
        local tab = Win:CreateTab(name or "Configs", "⚙")
        tab:CreateSection("Config Manager")
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

        tab:CreateButton({Name = "Save Config", Callback = function()
            local ok, err = Win:SaveConfig(nameInput:Get())
            Refresh()
            CrystalUI:Notify({Title = ok and "Config Saved" or "Save Failed", Content = ok and ("Saved '" .. nameInput:Get() .. "'") or tostring(err), Type = ok and "success" or "error", Duration = 2.5})
        end})
        tab:CreateButton({Name = "Load Config", Callback = function()
            local ok, err = Win:LoadConfig(nameInput:Get())
            CrystalUI:Notify({Title = ok and "Config Loaded" or "Load Failed", Content = ok and "Applied saved settings." or tostring(err), Type = ok and "success" or "error", Duration = 2.5})
        end})
        tab:CreateButton({Name = "Delete Config", Callback = function()
            CrystalUI:Dialog({
                Title = "Delete config?",
                Content = "ต้องการลบ '" .. tostring(nameInput:Get()) .. "' ใช่หรือไม่",
                ConfirmText = "Delete",
                OnConfirm = function()
                    Win:DeleteConfig(nameInput:Get())
                    Refresh()
                    CrystalUI:Notify({Title = "Deleted", Content = "Config removed.", Type = "warning", Duration = 2.5})
                end,
            })
        end})
        tab:CreateButton({Name = "Refresh List", Callback = Refresh})
        return tab
    end

    function Win:AddThemesTab(name)
        local tab = Win:CreateTab(name or "Themes", "✦")
        tab:CreateSection("Purple & Pink Palettes")
        local palettes = {
            {Name = "Neon Purple & Pink", P = Color3.fromRGB(168, 85, 247), K = Color3.fromRGB(236, 72, 153)},
            {Name = "Pastel Sakura & Lavender", P = Color3.fromRGB(192, 132, 252), K = Color3.fromRGB(244, 114, 182)},
            {Name = "Deep Amethyst & Rose", P = Color3.fromRGB(126, 34, 206), K = Color3.fromRGB(219, 39, 119)},
        }
        for _, pal in ipairs(palettes) do
            tab:CreateButton({Name = pal.Name, Callback = function()
                CrystalUI:SetTheme({Purple = pal.P, Pink = pal.K})
                CrystalUI:Notify({Title = "Theme Updated", Content = "Applied " .. pal.Name, Duration = 2.5})
            end})
        end
        tab:CreateSection("Custom")
        tab:CreateColorpicker({Name = "Primary", Default = Theme.Purple, Callback = function(c) CrystalUI:SetTheme({Purple = c}) end})
        tab:CreateColorpicker({Name = "Secondary", Default = Theme.Pink, Callback = function(c) CrystalUI:SetTheme({Pink = c}) end})
        return tab
    end

    return Win
end

return CrystalUI
