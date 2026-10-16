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

    -- Modern combo mechanic
    game.combo = 1
    game.comboTimer = 0
    game.maxCombo = 1
    game.comboMaxTime = 3.6

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
        color = {0.12, 0.78, 0.46},
        tailColor = {0.00, 0.94, 1.00},
        headColor = {0.24, 1.00, 0.68}
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
        score = self.score, best = self.best, reason = reason, maxCombo = self.maxCombo
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
        if self.comboTimer > 0 then
            self.combo = self.combo + 1
        else
            self.combo = 1
        end
        self.maxCombo = math.max(self.maxCombo, self.combo)
        self.comboTimer = self.comboMaxTime

        self:_saveBest()
        self.events:emit("food_eaten", {
            score = self.score,
            length = #self.snake,
            position = nextHead,
            combo = self.combo
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

    -- Update combo decay
    if self.comboTimer > 0 then
        self.comboTimer = math.max(0, self.comboTimer - dt)
        if self.comboTimer == 0 then
            self.combo = 1
        end
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
    if not love or not love.graphics then return end
    local renderer = self.entity:getComponent("renderer")
    local cellSize = renderer.size
    time = time or self.visualTime

    -- 1. Draw glowing Cyber-Grid Arena
    Theme.drawGridArena(self.originX, self.originY, self.columns, self.rows, cellSize, time)

    -- 2. Draw Living Plasma Food
    local head = self.entity:getComponent("position")
    local isNear = (self.food and head) and (math.abs(self.food.x - head.x) + math.abs(self.food.y - head.y) <= 4)
    Theme.drawFood(self.food, cellSize, self.originX, self.originY, time, isNear)

    -- 3. Draw Organic Cybernetic Snake
    local movement = self.entity:getComponent("movement")
    Theme.drawSnake(self.snake, movement, renderer, cellSize, self.originX, self.originY, time)
end

return SnakeGame
