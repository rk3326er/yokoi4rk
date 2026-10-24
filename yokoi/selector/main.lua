-- Yokoi game selector (PortMaster / Love2D)
-- Shows the packed game list with bezel previews; writes the chosen ref
-- to $YOKOI_SELECT_OUT and exits. Cancel (B) leaves without writing.

local games = {}   -- {idx, ref, name, date, mfr}
local sel = 1
local top = 1      -- first visible row
local ROWS = 10
local preview = {}
local preview_cache = {}

local MFR_COLOR = {
    -- NES palette ($0F black, $30 white, $16 red, $2A green, $12 blue, $27 orange)
    [0] = {0.42, 0.77, 0.36},   -- Nintendo: NES green ($2A/#6BB74A-ish)
    [1] = {0.91, 0.59, 0.20},   -- Tronica: NES orange ($27/#E89833-ish)
    [2] = {0.33, 0.48, 0.80},   -- Elektronika: NES blue ($12/#547ACC-ish)
}
local MFR_NAME = { [0] = "Nintendo", [1] = "Tronica", [2] = "Elektronika" }

local LIST_W = 400
local BASE_W, BASE_H = 640, 480

-- Uniform letterbox scale: UI is designed at 640x480 and scales to any
-- window/panel size (bigger screens = bigger text, never stretched).
local ui_scale = 1
local ui_off_x, ui_off_y = 0, 0
local function update_ui_transform()
    local w, h = love.graphics.getDimensions()
    ui_scale = math.min(w / BASE_W, h / BASE_H)
    ui_off_x = (w - BASE_W * ui_scale) / 2
    ui_off_y = (h - BASE_H * ui_scale) / 2
end

local function loadGames()
    -- love.filesystem reads inside the .love archive; fall back to raw fs paths.
    local fh = love.filesystem.newFile("games.txt", "r")
    if not fh then
        fh = io.open("games.txt", "r")
    end
    if not fh then
        fh = io.open(love.filesystem.getSourceBaseDirectory() .. "/games.txt", "r")
    end
    if not fh then return end
    local content
    if fh.read then
        content = fh:read("string")
    end
    fh:close()
    if not content then return end
    for line in content:gmatch("[^\r\n]+") do
        local idx, ref, name, date, mfr = line:match("^(%d+)\t([^\t]+)\t([^\t]*)\t([^\t]*)\t(%d+)")
        if idx then
            table.insert(games, { idx = tonumber(idx), ref = ref, name = name, date = date, mfr = tonumber(mfr) })
        end
    end
end

local function loadPreview(ref)
    if preview_cache[ref] ~= nil then return preview_cache[ref] end
    local img = nil
    local ok
    ok, img = pcall(love.graphics.newImage, ("img/%s.png"):format(ref))
    if not ok then img = nil end
    preview_cache[ref] = img
    return img
end

local function confirm()
    local out = os.getenv("YOKOI_SELECT_OUT")
    if not out or out == "" then out = ".yokoi_selection" end
    local fh = io.open(out, "w")
    if fh then
        fh:write(games[sel].ref)
        fh:close()
    end
    love.event.quit(0)
end

local function cancel()
    local out = os.getenv("YOKOI_SELECT_OUT")
    if out and out ~= "" then os.remove(out) end
    love.event.quit(0)
end

local function move(delta)
    if #games == 0 then return end
    sel = ((sel - 1 + delta) % #games) + 1
    -- keep selection in view
    if sel < top then top = sel end
    if sel > top + ROWS - 1 then top = sel - ROWS + 1 end
end

local font_big, font_title, font_small

function love.resize()
    update_ui_transform()
end

function love.load()
    -- Resizable window: on handhelds (KMS/DRM, no WM) a window IS fullscreen
    -- at the native panel mode; on desktops it opens as a resizable 640x480
    -- window. All drawing below is resolution-adaptive (uniform scale,
    -- centered), so any size presents correctly.
    love.window.setMode(640, 480, { fullscreen = false, resizable = true, highdpi = false })
    love.graphics.setBackgroundColor(0.13, 0.13, 0.16)  -- NES dark gray ($2D)
    -- larger text for small (3.5") screens: default love font is 12px
    font_title = love.graphics.setNewFont(20)
    font_big = love.graphics.setNewFont(18)
    font_small = love.graphics.setNewFont(16)
    update_ui_transform()
    loadGames()
    if #games == 0 then
        local out = os.getenv("YOKOI_SELECT_OUT")
        if out and out ~= "" then os.remove(out) end
        love.event.quit(1)
    end
end

local function onInput(action)
    if action == "up" then move(-1)
    elseif action == "down" then move(1)
    elseif action == "left" then move(-5)
    elseif action == "right" then move(5)
    elseif action == "confirm" then confirm()
    elseif action == "cancel" then cancel()
    end
end

-- hold-to-scroll: track held directions with an initial delay then repeat
local held = {}          -- action -> true while held
local hold_timer = 0     -- seconds since last repeat tick
local REPEAT_DELAY = 0.4 -- initial delay before auto-repeat
local REPEAT_RATE = 0.12 -- seconds between repeats while held

local HELD_KEYS = {
    up = "up", down = "down", left = "left", right = "right",
}

function love.keypressed(key)
    local action = HELD_KEYS[key]
    if action then
        held[action] = true
        hold_timer = 0
        onInput(action)  -- single tap moves one step immediately
        return
    end
    if key == "return" or key == "z" or key == "kpenter" then onInput("confirm")
    elseif key == "escape" or key == "x" then onInput("cancel")
    end
end

function love.keyreleased(key)
    local action = HELD_KEYS[key]
    if action then held[action] = nil end
end

local HELD_PAD = {
    dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
}

function love.gamepadpressed(_, button)
    local action = HELD_PAD[button]
    if action then
        held[action] = true
        hold_timer = 0
        onInput(action)  -- single tap moves one step immediately
        return
    end
    if button == "a" then onInput("confirm")
    elseif button == "b" or button == "start" then onInput("cancel")
    end
end

function love.gamepadreleased(_, button)
    local action = HELD_PAD[button]
    if action then held[action] = nil end
end

function love.update(dt)
    -- one action per tick while holding; first tick after REPEAT_DELAY,
    -- then every REPEAT_RATE seconds
    hold_timer = hold_timer + dt
    if hold_timer >= REPEAT_DELAY then
        local any = false
        for _, a in ipairs({"up", "down", "left", "right"}) do
            if held[a] then
                move(a == "up" and -1 or a == "down" and 1 or a == "left" and -5 or 5)
                any = true
            end
        end
        if any then
            hold_timer = REPEAT_DELAY - REPEAT_RATE
        end
    end
end

function love.draw()
    update_ui_transform()
    local w, h = BASE_W, BASE_H
    local win_w, win_h = love.graphics.getDimensions()

    -- clear the full window to the NES dark gray first (untransformed)
    love.graphics.setColor(0.13, 0.13, 0.16)  -- NES dark gray
    love.graphics.rectangle("fill", 0, 0, win_w, win_h)

    -- then draw the scaled/centered UI on top
    love.graphics.push()
    love.graphics.translate(ui_off_x, ui_off_y)
    love.graphics.scale(ui_scale, ui_scale)
    local font = love.graphics.getFont()
    local row_h = h / (ROWS + 2)

    -- header
    love.graphics.setFont(font_title)
    love.graphics.setColor(0.94, 0.94, 0.94)  -- NES white
    love.graphics.print(("YOKOI  -  %d games"):format(#games), 12, 4)
    love.graphics.setColor(0.35, 0.35, 0.40)  -- NES gray
    love.graphics.line(0, 32, w, 32)

    -- list
    for i = top, math.min(top + ROWS - 1, #games) do
        local g = games[i]
        local y = 34 + (i - top) * row_h
        if i == sel then
            love.graphics.setColor(0.63, 0.12, 0.10)  -- NES red ($16)
            love.graphics.rectangle("fill", 4, y, LIST_W - 8, row_h - 2)
        end
        local c = MFR_COLOR[g.mfr] or {0.8, 0.8, 0.8}
        love.graphics.setColor(c[1] * (i == sel and 1.4 or 0.8), c[2] * (i == sel and 1.4 or 0.8), c[3] * (i == sel and 1.4 or 0.8))
        love.graphics.setFont(font_big)
        local label = g.name
        if #label > 26 then label = label:sub(1, 25) .. "." end
        love.graphics.print(label, 12, y + row_h * 0.15)
    end

    -- right panel: preview + details
    local px = LIST_W + 10
    local pw = w - px - 10
    local g = games[sel]
    love.graphics.setColor(0.21, 0.21, 0.25)  -- NES gray ($00)
    love.graphics.rectangle("fill", px, 34, pw, h - 70)

    local img = loadPreview(g.ref)
    if img then
        local iw, ih = img:getDimensions()
        local scale = math.min((pw - 16) / iw, (h - 200) / ih)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(img, px + (pw - iw * scale) / 2, 44, 0, scale, scale)
    end

    love.graphics.setFont(font_title)
    love.graphics.setColor(0.94, 0.94, 0.94)  -- NES white
    local dname = g.name
    if #dname > 18 then dname = dname:sub(1, 17) .. "." end
    love.graphics.print(dname, px + 10, h - 132)
    love.graphics.setFont(font_small)
    love.graphics.setColor(0.63, 0.66, 0.72)  -- NES light gray
    love.graphics.print(("%s - %s"):format(MFR_NAME[g.mfr] or "?", g.date), px + 10, h - 104)

    -- footer
    love.graphics.setFont(font_small)
    love.graphics.setColor(0.5, 0.5, 0.55)  -- NES gray
    love.graphics.print("D-pad: browse   A: play   B: exit", 12, h - 26)
    love.graphics.pop()
end