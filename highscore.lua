local HighScore = {}
HighScore.__index = HighScore

-- Parse a small string rather than putting Lua 5.4 syntax in a LuaJIT module.
-- Standard LOVE uses LuaJIT, so it cannot parse highscore54.lua directly.
local compile = loadstring or load
local supportsClose = compile("local file <close> = nil") ~= nil
local native54 = supportsClose and require("highscore54") or nil

local function hasLoveFilesystem()
    return love and love.filesystem and love.filesystem.getSaveDirectory
end

local function validScore(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge
        or number == -math.huge or number < 0 then
        return 0
    end
    return math.floor(number)
end

function HighScore:new(filename)
    return setmetatable({filename = filename or "scores/highscore.txt"}, HighScore)
end

function HighScore:_path()
    if hasLoveFilesystem() then
        return love.filesystem.getSaveDirectory() .. "/" .. self.filename
    end
    return self.filename
end

function HighScore:load()
    local content
    if native54 then
        local ok, result = pcall(native54.load, self:_path())
        if ok then
            content = result
        end
    elseif hasLoveFilesystem() then
        -- The web runtime needs an existence check before reading a new save.
        if love.filesystem.getInfo(self.filename) then
            content = love.filesystem.read(self.filename)
        end
    else
        local file = io.open(self.filename, "r")
        if file then
            content = file:read("*a")
            file:close()
        end
    end
    return validScore(content)
end

function HighScore:save(score)
    score = validScore(score)

    if hasLoveFilesystem() then
        local directory = self.filename:match("^(.*)/[^/]+$")
        if directory and not love.filesystem.createDirectory(directory) then
            return nil, "Could not create the score directory"
        end
    end

    if native54 then
        local ok, result, message = pcall(native54.save, self:_path(), score)
        if not ok then
            return nil, result
        end
        return result, message
    end

    if hasLoveFilesystem() then
        -- Compatibility backend: LOVE handles opening and closing the file.
        return love.filesystem.write(self.filename, tostring(score) .. "\n")
    end

    local file, openError = io.open(self:_path(), "w")
    if not file then
        return nil, openError
    end
    local written, writeError = file:write(tostring(score), "\n")
    local closed, closeError = file:close()
    if not written then
        return nil, writeError
    end
    if not closed then
        return nil, closeError
    end
    return true
end

function HighScore:usesNativeClose()
    return supportsClose
end

return HighScore
