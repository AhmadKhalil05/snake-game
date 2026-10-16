-- Advanced visual effects and particle engine for the Neon Arcade aesthetic.
-- Purely visual feedback; has no authority over game simulation or rules.
local Theme = require("theme")

local Effects = {}
Effects.__index = Effects

function Effects:new(random)
    return setmetatable({
        particles = {},
        rings = {},
        popups = {},
        trails = {},
        random = random or (love and love.math and love.math.random) or math.random
    }, Effects)
end

function Effects:clear()
    self.particles = {}
    self.rings = {}
    self.popups = {}
    self.trails = {}
end

function Effects:burst(x, y, color, count, strength)
    color = color or Theme.colors.mint
    count = count or 14
    strength = strength or 105
    for index = 1, count do
        local angle = (index / count) * math.pi * 2 + self.random() * 0.4
        local speed = strength * (0.45 + self.random() * 0.85)
        table.insert(self.particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.45 + self.random() * 0.35,
            maxLife = 0.80,
            size = 1.6 + self.random() * 3.2,
            color = color,
            spin = (self.random() - 0.5) * 8
        })
    end

    -- Core flash ring
    table.insert(self.rings, {
        x = x, y = y, radius = 5, maxRadius = 38,
        life = 0.38, maxLife = 0.38, color = color,
        width = 2.5
    })
end

function Effects:shockwave(x, y, color)
    color = color or Theme.colors.danger
    table.insert(self.rings, {
        x = x, y = y, radius = 12, maxRadius = 180,
        life = 0.60, maxLife = 0.60, color = color,
        width = 3.5
    })
    table.insert(self.rings, {
        x = x, y = y, radius = 4, maxRadius = 90,
        life = 0.40, maxLife = 0.40, color = Theme.colors.cyan,
        width = 1.5
    })
end

function Effects:popup(x, y, text, color, scale)
    table.insert(self.popups, {
        x = x,
        y = y,
        text = tostring(text or "+1"),
        color = color or Theme.colors.mint,
        scale = scale or 1,
        life = 0.85,
        maxLife = 0.85,
        vy = -38
    })
end

function Effects:addTrail(x, y, color, size)
    table.insert(self.trails, {
        x = x,
        y = y,
        size = size or 16,
        color = color or Theme.colors.mint,
        life = 0.45,
        maxLife = 0.45
    })
end

function Effects:update(dt)
    dt = math.max(0, dt)

    -- Particles
    for index = #self.particles, 1, -1 do
        local p = self.particles[index]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.particles, index)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vx = p.vx * (1 - math.min(dt * 3.4, 0.90))
            p.vy = p.vy * (1 - math.min(dt * 3.4, 0.90)) + 12 * dt
        end
    end

    -- Expanding Shockwave Rings
    for index = #self.rings, 1, -1 do
        local ring = self.rings[index]
        ring.life = ring.life - dt
        if ring.life <= 0 then
            table.remove(self.rings, index)
        else
            local progress = 1 - ring.life / ring.maxLife
            ring.radius = 4 + (ring.maxRadius - 4) * (progress * (2 - progress)) -- ease out quad
        end
    end

    -- Floating Popups
    for index = #self.popups, 1, -1 do
        local pop = self.popups[index]
        pop.life = pop.life - dt
        if pop.life <= 0 then
            table.remove(self.popups, index)
        else
            pop.y = pop.y + pop.vy * dt
            pop.vy = pop.vy * (1 - math.min(dt * 2.2, 0.8))
        end
    end

    -- Phosphor Grid Trails
    for index = #self.trails, 1, -1 do
        local trail = self.trails[index]
        trail.life = trail.life - dt
        if trail.life <= 0 then
            table.remove(self.trails, index)
        end
    end
end

function Effects:draw(font)
    if not love or not love.graphics then return end
    local graphics = love.graphics

    -- Draw phosphor trails behind objects
    for index = 1, #self.trails do
        local trail = self.trails[index]
        local alpha = math.max(0, trail.life / trail.maxLife)
        graphics.setColor(trail.color[1], trail.color[2], trail.color[3], alpha * 0.18)
        graphics.rectangle("fill", trail.x - trail.size * 0.5, trail.y - trail.size * 0.5,
            trail.size, trail.size, 4, 4)
    end

    -- Shockwave rings
    for index = 1, #self.rings do
        local ring = self.rings[index]
        local alpha = math.max(0, ring.life / ring.maxLife)
        graphics.setColor(ring.color[1], ring.color[2], ring.color[3], alpha * 0.65)
        graphics.setLineWidth(ring.width or 2)
        graphics.circle("line", ring.x, ring.y, ring.radius)
        -- Soft inner glow
        graphics.setColor(ring.color[1], ring.color[2], ring.color[3], alpha * 0.12)
        graphics.circle("fill", ring.x, ring.y, ring.radius)
    end

    -- Particles
    for index = 1, #self.particles do
        local p = self.particles[index]
        local alpha = math.max(0, p.life / p.maxLife)
        -- Glow halo
        graphics.setColor(p.color[1], p.color[2], p.color[3], alpha * 0.35)
        graphics.circle("fill", p.x, p.y, p.size * 1.8)
        -- Solid core
        graphics.setColor(1, 1, 1, alpha * 0.95)
        graphics.circle("fill", p.x, p.y, p.size * 0.6)
    end

    -- Floating text popups
    if font then
        graphics.setFont(font)
    end
    for index = 1, #self.popups do
        local pop = self.popups[index]
        local alpha = math.max(0, pop.life / pop.maxLife)
        local scale = pop.scale or 1
        graphics.push()
        graphics.translate(pop.x, pop.y)
        if graphics.scale then
            graphics.scale(scale, scale)
        end
        -- Shadow glow
        graphics.setColor(0, 0, 0, alpha * 0.8)
        graphics.printf(pop.text, -100, 1, 200, "center")
        -- Main glowing text
        graphics.setColor(pop.color[1], pop.color[2], pop.color[3], alpha)
        graphics.printf(pop.text, -100, 0, 200, "center")
        graphics.pop()
    end

    graphics.setLineWidth(1)
    graphics.setColor(1, 1, 1, 1)
end

return Effects
