-- TagClient.client.lua
-- Builds and updates the in-game HUD for the Tag Game.
--
-- HUD layout:
--   ┌─────────────────────────────────────────────────┐
--   │  TOP BAR:  Round X/Y  │  Timer  │  IT: Name     │
--   └─────────────────────────────────────────────────┘
--   ┌──────────────────┐
--   │  SCOREBOARD      │  (right side, always visible)
--   │  1. Alice  - 123 │
--   │  2. Bob    -  87 │
--   └──────────────────┘
--   NOTIFICATION TOAST (bottom-centre, fades out)

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

------------------------------------------------------------------------
-- Wait for server events
------------------------------------------------------------------------
local eventsFolder  = ReplicatedStorage:WaitForChild("TagEvents", 10)
local updateStateEv = eventsFolder:WaitForChild("UpdateState", 10)
local notifyEv      = eventsFolder:WaitForChild("Notify", 10)

------------------------------------------------------------------------
-- Build ScreenGui
------------------------------------------------------------------------
local screenGui       = Instance.new("ScreenGui")
screenGui.Name        = "TagHud"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent      = localPlayer.PlayerGui

-- ── colour palette ────────────────────────────────────────────────
local C = {
    bg        = Color3.fromRGB(20,  20,  30),
    panel     = Color3.fromRGB(30,  30,  45),
    accent    = Color3.fromRGB(255, 80,  80),
    gold      = Color3.fromRGB(255, 220,  50),
    white     = Color3.fromRGB(240, 240, 240),
    dimWhite  = Color3.fromRGB(160, 160, 180),
    green     = Color3.fromRGB(80,  220, 100),
    transparent = Color3.fromRGB(0, 0, 0),
}

local function makePadding(frame, top, bot, left, right)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, top or 0)
    p.PaddingBottom = UDim.new(0, bot or 0)
    p.PaddingLeft   = UDim.new(0, left or 0)
    p.PaddingRight  = UDim.new(0, right or 0)
    p.Parent = frame
end

local function makeCorner(frame, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = frame
end

local function makeLabel(parent, name, text, size, bold, color)
    local lbl = Instance.new("TextLabel")
    lbl.Name            = name
    lbl.Text            = text
    lbl.TextSize        = size or 16
    lbl.Font            = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    lbl.TextColor3      = color or C.white
    lbl.BackgroundTransparency = 1
    lbl.Size            = UDim2.new(1, 0, 1, 0)
    lbl.TextXAlignment  = Enum.TextXAlignment.Center
    lbl.TextYAlignment  = Enum.TextYAlignment.Center
    lbl.Parent          = parent
    return lbl
end

------------------------------------------------------------------------
-- TOP BAR
------------------------------------------------------------------------
local topBar = Instance.new("Frame")
topBar.Name            = "TopBar"
topBar.Size            = UDim2.new(0.7, 0, 0, 48)
topBar.Position        = UDim2.new(0.15, 0, 0, 8)
topBar.BackgroundColor3 = C.panel
topBar.BorderSizePixel  = 0
topBar.Parent          = screenGui
makeCorner(topBar, 10)

-- Three equal columns inside top bar
local topLayout = Instance.new("UIListLayout")
topLayout.FillDirection = Enum.FillDirection.Horizontal
topLayout.SortOrder     = Enum.SortOrder.LayoutOrder
topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
topLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
topLayout.Parent = topBar

local function topCell(name, order)
    local cell = Instance.new("Frame")
    cell.Name             = name
    cell.Size             = UDim2.new(0.333, 0, 1, 0)
    cell.BackgroundTransparency = 1
    cell.LayoutOrder      = order
    cell.Parent           = topBar
    return cell
end

local roundCell  = topCell("RoundCell",  1)
local timerCell  = topCell("TimerCell",  2)
local itCell     = topCell("ItCell",     3)

local roundLbl   = makeLabel(roundCell,  "RoundLbl",  "Round -/-",  15, true)
local timerLbl   = makeLabel(timerCell,  "TimerLbl",  "0:00",       20, true, C.gold)
local itLbl      = makeLabel(itCell,     "ItLbl",     "IT: —",      15, true, C.accent)

-- Dividers between cells
local function addDivider(parent, xPos)
    local div = Instance.new("Frame")
    div.Size              = UDim2.new(0, 1, 0.6, 0)
    div.Position          = UDim2.new(xPos, 0, 0.2, 0)
    div.BackgroundColor3  = C.dimWhite
    div.BackgroundTransparency = 0.6
    div.BorderSizePixel   = 0
    div.Parent            = parent
end
addDivider(topBar, 0.333)
addDivider(topBar, 0.666)

------------------------------------------------------------------------
-- "YOU ARE IT" banner (shown only when local player is It)
------------------------------------------------------------------------
local itBanner = Instance.new("TextLabel")
itBanner.Name            = "ItBanner"
itBanner.Size            = UDim2.new(0.5, 0, 0, 40)
itBanner.Position        = UDim2.new(0.25, 0, 0, 62)
itBanner.BackgroundColor3 = C.accent
itBanner.BackgroundTransparency = 0.1
itBanner.Text            = "⚡  YOU ARE IT!  TAG SOMEONE!"
itBanner.TextColor3      = Color3.new(1, 1, 1)
itBanner.Font            = Enum.Font.GothamBold
itBanner.TextSize        = 18
itBanner.BorderSizePixel  = 0
itBanner.Visible          = false
itBanner.Parent           = screenGui
makeCorner(itBanner, 8)

------------------------------------------------------------------------
-- SCOREBOARD (right side)
------------------------------------------------------------------------
local scorePanel = Instance.new("Frame")
scorePanel.Name            = "ScorePanel"
scorePanel.Size            = UDim2.new(0, 190, 0, 220)
scorePanel.Position        = UDim2.new(1, -200, 0.5, -110)
scorePanel.BackgroundColor3 = C.panel
scorePanel.BackgroundTransparency = 0.15
scorePanel.BorderSizePixel  = 0
scorePanel.Parent           = screenGui
makeCorner(scorePanel, 10)
makePadding(scorePanel, 8, 8, 10, 10)

local scoreTitle = Instance.new("TextLabel")
scoreTitle.Name            = "Title"
scoreTitle.Size            = UDim2.new(1, 0, 0, 24)
scoreTitle.Position        = UDim2.new(0, 0, 0, 0)
scoreTitle.BackgroundTransparency = 1
scoreTitle.Text            = "🏅  Scores"
scoreTitle.TextColor3      = C.gold
scoreTitle.Font            = Enum.Font.GothamBold
scoreTitle.TextSize        = 16
scoreTitle.TextXAlignment  = Enum.TextXAlignment.Left
scoreTitle.Parent          = scorePanel

local scoreList = Instance.new("ScrollingFrame")
scoreList.Name             = "List"
scoreList.Size             = UDim2.new(1, 0, 1, -28)
scoreList.Position         = UDim2.new(0, 0, 0, 28)
scoreList.BackgroundTransparency = 1
scoreList.BorderSizePixel  = 0
scoreList.ScrollBarThickness = 3
scoreList.ScrollBarImageColor3 = C.dimWhite
scoreList.Parent           = scorePanel

local scoreListLayout = Instance.new("UIListLayout")
scoreListLayout.SortOrder  = Enum.SortOrder.LayoutOrder
scoreListLayout.Padding     = UDim.new(0, 3)
scoreListLayout.Parent      = scoreList

------------------------------------------------------------------------
-- NOTIFICATION TOAST (bottom-centre)
------------------------------------------------------------------------
local toast = Instance.new("Frame")
toast.Name             = "Toast"
toast.Size             = UDim2.new(0.55, 0, 0, 44)
toast.Position         = UDim2.new(0.225, 0, 1, -70)
toast.BackgroundColor3  = C.bg
toast.BackgroundTransparency = 0.15
toast.BorderSizePixel   = 0
toast.Visible           = false
toast.Parent            = screenGui
makeCorner(toast, 10)

local toastLabel = Instance.new("TextLabel")
toastLabel.Name           = "Msg"
toastLabel.Size           = UDim2.new(1, -16, 1, 0)
toastLabel.Position       = UDim2.new(0, 8, 0, 0)
toastLabel.BackgroundTransparency = 1
toastLabel.Text           = ""
toastLabel.TextColor3     = C.white
toastLabel.Font           = Enum.Font.Gotham
toastLabel.TextSize       = 15
toastLabel.TextWrapped    = true
toastLabel.TextXAlignment = Enum.TextXAlignment.Center
toastLabel.Parent         = toast

------------------------------------------------------------------------
-- PHASE OVERLAY (shown during Waiting / GameOver / RoundEnd)
------------------------------------------------------------------------
local overlay = Instance.new("Frame")
overlay.Name             = "Overlay"
overlay.Size             = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3  = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.55
overlay.Visible          = false
overlay.ZIndex           = 5
overlay.Parent           = screenGui

local overlayTitle = Instance.new("TextLabel")
overlayTitle.Name       = "Title"
overlayTitle.Size       = UDim2.new(0.7, 0, 0, 60)
overlayTitle.Position   = UDim2.new(0.15, 0, 0.35, 0)
overlayTitle.BackgroundTransparency = 1
overlayTitle.Text       = ""
overlayTitle.TextColor3 = C.gold
overlayTitle.Font       = Enum.Font.GothamBold
overlayTitle.TextSize   = 36
overlayTitle.ZIndex     = 6
overlayTitle.Parent     = screenGui

local overlayBody = Instance.new("TextLabel")
overlayBody.Name        = "Body"
overlayBody.Size        = UDim2.new(0.7, 0, 0, 40)
overlayBody.Position    = UDim2.new(0.15, 0, 0.35 + 0.1, 0)
overlayBody.BackgroundTransparency = 1
overlayBody.Text        = ""
overlayBody.TextColor3  = C.white
overlayBody.Font        = Enum.Font.Gotham
overlayBody.TextSize    = 20
overlayBody.ZIndex      = 6
overlayBody.Parent      = screenGui

------------------------------------------------------------------------
-- Toast notification helper
------------------------------------------------------------------------
local toastTween = nil

local function showToast(msg)
    if toastTween then toastTween:Cancel() end

    toastLabel.Text          = msg
    toast.BackgroundTransparency = 0.15
    toastLabel.TextTransparency  = 0
    toast.Visible = true

    -- Fade out after 3.5 s
    task.delay(3.5, function()
        toastTween = TweenService:Create(toast,
            TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { BackgroundTransparency = 1 })
        local lblTween = TweenService:Create(toastLabel,
            TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { TextTransparency = 1 })
        toastTween:Play()
        lblTween:Play()
        toastTween.Completed:Connect(function()
            toast.Visible = false
        end)
    end)
end

------------------------------------------------------------------------
-- Format seconds → "M:SS"
------------------------------------------------------------------------
local function formatTime(secs)
    secs = math.max(0, secs)
    local m = math.floor(secs / 60)
    local s = secs % 60
    return string.format("%d:%02d", m, s)
end

------------------------------------------------------------------------
-- Build / refresh the scoreboard rows
------------------------------------------------------------------------
local function refreshScoreboard(scoresData)
    -- Sort names by score descending
    local entries = {}
    for name, pts in pairs(scoresData) do
        table.insert(entries, { name = name, pts = pts })
    end
    table.sort(entries, function(a, b) return a.pts > b.pts end)

    -- Remove old rows
    for _, child in ipairs(scoreList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for i, entry in ipairs(entries) do
        local row = Instance.new("Frame")
        row.Name              = "Row_" .. i
        row.Size              = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.LayoutOrder       = i
        row.Parent            = scoreList

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size         = UDim2.new(0.65, 0, 1, 0)
        nameLabel.Position     = UDim2.new(0, 0, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text         = string.format("%d. %s", i, entry.name)
        nameLabel.TextColor3   = entry.name == localPlayer.Name and C.green or C.white
        nameLabel.Font         = entry.name == localPlayer.Name
            and Enum.Font.GothamBold or Enum.Font.Gotham
        nameLabel.TextSize     = 14
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent       = row

        local ptsLabel = Instance.new("TextLabel")
        ptsLabel.Size          = UDim2.new(0.35, 0, 1, 0)
        ptsLabel.Position      = UDim2.new(0.65, 0, 0, 0)
        ptsLabel.BackgroundTransparency = 1
        ptsLabel.Text          = tostring(entry.pts)
        ptsLabel.TextColor3    = C.gold
        ptsLabel.Font          = Enum.Font.GothamBold
        ptsLabel.TextSize      = 14
        ptsLabel.TextXAlignment = Enum.TextXAlignment.Right
        ptsLabel.Parent        = row
    end

    -- Auto-size scroll frame
    scoreList.CanvasSize = UDim2.new(0, 0, 0,
        scoreListLayout.AbsoluteContentSize.Y + 4)
end

------------------------------------------------------------------------
-- Main state update handler
------------------------------------------------------------------------
updateStateEvent.OnClientEvent:Connect(function(data)
    local p     = data.phase       or "Waiting"
    local round = data.round       or 0
    local total = data.totalRounds or 0
    local itName = data.itName     or ""
    local timer  = data.timer      or 0

    -- Top bar
    roundLbl.Text = string.format("Round %d / %d", round, total)
    timerLbl.Text = formatTime(timer)

    if itName ~= "" then
        itLbl.Text      = "IT: " .. itName
        itLbl.TextColor3 = C.accent
    else
        itLbl.Text       = "IT: —"
        itLbl.TextColor3  = C.dimWhite
    end

    -- Colour the timer red when under 10 s
    timerLbl.TextColor3 = timer <= 10 and C.accent or C.gold

    -- "You are It" banner
    itBanner.Visible = (itName == localPlayer.Name) and (p == "InRound")

    -- Scoreboard
    if data.scores then
        refreshScoreboard(data.scores)
    end

    -- Overlay / phase messaging
    local showOverlay = false
    local title, body = "", ""

    if p == "Waiting" then
        showOverlay = true
        title = "Waiting for Players…"
        body  = "Need at least 2 players to start"
    elseif p == "Intermission" then
        showOverlay = true
        title = string.format("Round %d starting in…  %s", round + 1, formatTime(timer))
        body  = "Get ready to run!"
    elseif p == "RoundEnd" then
        showOverlay = true
        title = string.format("Round %d Over!", round)
        body  = "Showing results…"
    elseif p == "GameOver" then
        showOverlay = true
        title = "🏆  Game Over!"
        -- Find winner from scores
        local best, bestPts = "", -1
        if data.scores then
            for name, pts in pairs(data.scores) do
                if pts > bestPts then bestPts = pts; best = name end
            end
        end
        body = best ~= "" and string.format("Winner: %s  (%d pts)", best, bestPts) or ""
    end

    overlay.Visible      = showOverlay
    overlayTitle.Visible = showOverlay
    overlayBody.Visible  = showOverlay
    if showOverlay then
        overlayTitle.Text = title
        overlayBody.Text  = body
    end
end)

------------------------------------------------------------------------
-- Notification handler
------------------------------------------------------------------------
notifyEv.OnClientEvent:Connect(function(msg)
    showToast(msg)
end)
