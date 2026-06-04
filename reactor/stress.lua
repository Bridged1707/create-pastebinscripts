local cfg = require("peripheral_config")
local monitorConfig = require("monitor_config")
local control = require("control_common")

local refreshRate = monitorConfig.refreshRate or 1
local warningPercent = monitorConfig.warningPercent or 85
local criticalPercent = monitorConfig.criticalPercent or 95

local THEME = {
    bg = colors.black, text = colors.white, headerBg = colors.blue,
    sectionBg = colors.gray, ok = colors.lime, warn = colors.yellow,
    crit = colors.orange, over = colors.red, standby = colors.lightGray,
    unknown = colors.orange, empty = colors.gray
}

local function isColor(t) return t and t.isColor and t.isColor() end
local function setColors(t, fg, bg)
    if isColor(t) then t.setTextColor(fg or THEME.text); t.setBackgroundColor(bg or THEME.bg) end
end
local function clear(t) setColors(t, THEME.text, THEME.bg); t.clear(); t.setCursorPos(1, 1) end
local function line(t, y, text, fg, bg)
    local w, h = t.getSize(); if y < 1 or y > h then return end
    setColors(t, fg, bg); t.setCursorPos(1, y); t.clearLine(); t.write(tostring(text or ""):sub(1, w)); setColors(t, THEME.text, THEME.bg)
end
local function at(t, x, y, text, fg, bg)
    local w, h = t.getSize(); if y < 1 or y > h or x > w then return end
    setColors(t, fg, bg); t.setCursorPos(x, y); t.write(tostring(text or ""):sub(1, w - x + 1)); setColors(t, THEME.text, THEME.bg)
end
local function percent(used, cap) if not cap or cap <= 0 then return 0 end return used / cap * 100 end
local function statusColor(s)
    if s == "OK" or s == "ON" then return THEME.ok end
    if s == "WARN" then return THEME.warn end
    if s == "CRIT" then return THEME.crit end
    if s == "OVER" then return THEME.over end
    if s == "OFF" or s == "STANDBY" then return THEME.standby end
    return THEME.unknown
end
local function bar(t, x, y, width, pct, status)
    if width < 4 then return end
    pct = math.max(0, math.min(100, pct or 0)); local fill = math.floor(width * pct / 100 + 0.5)
    if isColor(t) then
        at(t, x, y, string.rep(" ", width), THEME.text, THEME.empty)
        if fill > 0 then at(t, x, y, string.rep(" ", fill), THEME.text, statusColor(status)) end
    else
        at(t, x, y, "[" .. string.rep("#", math.max(0, fill - 2)) .. string.rep("-", math.max(0, width - fill - 2)) .. "]")
    end
end

local function readMeter(name)
    local meter = peripheral.wrap(name)
    if not meter then return { online = false, used = 0, capacity = 0, percent = 0, status = "MISSING" } end
    if type(meter.getStress) ~= "function" or type(meter.getStressCapacity) ~= "function" then
        return { online = false, used = 0, capacity = 0, percent = 0, status = "BAD TYPE" }
    end
    local okU, used = pcall(meter.getStress); local okC, cap = pcall(meter.getStressCapacity)
    if not okU or not okC then return { online = false, used = 0, capacity = 0, percent = 0, status = "READ ERR" } end
    local pct = percent(used, cap); local s = "OK"
    if used > cap then s = "OVER" elseif pct >= criticalPercent then s = "CRIT" elseif pct >= warningPercent then s = "WARN" end
    return { online = true, used = tonumber(used) or 0, capacity = tonumber(cap) or 0, percent = pct, status = s }
end

local function renderNetwork(t, y, label, clutchState, meter, speed)
    local active = clutchState == "ON"
    local meterStatus = active and meter.status or "STANDBY"
    local rpmStatus = active and speed.status or "STANDBY"
    local rpm = speed.rpm or 0
    local w = t.getSize()

    if w >= 64 then
        line(t, y, string.format(" %-8s Clutch:%-10s %7d/%-7d SU  %7.1f RPM", label, clutchState, math.floor(meter.used), math.floor(meter.capacity), rpm), statusColor(clutchState));
        bar(t, 42, y, math.min(12, w - 58), meter.percent, meterStatus)
        at(t, math.max(1, w - 7), y, string.format("%5.1f%%", meter.percent), statusColor(meterStatus))
    else
        line(t, y, string.format(" %s %s | %.1f%% SU | %.1f RPM", label, clutchState, meter.percent, rpm), statusColor(clutchState))
    end

    return active
end

local function render(t)
    clear(t)
    local y = 1
    line(t, y, " CREATE / NEW AGE ROTATION DASHBOARD ", THEME.text, THEME.headerBg); y = y + 2

    local totalUsed, totalCap, activeNetworks = 0, 0, 0
    for _, reactor in ipairs(cfg.reactors or {}) do
        local primaryOn, primaryState = control.getClutchState(reactor, "primary")
        local backupOn, backupState = control.getClutchState(reactor, "backup")
        local primaryMeter = readMeter(reactor.primaryStressometer)
        local backupMeter = readMeter(reactor.backupStressometer)
        local primarySpeed = control.readSpeedometer(reactor.primarySpeedometer)
        local backupSpeed = control.readSpeedometer(reactor.backupSpeedometer)

        line(t, y, " " .. reactor.label, THEME.text, THEME.sectionBg); y = y + 1
        if renderNetwork(t, y, "Primary", primaryState, primaryMeter, primarySpeed) then
            activeNetworks = activeNetworks + 1; totalUsed = totalUsed + primaryMeter.used; totalCap = totalCap + primaryMeter.capacity
        end
        y = y + 1
        if renderNetwork(t, y, "Backup", backupState, backupMeter, backupSpeed) then
            activeNetworks = activeNetworks + 1; totalUsed = totalUsed + backupMeter.used; totalCap = totalCap + backupMeter.capacity
        end
        y = y + 2
    end

    local totalPct = percent(totalUsed, totalCap)
    local totalStatus = totalPct >= criticalPercent and "CRIT" or totalPct >= warningPercent and "WARN" or "OK"
    line(t, y, " ACTIVE NETWORK TOTALS ", THEME.text, THEME.sectionBg); y = y + 1
    line(t, y, " Active Networks: " .. activeNetworks .. "   Used: " .. math.floor(totalUsed) .. "/" .. math.floor(totalCap) .. " SU"); y = y + 1
    line(t, y, string.format(" Load: %.1f%%  %s", totalPct, totalStatus), statusColor(totalStatus))
end

local function getMonitor()
    local out = monitorConfig.outputs and monitorConfig.outputs.stress_full
    if not out or out.enabled == false then return nil end
    local m = peripheral.wrap(out.monitor); if m and m.setTextScale then m.setTextScale(out.textScale or 0.5) end
    return m
end

while true do
    local ok, err = pcall(function() render(term); local m = getMonitor(); if m then render(m) end end)
    if not ok then clear(term); print("stress.lua error:"); print(err) end
    sleep(refreshRate)
end
