-- Central visual design system: colors, procedural shaders, and modern neon cyber-rendering.
-- Keeping this module rich and expressive allows gameplay logic to remain clean and decoupled.
local Theme = {}
Theme.__index = Theme

Theme.colors = {
    background = {0.016, 0.024, 0.048},
    backgroundTop = {0.035, 0.052, 0.108},
    surface = {0.050, 0.075, 0.138},
    surfaceBright = {0.078, 0.115, 0.198},
    line = {0.16, 0.28, 0.42},
    text = {0.92, 0.97, 1.00},
    muted = {0.48, 0.62, 0.78},
    cyan = {0.00, 0.94, 1.00},
    mint = {0.24, 1.00, 0.68},
    green = {0.12, 0.78, 0.46},
    violet = {0.68, 0.38, 1.00},
    pink = {1.00, 0.25, 0.62},
    orange = {1.00, 0.62, 0.18},
    gold = {1.00, 0.82, 0.24},
    danger = {1.00, 0.28, 0.38},
    black = {0.005, 0.008, 0.020}
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function Theme.new()
    return setmetatable({}, Theme)
end

function Theme.mix(a, b, amount)
    local t = clamp(amount, 0, 1)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t
    }
end

function Theme.setColor(color, alpha)
    if love and love.graphics then
        love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
    end
end

function Theme.pulse(time, speed, phase)
    return (math.sin((time or 0) * (speed or 1) + (phase or 0)) + 1) * 0.5
end

function Theme.createStars(count, width, height)
    local stars = {}
    for index = 1, count do
        local seed = index * 37.719
        local fractionX = (math.sin(seed * 1.71) + 1) * 0.5
        local fractionY = (math.sin(seed * 2.37 + 1.2) + 1) * 0.5
        stars[index] = {
            x = fractionX * (width or 800),
            y = fractionY * (height or 640),
            radius = 0.45 + ((math.sin(seed * 3.91) + 1) * 0.5) * 1.2,
            speed = 0.35 + ((math.sin(seed * 4.81) + 1) * 0.5) * 1.1,
            phase = seed,
            color = (index % 3 == 0) and Theme.colors.cyan or ((index % 3 == 1) and Theme.colors.mint or Theme.colors.violet)
        }
    end
    return stars
end

function Theme.drawBackground(time, stars, width, height)
    if not love or not love.graphics then return end
    local graphics = love.graphics
    width, height = width or 800, height or 640

    graphics.clear(Theme.colors.background[1], Theme.colors.background[2],
        Theme.colors.background[3], 1)

    -- Atmospheric gradient bands
    for band = 0, 14 do
        local t = band / 14
        local color = Theme.mix(Theme.colors.backgroundTop, Theme.colors.background, t)
        graphics.setColor(color[1], color[2], color[3], 1)
        graphics.rectangle("fill", 0, band * height / 15, width, height / 15 + 1)
    end

    -- Deep glowing nebulae behind the playing arena
    local glow = Theme.pulse(time, 0.75)
    Theme.glowCircle(width * 0.18, height * 0.22, 145 + glow * 20, Theme.colors.violet, 0.055, 5)
    Theme.glowCircle(width * 0.84, height * 0.75, 185 - glow * 15, Theme.colors.cyan, 0.048, 6)
    Theme.glowCircle(width * 0.50, height * 0.50, 120 + glow * 10, Theme.colors.mint, 0.025, 4)

    -- Ambient twinkling stars
    for index = 1, #(stars or {}) do
        local star = stars[index]
        local twinkle = 0.25 + Theme.pulse(time, star.speed, star.phase) * 0.65
        local c = star.color or Theme.colors.cyan
        graphics.setColor(c[1], c[2], c[3], twinkle * 0.9)
        graphics.circle("fill", star.x, star.y, star.radius)
        if star.radius > 1.2 and twinkle > 0.75 then
            graphics.setColor(1, 1, 1, (twinkle - 0.75) * 1.6)
            graphics.line(star.x - 3, star.y, star.x + 3, star.y)
            graphics.line(star.x, star.y - 3, star.x, star.y + 3)
        end
    end

    -- CRT cyber scan-lines
    graphics.setColor(0.18, 0.32, 0.52, 0.038)
    for y = 6, height, 6 do
        graphics.line(0, y, width, y)
    end
end

function Theme.glowCircle(x, y, radius, color, alpha, layers)
    if not love or not love.graphics then return end
    local graphics = love.graphics
    layers = layers or 4
    for layer = layers, 1, -1 do
        local progress = layer / layers
        graphics.setColor(color[1], color[2], color[3], (alpha or 0.1) * (1 - progress * 0.45))
        graphics.circle("fill", x, y, radius * (0.50 + progress * 0.65))
    end
end

function Theme.glowRect(x, y, width, height, radius, color, alpha, layers)
    if not love or not love.graphics then return end
    local graphics = love.graphics
    layers = layers or 4
    for layer = layers, 1, -1 do
        local expand = layer * 2.2
        local layerAlpha = (alpha or 0.12) * (1 - (layer - 1) / (layers + 1))
        graphics.setColor(color[1], color[2], color[3], layerAlpha)
        graphics.rectangle("fill", x - expand, y - expand, width + expand * 2,
            height + expand * 2, radius + expand, radius + expand)
    end
end

function Theme.panel(x, y, width, height, radius, accent, alpha)
    if not love or not love.graphics then return end
    local graphics = love.graphics
    accent = accent or Theme.colors.cyan
    alpha = alpha or 1
    Theme.glowRect(x, y, width, height, radius, accent, 0.05 * alpha, 4)
    graphics.setColor(Theme.colors.surface[1], Theme.colors.surface[2], Theme.colors.surface[3], 0.92 * alpha)
    graphics.rectangle("fill", x, y, width, height, radius, radius)
    -- Top glass shine line
    graphics.setColor(Theme.colors.surfaceBright[1], Theme.colors.surfaceBright[2],
        Theme.colors.surfaceBright[3], 0.65 * alpha)
    graphics.rectangle("fill", x + 1, y + 1, width - 2, 2, radius, radius)
    -- Neon accent border
    graphics.setColor(accent[1], accent[2], accent[3], 0.50 * alpha)
    graphics.setLineWidth(1)
    graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, radius, radius)
end

function Theme.badge(x, y, width, text, font, color)
    if not love or not love.graphics then return end
    local graphics = love.graphics
    color = color or Theme.colors.cyan
    if font then graphics.setFont(font) end
    graphics.setColor(color[1], color[2], color[3], 0.16)
    graphics.rectangle("fill", x, y, width, 24, 12, 12)
    graphics.setColor(color[1], color[2], color[3], 0.70)
    graphics.setLineWidth(1)
    graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, 23, 12, 12)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.printf(text, x, y + 5, width, "center")
end

function Theme.keycap(x, y, text, font, width)
    if not love or not love.graphics then return end
    local graphics = love.graphics
    width = width or 30
    if font then graphics.setFont(font) end
    graphics.setColor(0.09, 0.15, 0.24, 0.95)
    graphics.rectangle("fill", x, y, width, 22, 6, 6)
    graphics.setColor(0.30, 0.52, 0.72, 0.85)
    graphics.setLineWidth(1)
    graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, 21, 6, 6)
    graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 0.95)
    graphics.printf(text, x, y + 4, width, "center")
end

-- =========================================================================
-- MODERN ORGANIC CYBER-SNAKE RENDERING
-- =========================================================================
function Theme.drawSnake(snake, movement, renderer, cellSize, originX, originY, time)
    if not love or not love.graphics or not snake or #snake == 0 then return end
    local graphics = love.graphics
    local total = #snake
    local headColor = renderer and renderer.headColor or Theme.colors.mint
    local bodyColor = renderer and renderer.color or Theme.colors.green
    local tailColor = renderer and renderer.tailColor or Theme.colors.cyan

    -- Forward headlight cone from head
    local headPos = snake[1]
    local hx = originX + (headPos.x + 0.5) * cellSize
    local hy = originY + (headPos.y + 0.5) * cellSize
    local dx = movement and movement.dx or 1
    local dy = movement and movement.dy or 0

    graphics.push()
    local beamLength = cellSize * 2.8
    local beamWidth = cellSize * 1.5
    local fx = hx + dx * beamLength
    local fy = hy + dy * beamLength
    local lx = fx - dy * beamWidth * 0.5
    local ly = fy + dx * beamWidth * 0.5
    local rx = fx + dy * beamWidth * 0.5
    local ry = fy - dx * beamWidth * 0.5
    graphics.setColor(headColor[1], headColor[2], headColor[3], 0.055)
    if graphics.polygon then
        graphics.polygon("fill", hx, hy, lx, ly, rx, ry)
    else
        graphics.line(hx, hy, lx, ly)
        graphics.line(lx, ly, rx, ry)
        graphics.line(rx, ry, hx, hy)
    end
    graphics.pop()

    -- 1. Draw glowing connecting capsules between adjacent segments (continuous smooth body)
    for i = total, 2, -1 do
        local curr = snake[i]
        local prev = snake[i - 1]
        local depth = (i - 1) / math.max(1, total - 1)
        local segColor = Theme.mix(bodyColor, tailColor, depth * 0.85)
        local cx = originX + (curr.x + 0.5) * cellSize
        local cy = originY + (curr.y + 0.5) * cellSize
        local px = originX + (prev.x + 0.5) * cellSize
        local py = originY + (prev.y + 0.5) * cellSize

        -- Smooth tapered thickness
        local tRadius = cellSize * (0.38 - depth * 0.12)
        local pRadius = cellSize * (0.38 - math.max(0, depth - 1/total) * 0.12)

        -- Only draw connection if segments are adjacent (handles wrap or normal movement)
        if math.abs(curr.x - prev.x) + math.abs(curr.y - prev.y) <= 1.1 then
            graphics.setColor(segColor[1], segColor[2], segColor[3], 0.78)
            graphics.setLineWidth(tRadius * 1.9)
            graphics.line(cx, cy, px, py)
        end
    end

    -- 2. Draw Segment Nodes with glowing core
    for i = total, 1, -1 do
        local segment = snake[i]
        local depth = (i - 1) / math.max(1, total - 1)
        local isHead = (i == 1)
        local segColor = isHead and headColor or Theme.mix(bodyColor, tailColor, depth * 0.85)
        local cx = originX + (segment.x + 0.5) * cellSize
        local cy = originY + (segment.y + 0.5) * cellSize
        local radius = cellSize * (isHead and 0.44 or (0.40 - depth * 0.12))

        -- Soft outer bloom for first several segments
        if i <= 14 then
            local glowAlpha = isHead and 0.22 or (0.09 * (1 - i / 14))
            Theme.glowCircle(cx, cy, radius * 1.6, segColor, glowAlpha, 3)
        end

        -- Segment shell
        graphics.setColor(segColor[1], segColor[2], segColor[3], 1)
        graphics.circle("fill", cx, cy, radius)

        -- Segment inner specular/highlight
        graphics.setColor(1, 1, 1, isHead and 0.45 or 0.18)
        graphics.circle("fill", cx - 1.5, cy - 1.5, radius * 0.38)
    end

    -- 3. Cybernetic Laser Spine conduit connecting all segments
    if total >= 2 then
        graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.85)
        graphics.setLineWidth(1.8)
        for i = total, 2, -1 do
            local curr = snake[i]
            local prev = snake[i - 1]
            if math.abs(curr.x - prev.x) + math.abs(curr.y - prev.y) <= 1.1 then
                local cx = originX + (curr.x + 0.5) * cellSize
                local cy = originY + (curr.y + 0.5) * cellSize
                local px = originX + (prev.x + 0.5) * cellSize
                local py = originY + (prev.y + 0.5) * cellSize
                graphics.line(cx, cy, px, py)
            end
        end

        -- Pulsing data packets traveling down the spine
        for i = 1, total do
            local pulseVal = Theme.pulse(time, 9, -i * 0.42)
            if pulseVal > 0.65 then
                local segment = snake[i]
                local cx = originX + (segment.x + 0.5) * cellSize
                local cy = originY + (segment.y + 0.5) * cellSize
                graphics.setColor(1, 1, 1, (pulseVal - 0.65) * 2.8)
                graphics.circle("fill", cx, cy, 2.2)
            end
        end
    end

    -- 4. Cybernetic Head Details (Glowing visor / dual optics)
    local forward = cellSize * 0.22
    local sideways = cellSize * 0.20
    local eyeBaseX = hx + dx * forward
    local eyeBaseY = hy + dy * forward

    -- Cyber sensor sockets
    graphics.setColor(0.012, 0.035, 0.05, 1)
    graphics.circle("fill", eyeBaseX - dy * sideways, eyeBaseY + dx * sideways, 2.8)
    graphics.circle("fill", eyeBaseX + dy * sideways, eyeBaseY - dx * sideways, 2.8)

    -- Glowing optics (cyan/white laser sensors)
    local eyeGlow = 0.85 + Theme.pulse(time, 8) * 0.15
    graphics.setColor(0.1, 0.95, 1.0, eyeGlow)
    graphics.circle("fill", eyeBaseX - dy * sideways + dx * 0.5, eyeBaseY + dx * sideways + dy * 0.5, 1.6)
    graphics.circle("fill", eyeBaseX + dy * sideways + dx * 0.5, eyeBaseY - dx * sideways + dy * 0.5, 1.6)
    graphics.setColor(1, 1, 1, 0.95)
    graphics.circle("fill", eyeBaseX - dy * sideways + dx * 0.8, eyeBaseY + dx * sideways + dy * 0.8, 0.8)
    graphics.circle("fill", eyeBaseX + dy * sideways + dx * 0.8, eyeBaseY - dx * sideways + dy * 0.8, 0.8)

    graphics.setLineWidth(1)
    graphics.setColor(1, 1, 1, 1)
end

-- =========================================================================
-- LIVING MULTI-LAYER FOOD PLASMA CORE
-- =========================================================================
function Theme.drawFood(foodPos, cellSize, originX, originY, time, isNear)
    if not love or not love.graphics or not foodPos then return end
    local graphics = love.graphics
    local fx = originX + (foodPos.x + 0.5) * cellSize
    local fy = originY + (foodPos.y + 0.5) * cellSize

    local pulseSpeed = isNear and 9.5 or 5.2
    local pulse = Theme.pulse(time, pulseSpeed)
    local coreRadius = cellSize * (0.28 + pulse * 0.05)

    -- 1. Outer chromatic dispersion aura
    Theme.glowCircle(fx, fy, cellSize * (0.75 + pulse * 0.22), Theme.colors.pink, 0.12 + pulse * 0.06, 5)
    Theme.glowCircle(fx, fy, cellSize * (0.45 + pulse * 0.12), Theme.colors.orange, 0.16, 4)

    -- 2. Rotating orbital nano-satellites
    local orbitRadius = cellSize * (0.48 + pulse * 0.08)
    local rotAngle = time * (isNear and 4.8 or 2.6)
    for orbit = 1, 3 do
        local angle = rotAngle + (orbit * (math.pi * 2 / 3))
        local ox = fx + math.cos(angle) * orbitRadius
        local oy = fy + math.sin(angle) * orbitRadius
        graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.85)
        graphics.circle("fill", ox, oy, 1.8)
        graphics.setColor(1, 1, 1, 0.9)
        graphics.circle("fill", ox, oy, 0.9)
    end

    -- 3. Core plasma orb
    graphics.setColor(Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3], 1)
    graphics.circle("fill", fx, fy, coreRadius)

    -- 4. Inner white-hot energy nucleus
    graphics.setColor(1, 0.94, 0.75, 0.98)
    graphics.circle("fill", fx - coreRadius * 0.25, fy - coreRadius * 0.25, coreRadius * 0.42)

    -- 5. Pulsing perimeter containment ring
    graphics.setColor(Theme.colors.pink[1], Theme.colors.pink[2], Theme.colors.pink[3], 0.85)
    graphics.setLineWidth(1.6)
    graphics.circle("line", fx, fy, coreRadius * 1.35)

    graphics.setLineWidth(1)
    graphics.setColor(1, 1, 1, 1)
end

-- =========================================================================
-- MODERN CYBER-GRID ARENA WITH CHAMFERED BRACKETS
-- =========================================================================
function Theme.drawGridArena(originX, originY, columns, rows, cellSize, time)
    if not love or not love.graphics then return end
    local graphics = love.graphics
    local boardWidth = columns * cellSize
    local boardHeight = rows * cellSize

    -- Background arena plate
    graphics.setColor(Theme.colors.surface[1], Theme.colors.surface[2], Theme.colors.surface[3], 0.88)
    graphics.rectangle("fill", originX, originY, boardWidth, boardHeight, 8, 8)

    -- Matrix micro-dots at grid intersections (subtle, non-distracting)
    graphics.setColor(Theme.colors.line[1], Theme.colors.line[2], Theme.colors.line[3], 0.28)
    for y = 0, rows do
        for x = 0, columns do
            if (x % 3 == 0) and (y % 3 == 0) then
                local px = originX + x * cellSize
                local py = originY + y * cellSize
                graphics.rectangle("fill", px - 0.5, py - 0.5, 1, 1)
            end
        end
    end

    -- Inner neon grid lines (faint)
    graphics.setColor(Theme.colors.line[1], Theme.colors.line[2], Theme.colors.line[3], 0.16)
    for x = 1, columns - 1 do
        local px = originX + x * cellSize
        graphics.line(px, originY, px, originY + boardHeight)
    end
    for y = 1, rows - 1 do
        local py = originY + y * cellSize
        graphics.line(originX, py, originX + boardWidth, py)
    end

    -- Neon perimeter frame
    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.65)
    graphics.setLineWidth(1.2)
    graphics.rectangle("line", originX - 0.5, originY - 0.5, boardWidth + 1, boardHeight + 1, 8, 8)

    -- Chamfered corner cyber brackets
    local bSize = 24
    graphics.setLineWidth(2)
    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.95)

    -- Top-left
    graphics.line(originX - 6, originY + bSize, originX - 6, originY - 6)
    graphics.line(originX - 6, originY - 6, originX + bSize, originY - 6)

    -- Top-right
    graphics.line(originX + boardWidth - bSize, originY - 6, originX + boardWidth + 6, originY - 6)
    graphics.line(originX + boardWidth + 6, originY - 6, originX + boardWidth + 6, originY + bSize)

    -- Bottom-left
    graphics.line(originX - 6, originY + boardHeight - bSize, originX - 6, originY + boardHeight + 6)
    graphics.line(originX - 6, originY + boardHeight + 6, originX + bSize, originY + boardHeight + 6)

    -- Bottom-right
    graphics.line(originX + boardWidth - bSize, originY + boardHeight + 6, originX + boardWidth + 6, originY + boardHeight + 6)
    graphics.line(originX + boardWidth + 6, originY + boardHeight + 6, originX + boardWidth + 6, originY + boardHeight - bSize)

    graphics.setLineWidth(1)
    graphics.setColor(1, 1, 1, 1)
end

return Theme
