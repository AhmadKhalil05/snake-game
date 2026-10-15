-- Small reusable particle system. It has no gameplay authority: it only draws feedback.
local Theme = require("theme")

local Effects = {}
Effects.__index = Effects

function Effects:new(random)
    return setmetatable({particles = {}, rings = {}, random = random or math.random}, Effects)
end

function Effects:clear()
    self.particles = {}
    self.rings = {}
end

function Effects:burst(x, y, color, count, strength)
    color = color or Theme.colors.mint
    count = count or 12
    strength = strength or 90
    for index = 1, count do
        local angle = (index / count) * math.pi * 2 + self.random() * 0.34
        local speed = strength * (0.50 + self.random() * 0.70)
        table.insert(self.particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.42 + self.random() * 0.26,
            maxLife = 0.68,
            size = 1.4 + self.random() * 2.6,
            color = color
        })
    end
    table.insert(self.rings, {
        x = x, y = y, radius = 4, maxRadius = 33,
        life = 0.42, maxLife = 0.42, color = color
    })
end

function Effects:shockwave(x, y, color)
    table.insert(self.rings, {
        x = x, y = y, radius = 15, maxRadius = 165,
        life = 0.55, maxLife = 0.55, color = color or Theme.colors.danger
    })
end

function Effects:update(dt)
    for index = #self.particles, 1, -1 do
        local particle = self.particles[index]
        particle.life = particle.life - dt
        if particle.life <= 0 then
            table.remove(self.particles, index)
        else
            particle.x = particle.x + particle.vx * dt
            particle.y = particle.y + particle.vy * dt
            particle.vx = particle.vx * (1 - math.min(dt * 3.2, 0.92))
            particle.vy = particle.vy * (1 - math.min(dt * 3.2, 0.92)) + 11 * dt
        end
    end

    for index = #self.rings, 1, -1 do
        local ring = self.rings[index]
        ring.life = ring.life - dt
        if ring.life <= 0 then
            table.remove(self.rings, index)
        else
            local progress = 1 - ring.life / ring.maxLife
            ring.radius = 4 + (ring.maxRadius - 4) * progress
        end
    end
end

function Effects:draw()
    local graphics = love.graphics
    for index = 1, #self.rings do
        local ring = self.rings[index]
        local alpha = math.max(0, ring.life / ring.maxLife)
        graphics.setColor(ring.color[1], ring.color[2], ring.color[3], alpha * 0.42)
        graphics.setLineWidth(2)
        graphics.circle("line", ring.x, ring.y, ring.radius)
    end

    for index = 1, #self.particles do
        local particle = self.particles[index]
        local alpha = math.max(0, particle.life / particle.maxLife)
        graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
        graphics.circle("fill", particle.x, particle.y, particle.size * (0.55 + alpha * 0.45))
    end
end

return Effects
