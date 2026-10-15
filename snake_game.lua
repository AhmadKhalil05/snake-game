local Vector2 = require("vector2")
local Entity = require("entity")
local Events = require("events")
local HighScore = require("highscore")
local Theme = require("theme")

local SnakeGame = {}
SnakeGame.__index = SnakeGame

function SnakeGame:new(options)
    options = options or {}
    local game = setmetatable({}, SnakeGame)

    game.columns = options.columns or 36
    game.rows = options.rows or 24
    game.originX = options.originX or 40
    game.originY = options.originY or 116
    assert(game.columns >= 2 and game.rows >= 1, "The board is too small")

    game.events = options.events or Events:new()
    game.highScoreStore = options.highScore or HighScore:new()
    game.random = options.random
        or (love and love.math and love.math.random)
        or math.random

    game.score = 0
    game.best = game.highScoreStore:load()
    game.gameOver = false
    game.won = false
    game.paused = false
    game.reason = nil
    game.saveError = nil
    game.visualTime = 0

    local headX = math.floor(game.columns / 2)
    local headY = math.floor(game.rows / 2)
    local initialLength = math.min(options.initialLength or 3, headX + 1)
    assert(initialLength >= 1, "The snake must have at least one segment")
    game.snake = {}
    for i = 0, initialLength - 1 do
        table.insert(game.snake, Vector2:new(headX - i, headY))
    end

    game.entity = Entity:new()
    game.entity:addComponent("position", game.snake[1])
    game.entity:addComponent("movement", {
        dx = 1, dy = 0,
        nextDx = 1, nextDy = 0,
        timer = 0,
        interval = options.interval or 0.16
    })
    game.entity:addComponent("renderer", {
        size = options.cellSize or 20,
        color = {0.10, 0.64, 0.42},
        tailColor = {0.12, 0.34, 0.42},
        headColor = {0.40, 1.00, 0.67}
    })
    assert(game.entity:getComponent("movement").interval > 0,
        "Movement interval must be positive")

    game:spawnFood()
    return game
end

function SnakeGame:cellCenter(position)
    local size = self.entity:getComponent("renderer").size
    return self.originX + (position.x + 0.5) * size,
        self.originY + (position.y + 0.5) * size
end

function SnakeGame:spawnFood()
    local occupied = {}
    for i = 1, #self.snake do
        local segment = self.snake[i]
        occupied[segment.y * self.columns + segment.x] = true
    end

    -- Choose from empty cells. This also terminates when the whole board is full.
    local emptyCells = {}
    for y = 0, self.rows - 1 do
        for x = 0, self.columns - 1 do
            if not occupied[y * self.columns + x] then
                table.insert(emptyCells, Vector2:new(x, y))
            end
        end
    end

    if #emptyCells == 0 then
        self.food = nil
        self.won = true
        self.gameOver = true
        self.reason = "board_complete"
        self.events:emit("game_won", {score = self.score, best = self.best})
        return
    end

    self.food = emptyCells[self.random(1, #emptyCells)]
end

function SnakeGame:_saveBest()
    local newRecord = self.score > self.best
    if newRecord then
        self.best = self.score
    end
    if newRecord or self.saveError then
        local saved, message = self.highScoreStore:save(self.best)
        self.saveError = not saved and (message or "Could not save the score") or nil
    end
end

function SnakeGame:_finish(reason)
    self.gameOver = true
    self.reason = reason
    self:_saveBest()
    self.events:emit("game_over", {
        score = self.score, best = self.best, reason = reason
    })
end

function SnakeGame:changeDirection(dx, dy)
    if self.gameOver then
        return false
    end
    local cardinal = (dx == 1 and dy == 0) or (dx == -1 and dy == 0)
        or (dx == 0 and dy == 1) or (dx == 0 and dy == -1)
    if not cardinal then
        return false
    end

    local movement = self.entity:getComponent("movement")
    -- Compare with the last actual move, not another queued key press.
    -- This prevents a right -> up -> left reversal within one movement tick.
    if dx == -movement.dx and dy == -movement.dy then
        return false
    end
    movement.nextDx = dx
    movement.nextDy = dy
    return true
end

function SnakeGame:_step()
    local movement = self.entity:getComponent("movement")
    movement.dx = movement.nextDx
    movement.dy = movement.nextDy

    local position = self.entity:getComponent("position")
    local nextHead = position + Vector2:new(movement.dx, movement.dy)
    local eating = self.food ~= nil and nextHead == self.food

    if nextHead.x < 0 or nextHead.x >= self.columns
        or nextHead.y < 0 or nextHead.y >= self.rows then
        self:_finish("wall")
        return
    end

    -- When not growing, the tail vacates its cell during this same step.
    local lastOccupied = eating and #self.snake or (#self.snake - 1)
    for i = 1, lastOccupied do
        if nextHead == self.snake[i] then
            self:_finish("self")
            return
        end
    end

    table.insert(self.snake, 1, nextHead)
    self.entity:addComponent("position", nextHead)

    if eating then
        self.score = self.score + 1
        self:_saveBest()
        self.events:emit("food_eaten", {
            score = self.score,
            length = #self.snake,
            position = nextHead
        })
        self:spawnFood()
    else
        table.remove(self.snake)
    end
end

function SnakeGame:update(dt)
    if dt > 0 then
        self.visualTime = self.visualTime + dt
    end
    if self.gameOver or self.paused or dt <= 0 then
        return
    end

    local movement = self.entity:getComponent("movement")
    movement.timer = movement.timer + dt
    -- Allow tiny floating-point rounding errors at an exact tick boundary.
    while movement.timer + 1e-9 >= movement.interval and not self.gameOver do
        movement.timer = math.max(0, movement.timer - movement.interval)
        self:_step()
    end
end

function SnakeGame:togglePause()
    if not self.gameOver then
        self.paused = not self.paused
    end
end

function SnakeGame:draw(time)
    local graphics = love.graphics
    local renderer = self.entity:getComponent("renderer")
    local cellSize = renderer.size
    local boardWidth = self.columns * cellSize
    local boardHeight = self.rows * cellSize
    time = time or self.visualTime

    -- Framed board with a soft cyan halo.
    Theme.glowRect(self.originX - 8, self.originY - 8,
        boardWidth + 16, boardHeight + 16, 13, Theme.colors.cyan, 0.075, 5)
    graphics.setColor(0.012, 0.024, 0.049, 0.98)
    graphics.rectangle("fill", self.originX - 7, self.originY - 7,
        boardWidth + 14, boardHeight + 14, 12, 12)
    graphics.setColor(0.075, 0.12, 0.19, 1)
    graphics.rectangle("fill", self.originX, self.originY, boardWidth, boardHeight, 6, 6)

    -- The grid is deliberately quiet so the snake and food stay dominant.
    graphics.setLineWidth(1)
    for x = 1, self.columns - 1 do
        local pixelX = self.originX + x * cellSize
        local major = x % 6 == 0
        graphics.setColor(0.18, 0.38, 0.50, major and 0.18 or 0.075)
        graphics.line(pixelX, self.originY, pixelX, self.originY + boardHeight)
    end
    for y = 1, self.rows - 1 do
        local pixelY = self.originY + y * cellSize
        local major = y % 6 == 0
        graphics.setColor(0.18, 0.38, 0.50, major and 0.18 or 0.075)
        graphics.line(self.originX, pixelY, self.originX + boardWidth, pixelY)
    end

    -- Corner indicators make the board read as a neon terminal panel.
    local corner = 23
    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.82)
    graphics.line(self.originX - 7, self.originY + corner, self.originX - 7, self.originY - 1)
    graphics.line(self.originX - 7, self.originY - 7, self.originX + corner, self.originY - 7)
    graphics.line(self.originX + boardWidth - corner, self.originY - 7,
        self.originX + boardWidth + 7, self.originY - 7)
    graphics.line(self.originX + boardWidth + 7, self.originY - 7,
        self.originX + boardWidth + 7, self.originY + corner)
    graphics.line(self.originX - 7, self.originY + boardHeight - corner,
        self.originX - 7, self.originY + boardHeight + 7)
    graphics.line(self.originX - 7, self.originY + boardHeight + 7,
        self.originX + corner, self.originY + boardHeight + 7)
    graphics.line(self.originX + boardWidth - corner, self.originY + boardHeight + 7,
        self.originX + boardWidth + 7, self.originY + boardHeight + 7)
    graphics.line(self.originX + boardWidth + 7, self.originY + boardHeight + 7,
        self.originX + boardWidth + 7, self.originY + boardHeight - corner)

    if self.food then
        local foodX, foodY = self:cellCenter(self.food)
        local pulse = Theme.pulse(time, 5.4)
        Theme.glowCircle(foodX, foodY, cellSize * (0.54 + pulse * 0.14),
            Theme.colors.pink, 0.09 + pulse * 0.045, 5)
        graphics.setColor(Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3], 1)
        graphics.circle("fill", foodX, foodY, cellSize * (0.24 + pulse * 0.025))
        graphics.setColor(1, 0.90, 0.65, 0.95)
        graphics.circle("fill", foodX - cellSize * 0.075, foodY - cellSize * 0.085, cellSize * 0.068)
        graphics.setColor(Theme.colors.pink[1], Theme.colors.pink[2], Theme.colors.pink[3], 0.9)
        graphics.setLineWidth(1.5)
        graphics.circle("line", foodX, foodY, cellSize * (0.32 + pulse * 0.045))
    end

    local totalSegments = math.max(1, #self.snake - 1)
    for i = #self.snake, 1, -1 do
        local segment = self.snake[i]
        local depth = (i - 1) / totalSegments
        local color = i == 1 and renderer.headColor
            or Theme.mix(renderer.color, renderer.tailColor, depth * 0.70)
        local x = self.originX + segment.x * cellSize
        local y = self.originY + segment.y * cellSize
        local padding = i == 1 and 1.5 or 2.2
        local segmentSize = cellSize - padding * 2

        if i <= 16 then
            Theme.glowRect(x + padding, y + padding, segmentSize, segmentSize, 6,
                color, i == 1 and 0.17 or 0.055, 3)
        end
        graphics.setColor(color[1], color[2], color[3], 1)
        graphics.rectangle("fill", x + padding, y + padding, segmentSize, segmentSize, 5, 5)
        graphics.setColor(0.82, 1.0, 0.92, i == 1 and 0.58 or 0.20)
        graphics.rectangle("line", x + padding + 0.5, y + padding + 0.5,
            segmentSize - 1, segmentSize - 1, 4, 4)
        graphics.setColor(1, 1, 1, i == 1 and 0.19 or 0.075)
        graphics.rectangle("fill", x + padding + 3, y + padding + 3,
            math.max(2, segmentSize - 7), 2, 2, 2)
    end

    -- Two directional eyes make the head feel alive without a sprite asset.
    local head = self.entity:getComponent("position")
    local movement = self.entity:getComponent("movement")
    local headX, headY = self:cellCenter(head)
    local forward = cellSize * 0.17
    local sideways = cellSize * 0.18
    local eyeBaseX = headX + movement.dx * forward
    local eyeBaseY = headY + movement.dy * forward
    graphics.setColor(0.015, 0.055, 0.06, 1)
    graphics.circle("fill", eyeBaseX - movement.dy * sideways, eyeBaseY + movement.dx * sideways, 2.25)
    graphics.circle("fill", eyeBaseX + movement.dy * sideways, eyeBaseY - movement.dx * sideways, 2.25)
    graphics.setColor(0.80, 1, 0.95, 0.9)
    graphics.circle("fill", eyeBaseX - movement.dy * sideways - movement.dx * 0.5,
        eyeBaseY + movement.dx * sideways - movement.dy * 0.5, 0.65)
    graphics.circle("fill", eyeBaseX + movement.dy * sideways - movement.dx * 0.5,
        eyeBaseY - movement.dx * sideways - movement.dy * 0.5, 0.65)

    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.62)
    graphics.setLineWidth(1)
    graphics.rectangle("line", self.originX - 0.5, self.originY - 0.5,
        boardWidth + 1, boardHeight + 1, 6, 6)
    graphics.setColor(1, 1, 1, 1)
end

return SnakeGame
