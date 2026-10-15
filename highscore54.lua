-- Native Lua 5.4 implementation of the assignment's modern Lua feature.
-- <close> closes a file when its scope ends, including when an error occurs.
-- This module is only required by interpreters that support that syntax.
local HighScore54 = {}

function HighScore54.save(path, score)
    local file <close>, openError = io.open(path, "w")
    if not file then
        return nil, openError
    end

    local written, writeError = file:write(tostring(score), "\n")
    if not written then
        return nil, writeError
    end

    local flushed, flushError = file:flush()
    if not flushed then
        return nil, flushError
    end
    return true
end

function HighScore54.load(path)
    local file <close>, openError = io.open(path, "r")
    if not file then
        return nil, openError
    end
    return file:read("*a")
end

return HighScore54
