-- Entry point: LOVE owns the main loop; callbacks delegate to the state manager.
local GameState = require("gamestate")
local HighScore = require("highscore")
local Theme = require("theme")
local gameState

if not love then
    print("Run the graphical game with LOVE: love .")
    print("Run the Lua-only checks with: lua tests/run.lua")
    return
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setBackgroundColor(Theme.colors.background[1], Theme.colors.background[2],
        Theme.colors.background[3])

    local context = {
        highScore = HighScore:new(),
        stars = Theme.createStars(88, 800, 640),
        fonts = {
            title = love.graphics.newFont(58),
            display = love.graphics.newFont(36),
            heading = love.graphics.newFont(26),
            body = love.graphics.newFont(18),
            small = love.graphics.newFont(13),
            tiny = love.graphics.newFont(11),
            number = love.graphics.newFont(28)
        }
    }
    gameState = GameState:new(context)
end

function love.update(dt)
    gameState:update(dt)
end

function love.draw()
    gameState:draw()
end

function love.keypressed(key)
    if key == "f5" then
        love.event.quit("restart")
        return
    end
    gameState:keypressed(key)
end

function love.mousepressed(x, y, button)
    gameState:mousepressed(x, y, button)
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    gameState:mousepressed(x * w, y * h, 1)
end

function love.focus(focused)
    -- Pause when switching apps so the snake does not hit a wall unattended.
    if not focused and gameState and gameState.current == "playing" then
        local game = gameState.states.playing.game
        if game and not game.gameOver then
            game.paused = true
        end
    end
end
