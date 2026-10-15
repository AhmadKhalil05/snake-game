-- Run from the project directory: lua tests/run.lua
-- Works with Lua 5.4 and LuaJIT. No test framework or window is required.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Vector2 = require("vector2")
local Entity = require("entity")
local Input = require("input")
local Events = require("events")
local HighScore = require("highscore")
local SnakeGame = require("snake_game")

local passed, failed = 0, 0
local function check(name, test)
    local ok, message = pcall(test)
    if ok then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name .. ": " .. tostring(message))
    end
end

local function memoryScore(best)
    return {
        best = best or 0,
        writes = 0,
        load = function(self) return self.best end,
        save = function(self, score)
            self.best = score
            self.writes = self.writes + 1
            return true
        end
    }
end

local function newGame(options)
    options = options or {}
    options.columns = options.columns or 12
    options.rows = options.rows or 8
    options.interval = options.interval or 0.125
    options.initialLength = options.initialLength or 1
    options.highScore = options.highScore or memoryScore()
    options.random = options.random or function(first) return first end
    return SnakeGame:new(options)
end

local function position(game, coordinates, dx, dy)
    game.snake = {}
    for i = 1, #coordinates do
        game.snake[i] = Vector2:new(coordinates[i][1], coordinates[i][2])
    end
    game.entity:addComponent("position", game.snake[1])
    local movement = game.entity:getComponent("movement")
    movement.dx, movement.dy = dx, dy
    movement.nextDx, movement.nextDy = dx, dy
    movement.timer = 0
    game.food = Vector2:new(game.columns - 1, game.rows - 1)
end

check("Vector2 addition returns the correct vector", function()
    local a = Vector2:new(2, 3)
    local result = a + Vector2:new(-1, 4)
    assert(result == Vector2:new(1, 7))
    assert(a == Vector2:new(2, 3))
end)

check("Vector2 equality compares both coordinates", function()
    assert(Vector2:new(2, 3) == Vector2:new(2, 3))
    assert(Vector2:new(2, 3) ~= Vector2:new(2, 4))
end)

check("Vector2 tostring is readable", function()
    assert(tostring(Vector2:new(2, -3)) == "Vector2(2, -3)")
end)

check("Entity stores, retrieves and detects components", function()
    local entity = Entity:new()
    local component = Vector2:new(4, 5)
    assert(not entity:hasComponent("position"))
    entity:addComponent("position", component)
    assert(entity:getComponent("position") == component)
    assert(entity:hasComponent("position"))
    assert(entity:getComponent("missing") == nil)
    entity:addComponent("enabled", false)
    assert(entity:hasComponent("enabled"))
end)

check("Input executes bound commands and ignores unknown keys", function()
    local input = Input:new()
    local calls = 0
    input:bind("up", function() calls = calls + 1 end)
    assert(input:handleKey("up"))
    assert(not input:handleKey("unknown"))
    assert(calls == 1)
end)

check("Events notify each subscriber with data", function()
    local events = Events:new()
    local total = 0
    events:subscribe("food_eaten", function(data) total = total + data.score end)
    events:subscribe("food_eaten", function(data) total = total + data.score end)
    events:emit("food_eaten", {score = 3})
    events:emit("unregistered", {})
    assert(total == 6)
end)

check("Event buses are independent", function()
    local a, b = Events:new(), Events:new()
    local calls = 0
    a:subscribe("test", function() calls = calls + 1 end)
    b:emit("test", {})
    assert(calls == 0)
end)

check("Snake uses all three required components", function()
    local game = newGame()
    assert(game.entity:hasComponent("position"))
    assert(game.entity:hasComponent("movement"))
    assert(game.entity:hasComponent("renderer"))
end)

check("Snake moves continuously without a key press", function()
    local game = newGame()
    local before = game.snake[1]
    game:update(0.125)
    assert(game.snake[1] == before + Vector2:new(1, 0))
    assert(#game.snake == 1)
end)

check("Partial frame times accumulate", function()
    local game = newGame()
    local before = game.snake[1]
    game:update(0.0625)
    assert(game.snake[1] == before)
    game:update(0.0625)
    assert(game.snake[1] == before + Vector2:new(1, 0))
end)

check("A slow frame still performs each movement tick", function()
    local game = newGame({interval = 0.16})
    local before = game.snake[1]
    game:update(0.48)
    assert(game.snake[1] == before + Vector2:new(3, 0))
end)

check("Immediate reversal is rejected", function()
    local game = newGame()
    assert(not game:changeDirection(-1, 0))
    assert(not game:changeDirection(1, 1))
    assert(game:changeDirection(0, -1))
end)

check("Rapid queued keys cannot reverse the actual direction", function()
    local game = newGame()
    local before = game.snake[1]
    assert(game:changeDirection(0, -1))
    assert(not game:changeDirection(-1, 0))
    game:update(0.125)
    assert(game.snake[1] == before + Vector2:new(0, -1))
    assert(not game:changeDirection(0, 1))
end)

check("Eating increases score and length and emits an event", function()
    local events = Events:new()
    local data
    events:subscribe("food_eaten", function(value) data = value end)
    local game = newGame({events = events})
    game.food = game.snake[1] + Vector2:new(1, 0)
    game:update(0.125)
    assert(game.score == 1 and #game.snake == 2)
    assert(data.score == 1 and data.length == 2)
    assert(game.highScoreStore.best == 1)
end)

check("An existing higher record is not overwritten", function()
    local store = memoryScore(20)
    local game = newGame({highScore = store})
    game.food = game.snake[1] + Vector2:new(1, 0)
    game:update(0.125)
    assert(game.score == 1 and game.best == 20 and store.writes == 0)
end)

check("Food stays in bounds and away from every segment", function()
    local game = newGame({initialLength = 3})
    position(game, {{0, 0}, {1, 0}, {2, 0}}, 1, 0)
    game:spawnFood()
    assert(game.food.x >= 0 and game.food.x < game.columns)
    assert(game.food.y >= 0 and game.food.y < game.rows)
    for i = 1, #game.snake do assert(game.food ~= game.snake[i]) end
end)

local wallCases = {
    left = {{0, 2}, -1, 0}, right = {{11, 2}, 1, 0},
    top = {{3, 0}, 0, -1}, bottom = {{3, 7}, 0, 1}
}
for name, fixture in pairs(wallCases) do
    check("Wall collision at " .. name, function()
        local game = newGame()
        position(game, {fixture[1]}, fixture[2], fixture[3])
        local before = game.snake[1]
        game:update(0.125)
        assert(game.gameOver and game.reason == "wall")
        assert(game.snake[1] == before)
    end)
end

check("Self collision ends the round before changing the body", function()
    local game = newGame()
    position(game, {{2, 2}, {2, 3}, {3, 3}, {3, 2}, {4, 2}}, 1, 0)
    game:update(0.125)
    assert(game.gameOver and game.reason == "self")
    assert(game.snake[1] == Vector2:new(2, 2) and #game.snake == 5)
end)

check("Moving into the vacating tail is legal", function()
    local game = newGame()
    position(game, {{2, 2}, {2, 3}, {3, 3}, {3, 2}}, 1, 0)
    game:update(0.125)
    assert(not game.gameOver)
    assert(game.snake[1] == Vector2:new(3, 2) and #game.snake == 4)
end)

check("A paused game does not move or accumulate elapsed time", function()
    local game = newGame()
    local before = game.snake[1]
    game:togglePause()
    game:update(5)
    assert(game.snake[1] == before)
    game:togglePause()
    game:update(0.125)
    assert(game.snake[1] == before + Vector2:new(1, 0))
end)

check("Movement stops after game over", function()
    local game = newGame()
    game.gameOver = true
    local before = game.snake[1]
    game:update(4)
    assert(game.snake[1] == before)
end)

check("Filling the board wins without a food-generation loop", function()
    local events = Events:new()
    local won = false
    events:subscribe("game_won", function() won = true end)
    local game = newGame({columns = 2, rows = 2, events = events})
    position(game, {{0, 0}, {0, 1}, {1, 1}}, 1, 0)
    game.food = Vector2:new(1, 0)
    game:update(0.125)
    assert(game.won and game.gameOver and won)
    assert(game.food == nil and #game.snake == 4 and game.score == 1)
end)

check("Storage errors do not crash a round", function()
    local store = memoryScore()
    store.save = function() return nil, "read-only storage" end
    local game = newGame({highScore = store})
    game.food = game.snake[1] + Vector2:new(1, 0)
    game:update(0.125)
    assert(game.score == 1 and game.saveError == "read-only storage")
end)

check("A missing high-score file loads as zero", function()
    local path = os.tmpname()
    os.remove(path)
    assert(HighScore:new(path):load() == 0)
end)

check("A high score survives saving and a new store instance", function()
    local path = os.tmpname()
    assert(HighScore:new(path):save(17))
    assert(HighScore:new(path):load() == 17)
    os.remove(path)
end)

check("Malformed and negative score files are ignored", function()
    local path = os.tmpname()
    local values = {"not a score", "-4", "inf", "nan", ""}
    for i = 1, #values do
        local file = assert(io.open(path, "w"))
        file:write(values[i])
        file:close()
        assert(HighScore:new(path):load() == 0)
    end
    os.remove(path)
end)

check("An unwritable path reports a save failure", function()
    local path = os.tmpname()
    os.remove(path)
    local saved, message = HighScore:new(path .. "/missing/score.txt"):save(10)
    assert(not saved and message)
end)

if HighScore:new():usesNativeClose() then
    check("Lua 5.4 <close> closes the file even when writing throws", function()
        local backend = require("highscore54")
        local originalOpen = io.open
        local closed = false
        io.open = function()
            return setmetatable({
                write = function() error("forced write error") end
            }, {__close = function() closed = true end})
        end
        local ok = pcall(backend.save, "unused", 12)
        io.open = originalOpen
        assert(not ok and closed)
    end)
end

if not HighScore:new():usesNativeClose() then
    check("A fresh browser save is checked before it is read", function()
        local originalLove = love
        local exists, reads = false, 0
        love = {filesystem = {
            getSaveDirectory = function() return "/browser" end,
            getInfo = function() return exists and {type = "file"} or nil end,
            read = function()
                assert(exists, "Missing browser files must not be read")
                reads = reads + 1
                return "19\n"
            end
        }}
        local ok, message = pcall(function()
            assert(HighScore:new():load() == 0 and reads == 0)
            exists = true
            assert(HighScore:new():load() == 19 and reads == 1)
        end)
        love = originalLove
        assert(ok, message)
    end)
end

check("Menu, playing, commands, restart and observer UI work together", function()
    local originalLove = love
    local drawCalls = 0
    local function draw() drawCalls = drawCalls + 1 end
    love = {
        graphics = {
            setColor = draw, setFont = draw, print = draw, printf = draw,
            rectangle = draw, circle = draw, line = draw, setLineWidth = draw,
            clear = draw, push = draw, pop = draw, translate = draw
        },
        event = {quit = function() end}
    }
    local manager = require("gamestate"):new({
        highScore = memoryScore(),
        fonts = {title = {}, heading = {}, body = {}, small = {}, number = {}}
    })
    assert(manager.current == "menu")
    manager:draw()
    manager:keypressed("return")
    assert(manager.current == "playing")
    local state = manager.states.playing
    state.game.food = state.game.snake[1] + Vector2:new(1, 0)
    manager:update(0.16)
    assert(state.game.score == 1 and state.noticeTime > 0)
    manager:draw()
    manager:keypressed("p")
    assert(state.game.paused)
    manager:draw()
    manager:keypressed("r")
    assert(state.game.score == 0 and state.game.best == 1 and not state.game.paused)
    manager:keypressed("up")
    assert(state.game.entity:getComponent("movement").nextDy == -1)
    manager:keypressed("escape")
    assert(manager.current == "menu" and manager.states.menu.best == 1)
    manager:mousepressed(400, 435, 1)
    assert(manager.current == "playing")
    assert(drawCalls > 0)
    love = originalLove
end)

print(string.format("RESULT: %d passed, %d failed (%s)", passed, failed, _VERSION))
local results = {passed = passed, failed = failed, version = _VERSION}
assert(failed == 0, "Some checks failed")
return results
