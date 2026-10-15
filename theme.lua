-- Central visual system: colors and drawing helpers for the Neon Arcade look.
-- Keeping it separate lets gameplay code stay focused on rules and collision.
local Theme = {}
Theme.__index = Theme

Theme.colors = {
    background = {0.018, 0.027, 0.055},
    backgroundTop = {0.038, 0.057, 0.115},
    surface = {0.055, 0.082, 0.145},
    surfaceBright = {0.082, 0.121, 0.205},
    line = {0.18, 0.30, 0.43},
    text = {0.90, 0.96, 1.00},
    muted = {0.50, 0.63, 0.76},
    cyan = {0.22, 0.91, 1.00},
    mint = {0.36, 1.00, 0.67},
    green = {0.13, 0.72, 0.43},
    violet = {0.63, 0.43, 1.00},
    pink = {1.00, 0.32, 0.58},
    orange = {1.00, 0.65, 0.22},
    danger = {1.00, 0.31, 0.38},
    black = {0.006, 0.010, 0.024}
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
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
end

function Theme.pulse(time, speed, phase)
    return (math.sin(time * speed + (phase or 0)) + 1) * 0.5
end

function Theme.createStars(count, width, height)
    local stars = {}
    -- Deterministic values make the background stable without touching game RNG.
    for index = 1, count do
        local seed = index * 37.719
        local fractionX = (math.sin(seed * 1.71) + 1) * 0.5
        local fractionY = (math.sin(seed * 2.37 + 1.2) + 1) * 0.5
        stars[index] = {
            x = fractionX * width,
            y = fractionY * height,
            radius = 0.45 + ((math.sin(seed * 3.91) + 1) * 0.5) * 1.15,
            speed = 0.35 + ((math.sin(seed * 4.81) + 1) * 0.5) * 1.1,
            phase = seed
        }
    end
    return stars
end

function Theme.drawBackground(time, stars, width, height)
    local graphics = love.graphics
    width, height = width or 800, height or 640

    graphics.clear(Theme.colors.background[1], Theme.colors.background[2],
        Theme.colors.background[3], 1)

    -- Layered translucent bands imitate a deep arcade-gradient without assets.
    for band = 0, 12 do
        local t = band / 12
        local color = Theme.mix(Theme.colors.backgroundTop, Theme.colors.background, t)
        graphics.setColor(color[1], color[2], color[3], 1)
        graphics.rectangle("fill", 0, band * height / 13, width, height / 13 + 1)
    end

    -- Soft neon halos behind the play field.
    local glow = Theme.pulse(time, 0.65)
    Theme.glowCircle(width * 0.16, height * 0.18, 126 + glow * 15,
        Theme.colors.violet, 0.055, 5)
    Theme.glowCircle(width * 0.86, height * 0.77, 174 - glow * 12,
        Theme.colors.cyan, 0.045, 6)

    for index = 1, #(stars or {}) do
        local star = stars[index]
        local twinkle = 0.30 + Theme.pulse(time, star.speed, star.phase) * 0.55
        graphics.setColor(0.54, 0.82, 1.0, twinkle)
        graphics.circle("fill", star.x, star.y, star.radius)
    end

    -- Very subtle scan-lines make the background feel like an arcade display.
    graphics.setColor(0.18, 0.34, 0.55, 0.045)
    for y = 8, height, 8 do
        graphics.line(0, y, width, y)
    end
end

function Theme.glowCircle(x, y, radius, color, alpha, layers)
    local graphics = love.graphics
    layers = layers or 4
    for layer = layers, 1, -1 do
        local progress = layer / layers
        graphics.setColor(color[1], color[2], color[3], (alpha or 0.1) * (1 - progress * 0.48))
        graphics.circle("fill", x, y, radius * (0.54 + progress * 0.60))
    end
end

function Theme.glowRect(x, y, width, height, radius, color, alpha, layers)
    local graphics = love.graphics
    layers = layers or 4
    for layer = layers, 1, -1 do
        local expand = layer * 2
        local layerAlpha = (alpha or 0.12) * (1 - (layer - 1) / (layers + 1))
        graphics.setColor(color[1], color[2], color[3], layerAlpha)
        graphics.rectangle("fill", x - expand, y - expand, width + expand * 2,
            height + expand * 2, radius + expand, radius + expand)
    end
end

function Theme.panel(x, y, width, height, radius, accent, alpha)
    local graphics = love.graphics
    accent = accent or Theme.colors.cyan
    alpha = alpha or 1
    Theme.glowRect(x, y, width, height, radius, accent, 0.045 * alpha, 4)
    graphics.setColor(Theme.colors.surface[1], Theme.colors.surface[2], Theme.colors.surface[3], 0.94 * alpha)
    graphics.rectangle("fill", x, y, width, height, radius, radius)
    graphics.setColor(Theme.colors.surfaceBright[1], Theme.colors.surfaceBright[2],
        Theme.colors.surfaceBright[3], 0.55 * alpha)
    graphics.rectangle("fill", x + 1, y + 1, width - 2, 2, radius, radius)
    graphics.setColor(accent[1], accent[2], accent[3], 0.45 * alpha)
    graphics.setLineWidth(1)
    graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, radius, radius)
end

function Theme.badge(x, y, width, text, font, color)
    local graphics = love.graphics
    color = color or Theme.colors.cyan
    graphics.setFont(font)
    graphics.setColor(color[1], color[2], color[3], 0.16)
    graphics.rectangle("fill", x, y, width, 24, 12, 12)
    graphics.setColor(color[1], color[2], color[3], 0.65)
    graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, 23, 12, 12)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.printf(text, x, y + 5, width, "center")
end

function Theme.keycap(x, y, text, font, width)
    local graphics = love.graphics
    width = width or 30
    graphics.setFont(font)
    graphics.setColor(0.10, 0.16, 0.25, 0.95)
    graphics.rectangle("fill", x, y, width, 22, 5, 5)
    graphics.setColor(0.29, 0.48, 0.66, 0.78)
    graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, 21, 5, 5)
    graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 0.95)
    graphics.printf(text, x, y + 4, width, "center")
end

return Theme
