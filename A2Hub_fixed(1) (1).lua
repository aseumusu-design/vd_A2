--[[
================================================================================
   █████╗ ██████╗     ██╗  ██╗██╗   ██╗██████╗
  ██╔══██╗╚════██╗    ██║  ██║██║   ██║██╔══██╗
  ███████║ █████╔╝    ███████║██║   ██║██████╔╝
  ██╔══██║ ╚═══██╗    ██╔══██║██║   ██║██╔══██╗
  ██║  ██║██████╔╝    ██║  ██║╚██████╔╝██████╔╝
  ╚═╝  ╚═╝╚═════╝     ╚═╝  ╚═╝ ╚═════╝ ╚═════╝

   A2 HUB  •  Violence District Auto Farm
   UI   : A2 UI (custom, self-contained — dibuat sendiri, gak butuh WindUI)
   Base : DAMEUNGRR HUB logic (pastefy.app/jFeHlGlN/raw) — dibangun ulang & dirapikan

   Fitur:
     • Auto Farm (teleport server + finish line otomatis)
     • Monitoring Discord Webhook (Screws / EXP / Level / Secret)
     • Deteksi otomatis item/secret baru
     • Config tersimpan (auto-save)
     • Key system opsional (bisa dimatikan)
     • Auto Re-execute & Rejoin (script jalan lagi otomatis pas pindah server / rejoin)

   CARA PAKAI:
     1. Jalankan script ini di executor (Delta/Mobile/PC).
     2. Buka tab "Webhook", tempel URL webhook Discord, klik "CONNECT".
     3. (Opsional) Di section "Auto Re-execute & Rejoin", tempel URL RAW A2Hub.lua
        biar script otomatis dijalankan ulang pas pindah server / rejoin.
     4. Kalau sudah "TERHUBUNG", aktifkan Toggle "Auto Farm".
     5. Bot akan farm sendiri & lapor hasilnya ke Discord.
================================================================================
]]

-- ============================================================================
--  SERVICES & VARIABEL DASAR
-- ============================================================================
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local TweenService     = game:GetService("TweenService")
local TeleportService  = game:GetService("TeleportService")
local RunService       = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")   -- [BARU] buat RepairEvent / PlayerActionEvent
local UserInputService  = game:GetService("UserInputService")    -- [BARU] buat tombol floating FARM

local LocalPlayer = Players.LocalPlayer

local function colorFromHex(value)
    value = tostring(value or "000000"):gsub("#", "")
    local ok, color = pcall(function() return Color3.fromHex(value) end)
    if ok and color then return color end
    local r = (tonumber(value:sub(1, 2), 16) or 0) / 255
    local g = (tonumber(value:sub(3, 4), 16) or 0) / 255
    local b = (tonumber(value:sub(5, 6), 16) or 0) / 255
    return Color3.new(r, g, b)
end

-- Nama file config di executor
local CONFIG_FILE = "A2Hub_config.json"

-- ============================================================================
--  A2 UI  —  Custom UI (self-contained, TANPA WindUI)
--  UI ini dibuat sendiri. Bisa dipakai 2 cara:
--    1) INLINE (default) — kode UI udah nempel di bawah, gak butuh internet.
--    2) REMOTE — isi A2_UI_URL pakai RAW GitHub URL A2_UI.lua, nanti di-load dari situ.
--  Nama UI: "A2"
-- ============================================================================
--  ↓↓↓ RAW URL GitHub UI A2 kamu (di-load dari sini kalau ada internet) ↓↓↓
local A2_UI_URL = "https://raw.githubusercontent.com/aseumusu-design/UI-library-A2/refs/heads/main/A2_UI.lua"
-- Remote dipakai bila file GitHub sudah versi terbaru. Jika masih versi lama,
-- loader otomatis menolak remote tersebut dan memakai UI inline.
local USE_REMOTE_A2_UI = true
-- A2Hub bikin window-nya sendiri -> matiin auto-mount bawaan library UI
-- biar gak muncul window dobel.
pcall(function() if type(getgenv) == "function" then getgenv().A2UI_NO_AUTOMOUNT = true end end)
local WindUI
do
    local function __loadA2UI()
-- ============================================================================
--  A2 UI  —  Custom UI Library (self-contained, TANPA WindUI)
--  Dibuat sendiri buat A2 HUB. API-compatible dengan pemakaian di script.
--  Nama UI: "A2"
-- ============================================================================
local A2UI = {}
A2UI.__index = A2UI

local CoreGui        = game:GetService("CoreGui")
local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local function guiParent()
    -- gethui adalah parent paling stabil pada executor; PlayerGui adalah
    -- fallback resmi untuk LocalScript. CoreGui dicoba terakhir karena pada
    -- client biasa assignment ke CoreGui dapat ditolak oleh Roblox.
    local p
    pcall(function()
        if type(gethui) == "function" then p = gethui() end
    end)
    if p then return p end

    pcall(function()
        local player = Players.LocalPlayer
        if player then p = player:WaitForChild("PlayerGui", 10) end
    end)
    if p then return p end

    pcall(function() p = CoreGui end)
    return p
end

-- ---------------------------------------------------------------- THEME ----
-- hex() aman: kalau Color3.fromHex gak ada di client, fallback manual.
local function hex(s)
    local ok, c = pcall(function() return Color3.fromHex(s) end)
    if ok and c then return c end
    local r = (tonumber(s:sub(1, 2), 16) or 0) / 255
    local g = (tonumber(s:sub(3, 4), 16) or 0) / 255
    local b = (tonumber(s:sub(5, 6), 16) or 0) / 255
    return Color3.new(r, g, b)
end

local C = {
    bg      = hex("0c0d12"),
    panel   = hex("13151e"),
    card    = hex("191c27"),
    card2   = hex("232736"),
    stroke  = hex("2a2e3f"),
    text    = hex("e9ebf5"),
    dim     = hex("8b90a8"),
    accent  = hex("30ff6a"),
    accent2 = hex("00c2ff"),
    good    = hex("10c550"),
    bad     = hex("ef4f1d"),
    warn    = hex("eca201"),
    purple  = hex("7775f2"),
    blue    = hex("257af7"),
    grey    = hex("83889e"),
}
A2UI.Theme = C

-- ------------------------------------------------------------- HELPERS ----
local function mk(class, props)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then o[k] = v end
    end
    if props and props.Parent then o.Parent = props.Parent end
    return o
end

local function corner(parent, r)
    return mk("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = parent })
end

local function stroke(parent, color, thick, trans)
    return mk("UIStroke", { Color = color or C.stroke, Thickness = thick or 1, Transparency = trans or 0.5, Parent = parent })
end

local function pad(parent, t, r, b, l)
    return mk("UIPadding", {
        PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0), PaddingLeft = UDim.new(0, l or 0), Parent = parent,
    })
end

local function vlist(parent, gap, align)
    return mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, gap or 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = align or Enum.HorizontalAlignment.Left, Parent = parent,
    })
end

local function hlist(parent, gap, valign)
    return mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, gap or 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = valign or Enum.VerticalAlignment.Center, Parent = parent,
    })
end

-- Global drag manager (biar gak bikin koneksi numpuk)
local activeDrag = nil
UserInputService.InputChanged:Connect(function(input)
    if activeDrag and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - activeDrag.start
        activeDrag.frame.Position = UDim2.new(
            activeDrag.pos.X.Scale, activeDrag.pos.X.Offset + d.X,
            activeDrag.pos.Y.Scale, activeDrag.pos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        activeDrag = nil
    end
end)

local function draggable(frame, handle)
    handle = handle or frame
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            activeDrag = { frame = frame, start = input.Position, pos = frame.Position }
        end
    end)
end

-- --------------------------------------------------------- NOTIFICATION ----
local notifHolder
function A2UI:Notify(opts)
    opts = opts or {}
    local parent = guiParent()
    if not notifHolder or not notifHolder.Parent then
        notifHolder = mk("Frame", {
            Name = "A2Notifs", Size = UDim2.new(0, 300, 1, -20),
            Position = UDim2.new(1, -312, 0, 10), BackgroundTransparency = 1,
            ZIndex = 5000, Parent = parent,
        })
        vlist(notifHolder, 8, Enum.HorizontalAlignment.Right)
    end

    local card = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card, BackgroundTransparency = 0, BorderSizePixel = 0,
        LayoutOrder = -os.clock(), ZIndex = 5001, Parent = notifHolder,
    })
    corner(card, 10)
    stroke(card, C.stroke, 1, 0.3)
    pad(card, 10, 12, 10, 12)

    local accent = mk("Frame", {
        Size = UDim2.new(0, 3, 1, -16), Position = UDim2.new(0, 0, 0, 8),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Parent = card,
    })
    corner(accent, 2)

    local holder = mk("Frame", {
        Size = UDim2.new(1, -14, 0, 0), Position = UDim2.new(0, 12, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = card,
    })
    vlist(holder, 2)

    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
        Text = opts.Title or "A2", Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Parent = holder,
    })
    if opts.Content then
        mk("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, Text = opts.Content, Font = Enum.Font.Gotham,
            TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true, Parent = holder,
        })
    end

    -- slide-in animation
    card.Position = UDim2.new(1, 40, 0, 0)
    TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { Position = UDim2.new(0, 0, 0, 0) }):Play()

    task.delay(tonumber(opts.Duration) or 4, function()
        if card and card.Parent then
            local out = TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
            out:Play()
            for _, d in ipairs(card:GetDescendants()) do
                if d:IsA("TextLabel") then
                    TweenService:Create(d, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
                elseif d:IsA("Frame") then
                    TweenService:Create(d, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
                end
            end
            task.wait(0.3)
            pcall(function() card:Destroy() end)
        end
    end)
end

-- --------------------------------------------------------------- WINDOW ----
function A2UI:CreateWindow(opts)
    opts = opts or {}
    local self = setmetatable({}, A2UI)
    self.Tabs = {}
    self._tabCount = 0
    self._visible = true

    local parent = guiParent()
    if not parent then
        error("[A2 UI] Tidak menemukan parent GUI yang valid (PlayerGui/gethui/CoreGui)")
    end

    -- Hapus instance lama agar script yang di-execute ulang tidak membuat
    -- window tertutup/tertumpuk di bawah window sebelumnya.
    pcall(function()
        local old = parent:FindFirstChild("A2UI")
        if old then old:Destroy() end
    end)

    local gui = mk("ScreenGui", {
        Name = "A2UI", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 9999, Enabled = true,
    })
    -- Attach ke parent yang valid + verifikasi benar-benar ke-parent.
    pcall(function() gui.Parent = parent end)
    if not gui.Parent then
        pcall(function()
            gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
        end)
    end
    if not gui.Parent then
        error("[A2 UI] ScreenGui gagal dipasang ke parent")
    end
    gui.Enabled = true
    self.Gui = gui
    pcall(function() print("[A2 UI] GUI terpasang di: " .. tostring(gui.Parent)) end)

    local main = mk("Frame", {
        Name = "A2Main", Size = UDim2.new(0, 640, 0, 440),
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = C.bg,
        BorderSizePixel = 0, Parent = gui,
    })
    corner(main, 14); stroke(main, C.stroke, 1, 0.25)
    self.Main = main

    local scale = mk("UIScale", { Parent = main })
    local function fit()
        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
        -- Ukuran default diperkecil agar tidak memenuhi layar, tetapi tetap
        -- menyesuaikan resolusi dan tidak keluar dari viewport.
        local s = 0.78 * math.min(1, (vp.X - 30) / 640, (vp.Y - 30) / 440)
        if s < 0.45 then s = 0.45 end
        scale.Scale = s
    end
    fit()
    pcall(function()
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
    end)

    -- topbar
    local top = mk("Frame", {
        Name = "Top", Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.panel,
        BorderSizePixel = 0, Parent = main,
    })
    corner(top, 14)
    mk("Frame", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
        BackgroundColor3 = C.panel, BorderSizePixel = 0, Parent = top })
    draggable(main, top)
    mk("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Parent = top })

    local logo = mk("Frame", { Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0, 12, 0.5, -15),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Parent = top })
    corner(logo, 8)
    mk("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "A2",
        Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = C.bg, Parent = logo })

    mk("TextLabel", { Size = UDim2.new(0, 320, 0, 20), Position = UDim2.new(0, 52, 0, 7),
        BackgroundTransparency = 1, Text = opts.Title or "A2", Font = Enum.Font.GothamBold,
        TextSize = 15, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
    mk("TextLabel", { Size = UDim2.new(0, 320, 0, 14), Position = UDim2.new(0, 52, 0, 26),
        BackgroundTransparency = 1, Text = opts.Author or "", Font = Enum.Font.Gotham,
        TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Parent = top })

    local function winBtn(x, txt, col, cb)
        local b = mk("TextButton", {
            Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, x, 0.5, -13),
            BackgroundColor3 = C.card2, BorderSizePixel = 0, Text = txt,
            Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = col or C.dim,
            AutoButtonColor = false, Parent = top,
        })
        corner(b, 8)
        b.MouseButton1Click:Connect(cb)
        return b
    end
    winBtn(-70, "-", C.dim, function() self:Minimize() end)
    winBtn(-38, "X", C.bad, function() self:Close() end)

    -- sidebar
    local side = mk("Frame", {
        Name = "Side", Size = UDim2.new(0, 152, 1, -46), Position = UDim2.new(0, 0, 0, 46),
        BackgroundColor3 = C.panel, BorderSizePixel = 0, Parent = main,
    })
    mk("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = C.stroke, BorderSizePixel = 0, Parent = side })
    local sideScroll = mk("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = C.stroke,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = side,
    })
    vlist(sideScroll, 4, Enum.HorizontalAlignment.Center)
    pad(sideScroll, 8, 8, 8, 8)
    self.SideScroll = sideScroll

    -- content
    local content = mk("Frame", {
        Name = "Content", Size = UDim2.new(1, -152, 1, -46), Position = UDim2.new(0, 152, 0, 46),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Parent = main,
    })
    self.Content = content

    -- floating open button
    if opts.OpenButton and opts.OpenButton.Enabled ~= false then
        local ob = mk("TextButton", {
            Name = "A2Open", Size = UDim2.new(0, 54, 0, 54),
            Position = UDim2.new(0, 20, 0.5, -27), BackgroundColor3 = C.accent,
            BorderSizePixel = 0, Text = "A2", Font = Enum.Font.GothamBlack,
            TextSize = 18, TextColor3 = C.bg, AutoButtonColor = false,
            Visible = false, Parent = gui,
        })
        corner(ob, 16); stroke(ob, C.accent2, 2, 0.2)
        draggable(ob)
        ob.MouseButton1Click:Connect(function() self:Open() end)
        self.OpenBtn = ob
    end

    self.Minimized = false
    return self
end

function A2UI:Open()
    self._visible = true
    if self.Main then self.Main.Visible = true end
    if self.OpenBtn then self.OpenBtn.Visible = false end
end

function A2UI:Close()
    self._visible = false
    if self.Main then self.Main.Visible = false end
    if self.OpenBtn then self.OpenBtn.Visible = true end
end

function A2UI:Minimize()
    self.Minimized = not self.Minimized
    if self.Minimized then
        self:Close()
    else
        self:Open()
    end
end

function A2UI:Tag(opts)
    -- Tag cuma badge kecil di topbar; kita tampilkan sebagai teks subtitle tambahan
    opts = opts or {}
    if opts.Title and self.Main then
        local top = self.Main:FindFirstChild("Top")
        if top then
            local badge = mk("TextLabel", {
                Size = UDim2.new(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X,
                Position = UDim2.new(1, -108, 0.5, -9), BackgroundColor3 = C.card2,
                BackgroundTransparency = 0, Text = "  " .. tostring(opts.Title) .. "  ",
                Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = C.dim, Parent = top,
            })
            corner(badge, 6)
        end
    end
end

-- ------------------------------------------------------------------ TAB ----
local Tab = {}
Tab.__index = Tab

function A2UI:Tab(opts)
    opts = opts or {}
    self._tabCount = self._tabCount + 1
    local idx = self._tabCount
    local tab = setmetatable({}, Tab)
    tab.Window = self
    tab._count = 0

    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.card2,
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
        AutoButtonColor = false, LayoutOrder = idx, Parent = self.SideScroll,
    })
    corner(btn, 10)
    local hl = mk("Frame", { Size = UDim2.new(0, 3, 0, 18), Position = UDim2.new(0, 0, 0.5, -9),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Visible = false, Parent = btn })
    corner(hl, 2)
    local lbl = mk("TextLabel", {
        Size = UDim2.new(1, -18, 1, 0), Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1, Text = opts.Title or ("Tab " .. idx),
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
    })
    tab._btn, tab._hl, tab._lbl = btn, hl, lbl

    local page = mk("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.stroke,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, Parent = self.Content,
    })
    vlist(page, 10, Enum.HorizontalAlignment.Left)
    pad(page, 14, 14, 14, 14)
    tab._page = page

    btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)
    self.Tabs[#self.Tabs + 1] = tab
    if #self.Tabs == 1 then self:SelectTab(tab) end
    return tab
end

function A2UI:SelectTab(tab)
    for _, t in ipairs(self.Tabs) do
        local on = (t == tab)
        t._page.Visible = on
        t._btn.BackgroundTransparency = on and 0 or 1
        t._hl.Visible = on
        t._lbl.TextColor3 = on and C.text or C.dim
    end
    self._currentTab = tab
end

function Tab:Space()
    mk("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 1, Parent = self._page })
end

-- -------------------------------------------------------------- SECTION ----
local Section = {}
Section.__index = Section

function Tab:Section(opts)
    opts = opts or {}
    local sec = setmetatable({}, Section)
    sec.Tab = self
    sec._count = 0

    local card = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card, BorderSizePixel = 0, Parent = self._page,
    })
    corner(card, 12); stroke(card, C.stroke, 1, 0.55)
    local inner = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Parent = card,
    })
    vlist(inner, 8, Enum.HorizontalAlignment.Left)
    pad(inner, 12, 12, 12, 12)

    if opts.Title then
        local h = mk("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = opts.Title,
            Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.accent,
            TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = -1000, Parent = inner,
        })
    end
    sec._inner = inner
    sec._card = card
    return sec
end

function Section:Space()
    mk("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 1,
        LayoutOrder = self._count, Parent = self._inner })
end

-- Row helper: bikin baris judul + deskripsi, balikin (row, titleLabel, descLabel)
function Section:_row(title, desc)
    self._count = self._count + 1
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = self._count, Parent = self._inner,
    })
    local textHolder = mk("Frame", {
        Size = UDim2.new(1, -56, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Parent = row,
    })
    vlist(textHolder, 2)
    local t = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Text = title or "", Font = Enum.Font.GothamMedium,
        TextSize = 13, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Parent = textHolder,
    })
    local d
    if desc and desc ~= "" then
        d = mk("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, Text = desc, Font = Enum.Font.Gotham,
            TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true, Parent = textHolder,
        })
    end
    return row, t, d
end

-- --------------------------------------------------------------- TOGGLE ----
function Section:Toggle(opts)
    opts = opts or {}
    local row = self:_row(opts.Title, opts.Desc)
    local state = opts.Value and true or false

    local sw = mk("Frame", {
        Size = UDim2.new(0, 42, 0, 22), Position = UDim2.new(1, -42, 0, 0),
        BackgroundColor3 = C.card2, BorderSizePixel = 0, Parent = row,
    })
    corner(sw, 11)
    local knob = mk("Frame", {
        Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = C.dim, BorderSizePixel = 0, Parent = sw,
    })
    corner(knob, 8)

    local obj = {}
    local function render()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = state and C.bg or C.dim,
        }):Play()
        TweenService:Create(sw, TweenInfo.new(0.15), {
            BackgroundColor3 = state and C.accent or C.card2,
        }):Play()
    end
    render()

    local function setState(v, fire)
        state = v and true or false
        render()
        if fire ~= false and opts.Callback then
            task.spawn(function() opts.Callback(state) end)
        end
    end

    local hit = mk("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "",
        Parent = row,
    })
    hit.MouseButton1Click:Connect(function() setState(not state, true) end)

    obj.Set = function(v, fire) setState(v, fire) end
    obj.Get = function() return state end
    return obj
end

-- --------------------------------------------------------------- SLIDER ----
function Section:Slider(opts)
    opts = opts or {}
    local v = opts.Value or {}
    local min = tonumber(v.Min) or 0
    local max = tonumber(v.Max) or 100
    if max < min then min, max = max, min end
    local step = tonumber(opts.Step) or 1
    local cur = tonumber(v.Default) or min
    if cur < min then cur = min end
    if cur > max then cur = max end

    local row = self:_row(opts.Title, opts.Desc)
    local range = max - min
    local alpha = range > 0 and (cur - min) / range or 0
    -- value badge
    local badge = mk("TextLabel", {
        Size = UDim2.new(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X,
        Position = UDim2.new(1, -52, 0, 0), BackgroundColor3 = C.card2,
        Text = "  " .. tostring(cur) .. "  ", Font = Enum.Font.GothamMedium,
        TextSize = 11, TextColor3 = C.accent, Parent = row,
    })
    corner(badge, 6)

    -- track
    local track = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 0, 26),
        BackgroundColor3 = C.card2, BorderSizePixel = 0, Parent = row,
    })
    corner(track, 4)
    local fill = mk("Frame", {
        Size = UDim2.new(alpha, 0, 1, 0),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Parent = track,
    })
    corner(fill, 4)
    local knob = mk("Frame", {
        Size = UDim2.new(0, 16, 0, 16), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(alpha, 0, 0.5, 0),
        BackgroundColor3 = C.text, BorderSizePixel = 0, Parent = track,
    })
    corner(knob, 8); stroke(knob, C.accent, 2, 0)

    local dragging = false
    local function setVal(val, fire)
        val = math.clamp(val, min, max)
        if step > 0 then val = math.floor(val / step + 0.5) * step end
        cur = val
        local a = range > 0 and (cur - min) / range or 0
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        badge.Text = "  " .. tostring(cur) .. "  "
        if fire ~= false and opts.Callback then
            task.spawn(function() opts.Callback(cur) end)
        end
    end

    local function fromX(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        setVal(min + a * (max - min), true)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            fromX(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local obj = {}
    obj.Set = function(val) setVal(val, false) end
    obj.Get = function() return cur end
    return obj
end

-- --------------------------------------------------------------- BUTTON ----
local function colorOf(c)
    if typeof(c) == "Color3" then return c end
    if type(c) == "string" then return C[c:lower()] or C.accent end
    return C.accent
end

function Section:Button(opts)
    opts = opts or {}
    self._count = self._count + 1
    local col = colorOf(opts.Color)

    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, opts.Desc and 44 or 34),
        BackgroundColor3 = col, BackgroundTransparency = 0.82, BorderSizePixel = 0,
        Text = "", AutoButtonColor = false, LayoutOrder = self._count, Parent = self._inner,
    })
    corner(btn, 9); stroke(btn, col, 1, 0.4)

    local title = mk("TextLabel", {
        Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 8, 0, opts.Desc and 6 or 9),
        BackgroundTransparency = 1, Text = opts.Title or "Button",
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.text,
        TextXAlignment = opts.Justify == "Center" and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
        Parent = btn,
    })
    if opts.Desc then
        mk("TextLabel", {
            Size = UDim2.new(1, -16, 0, 14), Position = UDim2.new(0, 8, 0, 24),
            BackgroundTransparency = 1, Text = opts.Desc, Font = Enum.Font.Gotham,
            TextSize = 10, TextColor3 = C.dim,
            TextXAlignment = opts.Justify == "Center" and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
            Parent = btn,
        })
    end

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.68 }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.82 }):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        if opts.Callback then task.spawn(function() opts.Callback() end) end
    end)
    return btn
end

-- ---------------------------------------------------------------- INPUT ----
function Section:Input(opts)
    opts = opts or {}
    self._count = self._count + 1
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = self._count, Parent = self._inner,
    })
    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = opts.Title or "Input",
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local box = mk("TextBox", {
        Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 20),
        BackgroundColor3 = C.card2, BorderSizePixel = 0, Text = opts.Value or "",
        PlaceholderText = opts.Placeholder or "", PlaceholderColor3 = C.dim,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = row,
    })
    corner(box, 8); stroke(box, C.stroke, 1, 0.5)
    pad(box, 0, 10, 0, 10)

    box.Focused:Connect(function() stroke(box, C.accent, 1, 0.2) end)
    box.FocusLost:Connect(function()
        stroke(box, C.stroke, 1, 0.5)
        if opts.Callback then task.spawn(function() opts.Callback(box.Text) end) end
    end)
    return box
end

-- ------------------------------------------------------------- DROPDOWN ----
function Section:Dropdown(opts)
    opts = opts or {}
    self._count = self._count + 1
    local values = opts.Values or {}
    local current = opts.Value
    local open = false

    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = self._count, Parent = self._inner,
    })
    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = opts.Title or "Dropdown",
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 20),
        BackgroundColor3 = C.card2, BorderSizePixel = 0,
        Text = "  " .. tostring(current or "Pilih..."), Font = Enum.Font.Gotham,
        TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false, Parent = row,
    })
    corner(btn, 8); stroke(btn, C.stroke, 1, 0.5)

    local listFrame = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 1, 4),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panel,
        BorderSizePixel = 0, Visible = false, ZIndex = 50, Parent = btn,
    })
    corner(listFrame, 8); stroke(listFrame, C.stroke, 1, 0.3)
    local listScroll = mk("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.stroke, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = listFrame,
    })
    vlist(listScroll, 2)
    pad(listScroll, 6, 6, 6, 6)
    mk("UISizeConstraint", { MaxSize = Vector2.new(9999, 180), Parent = listScroll })

    local obj = {}
    local function rebuild()
        for _, ch in ipairs(listScroll:GetChildren()) do
            if ch:IsA("TextButton") then ch:Destroy() end
        end
        for i, val in ipairs(values) do
            local it = mk("TextButton", {
                Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C.card,
                BackgroundTransparency = (tostring(val) == tostring(current)) and 0.6 or 1,
                BorderSizePixel = 0, Text = "  " .. tostring(val), Font = Enum.Font.Gotham,
                TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false, LayoutOrder = i, Parent = listScroll,
            })
            corner(it, 6)
            it.MouseButton1Click:Connect(function()
                current = val
                btn.Text = "  " .. tostring(val)
                open = false
                listFrame.Visible = false
                if opts.Callback then task.spawn(function() opts.Callback(val) end) end
            end)
        end
    end
    rebuild()

    btn.MouseButton1Click:Connect(function()
        open = not open
        listFrame.Visible = open
        if open then rebuild() end
    end)

    obj.Refresh = function(newValues)
        values = newValues or {}
        rebuild()
    end
    obj.Select = function(val)
        current = val
        btn.Text = "  " .. tostring(val)
    end
    obj.Get = function() return current end
    return obj
end

-- ------------------------------------------------------------ PARAGRAPH ----
function Section:Paragraph(opts)
    opts = opts or {}
    self._count = self._count + 1
    local col = colorOf(opts.Color)
    local card = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card2, BackgroundTransparency = 0.4, BorderSizePixel = 0,
        LayoutOrder = self._count, Parent = self._inner,
    })
    corner(card, 9)
    local bar = mk("Frame", { Size = UDim2.new(0, 3, 1, -12), Position = UDim2.new(0, 0, 0, 6),
        BackgroundColor3 = col, BorderSizePixel = 0, Parent = card })
    corner(bar, 2)
    local holder = mk("Frame", { Size = UDim2.new(1, -16, 0, 0), Position = UDim2.new(0, 12, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = card })
    vlist(holder, 2)
    pad(holder, 8, 4, 8, 0)

    local title = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Text = opts.Title or "", Font = Enum.Font.GothamBold,
        TextSize = 12, TextColor3 = col, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Parent = holder,
    })
    local desc = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Text = opts.Desc or "", Font = Enum.Font.Gotham,
        TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Parent = holder,
    })

    local obj = {}
    obj.SetTitle = function(t) title.Text = t end
    obj.SetDesc = function(d) desc.Text = d end
    obj.Set = function(t, d)
        if t then title.Text = t end
        if d then desc.Text = d end
    end
    return obj
end

-- Tab-level shortcuts (biar sama kaya WindUI: Tab:Button, Tab:Paragraph)
function Tab:Button(opts) return self:Section({}):Button(opts) end
function Tab:Paragraph(opts) return self:Section({}):Paragraph(opts) end
function Tab:Toggle(opts) return self:Section({}):Toggle(opts) end
function Tab:Input(opts) return self:Section({}):Input(opts) end
function Tab:Dropdown(opts) return self:Section({}):Dropdown(opts) end
function Tab:Slider(opts) return self:Section({}):Slider(opts) end

-- ---------------------------------------------------------------- AUTO MOUNT
-- File ini sering dijalankan langsung dengan executor, bukan di-require
-- sebagai ModuleScript. Pada mode tersebut, return A2UI saja tidak akan
-- menampilkan apa pun, jadi buat window minimal yang langsung terlihat.
-- Saat dipakai sebagai ModuleScript, auto-mount tidak dijalankan agar API
-- library tetap aman dan caller tetap mengontrol pembuatan window sendiri.
local function isModuleScript()
    local ok, result = pcall(function()
        return script and script:IsA("ModuleScript")
    end)
    return ok and result == true
end

-- Skip auto-mount kalau diminta (dipakai script lain yg bikin window sendiri,
-- mis. A2Hub). Standalone tetap auto-mount biar langsung kelihatan.
local skipAuto = false
pcall(function()
    if type(getgenv) == "function" then
        skipAuto = (getgenv().A2UI_NO_AUTOMOUNT == true)
    end
end)

if not isModuleScript() and not skipAuto then
    task.defer(function()
        local ok, err = pcall(function()
            local window = A2UI:CreateWindow({
                Title = "A2 UI",
                Author = "Loaded successfully",
                OpenButton = { Enabled = true },
            })
            local tab = window:Tab({ Title = "Main" })
            local section = tab:Section({ Title = "A2 UI Library" })
            section:Paragraph({
                Title = "UI berhasil muncul",
                Desc = "Library aktif. Tambahkan kontrol dengan Tab:Section(), Button(), Toggle(), atau Slider().",
                Color = "accent",
            })
        end)
        if not ok then
            warn("[A2 UI] Gagal membuat window: " .. tostring(err))
        end
    end)
end

return A2UI

    end

    local ok, result

    -- 2) Coba load dari GitHub dulu (kalau A2_UI_URL diisi & ada internet)
    if USE_REMOTE_A2_UI and A2_UI_URL and A2_UI_URL ~= "" then
        ok, result = pcall(function()
            local src = game:HttpGet(A2_UI_URL)
            -- Versi lama auto-mount sendiri dan bisa menghapus window A2 Hub.
            -- Hanya jalankan remote yang memiliki guard no-auto-mount.
            assert(src:find("A2UI_NO_AUTOMOUNT", 1, true), "Remote A2_UI masih versi lama")
            local compile = loadstring or load
            assert(type(compile) == "function", "Executor tidak menyediakan loadstring/load")
            local chunk, compileErr = compile(src)
            assert(type(chunk) == "function", tostring(compileErr))
            return chunk()
        end)
        -- Validasi: hasil harus table & punya CreateWindow. Kalau nggak, anggap gagal.
        if not (ok and type(result) == "table" and result.CreateWindow) then
            warn("[A2 Hub] Gagal load A2 UI dari URL, pakai versi inline. Error: " .. tostring(result))
            ok = false
            result = nil
        end
    end

    -- Default/fallback: pakai versi INLINE (gak butuh internet) — UI PASTI muncul
    if not (ok and result) then
        ok, result = pcall(__loadA2UI)
    end

    if ok and type(result) == "table" and result.CreateWindow then
        WindUI = result
    else
        warn("[A2 Hub] Gagal load A2 UI: " .. tostring(result))
        return
    end
end

-- ============================================================================
--  CONFIG (SIMPAN / BACA)
-- ============================================================================
local DefaultConfig = {
    WebhookUrl     = "",
    AutoFarm       = false,
    AutoTeleport   = true,
    AutoFinishLine = true,
    AutoReport     = true,
    ReportSecrets  = true,
    MinPlayers     = 2,
    MaxPlayers     = 2,
    TeleportDelay  = 3,
    ReportEvery    = 1,       -- lapor tiap N run
    SecretKeywords = "secret,shard,fragment,key,item,drop,rare,mythic,legendary",
    ChangeMonitor  = true,    -- [BARU] lapor SETIAP perubahan Level/EXP/Screws (real-time)
    ChangeCooldown = 2,       -- [BARU] jeda minimal antar notif perubahan (detik, biar gak kena rate-limit Discord)
    WaitForGameStart = true,  -- [BARU] tunggu game/round mulai dulu sebelum farm (kaya di video)
    UsePromptTrigger = true,  -- [BARU] trigger ProximityPrompt + klik tombol action pas farm

    -- Auto re-execute / rejoin (biar bot nyala lagi pas pindah server / rejoin)
    ScriptUrl      = "",      -- URL RAW script A2Hub.lua (contoh: https://.../A2Hub.lua)
    AutoReexec     = true,    -- auto-execute ulang saat pindah server / rejoin
    AutoRejoin     = false,   -- auto rejoin kalau ke-disconnect
    RejoinDelay    = 5,       -- jeda (detik) sebelum rejoin

    -- Auto Execute (persistent, kayak folder "Auto Execute" di Delta)
    AutoLoadConfig = true,    -- "Set as Auto Load" — menu auto-kebuka + config tersimpan dipakai
    AutoConnect    = true,    -- auto hubungin webhook pas script jalan
    AutoEscape     = true,    -- tutup (escape) GUI otomatis setelah farm beneran jalan
    EscapeDelay    = 8,       -- jeda (detik) nunggu farm mulai sebelum auto escape

    -- [BARU] GENERATOR FARM (tombol FARM beneran: repair gen TERJAUH -> escape -> bypass gate)
    GenFarmEnabled     = false, -- toggle utama FARM (generator farm)
    GenTargetCount     = 1,     -- berapa gen yang di-repair sebelum escape (default 1)
    GenFarmRadius      = 76,    -- radius deteksi player lain (kalau ada player deket -> hop/escape)
    GenFarmHopCD       = 1.2,   -- cooldown hop antar gen (detik)
    GenFarthest        = true,  -- target gen TERJAUH dulu
    GenEscapeAfter     = true,  -- escape otomatis setelah target gen kelar
    GenBypassGate      = true,  -- bypass gate (fire PlayerActionEvent ESCAPED + firetouchinterest)
    GenInstantSkill    = true,  -- instant skillcheck
    GenAutoRepair      = true,  -- fire RepairEvent otomatis
    GenHopIfPlayerNear = true,  -- pindah gen kalau ada player deket
    GenFloatingButton  = true,  -- tampilkan tombol floating FARM (draggable)
    GenAutoLoop        = true,  -- ulang otomatis tiap round (abis escape, tunggu round baru)
    GenLoopDelay       = 6,     -- jeda (detik) nunggu round baru sebelum ulang
    GenAutoChangeServer = true, -- [BARU] abis escape -> ganti server otomatis (server hop)
    GenRejoinOnDeath   = true,  -- [BARU] kalau karakter mati pas farm -> rejoin server
    GenRejoinOnStall   = true,  -- [BARU] kalau farm macet (gak ada progress) -> rejoin
    GenStallTimeout    = 35,    -- [BARU] detik tanpa progress sebelum dianggap macet

    -- [BARU] Item / Gear / Inventory ke webhook
    ReportItems        = true,  -- kirim item/gear/inventory ke webhook
    ItemKeywords       = "item,gear,tool,inventory,weapon,skin,pet,backpack",
}

local Config = {}
do
    local function deepCopy(t)
        local c = {}
        for k, v in pairs(t) do c[k] = v end
        return c
    end
    Config = deepCopy(DefaultConfig)

    local ok, data = pcall(function()
        if readfile and isfile and isfile(CONFIG_FILE) then
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end
        return nil
    end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            if DefaultConfig[k] ~= nil then Config[k] = v end
        end
    end
end

local function saveConfig()
    pcall(function()
        if writefile then
            writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
        end
    end)
end

-- ============================================================================
--  [BARU] CONFIG MANAGER (kayak di video: create / list / load / overwrite /
--  delete / refresh / set as autoload / copy script)
-- ============================================================================
local CONFIG_DIR     = "A2Hub_Configs"       -- folder semua config
local AUTOLOAD_FILE  = "A2Hub_autoload.txt"  -- nyimpen nama config autoload

local function cleanConfigName(name)
    name = tostring(name or ""):gsub("%.json$", "")
    name = name:gsub("[^%w%-%_ ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    name = name:gsub("%s+", "_")
    if #name > 40 then name = name:sub(1, 40) end
    return name
end

local function ensureDir()
    pcall(function()
        if makefolder and not (isfolder and isfolder(CONFIG_DIR)) then
            makefolder(CONFIG_DIR)
        end
    end)
end

-- Terapkan tabel ke Config (cuma key yg dikenal)
local function applyConfigTable(data)
    if type(data) ~= "table" then return false end
    for k, v in pairs(data) do
        if DefaultConfig[k] ~= nil then Config[k] = v end
    end
    return true
end

-- Daftar semua config yg tersimpan
local function listConfigs()
    local out = {}
    ensureDir()
    pcall(function()
        if listfiles then
            for _, f in ipairs(listfiles(CONFIG_DIR)) do
                local name = tostring(f):match("([^/\\]+)%.json$")
                if name then out[#out + 1] = name end
            end
        end
    end)
    table.sort(out)
    return out
end

-- Simpan config aktif ke nama tertentu (create / overwrite)
local function saveNamedConfig(name)
    name = cleanConfigName(name)
    if name == "" then return false, "Nama config kosong atau tidak valid" end
    ensureDir()
    local ok = pcall(function()
        writefile(CONFIG_DIR .. "/" .. name .. ".json", HttpService:JSONEncode(Config))
    end)
    return ok, ok and ("Config '" .. name .. "' disimpan") or "Gagal menyimpan (executor gak support writefile)"
end

-- Muat config berdasarkan nama
local function loadNamedConfig(name)
    name = cleanConfigName(name)
    if name == "" then return false, "Nama config kosong atau tidak valid" end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG_DIR .. "/" .. name .. ".json"))
    end)
    if ok and applyConfigTable(data) then
        saveConfig()
        return true, ("Config '" .. name .. "' dimuat")
    end
    return false, "Config '" .. tostring(name) .. "' gak ketemu"
end

-- Hapus config
local function deleteNamedConfig(name)
    name = cleanConfigName(name)
    if name == "" then return false, "Nama config kosong atau tidak valid" end
    local ok = pcall(function() delfile(CONFIG_DIR .. "/" .. name .. ".json") end)
    return ok, ok and ("Config '" .. name .. "' dihapus") or "Gagal menghapus"
end

-- Set / get autoload
local function setAutoLoad(name)
    name = cleanConfigName(name)
    if name == "" then return false, "Pilih config dulu" end
    local ok = pcall(function() writefile(AUTOLOAD_FILE, name) end)
    return ok, ok and ("'" .. name .. "' di-set sebagai Auto Load") or "Gagal set autoload"
end

local function getAutoLoad()
    local ok, name = pcall(function() return readfile(AUTOLOAD_FILE) end)
    if ok and name and name ~= "" then return name end
    return nil
end

-- Muat config autoload (dipanggil pas script jalan)
local function loadAutoLoadConfig()
    -- 1) Dari file autoload (A2Hub_autoload.txt)
    local name = getAutoLoad()

    -- 2) Fallback: dari loader Auto Execute (getgenv().A2Hub_AutoLoadConfig)
    if (not name or name == "") and type(getgenv) == "function" then
        local g = getgenv()
        if type(g) == "table" and type(g.A2Hub_AutoLoadConfig) == "string" and g.A2Hub_AutoLoadConfig ~= "" then
            name = g.A2Hub_AutoLoadConfig
        end
    end

    if name and name ~= "" then
        local ok = loadNamedConfig(name)
        if ok then return name end
    end
    return nil
end

-- ============================================================================
--  STATE GLOBAL
-- ============================================================================
local State = {
    Connected    = false,
    Farming      = false,
    Runs         = 0,
    TotalScrews  = 0,
    TotalEXP     = 0,
    TotalLevel   = 0,
    SecretsFound = {},        -- { [name] = count }
    ItemsFound   = {},        -- [BARU] { [name=count] = true } item/gear yg udah dilapor
    ItemsInit    = false,     -- [BARU] baseline inventory udah diambil?
    Visited      = {},        -- server id yg sudah dikunjungi
    LastStats    = { screw = 0, exp = 0, level = 0 },
    MonitorLast  = { screw = 0, exp = 0, level = 0 },  -- [BARU] snapshot buat deteksi perubahan real-time
    MonitorPending = { screw = 0, exp = 0, level = 0 }, -- [BARU] akumulasi perubahan yg belum dikirim
    MonitorLastSent = 0,                                -- [BARU] waktu kirim terakhir (rate-limit)
    LastRejoin   = 0,         -- [BARU] waktu rejoin terakhir (anti rejoin dobel)
    Baseline     = nil,       -- statistik awal
    StatusText   = "Menunggu koneksi webhook...",
}

-- ============================================================================
--  HTTP REQUEST (kompatibel banyak executor)
-- ============================================================================
local function httpRequest(opts)
    if request then
        return request(opts)
    elseif http_request then
        return http_request(opts)
    elseif syn and syn.request then
        return syn.request(opts)
    else
        -- Fallback: HttpService (terbatas, tapi untuk GET cukup)
        local res = HttpService:RequestAsync(opts)
        return { StatusCode = res.StatusCode, Body = res.Body }
    end
end

-- ============================================================================
--  WEBHOOK DISCORD
-- ============================================================================
local function sendWebhook(embed)
    if not Config.WebhookUrl or Config.WebhookUrl == "" or Config.WebhookUrl == "NONE" then
        return false, "Webhook kosong"
    end
    local payload = { embeds = { embed } }
    local ok, res = pcall(function()
        return httpRequest({
            Url = Config.WebhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload),
        })
    end)
    if ok and res then
        local code = res.StatusCode or res.Status or 0
        return (code >= 200 and code < 300), ("HTTP " .. tostring(code))
    end
    return false, tostring(res)
end

local function testWebhook()
    local embed = {
        title = "🔗 A2 HUB — Koneksi Berhasil",
        description = "Webhook berhasil terhubung! Bot siap memantau hasil farm kamu.",
        color = 5763719, -- hijau
        fields = {
            { name = "👤 Player", value = LocalPlayer.Name, inline = true },
            { name = "🆔 UserId", value = tostring(LocalPlayer.UserId), inline = true },
            { name = "🎮 Game", value = tostring(game.PlaceId), inline = true },
        },
        footer = { text = "A2 HUB • Violence District" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    return sendWebhook(embed)
end

-- Laporan hasil satu run
local function reportRun(stats, gains)
    if not Config.AutoReport then return end
    local fields = {
        { name = "👤 Username", value = LocalPlayer.Name, inline = true },
        { name = "🆔 UserId", value = tostring(LocalPlayer.UserId), inline = true },
        { name = "🔩 Screws", value = string.format("%d  (+%d)", stats.screw, gains.screw or 0), inline = true },
        { name = "⭐ EXP", value = string.format("%d  (+%d)", stats.exp, gains.exp or 0), inline = true },
        { name = "🏆 Level", value = string.format("%d  (+%d)", stats.level, gains.level or 0), inline = true },
        { name = "🔁 Total Run", value = tostring(State.Runs), inline = true },
        { name = "🔩 Total Screws", value = tostring(State.TotalScrews), inline = true },
    }
    local embed = {
        title = "✅ A2 HUB — Run Selesai",
        color = 65484,
        fields = fields,
        footer = { text = "A2 HUB • Violence District" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    sendWebhook(embed)
end

-- Laporan secret/item baru
local function reportSecret(name, count)
    if not Config.ReportSecrets then return end
    local embed = {
        title = "💎 A2 HUB — SECRET DITEMUKAN!",
        description = string.format("Kamu mendapatkan **%s** (x%d)!", name, count),
        color = 15844367, -- emas
        fields = {
            { name = "👤 Username", value = LocalPlayer.Name, inline = true },
            { name = "🆔 UserId", value = tostring(LocalPlayer.UserId), inline = true },
            { name = "🔁 Run ke-", value = tostring(State.Runs), inline = true },
        },
        footer = { text = "A2 HUB • Secret Monitor" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    sendWebhook(embed)
end

-- [BARU] Laporan PERUBAHAN real-time (Level / EXP / Screws)
-- Dipanggil tiap kali ada perubahan stats, gak nunggu run selesai.
local function reportChange(stats, gains)
    if not Config.AutoReport then return end

    local parts = {}
    if (gains.level or 0) ~= 0 then
        table.insert(parts, string.format("🏆 **Level** %d → %d (%s%d)", stats.level - gains.level, stats.level, gains.level > 0 and "+" or "", gains.level))
    end
    if (gains.exp or 0) ~= 0 then
        table.insert(parts, string.format("⭐ **EXP** %d (%s%d)", stats.exp, gains.exp > 0 and "+" or "", gains.exp))
    end
    if (gains.screw or 0) ~= 0 then
        table.insert(parts, string.format("🔩 **Screws** %d (%s%d)", stats.screw, gains.screw > 0 and "+" or "", gains.screw))
    end
    if #parts == 0 then return end

    local embed = {
        title = "📈 A2 HUB — Perubahan Terdeteksi",
        description = table.concat(parts, "\n"),
        color = 3447003, -- biru
        fields = {
            { name = "👤 Username", value = LocalPlayer.Name, inline = true },
            { name = "🆔 UserId", value = tostring(LocalPlayer.UserId), inline = true },
            { name = "🔁 Total Run", value = tostring(State.Runs), inline = true },
        },
        footer = { text = "A2 HUB • Live Monitor" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    sendWebhook(embed)
end

-- [BARU] Laporan ITEM / GEAR baru (Backpack / Character / StarterGear)
local function reportItem(name, count)
    if not Config.ReportItems then return end
    local embed = {
        title = "\ud83c\udf92 A2 HUB \u2014 ITEM / GEAR BARU!",
        description = string.format("Kamu mendapatkan **%s** (x%d)!", name, count),
        color = 10181046, -- ungu
        fields = {
            { name = "\ud83d\udc64 Username", value = LocalPlayer.Name, inline = true },
            { name = "\ud83c\udd94 UserId", value = tostring(LocalPlayer.UserId), inline = true },
            { name = "\ud83d\udd01 Run ke-", value = tostring(State.Runs), inline = true },
        },
        footer = { text = "A2 HUB \u2022 Item Monitor" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    sendWebhook(embed)
end

-- [BARU] Kirim snapshot inventory lengkap (sekali pas connect)
local function reportInventorySnapshot(items)
    if not Config.ReportItems then return end
    local names = {}
    for name, count in pairs(items) do
        names[#names + 1] = string.format("\u2022 **%s** x%d", tostring(name), tonumber(count) or 1)
    end
    if #names == 0 then names[1] = "_Belum ada item di inventory._" end
    table.sort(names)
    local desc = table.concat(names, "\n")
    if #desc > 3800 then desc = desc:sub(1, 3800) .. "\n..." end
    local embed = {
        title = "\ud83c\udf92 A2 HUB \u2014 Inventory Snapshot",
        description = desc,
        color = 10181046,
        fields = {
            { name = "\ud83d\udc64 Username", value = LocalPlayer.Name, inline = true },
            { name = "\ud83c\udd94 UserId", value = tostring(LocalPlayer.UserId), inline = true },
            { name = "\ud83d\udce6 Total Jenis", value = tostring(#names), inline = true },
        },
        footer = { text = "A2 HUB \u2022 Inventory" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    sendWebhook(embed)
end

-- [BARU] Laporan karakter MATI (biar tau kenapa farm berhenti)
local function reportDeath()
    if not Config.AutoReport then return end
    local embed = {
        title = "\ud83d\udc80 A2 HUB \u2014 Karakter Mati",
        description = "Karakter mati pas farm. Bot bakal rejoin otomatis (kalau diaktifkan).",
        color = 15158332, -- merah
        fields = {
            { name = "\ud83d\udc64 Username", value = LocalPlayer.Name, inline = true },
            { name = "\ud83c\udd94 UserId", value = tostring(LocalPlayer.UserId), inline = true },
            { name = "\ud83d\udd01 Run ke-", value = tostring(State.Runs), inline = true },
        },
        footer = { text = "A2 HUB \u2022 Death Monitor" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    sendWebhook(embed)
end

-- [BARU] Laporan farm MACET (gak ada progress) -> mau rejoin
local function reportStall(seconds)
    if not Config.AutoReport then return end
    local embed = {
        title = "\u26a0\ufe0f A2 HUB \u2014 Farm Macet",
        description = string.format("Farm gak ada progress selama **%d detik**. Bot bakal rejoin (kalau diaktifkan).", tonumber(seconds) or 0),
        color = 16776960, -- kuning
        fields = {
            { name = "\ud83d\udc64 Username", value = LocalPlayer.Name, inline = true },
            { name = "\ud83c\udd94 UserId", value = tostring(LocalPlayer.UserId), inline = true },
            { name = "\ud83d\udd25 Gen", value = tostring((getgenv and getgenv().A2Hub_GenCount) or 0) .. "/" .. tostring(Config.GenTargetCount or 1), inline = true },
        },
        footer = { text = "A2 HUB \u2022 Stall Monitor" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    sendWebhook(embed)
end

-- ============================================================================
--  CORE FARM
-- ============================================================================

-- Ambil waktu sisa dari TimerLabel (Spectator)
local function getRemainingTime()
    local ok, result = pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return nil end
        local spectator = playerGui:FindFirstChild("Spectator")
        if not spectator then return nil end
        local time = spectator:FindFirstChild("time")
        if not time then return nil end
        local timerLabel = time:FindFirstChild("TimerLabel")
        if not timerLabel then return nil end
        local m, s = timerLabel.Text:match("(%d+):(%d+)")
        if m and s then
            return tonumber(m) + tonumber(s) / 60
        end
        return nil
    end)
    if ok then return result end
    return nil
end

-- ============================================================================
--  [BARU] TUNGGU GAME MULAI (dari video: "pas farm idup, tunggu game nya mulai dulu")
--  Biar bot gak maksa farm pas masih loading / masih spectator.
-- ============================================================================
local function isRoundStarted()
    local ok, started = pcall(function()
        -- 1) Timer spectator muncul = round jalan
        if getRemainingTime() ~= nil then return true end
        -- 2) Tim udah bukan spectator
        local team = LocalPlayer.Team
        if team and team.Name ~= "Spectator" then return true end
        return false
    end)
    return ok and started
end

local function waitForGameStart(timeout)
    timeout = tonumber(timeout) or 60
    local start = tick()
    -- tunggu game selesai loading dulu
    pcall(function()
        repeat task.wait(0.5) until game:IsLoaded() or (tick() - start >= timeout)
    end)
    -- tunggu round beneran mulai (timer / tim)
    repeat
        task.wait(0.5)
        if isRoundStarted() then return true end
    until (tick() - start) >= timeout
    return isRoundStarted()
end

-- ============================================================================
--  [BARU] FARM HELPERS (dari kode fix: trigger ProximityPrompt + klik action)
-- ============================================================================
local function findProximityPrompt(root)
    local found = nil
    pcall(function()
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then found = obj; break end
        end
    end)
    return found
end

local function triggerProximityPrompt(prompt)
    if not prompt then return false end
    pcall(function()
        prompt:InputHoldBegin()
        task.wait(0.05)
        prompt:InputHoldEnd()
    end)
    if typeof(firesignal) == "function" then
        pcall(function() firesignal(prompt.PromptButtonHoldBegan) end)
        pcall(function() firesignal(prompt.PromptButtonHoldEnded) end)
        pcall(function() firesignal(prompt.Triggered) end)
    end
    return true
end

-- Klik tombol action (Survivor-mob / Killer-mob) kalau ada
local function clickActionButton()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    for _, guiName in ipairs({ "Survivor-mob", "SurvivorMob", "Killer-mob" }) do
        local gui = pg:FindFirstChild(guiName)
        if gui then
            local controls = gui:FindFirstChild("Controls")
            if controls then
                local act = controls:FindFirstChild("action")
                    or controls:FindFirstChild("Action")
                    or controls:FindFirstChild("Gui-mob")
                if act and act.Visible then
                    if typeof(firesignal) == "function" then
                        pcall(function() firesignal(act.MouseButton1Down) end)
                        task.wait(0.02)
                        pcall(function() firesignal(act.MouseButton1Up) end)
                        pcall(function() firesignal(act.MouseButton1Click) end)
                    end
                    return true
                end
            end
        end
    end
    return false
end

-- Cari finish line di workspace
local function findFinishLine(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child.Name == "Fininshline" or child.Name == "Finishline" or child.Name == "FinishLine" then
            return child
        end
        local found = findFinishLine(child)
        if found then return found end
    end
    return nil
end

-- ============================================================================
--  [BARU] GENERATOR FARM  (tombol FARM beneran)
--  Alur: target gen TERJAUH -> teleport -> repair (fire RepairEvent + trigger
--  ProximityPrompt + klik action) -> instant skillcheck -> kalau ada player
--  deket pindah gen (hop) -> setelah target gen kelar -> ESCAPE -> ke gate ->
--  BYPASS GATE.
-- ============================================================================
local GenFarm = {
    Active  = false,
    Thread  = nil,
    Current = nil,
    LastHop = 0,
    Count   = 0,
    Done    = {},
    Status  = "idle",
    _syncing = false,
    TeleportAt   = 0,   -- [FIX] waktu teleport terakhir (biar repair gak fire pas masih gerak)
    LastProgress = 0,   -- [BARU] waktu progress terakhir (buat deteksi farm macet)
    Waiting      = false, -- [BARU] lagi nunggu round mulai (jangan dianggap macet)
}

-- Callback buat sinkron tombol floating <-> toggle di menu
local GenFarmSync = { fn = nil }

-- Ambil remote RepairEvent (ReplicatedStorage.Remotes.Generator.RepairEvent)
local function getRepairRemote()
    local remote = nil
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local gen = remotes and remotes:FindFirstChild("Generator")
        remote = gen and gen:FindFirstChild("RepairEvent")
    end)
    return remote
end

-- Titik-titik generator (GeneratorPoint)
local function getGenPoints(genModel)
    local pts = {}
    pcall(function()
        for _, o in ipairs(genModel:GetChildren()) do
            if o:IsA("BasePart") and o.Name:find("GeneratorPoint") then
                pts[#pts + 1] = o
            end
        end
        if #pts == 0 then
            for _, o in ipairs(genModel:GetDescendants()) do
                if o:IsA("BasePart") and o.Name:find("GeneratorPoint") then
                    pts[#pts + 1] = o
                end
            end
        end
    end)
    return pts
end

-- Semua generator (pakai cache KYS_Cache kalau ada, fallback scan workspace.Map)
-- Hasil scan di-cache ~1 detik biar loop gak lag (scan descendant mahal).
local GenCache = { raw = {}, time = 0 }
local function getAllGens()
    local now = tick()
    if (now - GenCache.time) >= 1 or #GenCache.raw == 0 then
        local raw = {}
        pcall(function()
            local cache = (type(getgenv) == "function") and getgenv().KYS_Cache or nil
            if cache and cache.Generators then
                for _, g in ipairs(cache.Generators) do
                    if g.model and g.model.Parent and g.part and g.part.Parent then
                        raw[#raw + 1] = g
                    end
                end
            end
            if #raw == 0 then
                local map = workspace:FindFirstChild("Map") or workspace
                for _, obj in ipairs(map:GetDescendants()) do
                    if obj:IsA("Model") and obj.Name == "Generator" then
                        local part = obj:FindFirstChild("HitBox", true)
                            or obj:FindFirstChild("GeneratorPoint", true)
                            or obj.PrimaryPart
                            or obj:FindFirstChildWhichIsA("BasePart", true)
                        if part and part.Parent then
                            raw[#raw + 1] = { model = obj, part = part }
                        end
                    end
                end
            end
        end)
        GenCache.raw = raw
        GenCache.time = now
    end

    -- Filter yang belum selesai
    local out = {}
    for _, g in ipairs(GenCache.raw) do
        if g.model and g.model.Parent and not GenFarm.Done[g.model] then
            out[#out + 1] = g
        end
    end
    return out
end

-- Progress repair (0-100)
local function getGenProgress(genModel)
    local p = 0
    pcall(function()
        p = genModel:GetAttribute("RepairProgress")
            or genModel:GetAttribute("repairProgress") or 0
        p = tonumber(p) or 0
        if p <= 1.001 then p = p * 100 end
    end)
    return math.clamp(p, 0, 100)
end

-- Ada player lain deket posisi? (killer/survivor lain)
local function playerNear(pos, radius)
    local found, who = false, nil
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local r = p.Character:FindFirstChild("HumanoidRootPart")
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                if r and h and h.Health > 0 and (r.Position - pos).Magnitude <= radius then
                    found, who = true, p
                    break
                end
            end
        end
    end)
    return found, who
end

-- Gen TERJAUH dari posisi
local function farthestGen(fromPos)
    local best, bd = nil, -1
    for _, g in ipairs(getAllGens()) do
        local d = (g.part.Position - fromPos).Magnitude
        if d > bd then bd = d; best = g end
    end
    return best
end

-- Gen TERDEKAT yang aman (gak ada player deket)
local function safeNearestGen(fromPos, radius)
    local list = {}
    for _, g in ipairs(getAllGens()) do
        local near = playerNear(g.part.Position, radius)
        if not near then
            list[#list + 1] = { g = g, d = (g.part.Position - fromPos).Magnitude }
        end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    return list[1] and list[1].g or nil
end

-- [FIX] Jarak karakter ke gen (ke point terdekat)
local function distToGen(gen, hrp)
    if not gen or not hrp then return math.huge end
    local pts = gen.model and getGenPoints(gen.model) or {}
    if #pts == 0 then
        if gen.part then return (gen.part.Position - hrp.Position).Magnitude end
        return math.huge
    end
    local best = math.huge
    for _, p in ipairs(pts) do
        local d = (p.Position - hrp.Position).Magnitude
        if d < best then best = d end
    end
    return best
end

-- [FIX] Stop repair (fire false) di gen tertentu -> biar gak "nyangkut" di gen lama
local function stopRepairGen(gen)
    if not gen or not gen.model then return end
    local rr = getRepairRemote()
    if not rr then return end
    for _, p in ipairs(getGenPoints(gen.model)) do
        pcall(function() rr:FireServer(p, false) end)
    end
end

-- Teleport ke gen + trigger prompt + klik action
local function teleportToGen(gen)
    if not gen or not gen.part then return false end
    local target = gen.part
    local ok = pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local pts = getGenPoints(gen.model)
        if #pts > 0 then
            local best, bd = pts[1], math.huge
            for _, p in ipairs(pts) do
                local d = (p.Position - hrp.Position).Magnitude
                if d < bd then bd = d; best = p end
            end
            target = best
        end
        hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
    end)
    task.wait(0.25)
    -- [FIX] Settle: pastiin karakter bener2 nyampe (anti rubber-band / ke-geser balik)
    pcall(function()
        for _ = 1, 8 do
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then break end
            if (hrp.Position - target.Position).Magnitude > 10 then
                hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
                task.wait(0.05)
            else
                break
            end
        end
    end)
    GenFarm.TeleportAt = tick()
    if Config.UsePromptTrigger then
        triggerProximityPrompt(findProximityPrompt(gen.model))
        task.wait(0.1)
        clickActionButton()
    end
    return ok
end

-- Instant skillcheck (set Line.Rotation = Goal.Rotation + 109)
local function instantSkillcheck()
    if not Config.GenInstantSkill then return end
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        local prompt = pg:FindFirstChild("SkillCheckPromptGui")
            or pg:FindFirstChild("SkillCheckPromptGui-con")
        if not prompt then return end
        local check = prompt:FindFirstChild("Check")
        if not check or not check.Visible then return end
        local line = check:FindFirstChild("Line")
        local goal = check:FindFirstChild("Goal")
        if not (line and goal) then return end
        line.Rotation = (tonumber(goal.Rotation) or 0) + 109
        if not clickActionButton() then
            if typeof(firesignal) == "function" then
                pcall(function() firesignal(check.MouseButton1Down) end)
                pcall(function() firesignal(check.MouseButton1Up) end)
            end
        end
    end)
end

-- Cari posisi exit / gate (finish line)
local function getExitPos()
    local exitPos, exitPart = nil, nil
    pcall(function()
        local cache = (type(getgenv) == "function") and getgenv().KYS_Cache or nil
        if cache then exitPos = cache.ExitPos; exitPart = cache.ExitPart end
    end)
    if not exitPos then
        local finish = findFinishLine(workspace)
        if finish then
            if finish:IsA("BasePart") then
                exitPos, exitPart = finish.Position, finish
            else
                local part = finish:FindFirstChildWhichIsA("BasePart", true)
                if part then exitPos, exitPart = part.Position, part end
            end
        end
    end
    return exitPos, exitPart
end

-- ESCAPE + BYPASS GATE (teleport ke gate, fire PlayerActionEvent, firetouchinterest)
local function doEscape()
    local exitPos, exitPart = getExitPos()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not exitPos then return false end
    hrp.CFrame = CFrame.new(exitPos + Vector3.new(0, 3, 0))
    task.wait(0.4)
    for _ = 1, 20 do
        pcall(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local gameR = remotes and remotes:FindFirstChild("Game")
            local e = gameR and gameR:FindFirstChild("PlayerActionEvent")
            if e then
                if e:IsA("RemoteEvent") then e:FireServer("ESCAPED", 200)
                elseif e:IsA("BindableEvent") then e:Fire("ESCAPED", 200) end
            end
        end)
        if Config.GenBypassGate then
            pcall(function()
                if typeof(firetouchinterest) == "function" and exitPart then
                    firetouchinterest(hrp, exitPart, 0)
                    task.wait(0.01)
                    firetouchinterest(hrp, exitPart, 1)
                end
            end)
        end
        task.wait(0.1)
    end
    return true
end

-- Loop utama generator farm
local function genFarmLoop()
    while GenFarm.Active do
        -- reset tiap round
        GenFarm.Count = 0
        GenFarm.Done = {}
        GenFarm.Current = nil
        GenFarm.Status = "Menunggu game mulai..."
        GenFarm.LastProgress = tick()
        getgenv().A2Hub_GenCount = 0

        -- Tunggu game/round mulai dulu (kaya di video)
        if Config.WaitForGameStart and not isRoundStarted() then
            GenFarm.Status = "Nunggu round mulai..."
            GenFarm.Waiting = true
            waitForGameStart(180)
            GenFarm.Waiting = false
            GenFarm.LastProgress = tick()
        end

        GenFarm.Status = "TP ke gen terjauh..."

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            task.wait(1.5)
            char = LocalPlayer.Character
            hrp = char and char:FindFirstChild("HumanoidRootPart")
        end

        local radius = tonumber(Config.GenFarmRadius) or 76
        local targetCount = tonumber(Config.GenTargetCount) or 1

        -- 1) Target gen TERJAUH dulu
        if hrp then
            local first = Config.GenFarthest and farthestGen(hrp.Position)
                or safeNearestGen(hrp.Position, radius)
            if first then
                GenFarm.Current = first
                teleportToGen(first)
            end
        end

        local lastRepair, lastPrompt = 0, 0
        local escaped = false
        local died = false

        while GenFarm.Active do
            task.wait(0.1)

            char = LocalPlayer.Character
            hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if not hrp or not hum or hum.Health <= 0 then
                -- [BARU] mati / respawn -> rejoin kalau diaktifkan
                if hum and hum.Health <= 0 and Config.GenRejoinOnDeath then
                    GenFarm.Status = "Mati \u2192 rejoin..."
                    reportDeath()
                    died = true
                    break
                end
                task.wait(1)
            else
                -- Escape kalau target gen udah kelar
                if GenFarm.Count >= targetCount then
                    GenFarm.Status = "Escape + bypass gate..."
                    if Config.GenEscapeAfter then doEscape() end
                    escaped = true
                    break
                end

                -- Cek player deket -> hop / escape
                local danger, who = playerNear(hrp.Position, radius)
                if danger and Config.GenHopIfPlayerNear then
                    local now = tick()
                    if now - GenFarm.LastHop >= (tonumber(Config.GenFarmHopCD) or 1.2) then
                        GenFarm.LastHop = now
                        local nextGen = safeNearestGen(hrp.Position, radius)
                        if nextGen then
                            stopRepairGen(GenFarm.Current)   -- [FIX] stop repair di gen lama
                            GenFarm.Current = nextGen
                            GenFarm.Status = "Hop: " .. ((who and who.Name) or "player") .. " deket"
                            teleportToGen(nextGen)
                        else
                            GenFarm.Status = "Player deket, escape..."
                            if Config.GenEscapeAfter then doEscape() end
                            escaped = true
                            break
                        end
                    end
                end

                -- Auto repair
                local gen = GenFarm.Current
                if gen and gen.model and gen.model.Parent then
                    -- [FIX] Cek karakter bener2 di gen SEKARANG (bukan gen lama setelah teleport)
                    local dist = distToGen(gen, hrp)
                    local settling = (tick() - (GenFarm.TeleportAt or 0)) < 0.6
                    if dist > 18 then
                        -- Belum nyampe / ke-geser -> teleport ulang, JANGAN repair
                        GenFarm.Status = "Teleport ulang ke gen (jarak " .. math.floor(dist) .. ")..."
                        teleportToGen(gen)
                    elseif getGenProgress(gen.model) >= 100 then
                        if not GenFarm.Done[gen.model] then
                            GenFarm.Done[gen.model] = true
                            GenFarm.Count = GenFarm.Count + 1
                            GenFarm.LastProgress = tick()
                            getgenv().A2Hub_GenCount = GenFarm.Count
                        end
                        stopRepairGen(gen)   -- [FIX] gen ini kelar -> stop repair di sini
                        local nextGen = safeNearestGen(hrp.Position, radius) or farthestGen(hrp.Position)
                        if nextGen then
                            GenFarm.Current = nextGen
                            GenFarm.Status = "Gen " .. GenFarm.Count .. "/" .. targetCount .. " kelar"
                            teleportToGen(nextGen)
                        else
                            GenFarm.Status = "Semua gen kelar, escape..."
                            if Config.GenEscapeAfter then doEscape() end
                            escaped = true
                            break
                        end
                    else
                        local now = tick()
                        if now - lastPrompt >= 0.5 then
                            lastPrompt = now
                            if Config.UsePromptTrigger then
                                triggerProximityPrompt(findProximityPrompt(gen.model))
                                clickActionButton()
                            end
                        end
                        if now - lastRepair >= 0.25 and not settling then
                            lastRepair = now
                            if Config.GenAutoRepair then
                                local rr = getRepairRemote()
                                if rr then
                                    for _, p in ipairs(getGenPoints(gen.model)) do
                                        pcall(function() rr:FireServer(p, true) end)
                                    end
                                    GenFarm.LastProgress = tick()  -- [BARU] tandai ada progress
                                end
                            end
                            instantSkillcheck()
                        else
                            instantSkillcheck()
                        end
                    end
                else
                    local nextGen = safeNearestGen(hrp.Position, radius) or farthestGen(hrp.Position)
                    if nextGen then
                        GenFarm.Current = nextGen
                        teleportToGen(nextGen)
                    end
                end
            end
        end

        -- Kalau user matiin farm -> keluar
        if not GenFarm.Active then break end

        -- [BARU] Mati -> rejoin server
        if died then
            if Config.GenRejoinOnDeath then rejoinNow() end
            break
        end

        -- [BARU] Abis escape -> ganti server otomatis (server hop)
        if escaped and Config.GenAutoChangeServer then
            GenFarm.Status = "Ganti server otomatis..."
            task.wait(1)
            pcall(teleportToServer)
            break
        end

        -- Kalau abis escape & auto-loop ON -> tunggu round baru, ulang
        if escaped and Config.GenAutoLoop then
            GenFarm.Status = "Nunggu round baru..."
            GenFarm.Waiting = true
            task.wait(tonumber(Config.GenLoopDelay) or 6)
            GenFarm.Waiting = false
            GenFarm.LastProgress = tick()
        else
            break
        end
    end

    GenFarm.Active = false
    GenFarm.Waiting = false
    GenFarm.Status = "idle"
end

-- Set (ON/OFF) generator farm
local function setGenFarm(state)
    state = state and true or false
    Config.GenFarmEnabled = state
    saveConfig()

    if state then
        if not GenFarm.Active then
            GenFarm.Active = true
            if GenFarm.Thread then pcall(task.cancel, GenFarm.Thread) end
            GenFarm.Thread = task.spawn(genFarmLoop)
        end
    else
        GenFarm.Active = false
        GenFarm.Waiting = false
        if GenFarm.Thread then
            pcall(task.cancel, GenFarm.Thread)
            GenFarm.Thread = nil
        end
        -- Matiin repair (fire false)
        local rr = getRepairRemote()
        if rr then
            for _, g in ipairs(getAllGens()) do
                for _, p in ipairs(getGenPoints(g.model)) do
                    pcall(function() rr:FireServer(p, false) end)
                end
            end
        end
    end

    -- Sinkron ke toggle di menu (tanpa nge-trigger callback)
    if GenFarmSync.fn then
        GenFarm._syncing = true
        pcall(GenFarmSync.fn)
        GenFarm._syncing = false
    end
end

-- Tombol floating FARM (draggable, ada lock)
local function createFloatingFarmButton()
    local parent
    pcall(function() parent = (gethui and gethui()) end)
    if not parent then pcall(function() parent = game:GetService("CoreGui") end) end
    if not parent then parent = LocalPlayer:FindFirstChild("PlayerGui") end
    if not parent then return end

    local old = parent:FindFirstChild("A2FarmBtnGui")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "A2FarmBtnGui"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 99999
    sg.Parent = parent

    local btn = Instance.new("TextButton")
    btn.Name = "A2FarmBtn"
    btn.Size = UDim2.new(0, 70, 0, 70)
    btn.Position = UDim2.new(0.08, 0, 0.85, 0)
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    btn.BackgroundTransparency = 0.15
    btn.Text = "🔥\nFARM"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.Active = true
    btn.Parent = sg
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Color3.fromRGB(255, 80, 80)
    stroke.Thickness = 2
    stroke.Transparency = 0.2

    local lockBtn = Instance.new("TextButton")
    lockBtn.Name = "Lock"
    lockBtn.Size = UDim2.new(0, 22, 0, 22)
    lockBtn.Position = UDim2.new(1, 2, 0, -2)
    lockBtn.AnchorPoint = Vector2.new(1, 0)
    lockBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    lockBtn.BackgroundTransparency = 0.3
    lockBtn.Text = "L"
    lockBtn.TextSize = 10
    lockBtn.Font = Enum.Font.GothamBold
    lockBtn.TextColor3 = Color3.new(1, 1, 1)
    lockBtn.Parent = btn
    Instance.new("UICorner", lockBtn).CornerRadius = UDim.new(1, 0)

    local locked = false
    lockBtn.MouseButton1Click:Connect(function()
        locked = not locked
        lockBtn.Text = locked and "X" or "L"
        lockBtn.BackgroundColor3 = locked
            and Color3.fromRGB(200, 50, 50)
            or Color3.fromRGB(60, 60, 60)
    end)

    local dragging, dragStart, startPos
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if locked then return end
            dragging = true
            dragStart = input.Position
            startPos = btn.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        btn.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local function refreshBtn()
        if GenFarm.Active then
            btn.BackgroundColor3 = Color3.fromRGB(20, 80, 30)
            btn.Text = "🔥\nON"
            stroke.Color = Color3.fromRGB(80, 255, 120)
        else
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            btn.Text = "🔥\nFARM"
            stroke.Color = Color3.fromRGB(255, 80, 80)
        end
    end

    local justDragged = false
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then justDragged = true end
        end
    end)
    btn.MouseButton1Click:Connect(function()
        if justDragged then justDragged = false; return end
        setGenFarm(not GenFarm.Active)
        refreshBtn()
        if WindUI then
            WindUI:Notify({
                Title = GenFarm.Active and "🔥 FARM ON" or "FARM OFF",
                Content = GenFarm.Active
                    and "Target gen terjauh → repair → escape → bypass gate."
                    or "Farm berhenti.",
                Icon = GenFarm.Active and "play" or "pause",
                Duration = 3,
            })
        end
    end)

    refreshBtn()
    -- refresh berkala biar sinkron sama toggle di menu
    task.spawn(function()
        while sg.Parent do
            task.wait(1)
            refreshBtn()
        end
    end)
end

-- Bikin tombol floating kalau di-set ON
if Config.GenFloatingButton then
    pcall(createFloatingFarmButton)
end

-- ============================================================================
--  AUTO RE-EXECUTE / REJOIN
--  Biar script otomatis jalan lagi pas pindah server atau rejoin.
-- ============================================================================

-- Cari fungsi queue_on_teleport dari berbagai executor
local function getQueueOnTeleport()
    if type(queue_on_teleport) == "function" then return queue_on_teleport end
    if type(queueonteleport) == "function" then return queueonteleport end
    if type(syn) == "table" and type(syn.queue_on_teleport) == "function" then return syn.queue_on_teleport end
    if type(fluxus) == "table" and type(fluxus.queue_on_teleport) == "function" then return fluxus.queue_on_teleport end
    if type(KRNL) == "table" and type(KRNL.queue_on_teleport) == "function" then return KRNL.queue_on_teleport end
    if type(getgenv) == "function" then
        local g = getgenv()
        if type(g) == "table" and type(g.queue_on_teleport) == "function" then return g.queue_on_teleport end
    end
    return nil
end

-- Ambil URL script (dari config atau getgenv)
local function getScriptUrl()
    local url = Config.ScriptUrl
    if (not url or url == "") and type(getgenv) == "function" then
        local g = getgenv()
        if type(g) == "table" and type(g.A2Hub_ScriptUrl) == "string" then
            url = g.A2Hub_ScriptUrl
        end
    end
    return url
end

-- Script yang bakal dijalankan di server berikutnya (load ulang A2Hub dari URL)
local function buildReexecScript()
    local url = getScriptUrl()
    if not url or url == "" then return nil end
    return string.format([[
        task.wait(3)
        local ok, err = pcall(function()
            local _compile = loadstring or load
            assert(type(_compile) == "function", "Executor tidak menyediakan loadstring/load")
            assert(type(game.HttpGet) == "function", "Executor tidak menyediakan game:HttpGet")
            local _fn, _err = _compile(game:HttpGet(%q))
            assert(type(_fn) == "function", tostring(_err))
            _fn()
        end)
        if not ok then warn("[A2 Hub] Auto re-execute gagal: " .. tostring(err)) end
    ]], url)
end

-- Queue script buat dijalankan di server berikutnya
local function queueReexec()
    if not Config.AutoReexec then return false, "Auto Re-execute sedang OFF" end
    local src = buildReexecScript()
    if not src then return false, "Script URL (RAW) masih kosong" end
    local qot = getQueueOnTeleport()
    if not qot then return false, "Executor tidak mendukung queue_on_teleport" end
    local ok = pcall(qot, src)
    return ok, ok and "Script di-queue, bakal jalan di server berikutnya" or "Gagal queue script"
end

-- Rejoin sekarang + queue re-execute
local function rejoinNow(force)
    -- [BARU] guard: biar gak rejoin dobel-dobel dalam waktu dekat
    if not force and State.LastRejoin and (tick() - State.LastRejoin) < 15 then
        return
    end
    State.LastRejoin = tick()
    queueReexec()
    task.spawn(function()
        task.wait(tonumber(Config.RejoinDelay) or 5)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end)
end

-- ============================================================================
--  AUTO EXECUTE (persistent, kayak folder "Auto Execute" di Delta)
--  Bikin "loader" yang bisa ditempel ke Delta/Auto Execute biar script
--  nyala sendiri tiap kali join game.
-- ============================================================================

-- Deteksi fungsi clipboard dari berbagai executor
local function getClipboardFn()
    if type(setclipboard) == "function" then return setclipboard end
    if type(toclipboard) == "function" then return toclipboard end
    if type(writeclipboard) == "function" then return writeclipboard end
    if type(set_clipboard) == "function" then return set_clipboard end
    if type(syn) == "table" and type(syn.write_clipboard) == "function" then
        return function(t) return syn.write_clipboard(t) end
    end
    if type(getgenv) == "function" then
        local g = getgenv()
        if type(g) == "table" then
            if type(g.setclipboard) == "function" then return g.setclipboard end
            if type(g.toclipboard) == "function" then return g.toclipboard end
            if type(g.writeclipboard) == "function" then return g.writeclipboard end
        end
    end
    return nil
end

local function copyText(text)
    local fn = getClipboardFn()
    if not fn then return false, "Executor tidak mendukung clipboard" end
    local ok = pcall(fn, text)
    return ok, ok and "Berhasil dicopy ke clipboard" or "Gagal copy ke clipboard"
end

-- Loader 1 baris (persis gaya video: loadstring + HttpGet)
local function buildLoaderLine()
    local url = getScriptUrl()
    if not url or url == "" then url = "URL_RAW_A2HUB_DISINI" end
    return string.format([[local _compile=loadstring or load; assert(type(_compile)=="function","Executor tidak menyediakan loadstring/load"); assert(type(game.HttpGet)=="function","Executor tidak menyediakan game:HttpGet"); local _fn,_err=_compile(game:HttpGet(%q)); assert(type(_fn)=="function",tostring(_err)); _fn()]], url)
end

-- Loader lengkap: tunggu game siap dulu, baru execute (biar gak gagal)
local function buildLoaderScript(nameOverride)
    local url = getScriptUrl()
    if not url or url == "" then url = "URL_RAW_A2HUB_DISINI" end
    local autoName = nameOverride or getAutoLoad() or ""
    return string.format([[
-- ============================================================
--  A2 HUB - Auto Execute Loader
--  Tempel file ini ke: Delta/Auto Execute/<nama>.lua
--  Script bakal otomatis jalan tiap kali kamu join game.
--  Config autoload: %s
-- ============================================================
getgenv().A2Hub_AutoLoadConfig = %q
getgenv().A2Hub_ScriptUrl = %q
task.wait(2)
repeat task.wait(0.5) until game:IsLoaded()
task.wait(1)
local ok, err = pcall(function()
    local _compile = loadstring or load
    assert(type(_compile) == "function", "Executor tidak menyediakan loadstring/load")
    assert(type(game.HttpGet) == "function", "Executor tidak menyediakan game:HttpGet")
    local _fn, _err = _compile(game:HttpGet(%q))
    assert(type(_fn) == "function", tostring(_err))
    _fn()
end)
if not ok then
    warn("[A2 Hub] Auto Execute gagal: " .. tostring(err))
end
]], autoName, autoName, url, url)
end

-- [BARU] Path kandidat folder "Auto Execute" (Delta & executor lain)
local AUTOEXEC_DIRS = {
    "Delta/AutoExecute",
    "delta/AutoExecute",
    "AutoExecute",
    "/storage/emulated/0/Delta/AutoExecute",
    "/sdcard/Delta/AutoExecute",
    "/storage/emulated/0/AutoExecute",
}

-- [BARU] Tulis file loader ke folder Auto Execute (biar tinggal join, auto jalan)
local function writeAutoExecFile(name, content)
    name = cleanConfigName((name and name ~= "") and name or (getAutoLoad() or "A2Hub"))
    if name == "" then name = "A2Hub" end
    content = content or buildLoaderScript(name)
    local written = nil
    for _, dir in ipairs(AUTOEXEC_DIRS) do
        local ok = pcall(function()
            if makefolder and isfolder and not isfolder(dir) then
                pcall(makefolder, dir)
            end
            writefile(dir .. "/" .. name .. ".lua", content)
        end)
        if ok then written = dir; break end
    end
    if written then
        return true, ("File '" .. name .. ".lua' dibuat di: " .. written)
    end
    return false, "Gagal nulis file (executor gak support writefile / folder gak ketemu). Pakai tombol Copy aja."
end

-- Cari server yang cocok (cari server yg ADA PLAYER-nya)
-- Return: list { { id = ..., players = ..., maxPlayers = ... }, ... }, jumlah
local function findAvailableServers()
    local placeId = game.PlaceId
    local strict  = {}   -- sesuai Min/Max Players
    local relaxed = {}   -- server yg ada player (>=1) tapi di luar Min/Max
    local anySrv  = {}   -- semua server (fallback terakhir)
    local cursor  = ""
    local pages   = 0

    local ok = pcall(function()
        while pages < 3 do
            pages = pages + 1
            local url = "https://games.roblox.com/v1/games/" .. placeId ..
                "/servers/Public?sortOrder=Asc&excludeFullGames=false&limit=100"
            if cursor ~= "" then
                url = url .. "&cursor=" .. cursor
            end

            local res = httpRequest({ Url = url, Method = "GET" })
            if not res then break end
            local code = res.StatusCode or res.Status or 0
            if code ~= 200 then break end

            local data = HttpService:JSONDecode(res.Body)
            for _, server in ipairs(data.data or {}) do
                local playerCount = tonumber(server.playing) or 0
                local maxPlayers  = tonumber(server.maxPlayers) or 0
                local serverId    = server.id
                if serverId and serverId ~= game.JobId and not State.Visited[serverId] then
                    local entry = { id = serverId, players = playerCount, maxPlayers = maxPlayers }
                    local notFull = (maxPlayers == 0) or (playerCount < maxPlayers)
                    if playerCount >= Config.MinPlayers and playerCount <= Config.MaxPlayers and notFull then
                        table.insert(strict, entry)
                    elseif playerCount >= 1 and notFull then
                        table.insert(relaxed, entry)
                    end
                    table.insert(anySrv, entry)
                end
            end

            cursor = data.nextPageCursor or ""
            if cursor == "" or #strict >= 15 then break end
        end
    end)

    if not ok then return {}, 0 end

    -- Prioritas: strict -> relaxed -> any
    local result = (#strict > 0) and strict or ((#relaxed > 0) and relaxed or anySrv)

    -- Urutkan: paling banyak player dulu (biar dapet server rame)
    table.sort(result, function(a, b) return (a.players or 0) > (b.players or 0) end)

    return result, #result
end

-- Teleport ke server lain (server yg ada player-nya)
local function teleportToServer()
    -- Queue auto re-execute biar script jalan lagi di server baru
    queueReexec()

    if game.JobId and game.JobId ~= "" then
        State.Visited[game.JobId] = true
    end

    local servers = findAvailableServers()
    if servers and #servers > 0 then
        -- Ambil salah satu dari 3 server paling rame (biar variasi tapi tetap rame)
        local pick = math.random(1, math.min(3, #servers))
        local chosen = servers[pick]
        State.Visited[chosen.id] = true
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen.id, LocalPlayer)
        end)
        if not ok then
            pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
        end
    else
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end
    task.wait(Config.TeleportDelay)
end

-- Teleport karakter ke finish line
local function teleportToFinishLine()
    local ok = pcall(function()
        local character = LocalPlayer.Character
        if not character then return end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local finishLine = findFinishLine(workspace)
        if not finishLine then return end

        local target = nil
        if finishLine:IsA("BasePart") then
            target = finishLine
        else
            for _, child in ipairs(finishLine:GetDescendants()) do
                if child:IsA("BasePart") then
                    target = child
                    break
                end
            end
        end
        if not target then return end

        hrp.CFrame = target.CFrame * CFrame.new(0, 2, 0)
    end)
    return ok
end

-- Ambil statistik player
-- [DIPERBAIKI] Sekarang baca dari ATTRIBUTE + leaderstats + variasi nama,
-- biar kalau nama attribute di game beda, stats tetap kebaca (gak selalu 0).
local function getPlayerStats()
    local stats = { screw = 0, exp = 0, level = 0 }
    pcall(function()
        local lp = LocalPlayer

        -- 1) Attribute utama (dipakai Violence District / base DAMEUNGRR)
        stats.screw = tonumber(lp:GetAttribute("Screws")) or 0
        stats.exp   = tonumber(lp:GetAttribute("EXP"))    or 0
        stats.level = tonumber(lp:GetAttribute("Level"))  or 0

        -- 2) Variasi nama attribute
        if stats.screw == 0 then stats.screw = tonumber(lp:GetAttribute("Screw")) or 0 end
        if stats.exp == 0   then stats.exp   = tonumber(lp:GetAttribute("Exp")) or tonumber(lp:GetAttribute("XP")) or tonumber(lp:GetAttribute("Experience")) or 0 end
        if stats.level == 0 then stats.level = tonumber(lp:GetAttribute("Lvl")) or 0 end

        -- 3) Fallback: leaderstats (kalau game pakai leaderstats)
        local ls = lp:FindFirstChild("leaderstats")
        if ls then
            local function pick(names)
                for _, n in ipairs(names) do
                    local v = ls:FindFirstChild(n)
                    if v and v:IsA("ValueBase") then return tonumber(v.Value) or 0 end
                end
                return nil
            end
            if stats.screw == 0 then stats.screw = pick({ "Screws", "Screw", "Money", "Coins", "Cash" }) or 0 end
            if stats.exp   == 0 then stats.exp   = pick({ "EXP", "Exp", "XP", "Experience" }) or 0 end
            if stats.level == 0 then stats.level = pick({ "Level", "Lvl" }) or 0 end
        end

        -- 4) [BARU] Fallback terakhir: scan semua NumberValue/IntValue di player
        --    (biar Level/EXP/Screws tetep kebaca walau nama-nya beda)
        if stats.screw == 0 or stats.exp == 0 or stats.level == 0 then
            for _, obj in ipairs(lp:GetDescendants()) do
                if obj:IsA("ValueBase") then
                    local n = tostring(obj.Name):lower()
                    local num = tonumber(obj.Value)
                    if num then
                        if stats.screw == 0 and (n:find("screw") or n:find("money") or n:find("coin") or n:find("cash")) then
                            stats.screw = num
                        elseif stats.exp == 0 and (n == "exp" or n == "xp" or n:find("experience")) then
                            stats.exp = num
                        elseif stats.level == 0 and (n == "level" or n == "lvl") then
                            stats.level = num
                        end
                    end
                end
            end
        end
    end)
    return stats
end

-- Scan atribut player untuk deteksi "secret"/item baru
local function scanSecrets()
    local keywords = {}
    for w in tostring(Config.SecretKeywords):gmatch("[^,]+") do
        keywords[#keywords + 1] = w:lower():gsub("^%s+", ""):gsub("%s+$", "")
    end

    local found = {}
    pcall(function()
        for name, value in pairs(LocalPlayer:GetAttributes()) do
            local lname = tostring(name):lower()
            for _, kw in ipairs(keywords) do
                if kw ~= "" and lname:find(kw, 1, true) then
                    found[name] = value
                    break
                end
            end
        end
    end)
    return found
end

-- Cek & lapor secret baru
local function checkNewSecrets()
    local found = scanSecrets()
    for name, value in pairs(found) do
        local key = tostring(name) .. "=" .. tostring(value)
        if not State.SecretsFound[key] then
            State.SecretsFound[key] = true
            reportSecret(tostring(name), tonumber(value) or 1)
            if WindUI then
                WindUI:Notify({
                    Title = "💎 SECRET DITEMUKAN!",
                    Content = tostring(name) .. " = " .. tostring(value),
                    Duration = 6,
                    Icon = "gem",
                })
            end
        end
    end
end

-- ============================================================================
--  [BARU] SCAN INVENTORY / GEAR (Backpack + Character + StarterGear + attributes)
--  Ini yang bikin item/gear muncul di webhook.
-- ============================================================================
local function scanInventory()
    local items = {}

    local function addContainer(container, tag)
        if not container then return end
        pcall(function()
            for _, obj in ipairs(container:GetChildren()) do
                if obj:IsA("Tool") then
                    items[obj.Name] = (items[obj.Name] or 0) + 1
                elseif obj:IsA("Accessory") then
                    local key = "[gear] " .. obj.Name
                    items[key] = (items[key] or 0) + 1
                elseif obj:IsA("Model") then
                    -- tool model / pet model (gabung per nama, biar equip/unequip gak bikin spam)
                    items[obj.Name] = (items[obj.Name] or 0) + 1
                end
            end
        end)
    end

    -- Karakter (tool yg lagi dipegang + aksesoris)
    addContainer(LocalPlayer.Character, "char")
    -- Backpack (semua tool yg dibawa)
    addContainer(LocalPlayer:FindFirstChild("Backpack"), "backpack")
    -- StarterGear (gear default)
    addContainer(LocalPlayer:FindFirstChild("StarterGear"), "gear")

    -- Attribute bernama item/gear/inventory (angka = jumlah)
    pcall(function()
        local kws = {}
        for w in tostring(Config.ItemKeywords or ""):gmatch("[^,]+") do
            kws[#kws + 1] = w:lower():gsub("^%s+", ""):gsub("%s+$", "")
        end
        for name, value in pairs(LocalPlayer:GetAttributes()) do
            local lname = tostring(name):lower()
            for _, kw in ipairs(kws) do
                if kw ~= "" and lname:find(kw, 1, true) then
                    if type(value) == "number" then
                        items["[stat] " .. tostring(name)] = value
                    elseif type(value) == "string" and value ~= "" then
                        items["[stat] " .. tostring(name)] = value
                    end
                    break
                end
            end
        end
    end)

    return items
end

-- Cek & lapor item/gear baru (baseline dulu biar gak spam pas awal)
local function checkNewItems()
    if not Config.ReportItems then return end
    local items = scanInventory()

    -- Baseline pertama: catat semua tanpa lapor (biar gak spam)
    if not State.ItemsInit then
        -- kalau inventory masih kosong (belum load), tunggu sampai ada isinya dulu
        local hasAny = false
        for _ in pairs(items) do hasAny = true; break end
        if not hasAny then return end
        State.ItemsInit = true
        for name, count in pairs(items) do
            State.ItemsFound[tostring(name) .. "=" .. tostring(count)] = true
        end
        -- Kirim snapshot sekali biar user tau isi inventory-nya
        if State.Connected then reportInventorySnapshot(items) end
        return
    end

    for name, count in pairs(items) do
        local key = tostring(name) .. "=" .. tostring(count)
        if not State.ItemsFound[key] then
            State.ItemsFound[key] = true
            reportItem(tostring(name), tonumber(count) or 1)
            if WindUI then
                WindUI:Notify({
                    Title = "\ud83c\udf92 ITEM / GEAR BARU!",
                    Content = tostring(name) .. " x" .. tostring(count),
                    Duration = 6,
                    Icon = "package",
                })
            end
        end
    end
end

-- ============================================================================
--  UI — WINDUI
-- ============================================================================
local Window = WindUI:CreateWindow({
    Title = "A2  |  Violence District",
    Author = "A2 Hub • Auto Farm",
    Folder = "A2Hub",
    Icon = "zap",
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "Buka A2 Hub",
        Enabled = true,
        Draggable = true,
        Scale = 0.5,
        Color = ColorSequence.new(colorFromHex("#30FF6A"), colorFromHex("#00C2FF")),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})

-- Safety net: kalau versi UI dari GitHub belum di-guard (auto-mount nyala),
-- buang window stray "A2UI" yang bukan punya A2Hub. Dijalankan 2x (timing).
task.spawn(function()
    for _ = 1, 2 do
        task.wait(0.7)
        pcall(function()
            local gui = Window and Window.Gui
            local par = gui and gui.Parent
            if par then
                for _, g in ipairs(par:GetChildren()) do
                    if g:IsA("ScreenGui") and g.Name == "A2UI" and g ~= gui then
                        g:Destroy()
                    end
                end
            end
        end)
    end
end)

Window:Tag({
    Title = "v1.0 • A2",
    Icon = "github",
    Color = colorFromHex("#1c1c1c"),
    Border = true,
})

-- Warna
local Green  = colorFromHex("#10C550")
local Blue   = colorFromHex("#257AF7")
local Purple = colorFromHex("#7775F2")
local Yellow = colorFromHex("#ECA201")
local Red    = colorFromHex("#EF4F1D")
local Grey   = colorFromHex("#83889E")

-- ===================== TAB: WEBHOOK (KONEKSI DULU) =====================
local WebhookTab = Window:Tab({
    Title = "Webhook",
    Desc = "Hubungkan Discord dulu",
    Icon = "link",
    IconColor = Blue,
    IconShape = "Square",
    Border = true,
})

local WebhookSection = WebhookTab:Section({ Title = "🔗 Koneksi Discord" })

local statusParagraph
statusParagraph = WebhookSection:Paragraph({
    Title = "Status: ❌ Belum Terhubung",
    Desc = "Tempel URL webhook Discord di bawah, lalu klik CONNECT.",
    Image = "solar:info-circle-bold",
    Color = "Red",
})

WebhookTab:Space()

local webhookInput
webhookInput = WebhookTab:Input({
    Title = "Discord Webhook URL",
    Desc = "Webhook untuk memantau hasil farm",
    Placeholder = "https://discord.com/api/webhooks/...",
    Value = Config.WebhookUrl,
    Callback = function(value)
        Config.WebhookUrl = value
        saveConfig()
    end,
})

WebhookTab:Space()

WebhookTab:Button({
    Title = "CONNECT & TEST",
    Desc = "Uji koneksi webhook lalu aktifkan monitoring",
    Color = Green,
    Justify = "Center",
    Icon = "plug-zap",
    Callback = function()
        if not Config.WebhookUrl or Config.WebhookUrl == "" then
            WindUI:Notify({ Title = "Gagal", Content = "Webhook masih kosong!", Icon = "circle-x", Duration = 4 })
            return
        end
        local ok, msg = testWebhook()
        if ok then
            State.Connected = true
            pcall(checkNewItems)   -- [BARU] kirim snapshot inventory
            State.StatusText = "✅ Terhubung — siap farm!"
            WindUI:Notify({ Title = "Terhubung!", Content = "Webhook aktif. Sekarang aktifkan Auto Farm.", Icon = "check", Duration = 5 })
            if statusParagraph then
                pcall(function()
                    statusParagraph:SetTitle("Status: ✅ Terhubung")
                    statusParagraph:SetDesc("Webhook aktif! Buka tab Farm lalu aktifkan Auto Farm.")
                end)
            end
        else
            State.Connected = false
            WindUI:Notify({ Title = "Gagal terhubung", Content = tostring(msg), Icon = "circle-x", Duration = 5 })
            if statusParagraph then
                pcall(function()
                    statusParagraph:SetTitle("Status: ❌ Gagal Terhubung")
                    statusParagraph:SetDesc("Cek lagi URL webhook. (" .. tostring(msg) .. ")")
                end)
            end
        end
    end,
})

WebhookTab:Space()

WebhookTab:Button({
    Title = "Kirim Test Embed",
    Desc = "Cek apakah webhook menerima pesan",
    Color = Blue,
    Justify = "Center",
    Icon = "send",
    Callback = function()
        local ok, msg = testWebhook()
        WindUI:Notify({
            Title = ok and "Terkirim!" or "Gagal",
            Content = tostring(msg),
            Icon = ok and "check" or "circle-x",
            Duration = 4,
        })
    end,
})

WebhookTab:Space()

WebhookTab:Toggle({
    Title = "Auto Report ke Discord",
    Desc = "Kirim hasil tiap run selesai",
    Value = Config.AutoReport,
    Callback = function(v)
        Config.AutoReport = v
        saveConfig()
    end,
})

WebhookTab:Space()

-- [BARU] Toggle monitor perubahan real-time
WebhookTab:Toggle({
    Title = "Monitor Perubahan (Level / EXP / Screws)",
    Desc = "Kirim notif tiap ada perubahan stats (real-time, gak nunggu run selesai)",
    Value = Config.ChangeMonitor,
    Callback = function(v)
        Config.ChangeMonitor = v
        saveConfig()
        WindUI:Notify({
            Title = v and "Monitor ON" or "Monitor OFF",
            Content = v and "Setiap perubahan bakal dikirim ke Discord." or "Monitor perubahan dimatikan.",
            Icon = v and "activity" or "pause",
            Duration = 4,
        })
    end,
})

WebhookTab:Space()

WebhookTab:Toggle({
    Title = "Report Secret / Item Baru",
    Desc = "Kirim notifikasi kalau dapat secret",
    Value = Config.ReportSecrets,
    Callback = function(v)
        Config.ReportSecrets = v
        saveConfig()
    end,
})

WebhookTab:Space()

-- [BARU] Toggle report item / gear / inventory
WebhookTab:Toggle({
    Title = "Report Item / Gear / Inventory",
    Desc = "Kirim item, gear, tool & isi inventory ke Discord (snapshot + tiap ada item baru)",
    Value = Config.ReportItems,
    Callback = function(v)
        Config.ReportItems = v
        saveConfig()
        if v then
            -- kirim snapshot sekarang biar user langsung liat isi inventory
            pcall(function() reportInventorySnapshot(scanInventory()) end)
        end
    end,
})

WebhookTab:Space()

WebhookTab:Button({
    Title = "Kirim Inventory Sekarang",
    Desc = "Kirim snapshot item/gear/inventory ke Discord",
    Color = Blue,
    Justify = "Center",
    Icon = "package",
    Callback = function()
        local ok, msg
        if not State.Connected then
            ok, msg = false, "Webhook belum terhubung"
        else
            ok = pcall(function() reportInventorySnapshot(scanInventory()) end)
            msg = ok and "Snapshot inventory terkirim" or "Gagal kirim"
        end
        WindUI:Notify({ Title = ok and "Terkirim!" or "Gagal", Content = tostring(msg), Icon = ok and "check" or "circle-x", Duration = 4 })
    end,
})

-- ===================== SECTION: AUTO RE-EXECUTE / REJOIN =====================
WebhookTab:Space()

local ReexecSection = WebhookTab:Section({ Title = "♻️ Auto Re-execute & Rejoin" })

ReexecSection:Paragraph({
    Title = "Biar bot nyala lagi otomatis",
    Desc = "Pas pindah server / rejoin, script bakal dijalankan ulang otomatis (pakai queue_on_teleport).",
    Image = "solar:refresh-circle-bold",
    Color = "Blue",
})

ReexecSection:Input({
    Title = "Script URL (RAW)",
    Desc = "Link raw A2Hub.lua — dipakai buat auto-execute ulang",
    Placeholder = "https://raw.githubusercontent.com/.../A2Hub.lua",
    Value = Config.ScriptUrl,
    Callback = function(v)
        Config.ScriptUrl = v
        saveConfig()
    end,
})

ReexecSection:Toggle({
    Title = "Auto Re-execute (pindah server / rejoin)",
    Desc = "Jalankan ulang script otomatis di server berikutnya",
    Value = Config.AutoReexec,
    Callback = function(v)
        Config.AutoReexec = v
        saveConfig()
        if v then
            local ok, msg = queueReexec()
            WindUI:Notify({ Title = ok and "Re-execute aktif" or "Catatan", Content = tostring(msg), Icon = ok and "check" or "info", Duration = 4 })
        end
    end,
})

ReexecSection:Toggle({
    Title = "Auto Rejoin kalau disconnect",
    Desc = "Rejoin otomatis kalau koneksi ke-disconnect",
    Value = Config.AutoRejoin,
    Callback = function(v)
        Config.AutoRejoin = v
        saveConfig()
    end,
})

ReexecSection:Button({
    Title = "Rejoin & Re-execute Sekarang",
    Desc = "Queue ulang script lalu rejoin server",
    Color = Purple,
    Justify = "Center",
    Icon = "refresh-cw",
    Callback = function()
        local ok, msg = queueReexec()
        WindUI:Notify({ Title = ok and "Re-execute di-queue" or "Gagal", Content = tostring(msg), Icon = ok and "check" or "circle-x", Duration = 4 })
        rejoinNow()
    end,
})

ReexecSection:Button({
    Title = "Queue Re-execute (tanpa rejoin)",
    Desc = "Set script biar jalan di server berikutnya",
    Color = Blue,
    Justify = "Center",
    Icon = "list-plus",
    Callback = function()
        local ok, msg = queueReexec()
        WindUI:Notify({ Title = ok and "Berhasil di-queue" or "Gagal", Content = tostring(msg), Icon = ok and "check" or "circle-x", Duration = 4 })
    end,
})

-- ===================== TAB: AUTO EXECUTE =====================
local ExecTab = Window:Tab({
    Title = "Auto Execute",
    Desc = "Nyala sendiri tiap join (Delta)",
    Icon = "rocket",
    IconColor = Yellow,
    IconShape = "Square",
    Border = true,
})

local ExecSection = ExecTab:Section({ Title = "🚀 Auto Execute (Delta)" })

ExecSection:Paragraph({
    Title = "Biar script nyala sendiri tiap masuk game",
    Desc = "Persis kayak di video: script ini bikin 'loader' yang kamu tempel ke folder Auto Execute Delta. Abis itu tiap join game, A2 Hub otomatis kebuka + farm jalan sendiri.",
    Image = "solar:rocket-bold",
    Color = "Yellow",
})

ExecSection:Input({
    Title = "Script URL (RAW)",
    Desc = "Link RAW A2Hub.lua (GitHub raw / pastefy raw / dll)",
    Placeholder = "https://raw.githubusercontent.com/.../A2Hub.lua",
    Value = Config.ScriptUrl,
    Callback = function(v)
        Config.ScriptUrl = v
        saveConfig()
    end,
})

ExecSection:Toggle({
    Title = "Set as Auto Load",
    Desc = "Pas auto-execute jalan, menu A2 Hub otomatis kebuka + config tersimpan langsung dipakai",
    Value = Config.AutoLoadConfig,
    Callback = function(v)
        Config.AutoLoadConfig = v
        saveConfig()
    end,
})

ExecSection:Toggle({
    Title = "Auto Connect Webhook",
    Desc = "Otomatis hubungin webhook pas script jalan (kalau URL udah disimpan)",
    Value = Config.AutoConnect,
    Callback = function(v)
        Config.AutoConnect = v
        saveConfig()
    end,
})

ExecSection:Toggle({
    Title = "Auto Escape (tutup menu pas farm mulai)",
    Desc = "Tunggu sampai farm beneran jalan, baru menu otomatis ditutup",
    Value = Config.AutoEscape,
    Callback = function(v)
        Config.AutoEscape = v
        saveConfig()
    end,
})

ExecSection:Button({
    Title = "📋 Copy Auto Execute Script",
    Desc = "Copy loader lengkap buat ditempel ke folder Auto Execute Delta",
    Color = Green,
    Justify = "Center",
    Icon = "clipboard-copy",
    Callback = function()
        local ok, msg = copyText(buildLoaderScript())
        WindUI:Notify({
            Title = ok and "Loader dicopy!" or "Gagal copy",
            Content = ok and "Tempel di Delta/Auto Execute (lihat langkah di bawah)." or tostring(msg),
            Icon = ok and "check" or "circle-x",
            Duration = 6,
        })
    end,
})

ExecSection:Button({
    Title = "📋 Copy Loader Sederhana (1 baris)",
    Desc = "Versi singkat: loadstring(game:HttpGet(...))()",
    Color = Blue,
    Justify = "Center",
    Icon = "clipboard",
    Callback = function()
        local ok, msg = copyText(buildLoaderLine())
        WindUI:Notify({
            Title = ok and "Loader dicopy!" or "Gagal copy",
            Content = ok and buildLoaderLine() or tostring(msg),
            Icon = ok and "check" or "circle-x",
            Duration = 6,
        })
    end,
})

ExecSection:Space()

ExecSection:Button({
    Title = "\ud83d\udcc1 Buat File di Folder AutoExecute",
    Desc = "Bikin file loader langsung di Delta/AutoExecute (pakai nama config autoload)",
    Color = Green,
    Justify = "Center",
    Icon = "folder-plus",
    Callback = function()
        local name = getAutoLoad() or "A2Hub"
        local ok, msg = writeAutoExecFile(name)
        WindUI:Notify({
            Title = ok and "File AutoExecute dibuat!" or "Gagal",
            Content = tostring(msg),
            Icon = ok and "check" or "circle-x",
            Duration = 8,
        })
    end,
})

ExecSection:Button({
    Title = "🔗 Copy Link Discord A2",
    Desc = "discord.gg/b7hJ4DaGz",
    Color = Purple,
    Justify = "Center",
    Icon = "link",
    Callback = function()
        local ok = copyText("https://discord.gg/b7hJ4DaGz")
        WindUI:Notify({ Title = "Discord A2", Content = ok and "discord.gg/b7hJ4DaGz (udah dicopy)" or "Gagal copy link", Icon = "link", Duration = 5 })
    end,
})

ExecSection:Paragraph({
    Title = "📖 STEP BY STEP (kaya di video)",
    Desc = "1. Tempel Script URL (RAW) di atas.\n2. Buka tab Config → isi Config Name → klik 'Create Config'.\n3. Pilih config di 'Config List' → klik 'Set as Auto Load'.\n4. Klik 'Copy Script' (di tab Config / tombol di atas).\n5. Buka app ZArchiver.\n6. Masuk folder 'Delta' → folder 'Auto Execute'.\n7. Klik tombol + (bikin file baru), kasih nama bebas (contoh: a2hub.lua).\n8. Buka file itu, tempel script yang tadi dicopy, lalu Save.\n9. Buka Roblox, join game (private/public server).\n10. Tunggu game mulai → script otomatis jalan + config auto load. Menu kebuka sendiri, terus nutup otomatis pas farm mulai (kalau Auto Escape ON).",
    Image = "solar:list-check-bold",
    Color = "Blue",
})

-- ===================== TAB: FARM =====================
local FarmTab = Window:Tab({
    Title = "Auto Farm",
    Desc = "Pengaturan farming",
    Icon = "tractor",
    IconColor = Green,
    IconShape = "Square",
    Border = true,
})

local FarmSection = FarmTab:Section({ Title = "🌾 Kontrol Utama" })

local farmToggle
farmToggle = FarmSection:Toggle({
    Title = "AUTO FARM",
    Desc = "Farm otomatis (perlu webhook terhubung)",
    Value = Config.AutoFarm,
    Callback = function(v)
        if v and not State.Connected then
            WindUI:Notify({
                Title = "Belum terhubung!",
                Content = "Hubungkan webhook dulu di tab Webhook.",
                Icon = "triangle-alert",
                Duration = 5,
            })
            task.defer(function()
                pcall(function() farmToggle:Set(false) end)
            end)
            return
        end
        Config.AutoFarm = v
        State.Farming = v
        saveConfig()
        -- [BARU] biar gak bentrok sama Generator Farm
        if v and GenFarm.Active then setGenFarm(false) end
        WindUI:Notify({
            Title = v and "Auto Farm ON" or "Auto Farm OFF",
            Content = v and "Bot mulai farming..." or "Bot berhenti.",
            Icon = v and "play" or "pause",
            Duration = 3,
        })
    end,
})

FarmTab:Space()

FarmSection:Toggle({
    Title = "Auto Teleport Server",
    Desc = "Pindah server otomatis",
    Value = Config.AutoTeleport,
    Callback = function(v) Config.AutoTeleport = v; saveConfig() end,
})

FarmTab:Space()

FarmSection:Toggle({
    Title = "Auto Finish Line",
    Desc = "Teleport ke garis finish",
    Value = Config.AutoFinishLine,
    Callback = function(v) Config.AutoFinishLine = v; saveConfig() end,
})

FarmTab:Space()

-- [BARU] Tunggu game mulai dulu (kaya di video)
FarmSection:Toggle({
    Title = "Tunggu Game Mulai Dulu",
    Desc = "Bot nunggu round beneran mulai sebelum farm (gak maksa pas loading/spectator)",
    Value = Config.WaitForGameStart,
    Callback = function(v) Config.WaitForGameStart = v; saveConfig() end,
})

FarmTab:Space()

-- [BARU] Trigger ProximityPrompt + klik tombol action
FarmSection:Toggle({
    Title = "Trigger Prompt + Klik Action",
    Desc = "Trigger ProximityPrompt & klik tombol action pas farm (biar repair/escape jalan)",
    Value = Config.UsePromptTrigger,
    Callback = function(v) Config.UsePromptTrigger = v; saveConfig() end,
})

FarmTab:Space()

-- ===================== SECTION: GENERATOR FARM (FARM beneran) =====================
local GenSection = FarmTab:Section({ Title = "🔥 Generator Farm (FARM)" })

local genFarmToggle
genFarmToggle = GenSection:Toggle({
    Title = "🔥 FARM (Generator)",
    Desc = "Target gen TERJAUH → repair → instant skillcheck → escape → bypass gate",
    Value = Config.GenFarmEnabled,
    Callback = function(v)
        if GenFarm._syncing then return end
        setGenFarm(v)
        -- [BARU] biar gak bentrok sama Auto Farm lama
        if v then
            Config.AutoFarm = false
            State.Farming = false
            saveConfig()
            if farmToggle then pcall(function() farmToggle:Set(false, false) end) end
        end
        WindUI:Notify({
            Title = v and "🔥 FARM ON" or "FARM OFF",
            Content = v and "Bot cari gen terjauh & repair..." or "Farm generator berhenti.",
            Icon = v and "play" or "pause",
            Duration = 3,
        })
    end,
})

-- Sinkron toggle kalau diubah dari tombol floating
GenFarmSync.fn = function()
    if genFarmToggle then pcall(function() genFarmToggle:Set(GenFarm.Active, false) end) end
end

FarmTab:Space()

local genStatusParagraph
genStatusParagraph = GenSection:Paragraph({
    Title = "📋 Status Generator Farm",
    Desc = "idle",
    Image = "solar:fire-bold",
    Color = "Red",
})

-- Live update status
task.spawn(function()
    while true do
        task.wait(1)
        if genStatusParagraph then
            local txt
            if GenFarm.Active then
                txt = "🔥 AKTIF — " .. tostring(GenFarm.Status) ..
                    "  (gen " .. tostring(GenFarm.Count) .. "/" .. tostring(Config.GenTargetCount or 1) .. ")"
            else
                txt = "idle — aktifkan toggle di atas atau tombol 🔥 FARM di layar"
            end
            pcall(function() genStatusParagraph:SetDesc(txt) end)
        end
    end
end)

FarmTab:Space()

GenSection:Slider({
    Title = "Target Gen (sebelum escape)",
    Step = 1,
    Value = { Min = 1, Max = 8, Default = Config.GenTargetCount },
    Callback = function(v) Config.GenTargetCount = v; saveConfig() end,
})

GenSection:Space()

GenSection:Slider({
    Title = "Radius Deteksi Player",
    Step = 1,
    Value = { Min = 10, Max = 200, Default = Config.GenFarmRadius },
    Callback = function(v) Config.GenFarmRadius = v; saveConfig() end,
})

GenSection:Space()

GenSection:Slider({
    Title = "Hop Cooldown (detik)",
    Step = 0.1,
    Value = { Min = 0.2, Max = 5, Default = Config.GenFarmHopCD },
    Callback = function(v) Config.GenFarmHopCD = v; saveConfig() end,
})

FarmTab:Space()

GenSection:Toggle({
    Title = "Target Gen Terjauh",
    Desc = "Pilih gen paling jauh dulu (kaya di video)",
    Value = Config.GenFarthest,
    Callback = function(v) Config.GenFarthest = v; saveConfig() end,
})

GenSection:Space()

GenSection:Toggle({
    Title = "Escape + Bypass Gate",
    Desc = "Setelah target gen kelar → teleport ke gate → bypass (ESCAPED)",
    Value = Config.GenEscapeAfter,
    Callback = function(v) Config.GenEscapeAfter = v; Config.GenBypassGate = v; saveConfig() end,
})

GenSection:Space()

GenSection:Toggle({
    Title = "Instant Skillcheck",
    Desc = "Auto selesaiin skillcheck repair",
    Value = Config.GenInstantSkill,
    Callback = function(v) Config.GenInstantSkill = v; saveConfig() end,
})

GenSection:Space()

GenSection:Toggle({
    Title = "Auto Repair (fire RepairEvent)",
    Desc = "Kirim repair ke server otomatis",
    Value = Config.GenAutoRepair,
    Callback = function(v) Config.GenAutoRepair = v; saveConfig() end,
})

GenSection:Space()

GenSection:Toggle({
    Title = "Hop kalau Player Deket",
    Desc = "Pindah ke gen lain kalau ada player/killer deket",
    Value = Config.GenHopIfPlayerNear,
    Callback = function(v) Config.GenHopIfPlayerNear = v; saveConfig() end,
})

GenSection:Space()

GenSection:Toggle({
    Title = "Auto Loop (ulang tiap round)",
    Desc = "Abis escape → tunggu round baru → farm lagi otomatis",
    Value = Config.GenAutoLoop,
    Callback = function(v) Config.GenAutoLoop = v; saveConfig() end,
})

GenSection:Space()

GenSection:Toggle({
    Title = "Auto Ganti Server (Server Hop)",
    Desc = "Abis escape \u2192 langsung ganti server otomatis cari yg ada player",
    Value = Config.GenAutoChangeServer,
    Callback = function(v) Config.GenAutoChangeServer = v; saveConfig() end,
})

GenSection:Space()

GenSection:Toggle({
    Title = "Auto Rejoin kalau Mati",
    Desc = "Karakter mati pas farm \u2192 rejoin server otomatis",
    Value = Config.GenRejoinOnDeath,
    Callback = function(v) Config.GenRejoinOnDeath = v; saveConfig() end,
})

GenSection:Space()

GenSection:Toggle({
    Title = "Auto Rejoin kalau Farm Macet",
    Desc = "Farm gak ada progress (nyangkut) \u2192 rejoin server otomatis",
    Value = Config.GenRejoinOnStall,
    Callback = function(v) Config.GenRejoinOnStall = v; saveConfig() end,
})

GenSection:Space()

GenSection:Toggle({
    Title = "Tombol Floating FARM",
    Desc = "Tampilkan tombol 🔥 FARM di layar (draggable)",
    Value = Config.GenFloatingButton,
    Callback = function(v)
        Config.GenFloatingButton = v
        saveConfig()
        if v then
            pcall(createFloatingFarmButton)
        else
            pcall(function()
                local parent = (gethui and gethui()) or game:GetService("CoreGui")
                local old = parent and parent:FindFirstChild("A2FarmBtnGui")
                if old then old:Destroy() end
            end)
        end
    end,
})

FarmTab:Space()

GenSection:Button({
    Title = "🔎 Cari Server (yang ada player)",
    Desc = "Cek berapa server rame yang ketemu, lalu teleport",
    Color = Yellow,
    Justify = "Center",
    Icon = "search",
    Callback = function()
        task.spawn(function()
            local servers, count = findAvailableServers()
            if count and count > 0 then
                local top = servers[1]
                WindUI:Notify({
                    Title = "🔎 Ketemu " .. count .. " server",
                    Content = "Server paling rame: " .. tostring(top.players) .. " player. Teleport...",
                    Icon = "check",
                    Duration = 5,
                })
            else
                WindUI:Notify({
                    Title = "Gak ada server ketemu",
                    Content = "Fallback: teleport biasa.",
                    Icon = "triangle-alert",
                    Duration = 5,
                })
            end
            teleportToServer()
        end)
    end,
})

FarmTab:Space()

local SettingsSection = FarmTab:Section({ Title = "⚙️ Pengaturan" })

SettingsSection:Slider({
    Title = "Min Players",
    Step = 1,
    Value = { Min = 0, Max = 30, Default = Config.MinPlayers },
    Callback = function(v) Config.MinPlayers = v; saveConfig() end,
})

SettingsSection:Space()

SettingsSection:Slider({
    Title = "Max Players",
    Step = 1,
    Value = { Min = 1, Max = 50, Default = Config.MaxPlayers },
    Callback = function(v) Config.MaxPlayers = v; saveConfig() end,
})

SettingsSection:Space()

SettingsSection:Slider({
    Title = "Teleport Delay (detik)",
    Step = 1,
    Value = { Min = 1, Max = 15, Default = Config.TeleportDelay },
    Callback = function(v) Config.TeleportDelay = v; saveConfig() end,
})

FarmTab:Space()

FarmTab:Button({
    Title = "Paksa Teleport Server",
    Color = Yellow,
    Justify = "Center",
    Icon = "shuffle",
    Callback = function()
        task.spawn(function() teleportToServer() end)
        WindUI:Notify({ Title = "Teleport", Content = "Mencari server...", Icon = "shuffle", Duration = 3 })
    end,
})

FarmTab:Space()

FarmTab:Button({
    Title = "Teleport ke Finish Line",
    Color = Purple,
    Justify = "Center",
    Icon = "flag",
    Callback = function()
        local ok = teleportToFinishLine()
        WindUI:Notify({
            Title = ok and "Berhasil" or "Gagal",
            Content = ok and "Teleport ke finish line." or "Finish line tidak ditemukan.",
            Icon = ok and "check" or "circle-x",
            Duration = 3,
        })
    end,
})

-- ===================== TAB: STATS =====================
local StatsTab = Window:Tab({
    Title = "Stats",
    Desc = "Statistik farm",
    Icon = "bar-chart-3",
    IconColor = Yellow,
    IconShape = "Square",
    Border = true,
})

local StatsSection = StatsTab:Section({ Title = "📊 Statistik" })

local statsParagraph
statsParagraph = StatsSection:Paragraph({
    Title = "Memuat...",
    Desc = "Tekan Refresh untuk memperbarui.",
    Image = "solar:chart-bold",
    Color = "Blue",
})

StatsTab:Space()

local function refreshStats()
    local s = getPlayerStats()
    State.LastStats = s
    local text = string.format(
        "🔩 Screws : %d\n⭐ EXP : %d\n🏆 Level : %d\n\n🔁 Total Run : %d\n📦 Total Screws (farm) : %d\n💎 Secret ditemukan : %d",
        s.screw, s.exp, s.level, State.Runs, State.TotalScrews, (function()
            local c = 0
            for _ in pairs(State.SecretsFound) do c = c + 1 end
            return c
        end)()
    )
    if statsParagraph then
        pcall(function()
            statsParagraph:SetTitle("Statistik Player")
            statsParagraph:SetDesc(text)
        end)
    end
end

StatsTab:Button({
    Title = "Refresh Stats",
    Color = Blue,
    Justify = "Center",
    Icon = "refresh-cw",
    Callback = refreshStats,
})

StatsTab:Space()

StatsTab:Button({
    Title = "Kirim Stats Sekarang ke Discord",
    Color = Green,
    Justify = "Center",
    Icon = "send",
    Callback = function()
        local s = getPlayerStats()
        reportRun(s, { screw = 0, exp = 0, level = 0 })
        WindUI:Notify({ Title = "Terkirim", Content = "Stats dikirim ke Discord.", Icon = "check", Duration = 3 })
    end,
})

StatsTab:Space()

StatsTab:Button({
    Title = "Reset Statistik",
    Color = Red,
    Justify = "Center",
    Icon = "trash-2",
    Callback = function()
        State.Runs = 0
        State.TotalScrews = 0
        State.TotalEXP = 0
        State.TotalLevel = 0
        State.SecretsFound = {}
        refreshStats()
        WindUI:Notify({ Title = "Reset", Content = "Statistik direset.", Icon = "refresh-cw", Duration = 3 })
    end,
})

-- ===================== TAB: CONFIG =====================
local ConfigTab = Window:Tab({
    Title = "Config",
    Desc = "Simpan / muat setelan",
    Icon = "settings",
    IconColor = Grey,
    IconShape = "Square",
    Border = true,
})

ConfigTab:Section({ Title = "💾 Config Manager" })

-- Variabel pelacak (dideklarasi di atas biar bisa diakses semua callback)
local configName = ""
local selectedConfig = nil
local configDropdown
local configStatus

local ConfigSection = ConfigTab:Section({ Title = "📁 Buat / Pilih Config" })

ConfigSection:Input({
    Title = "Config Name",
    Desc = "Nama config baru (bebas, contoh: farm1)",
    Placeholder = "farm1",
    Value = "",
    Callback = function(v) configName = v end,
})

ConfigSection:Space()

ConfigSection:Button({
    Title = "Create Config",
    Desc = "Simpan setelan sekarang ke nama di atas (+ otomatis jadi Auto Load)",
    Color = Green,
    Justify = "Center",
    Icon = "file-plus",
    Callback = function()
        local ok, msg = saveNamedConfig(configName)
        if ok then
            -- Auto set as autoload (biar auto-execute langsung pakai config ini)
            setAutoLoad(configName)
            selectedConfig = configName
            if configDropdown then
                pcall(function() configDropdown:Refresh(listConfigs()) end)
                pcall(function() configDropdown:Select(configName) end)
            end
            if configStatus then
                pcall(function() configStatus:SetDesc("Current config set: " .. tostring(configName) .. " (auto load)") end)
            end
        end
        WindUI:Notify({
            Title = ok and "Config Dibuat + Auto Load" or "Gagal",
            Content = tostring(msg),
            Icon = ok and "check" or "circle-x",
            Duration = 4,
        })
    end,
})

ConfigSection:Space()

configDropdown = ConfigSection:Dropdown({
    Title = "Config List",
    Desc = "Pilih config yang tersimpan",
    Values = listConfigs(),
    Value = nil,
    SearchBarEnabled = true,
    Callback = function(v) selectedConfig = v end,
})

ConfigSection:Space()

ConfigSection:Button({
    Title = "Load Config",
    Desc = "Muat setelan dari config terpilih",
    Color = Blue,
    Justify = "Center",
    Icon = "download",
    Callback = function()
        local ok, msg = loadNamedConfig(selectedConfig)
        WindUI:Notify({ Title = ok and "Config Dimuat" or "Gagal", Content = tostring(msg), Icon = ok and "check" or "circle-x", Duration = 4 })
        if ok and configStatus then pcall(function() configStatus:SetDesc("Loaded config '" .. tostring(selectedConfig) .. "'") end) end
    end,
})

ConfigSection:Space()

ConfigSection:Button({
    Title = "Overwrite Config",
    Desc = "Timpa config terpilih dengan setelan sekarang",
    Color = Yellow,
    Justify = "Center",
    Icon = "save",
    Callback = function()
        local ok, msg = saveNamedConfig(selectedConfig)
        WindUI:Notify({ Title = ok and "Ditimpa" or "Gagal", Content = tostring(msg), Icon = ok and "check" or "circle-x", Duration = 4 })
    end,
})

ConfigSection:Space()

ConfigSection:Button({
    Title = "Delete Config",
    Desc = "Hapus config terpilih",
    Color = Red,
    Justify = "Center",
    Icon = "trash-2",
    Callback = function()
        local ok, msg = deleteNamedConfig(selectedConfig)
        WindUI:Notify({ Title = ok and "Dihapus" or "Gagal", Content = tostring(msg), Icon = ok and "check" or "circle-x", Duration = 4 })
        if ok and configDropdown then pcall(function() configDropdown:Refresh(listConfigs()) end) end
        selectedConfig = nil
    end,
})

ConfigSection:Space()

ConfigSection:Button({
    Title = "Refresh List",
    Desc = "Muat ulang daftar config",
    Color = Grey,
    Justify = "Center",
    Icon = "refresh-cw",
    Callback = function()
        if configDropdown then pcall(function() configDropdown:Refresh(listConfigs()) end) end
        WindUI:Notify({ Title = "Refresh", Content = "Daftar config dimuat ulang.", Icon = "refresh-cw", Duration = 3 })
    end,
})

ConfigSection:Space()

ConfigSection:Button({
    Title = "Set as Auto Load",
    Desc = "Config terpilih bakal otomatis dipakai tiap script jalan",
    Color = Purple,
    Justify = "Center",
    Icon = "pin",
    Callback = function()
        local ok, msg = setAutoLoad(selectedConfig)
        WindUI:Notify({ Title = ok and "Auto Load Aktif" or "Gagal", Content = tostring(msg), Icon = ok and "check" or "circle-x", Duration = 4 })
        if configStatus then pcall(function() configStatus:SetDesc("Current config set: " .. tostring(selectedConfig) .. " (auto load)") end) end
    end,
})

ConfigTab:Space()

configStatus = ConfigTab:Paragraph({
    Title = "Status Config",
    Desc = "Current config set: " .. tostring(getAutoLoad() or "belum ada"),
    Image = "solar:folder-bold",
    Color = "Blue",
})

ConfigTab:Space()

-- ===================== SECTION: AUTO EXECUTE (menu helper) =====================
local AutoExecSection = ConfigTab:Section({ Title = "🚀 Auto Execute (Delta)" })

AutoExecSection:Paragraph({
    Title = "📖 Cara bikin Auto Execute",
    Desc = "1. Isi Config Name di atas → Create Config.\n2. Pilih config di Config List → Set as Auto Load.\n3. Klik 'Copy Script Auto Execute' di bawah.\n4. Buka ZArchiver → folder Delta → Auto Execute → bikin file baru (nama bebas, mis. afk).\n5. Buka file → tempel script → Save.\n6. Join game → script auto jalan → config auto load.",
    Image = "solar:rocket-bold",
    Color = "Green",
})

AutoExecSection:Space()

AutoExecSection:Button({
    Title = "📋 Copy Script Auto Execute (dengan config)",
    Desc = "Loader + nama config autoload, tinggal tempel ke Delta/Auto Execute",
    Color = Green,
    Justify = "Center",
    Icon = "clipboard-copy",
    Callback = function()
        local ok, msg = copyText(buildLoaderScript())
        WindUI:Notify({
            Title = ok and "Script Auto Execute dicopy!" or "Gagal copy",
            Content = ok and ("Config autoload: " .. tostring(getAutoLoad() or "belum di-set")) or tostring(msg),
            Icon = ok and "check" or "circle-x",
            Duration = 6,
        })
    end,
})

AutoExecSection:Space()

AutoExecSection:Button({
    Title = "📄 Simpan Loader ke File (A2Hub_AutoExec.lua)",
    Desc = "Simpan loader ke workspace executor (kalau didukung writefile)",
    Color = Blue,
    Justify = "Center",
    Icon = "save",
    Callback = function()
        local ok = pcall(function()
            writefile("A2Hub_AutoExec.lua", buildLoaderScript())
        end)
        WindUI:Notify({
            Title = ok and "File disimpan" or "Gagal simpan",
            Content = ok and "A2Hub_AutoExec.lua ada di workspace executor. Copy ke folder Auto Execute." or "Executor gak support writefile.",
            Icon = ok and "check" or "circle-x",
            Duration = 6,
        })
    end,
})

ConfigTab:Space()

-- ===================== SECTION: FOLDER CONFIG (Delta AutoExecute) =====================
local FolderSection = ConfigTab:Section({ Title = "\ud83d\udcc1 Folder Config (Delta AutoExecute)" })

local autoExecName = getAutoLoad() or ""

FolderSection:Paragraph({
    Title = "\ud83d\udcc1 Bikin folder config di Delta",
    Desc = "Bikin file loader di folder AutoExecute Delta. Isi nama config yg udah kamu buat \u2192 pas join game, script auto jalan + config auto load + rejoin otomatis aktif.",
    Image = "solar:folder-bold",
    Color = "Green",
})

FolderSection:Space()

FolderSection:Input({
    Title = "Nama File Auto Execute",
    Desc = "Nama file yg bakal dibuat di folder AutoExecute (mis. afk). Isi nama config yg udah kamu buat.",
    Placeholder = "afk",
    Value = autoExecName,
    Callback = function(v) autoExecName = v end,
})

FolderSection:Space()

FolderSection:Button({
    Title = "\ud83d\udcc1 Buat File Loader di Folder AutoExecute",
    Desc = "Bikin file <nama>.lua di Delta/AutoExecute (auto load config + rejoin langsung aktif)",
    Color = Green,
    Justify = "Center",
    Icon = "folder-plus",
    Callback = function()
        local name = (autoExecName and autoExecName ~= "") and autoExecName or (getAutoLoad() or "A2Hub")
        pcall(setAutoLoad, name)
        local ok, msg = writeAutoExecFile(name)
        WindUI:Notify({
            Title = ok and "File AutoExecute dibuat!" or "Gagal",
            Content = tostring(msg),
            Icon = ok and "check" or "circle-x",
            Duration = 8,
        })
    end,
})

FolderSection:Space()

FolderSection:Button({
    Title = "\ud83d\udccb Copy Loader (nama ini)",
    Desc = "Copy isi loader buat ditempel manual ke file AutoExecute",
    Color = Blue,
    Justify = "Center",
    Icon = "clipboard-copy",
    Callback = function()
        local name = (autoExecName and autoExecName ~= "") and autoExecName or (getAutoLoad() or "")
        local ok, msg = copyText(buildLoaderScript(name))
        WindUI:Notify({
            Title = ok and "Loader dicopy!" or "Gagal",
            Content = ok and ("Config autoload: " .. tostring(name)) or tostring(msg),
            Icon = ok and "check" or "circle-x",
            Duration = 6,
        })
    end,
})

FolderSection:Space()

FolderSection:Paragraph({
    Title = "📖 Cara pakai (singkat)",
    Desc = "1. Bikin config di atas (Create Config) + Set as Auto Load.\n2. Isi 'Nama File Auto Execute' = nama config kamu (mis. afk).\n3. Klik 'Buat File Loader di Folder AutoExecute'.\n4. Buka ZArchiver → Delta → AutoExecute → cek file <nama>.lua.\n5. Join game → script auto jalan → config auto load → rejoin otomatis aktif.",
    Image = "solar:rocket-bold",
    Color = "Green",
})

FolderSection:Paragraph({
    Title = "📱 Panduan HP + ZArchiver",
    Desc = "A. Di tab Config, isi nama tanpa .json (contoh: afk), lalu tekan Create Config.\nB. Pilih nama itu di Config List, tekan Set as Auto Load, lalu pastikan Status Config menampilkan nama yang sama.\nC. Isi Nama File Auto Execute dengan nama sederhana (contoh: a2hub), lalu tekan Buat File Loader di Folder AutoExecute.\nD. Buka ZArchiver → Penyimpanan Internal → Delta → AutoExecute. Cari file a2hub.lua.\nE. Jika file sudah ada, jangan buat duplikat; hapus/replace file lama atau gunakan nama berbeda.\nF. Tutup Roblox sepenuhnya, buka lagi melalui executor, lalu join game. Loader akan memanggil URL script dan config autoload dipakai otomatis.\nG. Jika folder tidak terdeteksi, tekan Copy Loader, buat file .lua manual di folder AutoExecute, paste, lalu Save. Path Android bisa berbeda: gunakan folder AutoExecute yang dibuat aplikasi executor kamu.",
    Image = "solar:smartphone-bold",
    Color = "Blue",
})

ConfigTab:Space()

ConfigTab:Button({
    Title = "📋 Copy Script (buat Auto Execute)",
    Desc = "Copy loader buat ditempel ke Delta/Auto Execute",
    Color = Green,
    Justify = "Center",
    Icon = "clipboard-copy",
    Callback = function()
        local ok, msg = copyText(buildLoaderScript())
        WindUI:Notify({
            Title = ok and "Script dicopy!" or "Gagal copy",
            Content = ok and "Tempel ke Delta/Auto Execute." or tostring(msg),
            Icon = ok and "check" or "circle-x",
            Duration = 6,
        })
    end,
})

ConfigTab:Space()

ConfigTab:Button({
    Title = "Reset Config ke Default",
    Color = Red,
    Justify = "Center",
    Icon = "rotate-ccw",
    Callback = function()
        for k, v in pairs(DefaultConfig) do Config[k] = v end
        saveConfig()
        WindUI:Notify({ Title = "Reset", Content = "Config dikembalikan ke default.", Icon = "refresh-cw", Duration = 3 })
    end,
})

ConfigTab:Space()

ConfigTab:Paragraph({
    Title = "Tentang",
    Desc = "A2 HUB • Auto Farm Violence District\nUI: A2 UI (custom, self-contained)\nBase logic: DAMEUNGRR HUB\n\nGunakan dengan bijak.",
    Image = "solar:info-square-bold",
    Color = "Blue",
})

-- ============================================================================
--  MAIN LOOP — AUTO FARM
-- ============================================================================
task.spawn(function()
    -- Ambil baseline statistik
    task.wait(1)
    State.Baseline = getPlayerStats()
    State.LastStats = State.Baseline   -- [FIX] dulu LastStats mulai dari 0 -> gain run pertama jadi ngaco

    while true do
        task.wait(1)

        if State.Farming and State.Connected then
            -- [BARU] Tunggu game/round mulai dulu (kaya di video)
            if Config.WaitForGameStart and not isRoundStarted() then
                if not State.WaitingGame then
                    State.WaitingGame = true
                    if WindUI then
                        WindUI:Notify({ Title = "⏳ Menunggu Game", Content = "Nunggu round mulai dulu sebelum farm...", Icon = "hourglass", Duration = 5 })
                    end
                end
                waitForGameStart(180)
                State.WaitingGame = false
            end

            local startTime = tick()
            local remaining = nil

            -- Tunggu timer muncul (max 30s)
            repeat
                remaining = getRemainingTime()
                if not remaining then task.wait(1) end
            until remaining or (tick() - startTime >= 30)

            if not remaining or remaining > 1 then
                -- Timer belum mulai → pindah server
                if Config.AutoTeleport then
                    teleportToServer()
                else
                    task.wait(2)
                end
            else
                -- Tunggu sampai timer habis
                repeat
                    task.wait(0.5)
                    local t = getRemainingTime()
                    if not t then break end
                    remaining = t
                until remaining <= 0

                -- Cek tim (bukan spectator)
                local startTeam = LocalPlayer.Team
                local checkStart = tick()
                local isNotSpectator = false
                repeat
                    task.wait(0.5)
                    local team = LocalPlayer.Team
                    if team and team.Name ~= "Spectator" then
                        isNotSpectator = true
                        break
                    end
                until (tick() - checkStart >= 10)

                if not isNotSpectator then
                    if Config.AutoTeleport then teleportToServer() end
                else
                    -- AUTO ESCAPE: begitu farm beneran mulai, tutup GUI otomatis
                    if Config.AutoEscape and not State.Escaped then
                        State.Escaped = true
                        task.spawn(function()
                            task.wait(tonumber(Config.EscapeDelay) or 8)
                            pcall(function() Window:Close() end)
                            if WindUI then
                                WindUI:Notify({ Title = "🚀 Auto Escape", Content = "Farm udah jalan, menu ditutup otomatis.", Icon = "rocket", Duration = 5 })
                            end
                        end)
                    end
                    task.wait(5)
                    -- [BARU] Trigger ProximityPrompt + klik tombol action (dari kode fix)
                    if Config.UsePromptTrigger then
                        pcall(function()
                            local char = LocalPlayer.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                local map = workspace:FindFirstChild("Map") or workspace
                                local n = 0
                                for _, obj in ipairs(map:GetDescendants()) do
                                    if obj:IsA("ProximityPrompt") and obj.Enabled then
                                        local part = obj.Parent
                                        if part and part:IsA("BasePart")
                                            and (part.Position - hrp.Position).Magnitude <= 40 then
                                            triggerProximityPrompt(obj)
                                            n = n + 1
                                            if n >= 5 then break end
                                        end
                                    end
                                end
                                clickActionButton()
                            end
                        end)
                    end
                    if Config.AutoFinishLine then teleportToFinishLine() end
                    task.wait(5)

                    -- Ambil stats & hitung gain
                    local s = getPlayerStats()
                    local gains = {
                        screw = (s.screw or 0) - (State.LastStats.screw or 0),
                        exp   = (s.exp or 0) - (State.LastStats.exp or 0),
                        level = (s.level or 0) - (State.LastStats.level or 0),
                    }
                    State.Runs = State.Runs + 1
                    State.TotalScrews = State.TotalScrews + math.max(gains.screw, 0)
                    State.TotalEXP = State.TotalEXP + math.max(gains.exp, 0)
                    State.LastStats = s

                    -- Cek secret baru
                    checkNewSecrets()
                    -- [BARU] Cek item/gear baru
                    pcall(checkNewItems)

                    -- Lapor ke Discord
                    if State.Runs % math.max(Config.ReportEvery, 1) == 0 then
                        reportRun(s, gains)
                    end

                    refreshStats()
                    task.wait(2)
                    if Config.AutoTeleport then teleportToServer() end
                end
            end
        end
    end
end)

-- ============================================================================
--  [BARU] LIVE MONITOR — DETEKSI SETIAP PERUBAHAN (Level / EXP / Screws)
--  Ini yang bikin "setiap perubahan" muncul di Discord, gak nunggu run kelar.
-- ============================================================================
task.spawn(function()
    task.wait(3)
    State.MonitorLast = getPlayerStats()

    while true do
        task.wait(2) -- polling tiap 2 detik

        local s = getPlayerStats()

        -- [BARU] cek item/gear/inventory baru (tiap ~6 detik)
        State._itemTick = (State._itemTick or 0) + 1
        if State.Connected and State._itemTick % 3 == 0 then
            pcall(checkNewItems)
        end

        if State.Connected and Config.ChangeMonitor then
            local last = State.MonitorLast
            local dScrew = (s.screw or 0) - (last.screw or 0)
            local dExp   = (s.exp or 0)   - (last.exp or 0)
            local dLevel = (s.level or 0) - (last.level or 0)

            if dScrew ~= 0 or dExp ~= 0 or dLevel ~= 0 then
                -- akumulasi perubahan (biar gak ada yang kelewat walau kena cooldown)
                State.MonitorPending.screw = State.MonitorPending.screw + dScrew
                State.MonitorPending.exp   = State.MonitorPending.exp   + dExp
                State.MonitorPending.level = State.MonitorPending.level + dLevel
                State.MonitorLast = s
            end

            local p = State.MonitorPending
            if (p.screw ~= 0 or p.exp ~= 0 or p.level ~= 0) then
                local now = tick()
                local cooldown = tonumber(Config.ChangeCooldown) or 2
                if (now - (State.MonitorLastSent or 0)) >= cooldown then
                    reportChange(s, { screw = p.screw, exp = p.exp, level = p.level })
                    State.MonitorLastSent = now
                    State.MonitorPending = { screw = 0, exp = 0, level = 0 }
                end
            end
        else
            -- kalau monitor OFF / belum connect, tetap sinkron biar gak nge-spam pas dinyalain
            State.MonitorLast = s
            State.MonitorPending = { screw = 0, exp = 0, level = 0 }
        end
    end
end)

-- ============================================================================
--  [BARU] DEATH DETECTION — karakter mati pas farm -> rejoin otomatis
-- ============================================================================
do
    local function hookDeath(char)
        pcall(function()
            local hum = char:WaitForChild("Humanoid", 10)
            if not hum then return end
            hum.Died:Connect(function()
                if (State.Farming or GenFarm.Active) and Config.GenRejoinOnDeath then
                    reportDeath()
                    if WindUI then
                        WindUI:Notify({
                            Title = "\ud83d\udc80 Karakter Mati",
                            Content = "Rejoin server otomatis...",
                            Icon = "skull",
                            Duration = 6,
                        })
                    end
                    rejoinNow()
                end
            end)
        end)
    end

    pcall(function()
        LocalPlayer.CharacterAdded:Connect(hookDeath)
        if LocalPlayer.Character then hookDeath(LocalPlayer.Character) end
    end)
end

-- ============================================================================
--  [BARU] STALL WATCHDOG — farm macet (gak ada progress) -> rejoin otomatis
-- ============================================================================
task.spawn(function()
    while true do
        task.wait(5)
        if GenFarm.Active and Config.GenRejoinOnStall and not GenFarm.Waiting then
            local now = tick()
            local last = GenFarm.LastProgress or now
            local timeout = tonumber(Config.GenStallTimeout) or 35
            if (now - last) > timeout then
                GenFarm.Status = "Macet \u2192 rejoin..."
                reportStall(now - last)
                if WindUI then
                    WindUI:Notify({
                        Title = "\u26a0\ufe0f Farm Macet",
                        Content = "Gak ada progress " .. math.floor(now - last) .. "s. Rejoin server...",
                        Icon = "triangle-alert",
                        Duration = 6,
                    })
                end
                GenFarm.LastProgress = now   -- reset biar gak spam
                rejoinNow()
            end
        end
    end
end)

-- ============================================================================
--  AUTO RE-EXECUTE SETUP
-- ============================================================================
do
    -- Queue pertama begitu script jalan
    task.spawn(function()
        task.wait(3)
        if Config.AutoReexec then queueReexec() end
    end)

    -- Re-queue berkala (biar queue_on_teleport selalu siap)
    task.spawn(function()
        while true do
            task.wait(30)
            if Config.AutoReexec and State.Connected then
                queueReexec()
            end
        end
    end)

    -- Kalau LocalPlayer hilang (disconnect) -> queue re-exec (+ rejoin kalau aktif)
    pcall(function()
        LocalPlayer.AncestryChanged:Connect(function(_, parent)
            if not parent then
                queueReexec()
                if Config.AutoRejoin then rejoinNow() end
            end
        end)
    end)

    -- Kalau server mau tutup -> queue re-exec
    pcall(function()
        local oldOnClose = game.OnClose
        game.OnClose = function()
            queueReexec()
            if type(oldOnClose) == "function" then pcall(oldOnClose) end
        end
    end)
end

-- ============================================================================
--  AUTO LOAD (Set as Auto Load) + AUTO CONNECT + AUTO START
--  Biar pas auto-execute jalan, menu langsung kebuka & farm langsung siap.
-- ============================================================================
task.spawn(function()
    task.wait(1.5)

    -- Muat config autoload hanya jika toggle AutoLoadConfig aktif.
    -- Ini membuat pilihan user di tab Config benar-benar dihormati.
    local autoName = Config.AutoLoadConfig and loadAutoLoadConfig() or nil
    if autoName then
        if configStatus then
            pcall(function() configStatus:SetDesc("Current config set: " .. tostring(autoName) .. " (auto load)") end)
        end
        if WindUI then
            WindUI:Notify({ Title = "📁 Auto Load Config", Content = "Config '" .. tostring(autoName) .. "' dimuat otomatis.", Icon = "folder-check", Duration = 5 })
        end
    end

    if Config.AutoLoadConfig then
        -- Pastikan menu kebuka (auto load)
        pcall(function() Window:Open() end)

        -- Auto connect webhook (kalau URL udah disimpan)
        if Config.AutoConnect and Config.WebhookUrl and Config.WebhookUrl ~= "" then
            local ok = testWebhook()
            if ok then
                State.Connected = true
                pcall(checkNewItems)   -- [BARU] kirim snapshot inventory
                State.StatusText = "✅ Terhubung (auto) — siap farm!"
                if statusParagraph then
                    pcall(function()
                        statusParagraph:SetTitle("Status: ✅ Terhubung (auto)")
                        statusParagraph:SetDesc("Webhook auto-connect berhasil. Farm siap jalan.")
                    end)
                end
                -- Auto start farm (kalau di-set ON)
                if Config.AutoFarm then
                    State.Farming = true
                    if farmToggle then pcall(function() farmToggle:Set(true) end) end
                end
            end
        end
    else
        -- Auto Load OFF → menu mulai ketutup (tinggal klik tombol buat buka)
        pcall(function() Window:Close() end)
    end

    -- [BARU] Auto start generator farm (kalau di-set ON di config autoload)
    if Config.GenFarmEnabled then
        task.wait(1)
        setGenFarm(true)
        if WindUI then
            WindUI:Notify({
                Title = "🔥 Generator Farm ON (auto)",
                Content = "Config nyalain generator farm. Bot cari gen terjauh...",
                Icon = "play",
                Duration = 5,
            })
        end
    end
end)

-- ============================================================================
--  SELESAI
-- ============================================================================
WindUI:Notify({
    Title = "A2 HUB Dimuat!",
    Content = "Buka tab Webhook untuk menghubungkan Discord.",
    Duration = 6,
    Icon = "zap",
})

print("[A2 Hub] Loaded successfully. Base logic: DAMEUNGRR HUB.")
