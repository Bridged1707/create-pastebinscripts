local cfg = require("peripheral_config")
local monitorConfig = require("monitor_config")

local refreshRate = monitorConfig.refreshRate or 1
local warningPercent = monitorConfig.warningPercent or 85
local criticalPercent = monitorConfig.criticalPercent or 95

local THEME = {
    bg = colors.black, text = colors.white, muted = colors.lightGray,
    headerBg = colors.blue, sectionBg = colors.gray,
    ok = colors.lime, warn = colors.yellow, crit = colors.orange,
    over = colors.red, standby = colors.lightGray, unknown = colors.orange,
    empty = colors.gray
}

local function isColor(t) return t and t.isColor and t.isColor() end
local function setColors(t, fg, bg)
    if isColor(t) then
        t.setTextColor(fg or THEME.text)
        t.setBackgroundColor(bg or THEME.bg)
    end
end
local function clear(t)
    setColors(t, THEME.text, THEME.bg)
    t.clear(); t.setCursorPos(1, 1)
end
local function line(t, y, text, fg, bg)
    local w, h = t.getSize()
    if y < 1 or y > h then return end
    setColors(t, fg, bg)
    t.setCursorPos(1, y); t.clearLine(); t.write(tostring(text or ""):sub(1, w))
    setColors(t, THEME.text, THEME.bg)
end
local function at(t, x, y, text, fg, bg)
    local w, h = t.getSize()
    if y < 1 or y > h or x > w then return end
    setColors(t, fg, bg)
    t.setCursorPos(x, y); t.write(tostring(text or ""):sub(1, w - x + 1))
    setColors(t, THEME.text, THEME.bg)
end
local function round(n, p)
    local m = 10 ^ (p or 0); return math.floor(n * m + 0.5) / m
end
local function percent(used, cap)
    if not cap or cap <= 0 then return 0 end
    return used / cap * 100
end
local function statusColor(s)
    if s == "OK" or s == "ON" then return THEME.ok end
    if s == "WARN" then return THEME.warn end
    if s == "CRIT" then return THEME.crit end
    if s == "OVER" then return THEME.over end
    if s == "OFF" or s == "STANDBY" or s == "DISABLED" then return THEME.standby end
    return THEME.unknown
end
local function bar(t, x, y, width, pct, status)
    if width < 4 then return end
    pct = math.max(0, math.min(100, pct or 0))
    local fill = math.floor(width * pct / 100 + 0.5)
    if isColor(t) then
        at(t, x, y, string.rep(" ", width), THEME.text, THEME.empty)
        if fill > 0 then at(t, x, y, string.rep(" ", fill), THEME.text, statusColor(status)) end
    else
        at(t, x, y, "[" .. string.rep("#", math.max(0, fill - 2)) .. string.rep("-", math.max(0, width - fill - 2)) .. "]")
    end
end

local function reactorState(reactor)
    if reactor.enabled == false then return false, "DISABLED" end
    local r = reactor.relay
    if not r or not r.peripheral or r.peripheral:find("CHANGE_ME", 1, true) then
        return cfg.missingRelayMeansOn == true, "NO RELAY"
    end
    local relay = peripheral.wrap(r.peripheral)
    if not relay or type(relay.getAnalogInput) ~= "function" then
        return cfg.missingRelayMeansOn == true, "MISSING"
    end
    local ok, signal = pcall(relay.getAnalogInput, r.side or "back")
    if not ok then return cfg.missingRelayMeansOn == true, "ERROR" end
    local on = signal >= (r.threshold or 1)
    if r.inverted then on = not on end
    return on, on and "ON" or "OFF"
end

local function readMeter(name)
    local meter = peripheral.wrap(name)
    if not meter then return { online = false, used = 0, capacity = 0, percent = 0, status = "MISSING" } end
    if type(meter.getStress) ~= "function" or type(meter.getStressCapacity) ~= "function" then
        return { online = false, used = 0, capacity = 0, percent = 0, status = "BAD TYPE" }
    end
    local okU, used = pcall(meter.getStress)
    local okC, cap = pcall(meter.getStressCapacity)
    if not okU or not okC then return { online = false, used = 0, capacity = 0, percent = 0, status = "READ ERR" } end
    local pct = percent(used, cap)
    local s = "OK"
    if used > cap then s = "OVER" elseif pct >= criticalPercent then s = "CRIT" elseif pct >= warningPercent then s = "WARN" end
    return { online = true, used = used, capacity = cap, percent = pct, status = s }
end

local function render(t)
    clear(t)
    local w = t.getSize()
    local y = 1
    line(t, y, " CREATE / NEW AGE STRESS DASHBOARD ", THEME.text, THEME.headerBg); y = y + 2

    local totalUsed, totalCap, active = 0, 0, 0
    for _, reactor in ipairs(cfg.reactors or {}) do
        local isOn, state = reactorState(reactor)
        local steam = readMeter(reactor.steamStressometer)
        local backup = readMeter(reactor.backupStressometer)
        local steamStatus = isOn and steam.status or "STANDBY"
        local backupStatus = isOn and backup.status or "STANDBY"

        line(t, y, " " .. reactor.label .. "  " .. state, statusColor(state), THEME.sectionBg); y = y + 1
        if w >= 52 then
            line(t, y, " Steam   " .. math.floor(steam.used) .. "/" .. math.floor(steam.capacity) .. " SU");
            bar(t, 28, y, math.min(18, w - 38), steam.percent, steamStatus)
            at(t, math.max(1, w - 8), y, string.format("%5.1f%%", steam.percent), statusColor(steamStatus)); y = y + 1
            line(t, y, " Backup  " .. math.floor(backup.used) .. "/" .. math.floor(backup.capacity) .. " SU");
            bar(t, 28, y, math.min(18, w - 38), backup.percent, backupStatus)
            at(t, math.max(1, w - 8), y, string.format("%5.1f%%", backup.percent), statusColor(backupStatus)); y = y + 2
        else
            line(t, y, string.format(" Steam  %5.1f%%  %s", steam.percent, steamStatus), statusColor(steamStatus)); y = y + 1
            line(t, y, string.format(" Backup %5.1f%%  %s", backup.percent, backupStatus), statusColor(backupStatus)); y = y + 2
        end

        if isOn then
            active = active + 1
            totalUsed = totalUsed + steam.used + backup.used
            totalCap = totalCap + steam.capacity + backup.capacity
        end
    end

    local totalPct = percent(totalUsed, totalCap)
    local totalStatus = totalPct >= criticalPercent and "CRIT" or totalPct >= warningPercent and "WARN" or "OK"
    line(t, y, " ACTIVE TOTALS ", THEME.text, THEME.sectionBg); y = y + 1
    line(t, y, " Active Reactors: " .. active .. "   Used: " .. math.floor(totalUsed) .. "/" .. math.floor(totalCap) .. " SU"); y = y + 1
    line(t, y, string.format(" Load: %.1f%%  %s", round(totalPct, 1), totalStatus), statusColor(totalStatus))
end

local function getMonitor()
    local out = monitorConfig.outputs and monitorConfig.outputs.stress_full
    if not out or out.enabled == false then return nil end
    local m = peripheral.wrap(out.monitor)
    if m and m.setTextScale then m.setTextScale(out.textScale or 0.5) end
    return m
end

while true do
    local ok, err = pcall(function()
        render(term)
        local m = getMonitor(); if m then render(m) end
    end)
    if not ok then clear(term); print("stress.lua error:"); print(err) end
    sleep(refreshRate)
end
