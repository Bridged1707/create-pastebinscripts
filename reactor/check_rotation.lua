local cfg = require("peripheral_config")

local function inspect(name, expectedMethods)
    print("Peripheral: " .. tostring(name))

    if type(name) ~= "string" or name == "" or name:find("CHANGE_ME", 1, true) then
        print("  Status: UNCONFIGURED")
        return
    end

    local wrapped = peripheral.wrap(name)
    if not wrapped then
        print("  Status: MISSING")
        return
    end

    print("  Type: " .. tostring(peripheral.getType(name)))

    for _, methodName in ipairs(expectedMethods) do
        if type(wrapped[methodName]) == "function" then
            local ok, value = pcall(wrapped[methodName])
            if ok then
                print("  " .. methodName .. ": " .. tostring(value))
            else
                print("  " .. methodName .. ": ERROR " .. tostring(value))
            end
        else
            print("  " .. methodName .. ": NOT AVAILABLE")
        end
    end
end

for _, reactor in ipairs(cfg.reactors or {}) do
    if reactor.enabled ~= false then
        print("============================")
        print(reactor.label)
        print("============================")

        print("Primary Stressometer")
        inspect(reactor.primaryStressometer, { "getStress", "getStressCapacity" })
        print()

        print("Backup Stressometer")
        inspect(reactor.backupStressometer, { "getStress", "getStressCapacity" })
        print()

        print("Primary Speedometer")
        inspect(reactor.primarySpeedometer, { "getSpeed" })
        print()

        print("Backup Speedometer")
        inspect(reactor.backupSpeedometer, { "getSpeed" })
        print()
    end
end
