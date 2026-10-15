local Input = {}
Input.__index = Input

function Input:new()
    return setmetatable({commands = {}}, Input)
end

-- Command pattern: a key selects a callable command.
function Input:bind(key, command)
    assert(type(command) == "function", "An input command must be a function")
    self.commands[key] = command
end

function Input:handleKey(key)
    local command = self.commands[key]
    if command then
        command()
        return true
    end
    return false
end

return Input
