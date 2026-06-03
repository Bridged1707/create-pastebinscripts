local monitorConfig = require("monitor_config")
local fuelConfig = require("reactor_fuel_config")

local refreshRate = monitorConfig.refreshRate or 1
local outputConfig = nil
local monitor = nil

local THEME = {
    bg = colors.black,
    text = colors.white,
    muted = colors.gray,
    headerBg = colors.purple,
    headerText = colors.white,
    section = colors.cyan,
    ok = colors.lime,
    low = colors.yellow,
    crit = colors.red,
    missing = colors.red,
    barFillOk = colors.lime,
    barFillLow = colors.yellow,
    barFillCrit = colors.red,
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

local function findOutputConfig()
    if not monitorConfig.outputs then return nil end
    return monitorConfig.outputs.reactor_fuel
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

local function clearTarget(target)
    resetColors(target)
    target.clear()
    target.setCursorPos(1, 1)
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

local function fuelFilterIsEmpty()
    local fuelItems = fuelConfig.fuelItems or {}
    for _ in pairs(fuelItems) do return false end
    return true
end

local function isFuelItem(itemName)
    local fuelItems = fuelConfig.fuelItems or {}
    if fuelFilterIsEmpty() then return true end
    if fuelItems[itemName] == true then return true end
    for _, value in pairs(fuelItems) do
        if value == itemName then return true end
    end
    return false
end

local function getStatus(percent, online)
    if not online then return "MISSING" end
    if percent <= (fuelConfig.criticalFuelPercent or 10) then return "CRIT" end
    if percent <= (fuelConfig.lowFuelPercent or 25) then return "LOW" end
    return "OK"
end

local function statusColor(status)
    if status == "OK" then return THEME.ok end
    if status == "LOW" then return THEME.low end
    if status == "CRIT" then return THEME.crit end
    if status == "MISSING" or status == "BAD" or status == "ERROR" or status == "Missing" or status == "Read Error" then return THEME.missing end
    return THEME.text
end

local function drawBar(target, x, y, width, percent, status)
    if width < 4 then return end
    local fill = math.floor(math.min(math.max(percent, 0), 100) / 100 * width + 0.5)
    local color = THEME.barFillOk
    if status == "LOW" then color = THEME.barFillLow end
    if status == "CRIT" then color = THEME.barFillCrit end

    if supportsColor(target) then
        writeAt(target, x, y, string.rep(" ", width), THEME.text, THEME.barEmpty)
        if fill > 0 then writeAt(target, x, y, string.rep(" ", fill), THEME.text, color) end
    else
        writeAt(target, x, y, "[" .. string.rep("#", math.max(0, fill - 2)) .. string.rep("-", math.max(0, width - fill - 2)) .. "]")
    end
end

local function readVault(entry)
    local inv = peripheral.wrap(entry.peripheral)

    if not inv then
        return {
            label = entry.label, reactor = entry.reactor, peripheral = entry.peripheral,
            online = false, error = "Missing", totalCount = 0, itemTypes = 0,
            percent = 0, status = "MISSING", items = {}, allItems = {}
        }
    end

    if type(inv.list) ~= "function" then
        return {
            label = entry.label, reactor = entry.reactor, peripheral = entry.peripheral,
            online = false, error = "Not Inventory", totalCount = 0, itemTypes = 0,
            percent = 0, status = "BAD", items = {}, allItems = {}
        }
    end

    local ok, slots = pcall(function() return inv.list() end)

    if not ok or not slots then
        return {
            label = entry.label, reactor = entry.reactor, peripheral = entry.peripheral,
            online = false, error = "Read Error", totalCount = 0, itemTypes = 0,
            percent = 0, status = "ERROR", items = {}, allItems = {}
        }
    end

    local totalCount = 0
    local items = {}
    local allItems = {}
    local itemTypes = 0

    for _, item in pairs(slots) do
        if item and item.name then
            local count = item.count or 0

            if not allItems[item.name] then allItems[item.name] = { name = item.name, count = 0 } end
            allItems[item.name].count = allItems[item.name].count + count

            if isFuelItem(item.name) then
                if not items[item.name] then
                    items[item.name] = { name = item.name, count = 0 }
                    itemTypes = itemTypes + 1
                end

                items[item.name].count = items[item.name].count + count
                totalCount = totalCount + count
            end
        end
    end

    local expected = fuelConfig.expectedFuelPerVault or 1024
    local percent = 0
    if expected > 0 then percent = totalCount / expected * 100 end

    return {
        label = entry.label, reactor = entry.reactor, peripheral = entry.peripheral,
        online = true, totalCount = totalCount, itemTypes = itemTypes,
        percent = percent, status = getStatus(percent, true), items = items, allItems = allItems
    }
end

local function buildData()
    local results = {}
    local totalFuel = 0
    local online = 0
    local missing = 0
    local low = 0
    local critical = 0

    for _, entry in ipairs(fuelConfig.vaults or {}) do
        local data = readVault(entry)
        table.insert(results, data)
        totalFuel = totalFuel + data.totalCount

        if data.online then
            online = online + 1
            if data.status == "LOW" then low = low + 1
            elseif data.status == "CRIT" then critical = critical + 1 end
        else
            missing = missing + 1
        end
    end

    local expectedTotal = (fuelConfig.expectedFuelPerVault or 1024) * #(fuelConfig.vaults or {})
    local totalPercent = 0
    if expectedTotal > 0 then totalPercent = totalFuel / expectedTotal * 100 end

    return {
        results = results, totalFuel = totalFuel, expectedTotal = expectedTotal,
        totalPercent = totalPercent, online = online, missing = missing,
        low = low, critical = critical
    }
end

local function renderCompact(target, data)
    local w = target.getSize()
    local y = 1
    clearTarget(target)
    header(target, "REACTOR FUEL", "compact dashboard")
    y = 4

    for _, row in ipairs(data.results) do
        if row.online then
            writeLine(target, y, padRight(row.label, 14) .. padLeft(row.totalCount, 7) .. "  " .. padLeft(round(row.percent, 1) .. "%", 7) .. " " .. row.status, statusColor(row.status))
            drawBar(target, 1, y + 1, math.min(w, 32), row.percent, row.status)
        else
            writeLine(target, y, padRight(row.label, 14) .. " " .. row.error, statusColor(row.status))
        end
        y = y + 3
    end
end

local function renderDashboard(target, data)
    local w = target.getSize()
    if w < 60 then return renderCompact(target, data) end

    local y = 1
    clearTarget(target)

    header(target, "CREATE NEW AGE REACTOR FUEL", "vault fuel levels")
    y = 4

    writeLine(target, y, padRight("Vault", 16) .. padRight("Reactor", 12) .. padLeft("Fuel", 8) .. " " .. padLeft("Target", 8) .. " " .. padLeft("Fill", 7) .. "  Status", THEME.section)
    y = y + 1
    writeLine(target, y, string.rep("-", math.min(w, 66)), THEME.muted)
    y = y + 1

    for _, row in ipairs(data.results) do
        if row.online then
            local line = padRight(row.label, 16) ..
                padRight(row.reactor, 12) ..
                padLeft(row.totalCount, 8) .. " " ..
                padLeft(fuelConfig.expectedFuelPerVault or 1024, 8) .. " " ..
                padLeft(round(row.percent, 1) .. "%", 7) .. "  " .. row.status
            writeLine(target, y, line, statusColor(row.status))
            if w >= 78 then drawBar(target, 68, y, math.min(18, w - 67), row.percent, row.status) end
        else
            writeLine(target, y, padRight(row.label, 16) .. padRight(row.reactor, 12) .. padRight("--", 9) .. padRight("--", 9) .. padRight("--", 9) .. row.error, statusColor(row.status))
        end
        y = y + 1
    end

    y = y + 1
    local overallStatus = "OK"
    if data.missing > 0 then overallStatus = "MISSING"
    elseif data.critical > 0 then overallStatus = "CRIT"
    elseif data.low > 0 then overallStatus = "LOW" end

    writeLine(target, y, "SUMMARY", THEME.section) y = y + 1
    writeLine(target, y, "Online " .. data.online .. "/" .. #(fuelConfig.vaults or {}) ..
        " | Missing " .. data.missing ..
        " | Fuel " .. data.totalFuel .. "/" .. data.expectedTotal ..
        " | Fill " .. round(data.totalPercent, 1) .. "%" ..
        " | " .. overallStatus,
        statusColor(overallStatus))
    y = y + 1
    drawBar(target, 1, y, math.min(w, 50), data.totalPercent, overallStatus)
    y = y + 2

    if data.missing > 0 then
        writeLine(target, y, "ACTION: One or more fuel vaults are missing.", THEME.missing)
    elseif data.critical > 0 then
        writeLine(target, y, "ACTION: Reactor fuel is critical.", THEME.crit)
    elseif data.low > 0 then
        writeLine(target, y, "ACTION: Reactor fuel is low.", THEME.low)
    else
        writeLine(target, y, "Fuel vaults look OK.", THEME.ok)
    end
end

local function renderDetails(target, data)
    local y = 1
    clearTarget(target)

    header(target, "REACTOR FUEL DETAILS", "matching items and counts")
    y = 4

    for _, row in ipairs(data.results) do
        writeLine(target, y, row.label .. " - " .. row.status .. " - Counted: " .. row.totalCount, statusColor(row.status))
        y = y + 1

        if row.online then
            if row.itemTypes == 0 then
                writeLine(target, y, "  No matching fuel items counted.", THEME.low) y = y + 1
                writeLine(target, y, "  Items found in vault:", THEME.section) y = y + 1
                for itemName, item in pairs(row.allItems or {}) do
                    writeLine(target, y, "  " .. itemName .. ": " .. item.count, THEME.text) y = y + 1
                end
            else
                for itemName, item in pairs(row.items) do
                    writeLine(target, y, "  " .. itemName .. ": " .. item.count, THEME.text) y = y + 1
                end
            end
        else
            writeLine(target, y, "  " .. row.error, statusColor(row.status)) y = y + 1
        end

        y = y + 1
    end
end

local function render(target, data)
    local mode = "reactor_fuel"
    if outputConfig and outputConfig.mode then mode = outputConfig.mode end

    if mode == "reactor_fuel_details" then
        renderDetails(target, data)
    else
        renderDashboard(target, data)
    end
end

local function loadMonitor()
    outputConfig = findOutputConfig()

    if not outputConfig or not outputConfig.enabled then
        monitor = nil
        return
    end

    monitor = peripheral.wrap(outputConfig.monitor)
    if monitor and monitor.setTextScale then monitor.setTextScale(outputConfig.textScale or 0.5) end
end

while true do
    loadMonitor()
    local data = buildData()

    render(term, data)

    if monitor then
        render(monitor, data)
    else
        local _, h = term.getSize()
        term.setCursorPos(1, h)
        term.clearLine()
        print("Monitor output disabled or missing.")
    end

    sleep(refreshRate)
end
