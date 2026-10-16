-- Procedural audio synthesizer for Neon Runner.
-- Synthesizes retro-cyber sound effects in memory using mathematical waveforms.
-- Requires zero audio asset files and degrades gracefully when audio is unavailable.

local Audio = {}
Audio.__index = Audio

function Audio:new()
    local instance = setmetatable({
        muted = false,
        volume = 0.85,
        sources = {},
        available = false
    }, Audio)

    -- Check if Love audio subsystems are available
    if love and love.audio and love.sound and love.sound.newSoundData then
        instance.available = true
        instance:_initSounds()
    end

    return instance
end

function Audio:_createTone(duration, sampleRate, freqFunc, volumeFunc, waveFunc)
    sampleRate = sampleRate or 22050
    local totalSamples = math.floor(duration * sampleRate)
    local ok, soundData = pcall(love.sound.newSoundData, totalSamples, sampleRate, 16, 1)
    if not ok or not soundData then return nil end

    local phase = 0
    for i = 0, totalSamples - 1 do
        local t = i / totalSamples
        local timeSec = i / sampleRate
        local freq = freqFunc(t, timeSec)
        local vol = volumeFunc(t, timeSec)
        phase = phase + (freq * 2 * math.pi) / sampleRate

        local sample = waveFunc(phase, t, timeSec) * vol
        sample = math.max(-1, math.min(1, sample))
        soundData:setSample(i, sample)
    end

    local sourceOk, source = pcall(love.audio.newSource, soundData, "static")
    if sourceOk and source then
        return source
    end
    return nil
end

function Audio:_initSounds()
    if not self.available then return end

    -- Turn click: brief, gentle tactile blip
    self.sources.turn = self:_createTone(0.022, 22050,
        function() return 1250 end,
        function(t) return (1 - t) * (1 - t) * 0.18 end,
        function(phase) return math.sin(phase) end
    )

    -- Game start: uplifting dual-tone arcade chime
    self.sources.start = self:_createTone(0.24, 22050,
        function(t) return t < 0.45 and 440 or 880 end,
        function(t) return math.sin(t * math.pi) * 0.38 end,
        function(phase) return math.sin(phase) + 0.25 * math.sin(phase * 2) end
    )

    -- Crash / Game Over: dramatic downward sweep and sub-bass impact
    self.sources.die = self:_createTone(0.48, 22050,
        function(t) return math.max(38, 180 * (1 - t * 0.85)) end,
        function(t) return (1 - t * 0.95) * 0.55 end,
        function(phase, t)
            local sine = math.sin(phase)
            local noise = (math.random() * 2 - 1) * math.max(0, 0.4 - t)
            return sine * 0.8 + noise * 0.35
        end
    )

    -- Pre-synthesize food chimes for combos 1 to 5
    local notes = {523.25, 659.25, 783.99, 1046.50, 1318.51, 1567.98} -- C5, E5, G5, C6, E6, G6
    self.sources.eatCombos = {}
    for combo = 1, #notes do
        local baseFreq = notes[combo]
        self.sources.eatCombos[combo] = self:_createTone(0.18, 22050,
            function(t) return baseFreq * (1 + 0.12 * (1 - t)) end,
            function(t) return (1 - t) * (1 - t) * 0.42 end,
            function(phase)
                return math.sin(phase) * 0.75 + math.sin(phase * 2) * 0.25
            end
        )
    end
end

function Audio:play(name)
    if self.muted or not self.available then return end
    local source = self.sources[name]
    if source then
        pcall(function()
            local clone = source:clone()
            clone:setVolume(self.volume)
            clone:play()
        end)
    end
end

function Audio:playTurn()
    self:play("turn")
end

function Audio:playStart()
    self:play("start")
end

function Audio:playDie()
    self:play("die")
end

function Audio:playEat(combo)
    if self.muted or not self.available then return end
    combo = math.max(1, math.min(combo or 1, #(self.sources.eatCombos or {})))
    local source = self.sources.eatCombos and self.sources.eatCombos[combo]
    if source then
        pcall(function()
            local clone = source:clone()
            clone:setVolume(self.volume)
            clone:play()
        end)
    end
end

function Audio:toggleMute()
    self.muted = not self.muted
    return self.muted
end

return Audio
