local monitorConfig = require("monitor_config")
local fuelConfig = require("reactor_fuel_config")

local refreshRate = monitorConfig.refreshRate or 1
local outputConfig = nil
local monitor = nil

local function findOutputConfig()
    if not monitorConfig.outputs then return nil end
    return monitorConfig.outputs.reactor_fuel
end

local function round(num, places)
    local mult = 10 ^ (places or 0)
    return math.floor(num * mult + 0.5) / mult
end

local function padRight(text, length)
    text = tostring(text)
    if #text >= length then return text:sub(1, length) end
    return text .. string.rep(" ", length - #text)
end

local function clearTarget(target)
    target.clear()
    target.setCursorPos(1, 1)
end

local function writeLine(target, y, text)
    target.setCursorPos(1, y)
    target.clearLine()
    target.write(text)
end

local function isFuelItem(itemName)
    local fuelItems = fuelConfig.fuelItems or {}

    local hasFilter = false
    for _ in pairs(fuelItems) do
        hasFilter = true
        break
    end

    if not hasFilter then
        return true
    end

    return fuelItems[itemName] == true
end

local function getStatus(percent, online)
    if not online then
        return "MISSING"
    end

    if percent <= (fuelConfig.criticalFuelPercent or 10) then
        return "CRIT"
    elseif percent <= (fuelConfig.lowFuelPercent or 25) then
        return "LOW"
    else
        return "OK"
    end
end

local function readVault(entry)
    local inv = peripheral.wrap(entry.peripheral)

    if not inv then
        return {
            label = entry.label,
            reactor = entry.reactor,
            peripheral = entry.peripheral,
            online = false,
            error = "Missing",
            totalCount = 0,
            itemTypes = 0,
            percent = 0,
            status = "MISSING",
            items = {}
        }
    end

    if type(inv.list) ~= "function" then
        return {
            label = entry.label,
            reactor = entry.reactor,
            peripheral = entry.peripheral,
            online = false,
            error = "Not Inventory",
            totalCount = 0,
            itemTypes = 0,
            percent = 0,
            status = "BAD",
            items = {}
        }
    end

    local ok, slots = pcall(inv.list)

    if not ok or not slots then
        return {
            label = entry.label,
            reactor = entry.reactor,
            peripheral = entry.peripheral,
            online = false,
            error = "Read Error",
            totalCount = 0,
            itemTypes = 0,
            percent = 0,
            status = "ERROR",
            items = {}
        }
    end

    local totalCount = 0
    local items = {}
    local itemTypes = 0

    for slot, item in pairs(slots) do
        if item and item.name and isFuelItem(item.name) then
            local count = item.count or 0

            if not items[item.name] then
                items[item.name] = {
                    name = item.name,
                    count = 0
                }
                itemTypes = itemTypes + 1
            end

            items[item.name].count = items[item.name].count + count
            totalCount = totalCount + count
        end
    end

    local expected = fuelConfig.expectedFuelPerVault or 1024
    local percent = 0

    if expected > 0 then
        percent = totalCount / expected * 100
    end

    return {
        label = entry.label,
        reactor = entry.reactor,
        peripheral = entry.peripheral,
        online = true,
        totalCount = totalCount,
        itemTypes = itemTypes,
        percent = percent,
        status = getStatus(percent, true),
        items = items
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

local function renderDashboard(target, data)
    local y = 1
    clearTarget(target)

    writeLine(target, y, "CREATE NEW AGE REACTOR FUEL") y = y + 1
    writeLine(target, y, "----------------------------") y = y + 1
    writeLine(target, y, padRight("Vault", 16) .. padRight("Reactor", 12) .. padRight("Fuel", 10) .. padRight("Target", 10) .. padRight("Fill", 8) .. "Status") y = y + 1
    writeLine(target, y, string.rep("-", 64)) y = y + 1

    for _, row in ipairs(data.results) do
        if row.online then
            writeLine(target, y,
                padRight(row.label, 16) ..
                padRight(row.reactor, 12) ..
                padRight(tostring(row.totalCount), 10) ..
                padRight(tostring(fuelConfig.expectedFuelPerVault or 1024), 10) ..
                padRight(round(row.percent, 1) .. "%", 8) ..
                row.status
            )
        else
            writeLine(target, y,
                padRight(row.label, 16) ..
                padRight(row.reactor, 12) ..
                padRight("--", 10) ..
                padRight("--", 10) ..
                padRight("--", 8) ..
                row.error
            )
        end
        y = y + 1
    end

    y = y + 1
    writeLine(target, y, "SUMMARY") y = y + 1
    writeLine(target, y, "-------") y = y + 1
    writeLine(target, y, "Online:       " .. data.online .. "/" .. #(fuelConfig.vaults or {})) y = y + 1
    writeLine(target, y, "Missing:      " .. data.missing) y = y + 1
    writeLine(target, y, "Total Fuel:   " .. data.totalFuel) y = y + 1
    writeLine(target, y, "Target Total: " .. data.expectedTotal) y = y + 1
    writeLine(target, y, "Total Fill:   " .. round(data.totalPercent, 1) .. "%") y = y + 1
    writeLine(target, y, "Low Vaults:   " .. data.low) y = y + 1
    writeLine(target, y, "Critical:     " .. data.critical) y = y + 2

    if data.missing > 0 then
        writeLine(target, y, "ACTION: One or more fuel vaults are missing.")
    elseif data.critical > 0 then
        writeLine(target, y, "ACTION: Reactor fuel is critical.")
    elseif data.low > 0 then
        writeLine(target, y, "ACTION: Reactor fuel is low.")
    else
        writeLine(target, y, "Fuel vaults look OK.")
    end
end

local function renderDetails(target, data)
    local y = 1

    clearTarget(target)

    writeLine(target, y, "REACTOR FUEL DETAILS")
    y = y + 1
    writeLine(target, y, "--------------------")
    y = y + 2

    for _, row in ipairs(data.results) do
        writeLine(target, y, row.label .. " - " .. row.status)
        y = y + 1

        if row.online then
            if row.itemTypes == 0 then
                writeLine(target, y, "  No counted fuel items.")
                y = y + 1
            else
                for itemName, item in pairs(row.items) do
                    writeLine(target, y, "  " .. itemName .. ": " .. item.count)
                    y = y + 1
                end
            end
        else
            writeLine(target, y, "  " .. row.error)
            y = y + 1
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
        term.setCursorPos(1, 20)
        term.clearLine()
        print("Monitor output disabled or missing.")
    end

    sleep(refreshRate)
end