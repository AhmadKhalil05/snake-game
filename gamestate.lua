local GameState = {}
GameState.__index = GameState

function GameState:new(context)
    local manager = setmetatable({states = {}, current = nil, context = context}, GameState)
    manager.states.menu = require("states.menu_state"):new(manager, context)
    manager.states.playing = require("states.game_state"):new(manager, context)
    manager:switch("menu")
    return manager
end

function GameState:switch(newState)
    assert(self.states[newState], "Unknown game state: " .. tostring(newState))

    local previous = self.states[self.current]
    if previous and previous.exit then
        previous:exit()
    end

    self.current = newState
    local current = self.states[newState]
    if current.enter then
        current:enter()
    end
end

function GameState:update(dt)
    self.states[self.current]:update(dt)
end

function GameState:draw()
    self.states[self.current]:draw()
end

function GameState:keypressed(key)
    local current = self.states[self.current]
    if current.keypressed then
        current:keypressed(key)
    end
end

function GameState:mousepressed(x, y, button)
    local current = self.states[self.current]
    if current.mousepressed then
        current:mousepressed(x, y, button)
    end
end

return GameState
