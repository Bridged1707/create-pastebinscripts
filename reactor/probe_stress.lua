print("ALL PERIPHERALS")
print("===============")

for _, name in ipairs(peripheral.getNames()) do
    local pType = peripheral.getType(name)
    local methods = peripheral.getMethods(name) or {}

    print()
    print("Name: " .. name)
    print("Type: " .. tostring(pType))

    local hasStress = false
    local hasCapacity = false

    for _, method in ipairs(methods) do
        if method == "getStress" then
            hasStress = true
        elseif method == "getStressCapacity" then
            hasCapacity = true
        end
    end

    if name:lower():find("stress") or hasStress or hasCapacity then
        print("Methods: " .. textutils.serialize(methods))

        if hasStress then
            local ok, value = pcall(peripheral.call, name, "getStress")
            print("getStress: " .. tostring(ok) .. " / " .. tostring(value))
        end

        if hasCapacity then
            local ok, value = pcall(peripheral.call, name, "getStressCapacity")
            print("getStressCapacity: " .. tostring(ok) .. " / " .. tostring(value))
        end
    end
end
