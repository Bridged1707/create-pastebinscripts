local stressConfig = require("stress_config")
local monitorConfig = require("monitor_config")

local refreshRate = monitorConfig.refreshRate or 1
local warningPercent = monitorConfig.warningPercent or 85
local criticalPercent = monitorConfig.criticalPercent or 95

local outputs = {}

local THEME = {
    bg = colors.black,
    text = colors.white,
    muted = colors.gray,
    headerBg = colors.blue,
    headerText = colors.white,
    section = colors.cyan,
    ok = colors.lime,
    warn = colors.yellow,
    crit = colors.orange,
    over = colors.red,
    missing = colors.red,
    barFillOk = colors.lime,
    barFillWarn = colors.yellow,
    barFillCrit = colors.orange,
    barFillOver = colors.red,
    barEmpty = colors.gray
}

local function supportsColor(target)
    return target and target.isColor and target.isColor()
end

local function setFg(target, color)
    if supportsColor(target) and color then target.setTextColor(color) end
end

local function setBg(target, color)
    if supportsColor(target) and color then target.setBackgroundColor(color) end
end

local function resetColors(target)
    setBg(target, THEME.bg)
    setFg(target, THEME.text)
end

local function round(num, places)
    local mult = 10 ^ (places or 0)
    return math.floor(num * mult + 0.5) / mult
end

local function padRight(text, length)
    text = tostring(text or "")
    if #text >= length then return text:sub(1, length) end
    return text .. string.rep(" ", length - #text)
end

local function padLeft(text, length)
    text = tostring(text or "")
    if #text >= length then return text:sub(1, length) end
    return string.rep(" ", length - #text) .. text
end

local function contains(text, value)
    return string.find(string.lower(tostring(text or "")), string.lower(value), 1, true) ~= nil
end

local function percentOf(used, capacity)
    if capacity <= 0 then return 0 end
    return used / capacity * 100
end

local function getStatus(used, capacity)
    if capacity <= 0 then return "NO CAP" end
    local percent = percentOf(used, capacity)
    if used > capacity then return "OVER" end
    if percent >= criticalPercent then return "CRIT" end
    if percent >= warningPercent then return "WARN" end
    return "OK"
end

local function statusColor(status)
    if status == "OK" then return THEME.ok end
    if status == "WARN" or status == "WARNING" then return THEME.warn end
    if status == "CRIT" or status == "CRITICAL" then return THEME.crit end
    if status == "OVER" or status == "OVERSTRESSED" then return THEME.over end
    if status == "NO CAP" or status == "MISSING" or status == "Missing" or status == "Read Error" or status == "Not Stress" then return THEME.missing end
    return THEME.text
end

local function percentStatus(percent, overstressed)
    if overstressed then return "OVER" end
    if percent >= criticalPercent then return "CRIT" end
    if percent >= warningPercent then return "WARN" end
    return "OK"
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

local function writeAt(target, x, y, text, fg, bg)
    local w, h = target.getSize()
    if y < 1 or y > h or x > w then return end
    if bg then setBg(target, bg) end
    if fg then setFg(target, fg) end
    target.setCursorPos(x, y)
    target.write(tostring(text or ""):sub(1, w - x + 1))
    resetColors(target)
end

local function writeLine(target, y, text, fg, bg)
    local w, h = target.getSize()
    if y < 1 or y > h then return end
    target.setCursorPos(1, y)
    if bg then setBg(target, bg) end
    if fg then setFg(target, fg) end
    target.clearLine()
    target.write(tostring(text or ""):sub(1, w))
    resetColors(target)
end

local function clearTarget(target)
    resetColors(target)
    target.clear()
    target.setCursorPos(1, 1)
end

local function header(target, title, subtitle)
    local w = target.getSize()
    setBg(target, THEME.headerBg)
    setFg(target, THEME.headerText)
    target.setCursorPos(1, 1)
    target.clearLine()
    target.write((" " .. title):sub(1, w))
    resetColors(target)
    if subtitle then writeLine(target, 2, " " .. subtitle, THEME.muted) end
end

local function drawBar(target, x, y, width, percent, status)
    if width < 4 then return end
    local fill = math.floor(math.min(math.max(percent, 0), 100) / 100 * width + 0.5)
    local color = THEME.barFillOk
    if status == "WARN" then color = THEME.barFillWarn end
    if status == "CRIT" then color = THEME.barFillCrit end
    if status == "OVER" then color = THEME.barFillOver end

    if supportsColor(target) then
        writeAt(target, x, y, string.rep(" ", width), THEME.text, THEME.barEmpty)
        if fill > 0 then writeAt(target, x, y, string.rep(" ", fill), THEME.text, color) end
    else
        writeAt(target, x, y, "[" .. string.rep("#", math.max(0, fill - 2)) .. string.rep("-", math.max(0, width - fill - 2)) .. "]")
    end
end

local function renderCompact(target, data)
    local w = target.getSize()
    local y = 1
    clearTarget(target)
    header(target, "CREATE STRESS", "compact dashboard")
    y = 4

    for _, row in ipairs(data.results) do
        if row.online then
            local status = row.status
            writeLine(target, y, padRight(row.label, 14) .. padLeft(round(row.percent, 1) .. "%", 7) .. " " .. status, statusColor(status))
            drawBar(target, 1, y + 1, math.min(w, 32), row.percent, status)
        else
            writeLine(target, y, padRight(row.label, 14) .. " " .. row.error, statusColor(row.error))
        end
        y = y + 3
    end
end

local function renderFull(target, data)
    local w = target.getSize()
    if w < 64 then return renderCompact(target, data) end

    local y = 1
    clearTarget(target)
    header(target, "CREATE / NEW AGE STRESS", "used / capacity / load")
    y = 4

    writeLine(target, y, padRight("Name", 15) .. padRight("Group", 16) .. padLeft("Used", 9) .. " " .. padLeft("Cap", 9) .. " " .. padLeft("Load", 7) .. "  Status", THEME.section)
    y = y + 1
    writeLine(target, y, string.rep("-", math.min(w, 72)), THEME.muted)
    y = y + 1

    for _, row in ipairs(data.results) do
        if row.online then
            local status = row.status
            local line = padRight(row.label, 15) ..
                padRight(row.group, 16) ..
                padLeft(math.floor(row.used), 7) .. "SU " ..
                padLeft(math.floor(row.capacity), 7) .. "SU " ..
                padLeft(round(row.percent, 1) .. "%", 7) .. "  " .. status
            writeLine(target, y, line, statusColor(status))
            if w >= 82 then drawBar(target, 73, y, math.min(16, w - 72), row.percent, status) end
        else
            local line = padRight(row.label, 15) .. padRight(row.group, 16) .. padRight("--", 10) .. padRight("--", 10) .. padRight("--", 9) .. row.error
            writeLine(target, y, line, statusColor(row.error))
        end
        y = y + 1
    end

    y = y + 1

    local function totalsLine(title, totals)
        local percent = percentOf(totals.used, totals.capacity)
        local status = percentStatus(percent, totals.overstressed > 0)
        writeLine(target, y, title, THEME.section) y = y + 1
        writeLine(target, y,
            "Online " .. totals.online ..
            " | Missing " .. totals.missing ..
            " | Used " .. math.floor(totals.used) .. " SU" ..
            " | Cap " .. math.floor(totals.capacity) .. " SU" ..
            " | Load " .. round(percent, 1) .. "%" ..
            " | " .. status,
            statusColor(status)
        )
        y = y + 1
        drawBar(target, 1, y, math.min(w, 50), percent, status)
        y = y + 2
    end

    totalsLine("STEAM ENGINES", data.steamTotals)
    totalsLine("BACKUP ENGINES", data.backupTotals)
    totalsLine("OVERALL", data.overallTotals)
end

local function renderSummary(target, data)
    local y = 1
    clearTarget(target)

    local steamPercent = percentOf(data.steamTotals.used, data.steamTotals.capacity)
    local backupPercent = percentOf(data.backupTotals.used, data.backupTotals.capacity)
    local overallPercent = percentOf(data.overallTotals.used, data.overallTotals.capacity)

    header(target, "CREATE STRESS SUMMARY", "steam / backup / total")
    y = 4

    local function line(name, totals, percent)
        local status = percentStatus(percent, totals.overstressed > 0)
        writeLine(target, y, padRight(name, 8) .. " " .. totals.online .. "/4  " .. math.floor(totals.used) .. "/" .. math.floor(totals.capacity) .. " SU  " .. round(percent, 1) .. "%  " .. status, statusColor(status))
        y = y + 1
        drawBar(target, 1, y, 36, percent, status)
        y = y + 2
    end

    line("STEAM", data.steamTotals, steamPercent)
    line("BACKUP", data.backupTotals, backupPercent)
    line("TOTAL", data.overallTotals, overallPercent)
end

local function renderAlerts(target, data)
    local y = 1
    local foundAlert = false
    clearTarget(target)

    header(target, "CREATE STRESS ALERTS", "only problems shown")
    y = 4

    for _, row in ipairs(data.results) do
        if not row.online then
            writeLine(target, y, row.label .. ": " .. row.error, statusColor(row.error)) y = y + 1
            foundAlert = true
        elseif row.used > row.capacity then
            writeLine(target, y, row.label .. ": OVERSTRESSED", THEME.over) y = y + 1
            foundAlert = true
        elseif row.percent >= criticalPercent then
            writeLine(target, y, row.label .. ": CRITICAL " .. round(row.percent, 1) .. "%", THEME.crit) y = y + 1
            foundAlert = true
        elseif row.percent >= warningPercent then
            writeLine(target, y, row.label .. ": WARNING " .. round(row.percent, 1) .. "%", THEME.warn) y = y + 1
            foundAlert = true
        end
    end

    if not foundAlert then writeLine(target, y, "No stress alerts.", THEME.ok) end
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

while true do
    loadOutputs()
    local data = buildData()

    renderFull(term, data)

    for _, output in pairs(outputs) do
        renderOutput(output, data)
    end

    sleep(refreshRate)
end
