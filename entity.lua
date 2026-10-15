local Entity = {}
Entity.__index = Entity

function Entity:new()
    return setmetatable({components = {}}, Entity)
end

function Entity:addComponent(name, component)
    assert(type(name) == "string", "Component names must be strings")
    assert(component ~= nil, "A component cannot be nil")
    self.components[name] = component
    return self
end

function Entity:getComponent(name)
    return self.components[name]
end

function Entity:hasComponent(name)
    return self.components[name] ~= nil
end

return Entity
