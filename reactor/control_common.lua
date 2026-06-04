local M = {}
local resolver = require("peripheral_resolver")

local function isPlaceholder(value)
    return type(value) ~= "string" or value == "" or value:find("CHANGE_ME", 1, true) ~= nil
end

function M.findReactor(cfg, selector)
    selector = tostring(selector or ""):lower()
    local number = tonumber(selector)

    for index, reactor in ipairs(cfg.reactors or {}) do
        if number == index or selector == tostring(reactor.id or ""):lower() or selector == tostring(reactor.label or ""):lower() then
            return reactor, index
        end
    end

    return nil, nil
end

function M.selectedReactors(cfg, selector)
    if tostring(selector or ""):lower() == "all" then
        return cfg.reactors or {}
    end

    local reactor = M.findReactor(cfg, selector)
    if reactor then return { reactor } end
    return {}
end

function M.getRelayState(relayConfig)
    if not relayConfig or isPlaceholder(relayConfig.peripheral) then
        return nil, "UNCONFIGURED"
    end

    local relay, _, resolveStatus = resolver.wrap(relayConfig.peripheral, {})
    if not relay then return nil, resolveStatus or "MISSING" end

    local side = relayConfig.outputSide or "back"
    local ok, powered

    if type(relay.getOutput) == "function" then
        ok, powered = pcall(relay.getOutput, side)
    elseif type(relay.getAnalogOutput) == "function" then
        local value
        ok, value = pcall(relay.getAnalogOutput, side)
        powered = ok and value > 0 or false
    else
        return nil, "BAD TYPE"
    end

    if not ok then return nil, "READ ERR" end

    local enabled
    if relayConfig.poweredMeansEnabled == true then
        enabled = powered == true
    else
        enabled = powered ~= true
    end

    return enabled, enabled and "ON" or "OFF"
end

function M.setRelayState(relayConfig, enabled)
    if not relayConfig or isPlaceholder(relayConfig.peripheral) then
        return false, "UNCONFIGURED"
    end

    local relay, _, resolveStatus = resolver.wrap(relayConfig.peripheral, {})
    if not relay then return false, resolveStatus or "MISSING" end

    local powered
    if relayConfig.poweredMeansEnabled == true then
        powered = enabled == true
    else
        powered = enabled ~= true
    end

    local side = relayConfig.outputSide or "back"
    local ok, err

    if type(relay.setOutput) == "function" then
        ok, err = pcall(relay.setOutput, side, powered)
    elseif type(relay.setAnalogOutput) == "function" then
        ok, err = pcall(relay.setAnalogOutput, side, powered and 15 or 0)
    else
        return false, "BAD TYPE"
    end

    if not ok then return false, tostring(err or "WRITE ERR") end
    return true, enabled and "ON" or "OFF"
end

function M.getFuelFeedState(reactor)
    local total, enabledCount, unknownCount = 0, 0, 0
    local details = {}

    for index, chute in ipairs(reactor.fuelChutes or {}) do
        total = total + 1
        local enabled, state = M.getRelayState(chute.relay)
        if enabled == true then enabledCount = enabledCount + 1 end
        if enabled == nil then unknownCount = unknownCount + 1 end
        table.insert(details, {
            index = index,
            label = chute.label or ("Rod " .. index),
            enabled = enabled,
            state = state
        })
    end

    local state
    if total == 0 then state = "NO CHUTES"
    elseif unknownCount > 0 then state = "UNKNOWN"
    elseif enabledCount == 0 then state = "OFF"
    elseif enabledCount == total then state = "ON"
    else state = "PARTIAL" end

    return {
        total = total,
        enabledCount = enabledCount,
        unknownCount = unknownCount,
        state = state,
        active = enabledCount > 0,
        details = details
    }
end

function M.getClutchState(reactor, network)
    local clutch = reactor.clutches and reactor.clutches[network]
    if not clutch then return nil, "NO CLUTCH" end
    return M.getRelayState(clutch.relay)
end

function M.readSpeedometer(name)
    if isPlaceholder(name) then return { online = false, rpm = 0, status = "UNCONFIGURED", configuredName = name } end
    local meter, actualName, resolveStatus = resolver.wrap(name, { "getSpeed" })
    if not meter then return { online = false, rpm = 0, status = resolveStatus or "MISSING", configuredName = name, actualName = actualName } end
    local ok, speed = pcall(meter.getSpeed)
    if not ok then return { online = false, rpm = 0, status = "READ ERR", configuredName = name, actualName = actualName } end
    return { online = true, rpm = tonumber(speed) or 0, status = "OK", configuredName = name, actualName = actualName }
end

return M
