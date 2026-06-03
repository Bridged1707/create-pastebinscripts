local stressConfig = require("stress_config")
local monitorConfig = require("monitor_config")

local refreshRate = monitorConfig.refreshRate or 1
local warningPercent = monitorConfig.warningPercent or 85
local criticalPercent = monitorConfig.criticalPercent or 95

local outputs = {}

local function round(num, places)
    local mult = 10 ^ (places or 0)
    return math.floor(num * mult + 0.5) / mult
end

local function padRight(text, length)
    text = tostring(text)
    if #text >= length then return text:sub(1, length) end
    return text .. string.rep(" ", length - #text)
end

local function contains(text, value)
    return string.find(string.lower(text), string.lower(value), 1, true) ~= nil
end

local function percentOf(used, capacity)
    if capacity <= 0 then return 0 end
    return used / capacity * 100
end

local function getStatus(used, capacity)
    if capacity <= 0 then return "NO CAP" end
    local percent = percentOf(used, capacity)
    if used > capacity then
        return "OVER"
    elseif percent >= criticalPercent then
        return "CRIT"
    elseif percent >= warningPercent then
        return "WARN"
    else
        return "OK"
    end
end

local function makeTotals()
    return { used = 0, capacity = 0, online = 0, missing = 0, overstressed = 0 }
end

local function addToTotals(totals, data)
    if data.online then
        totals.online = totals.online + 1
        totals.used = totals.used + data.used
        totals.capacity = totals.capacity + data.capacity
        if data.used > data.capacity then totals.overstressed = totals.overstressed + 1 end
    else
        totals.missing = totals.missing + 1
    end
end

local function readStressometer(entry)
    local p = peripheral.wrap(entry.peripheral)

    if not p then
        return { label = entry.label, group = entry.group, peripheral = entry.peripheral, online = false, error = "Missing" }
    end

    if type(p.getStress) ~= "function" or type(p.getStressCapacity) ~= "function" then
        return { label = entry.label, group = entry.group, peripheral = entry.peripheral, online = false, error = "Not Stress" }
    end

    local okUsed, used = pcall(p.getStress)
    local okCap, capacity = pcall(p.getStressCapacity)

    if not okUsed or not okCap then
        return { label = entry.label, group = entry.group, peripheral = entry.peripheral, online = false, error = "Read Error" }
    end

    local percent = percentOf(used, capacity)

    return {
        label = entry.label,
        group = entry.group,
        peripheral = entry.peripheral,
        online = true,
        used = used,
        capacity = capacity,
        percent = percent,
        status = getStatus(used, capacity)
    }
end

local function buildData()
    local results = {}
    local steamTotals = makeTotals()
    local backupTotals = makeTotals()
    local overallTotals = makeTotals()

    for _, entry in ipairs(stressConfig) do
        local data = readStressometer(entry)
        table.insert(results, data)
        addToTotals(overallTotals, data)

        if contains(entry.group, "Steam") then
            addToTotals(steamTotals, data)
        elseif contains(entry.group, "Backup") then
            addToTotals(backupTotals, data)
        end
    end

    return { results = results, steamTotals = steamTotals, backupTotals = backupTotals, overallTotals = overallTotals }
end

local function writeLine(target, y, text)
    local w, h = target.getSize()
    if y < 1 or y > h then return end
    target.setCursorPos(1, y)
    target.clearLine()
    target.write(tostring(text):sub(1, w))
end

local function clearTarget(target)
    target.clear()
    target.setCursorPos(1, 1)
end

local function renderFull(target, data)
    local y = 1
    clearTarget(target)

    writeLine(target, y, "CREATE / NEW AGE STRESS DASHBOARD") y = y + 1
    writeLine(target, y, "---------------------------------") y = y + 1
    writeLine(target, y, padRight("Name", 15) .. padRight("Group", 17) .. padRight("Used", 10) .. padRight("Cap", 10) .. padRight("Load", 8) .. "Status") y = y + 1
    writeLine(target, y, string.rep("-", 67)) y = y + 1

    for _, row in ipairs(data.results) do
        if row.online then
            writeLine(target, y,
                padRight(row.label, 15) ..
                padRight(row.group, 17) ..
                padRight(tostring(math.floor(row.used)) .. " SU", 10) ..
                padRight(tostring(math.floor(row.capacity)) .. " SU", 10) ..
                padRight(round(row.percent, 1) .. "%", 8) ..
                row.status
            )
        else
            writeLine(target, y,
                padRight(row.label, 15) ..
                padRight(row.group, 17) ..
                padRight("--", 10) ..
                padRight("--", 10) ..
                padRight("--", 8) ..
                row.error
            )
        end
        y = y + 1
    end

    y = y + 1

    local function totalsLine(title, totals)
        local percent = percentOf(totals.used, totals.capacity)
        local status = "OK"
        if totals.overstressed > 0 then status = "OVERSTRESSED"
        elseif percent >= criticalPercent then status = "CRITICAL"
        elseif percent >= warningPercent then status = "WARNING" end

        writeLine(target, y, title) y = y + 1
        writeLine(target, y,
            "Online " .. totals.online ..
            " | Missing " .. totals.missing ..
            " | Used " .. math.floor(totals.used) .. " SU" ..
            " | Cap " .. math.floor(totals.capacity) .. " SU" ..
            " | Load " .. round(percent, 1) .. "%"
        ) y = y + 1
        writeLine(target, y, "Status: " .. status) y = y + 2
    end

    totalsLine("STEAM ENGINE TOTALS", data.steamTotals)
    totalsLine("BACKUP ENGINE TOTALS", data.backupTotals)
    totalsLine("OVERALL TOTALS", data.overallTotals)
end

local function renderSummary(target, data)
    local y = 1
    clearTarget(target)

    local steamPercent = percentOf(data.steamTotals.used, data.steamTotals.capacity)
    local backupPercent = percentOf(data.backupTotals.used, data.backupTotals.capacity)
    local overallPercent = percentOf(data.overallTotals.used, data.overallTotals.capacity)

    writeLine(target, y, "CREATE STRESS SUMMARY") y = y + 1
    writeLine(target, y, "---------------------") y = y + 2

    writeLine(target, y, "STEAM:  " .. data.steamTotals.online .. "/4 | " .. math.floor(data.steamTotals.used) .. "/" .. math.floor(data.steamTotals.capacity) .. " SU | " .. round(steamPercent, 1) .. "%") y = y + 2
    writeLine(target, y, "BACKUP: " .. data.backupTotals.online .. "/4 | " .. math.floor(data.backupTotals.used) .. "/" .. math.floor(data.backupTotals.capacity) .. " SU | " .. round(backupPercent, 1) .. "%") y = y + 2
    writeLine(target, y, "TOTAL:  " .. data.overallTotals.online .. "/8 | " .. math.floor(data.overallTotals.used) .. "/" .. math.floor(data.overallTotals.capacity) .. " SU | " .. round(overallPercent, 1) .. "%") y = y + 2

    if data.overallTotals.overstressed > 0 then
        writeLine(target, y, "STATUS: OVERSTRESSED")
    elseif overallPercent >= criticalPercent then
        writeLine(target, y, "STATUS: CRITICAL")
    elseif overallPercent >= warningPercent then
        writeLine(target, y, "STATUS: WARNING")
    else
        writeLine(target, y, "STATUS: OK")
    end
end

local function renderAlerts(target, data)
    local y = 1
    local foundAlert = false
    clearTarget(target)

    writeLine(target, y, "CREATE STRESS ALERTS") y = y + 1
    writeLine(target, y, "--------------------") y = y + 2

    for _, row in ipairs(data.results) do
        if not row.online then
            writeLine(target, y, row.label .. ": " .. row.error) y = y + 1
            foundAlert = true
        elseif row.used > row.capacity then
            writeLine(target, y, row.label .. ": OVERSTRESSED") y = y + 1
            foundAlert = true
        elseif row.percent >= criticalPercent then
            writeLine(target, y, row.label .. ": CRITICAL " .. round(row.percent, 1) .. "%") y = y + 1
            foundAlert = true
        elseif row.percent >= warningPercent then
            writeLine(target, y, row.label .. ": WARNING " .. round(row.percent, 1) .. "%") y = y + 1
            foundAlert = true
        end
    end

    if not foundAlert then writeLine(target, y, "No stress alerts.") end
end

local function renderOutput(output, data)
    if output.mode == "full" then
        renderFull(output.target, data)
    elseif output.mode == "summary" then
        renderSummary(output.target, data)
    elseif output.mode == "alerts" then
        renderAlerts(output.target, data)
    end
end

local function loadOutputs()
    outputs = {}

    for name, cfg in pairs(monitorConfig.outputs or {}) do
        if cfg.enabled and (cfg.mode == "full" or cfg.mode == "summary" or cfg.mode == "alerts") then
            local target = peripheral.wrap(cfg.monitor)
            if target then
                if target.setTextScale then target.setTextScale(cfg.textScale or 1) end
                outputs[name] = { name = name, target = target, monitor = cfg.monitor, mode = cfg.mode or "summary" }
            end
        end
    end
end

loadOutputs()

while true do
    loadOutputs()
    local data = buildData()

    renderFull(term, data)

    for _, output in pairs(outputs) do
        renderOutput(output, data)
    end

    sleep(refreshRate)
end
