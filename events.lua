local Events = {}
Events.__index = Events

function Events:new()
    return setmetatable({listeners = {}}, Events)
end

-- Observer pattern: subscribers react without being coupled to SnakeGame.
function Events:subscribe(event, callback)
    assert(type(callback) == "function", "An event listener must be a function")
    local listeners = self.listeners[event]
    if not listeners then
        listeners = {}
        self.listeners[event] = listeners
    end
    table.insert(listeners, callback)
end

function Events:emit(event, data)
    local listeners = self.listeners[event] or {}
    for i = 1, #listeners do
        listeners[i](data)
    end
end

return Events
