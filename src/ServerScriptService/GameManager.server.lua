-- GameManager.server.lua
-- Manages the full Tag Game loop: waiting, intermission, rounds, and scoring.
--
-- Game flow:
--   Waiting → (enough players) → Intermission → InRound → RoundEnd
--             ↑__________________________________↑  (repeat for ROUND_COUNT rounds)
--   After all rounds → GameOver → restart

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

------------------------------------------------------------------------
-- Remote events setup
-- All events live in a folder in ReplicatedStorage so the client
-- can WaitForChild them safely.
------------------------------------------------------------------------
local eventsFolder = Instance.new("Folder")
eventsFolder.Name  = "TagEvents"
eventsFolder.Parent = ReplicatedStorage

-- Server → All clients: full game state snapshot
local updateStateEvent = Instance.new("RemoteEvent")
updateStateEvent.Name  = "UpdateState"
updateStateEvent.Parent = eventsFolder

-- Server → specific / all clients: toast notification text
local notifyEvent  = Instance.new("RemoteEvent")
notifyEvent.Name   = "Notify"
notifyEvent.Parent = eventsFolder

------------------------------------------------------------------------
-- Game state (server-authoritative)
------------------------------------------------------------------------
local phase          = "Waiting"  -- Waiting|Intermission|InRound|RoundEnd|GameOver
local currentRound   = 0
local itPlayer       = nil        -- the current "It" Player object
local scores         = {}         -- [Player] = cumulative integer score
local tagCooldowns   = {}         -- [Player] = tick() at time of last tag
local touchConns     = {}         -- active Touched connections on It's character

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function alivePlayers()
    return Players:GetPlayers()
end

local function getScore(p)
    return scores[p] or 0
end

local function hasCooldown(p)
    return tagCooldowns[p] ~= nil
        and (tick() - tagCooldowns[p]) < GameConfig.TAG_IMMUNITY
end

local function buildPacket(timer)
    local scoreTable = {}
    for _, p in ipairs(alivePlayers()) do
        scoreTable[p.Name] = getScore(p)
    end
    return {
        phase       = phase,
        round       = currentRound,
        totalRounds = GameConfig.ROUND_COUNT,
        itName      = itPlayer and itPlayer.Name or "",
        timer       = math.max(0, math.ceil(timer or 0)),
        scores      = scoreTable,
    }
end

local function broadcast(timer)
    updateStateEvent:FireAllClients(buildPacket(timer))
end

local function notify(msg, target)
    if target then
        notifyEvent:FireClient(target, msg)
    else
        notifyEvent:FireAllClients(msg)
    end
end

------------------------------------------------------------------------
-- Visual / stat helpers
------------------------------------------------------------------------
local function applyItLook(player, isIt)
    local char = player.Character
    if not char then return end

    -- Walk speed
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = isIt and GameConfig.IT_WALK_SPEED or GameConfig.NORMAL_WALK_SPEED
    end

    -- Red highlight when It
    local existing = char:FindFirstChild("TagHighlight")
    if isIt then
        if not existing then
            local hl = Instance.new("Highlight")
            hl.Name             = "TagHighlight"
            hl.FillColor        = Color3.fromRGB(220, 50, 50)
            hl.OutlineColor     = Color3.fromRGB(255, 230, 0)
            hl.FillTransparency = 0.45
            hl.Parent           = char
        end
    else
        if existing then existing:Destroy() end
    end
end

------------------------------------------------------------------------
-- Tag detection
------------------------------------------------------------------------
local function clearTouchConns()
    for _, c in ipairs(touchConns) do c:Disconnect() end
    touchConns = {}
end

-- Forward declaration so onTouched can reference it
local transferIt

local function onTouched(hit, taggerPlayer)
    if phase ~= "InRound"        then return end
    if taggerPlayer ~= itPlayer  then return end
    if hasCooldown(taggerPlayer) then return end

    local hitChar  = hit.Parent
    local victim   = Players:GetPlayerFromCharacter(hitChar)

    if not victim or victim == taggerPlayer then return end
    if not victim.Character              then return end
    if hasCooldown(victim)               then return end

    transferIt(taggerPlayer, victim)
end

local function connectItTouched(player)
    clearTouchConns()
    local char = player.Character
    if not char then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local conn = part.Touched:Connect(function(hit)
                onTouched(hit, player)
            end)
            table.insert(touchConns, conn)
        end
    end
end

-- Assign a new It player
transferIt = function(oldIt, newIt)
    -- Remove old It status
    if oldIt and oldIt.Character then
        applyItLook(oldIt, false)
    end
    tagCooldowns[oldIt] = tick()  -- brief immunity so they're not immediately re-tagged

    -- Set new It
    itPlayer = newIt
    tagCooldowns[newIt] = tick()
    applyItLook(newIt, true)
    connectItTouched(newIt)

    notify(string.format("🏃 %s tagged %s! %s is now IT!", oldIt.Name, newIt.Name, newIt.Name))
    broadcast()
end

------------------------------------------------------------------------
-- Round helpers
------------------------------------------------------------------------
local function pickRandom(list)
    return list[math.random(1, #list)]
end

local function beginRound(timer)
    broadcast(timer)
end

local function startRound()
    local plist = alivePlayers()
    if #plist < GameConfig.MIN_PLAYERS then
        return false
    end

    currentRound = currentRound + 1
    phase        = "InRound"

    -- Clear all visuals first
    for _, p in ipairs(plist) do
        applyItLook(p, false)
    end

    -- Pick initial It
    itPlayer = pickRandom(plist)
    tagCooldowns[itPlayer] = tick()
    applyItLook(itPlayer, true)
    connectItTouched(itPlayer)

    notify(string.format("⚡ Round %d/%d — %s is IT! RUN!", currentRound, GameConfig.ROUND_COUNT, itPlayer.Name))
    notify("YOU ARE IT! Tag someone!", itPlayer)
    broadcast(GameConfig.ROUND_DURATION)
    return true
end

local function finishRound(neverItPlayers)
    phase = "RoundEnd"
    clearTouchConns()

    -- Award survival bonus to everyone who was never It this round
    for _, p in ipairs(neverItPlayers) do
        if p and p.Parent then
            scores[p] = getScore(p) + GameConfig.ROUND_SURVIVAL_BONUS
        end
    end

    if itPlayer and itPlayer.Character then
        applyItLook(itPlayer, false)
    end
    itPlayer = nil

    notify(string.format("🔔 Round %d ended!", currentRound))
    broadcast(0)
end

local function showGameOver()
    phase = "GameOver"
    clearTouchConns()

    -- Find top scorer
    local winner, topScore = nil, -1
    for _, p in ipairs(alivePlayers()) do
        local s = getScore(p)
        if s > topScore then
            topScore = s
            winner   = p
        end
    end

    if winner then
        notify(string.format("🏆 Game Over! Winner: %s with %d points!", winner.Name, topScore))
    else
        notify("Game Over! No winner this time.")
    end
    broadcast(0)
end

------------------------------------------------------------------------
-- Main game loop
------------------------------------------------------------------------
local function runGame()
    -- Reset state
    currentRound = 0
    itPlayer     = nil
    tagCooldowns = {}
    scores       = {}
    for _, p in ipairs(alivePlayers()) do
        scores[p] = 0
    end

    for roundNum = 1, GameConfig.ROUND_COUNT do
        ----------------------------------------------------------------
        -- Intermission
        ----------------------------------------------------------------
        phase = "Intermission"
        notify(string.format("⏳ Round %d/%d starts in %d seconds…",
            roundNum, GameConfig.ROUND_COUNT, GameConfig.INTERMISSION_DELAY))

        local intStart = tick()
        repeat
            local remaining = GameConfig.INTERMISSION_DELAY - (tick() - intStart)
            broadcast(remaining)
            task.wait(1)

            -- Pause intermission if player count drops
            if #alivePlayers() < GameConfig.MIN_PLAYERS then
                phase = "Waiting"
                notify("Not enough players — waiting…")
                broadcast(0)
                repeat task.wait(2) until #alivePlayers() >= GameConfig.MIN_PLAYERS
                -- Restart intermission countdown
                phase    = "Intermission"
                intStart = tick()
                notify(string.format("⏳ Round %d/%d starts in %d seconds…",
                    roundNum, GameConfig.ROUND_COUNT, GameConfig.INTERMISSION_DELAY))
            end
        until (tick() - intStart) >= GameConfig.INTERMISSION_DELAY

        ----------------------------------------------------------------
        -- Round
        ----------------------------------------------------------------
        if not startRound() then
            break
        end

        -- Track who was It during this round for survival bonus
        local wasIt       = {}     -- set of players who were It at least once
        local roundStart  = tick()

        repeat
            task.wait(1)

            -- Award per-second survival points to non-It players
            if itPlayer then
                wasIt[itPlayer] = true
                for _, p in ipairs(alivePlayers()) do
                    if p ~= itPlayer then
                        scores[p] = getScore(p) + GameConfig.POINTS_PER_SECOND
                    end
                end
            end

            local elapsed   = tick() - roundStart
            local remaining = GameConfig.ROUND_DURATION - elapsed
            broadcast(remaining)

        until phase ~= "InRound" or (tick() - roundStart) >= GameConfig.ROUND_DURATION

        -- Build list of players who were never It
        local neverIt = {}
        for _, p in ipairs(alivePlayers()) do
            if not wasIt[p] then
                table.insert(neverIt, p)
            end
        end

        finishRound(neverIt)

        -- Show results briefly
        task.wait(GameConfig.RESULTS_DISPLAY)
    end

    ----------------------------------------------------------------
    -- Game Over
    ----------------------------------------------------------------
    showGameOver()
    task.wait(GameConfig.RESULTS_DISPLAY + 4)

    -- Loop forever: restart
    runGame()
end

------------------------------------------------------------------------
-- Player lifecycle hooks
------------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
    scores[player] = scores[player] or 0

    player.CharacterAdded:Connect(function(char)
        -- Ensure correct walk speed on respawn
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            hum.WalkSpeed = GameConfig.NORMAL_WALK_SPEED
        end

        -- Re-apply It status after respawn
        if player == itPlayer and phase == "InRound" then
            task.delay(1, function()
                applyItLook(player, true)
                connectItTouched(player)
            end)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    scores[player]       = nil
    tagCooldowns[player] = nil

    -- If the It player leaves, pick a new one immediately
    if player == itPlayer and phase == "InRound" then
        itPlayer = nil
        local remaining = alivePlayers()
        if #remaining >= 1 then
            local newIt = pickRandom(remaining)
            itPlayer = newIt
            tagCooldowns[newIt] = tick()
            applyItLook(newIt, true)
            connectItTouched(newIt)
            notify(string.format("The previous It left. %s is now IT!", newIt.Name))
            broadcast()
        end
    end
end)

------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------
task.spawn(function()
    task.wait(2)  -- let the world load

    phase = "Waiting"
    broadcast(0)
    notify(string.format("Waiting for %d players to join…", GameConfig.MIN_PLAYERS))

    repeat task.wait(2) until #alivePlayers() >= GameConfig.MIN_PLAYERS

    runGame()
end)
