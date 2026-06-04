-- Manual mapping for every reactor component.
-- Peripheral numbers do not need to match reactor numbers.
return {
    -- When a relay is missing or still set to CHANGE_ME, keep monitoring enabled.
    -- This prevents a bad relay mapping from hiding fuel/stress problems.
    missingRelayMeansOn = true,

    fuelItems = {
        ["create_new_age:nuclear_fuel"] = true
    },

    expectedFuelPerVault = 1024,
    lowFuelPercent = 25,
    criticalFuelPercent = 10,

    reactors = {
        {
            id = "reactor_1",
            label = "Reactor 1",
            enabled = true,
            relay = { peripheral = "CHANGE_ME_RELAY_1", side = "back", threshold = 1, inverted = false },
            fuelVault = "create:item_vault_1",
            steamStressometer = "Create_Stressometer_1",
            backupStressometer = "Create_Stressometer_2"
        },
        {
            id = "reactor_2",
            label = "Reactor 2",
            enabled = true,
            relay = { peripheral = "CHANGE_ME_RELAY_2", side = "back", threshold = 1, inverted = false },
            fuelVault = "create:item_vault_2",
            steamStressometer = "Create_Stressometer_3",
            backupStressometer = "Create_Stressometer_4"
        },
        {
            id = "reactor_3",
            label = "Reactor 3",
            enabled = true,
            relay = { peripheral = "CHANGE_ME_RELAY_3", side = "back", threshold = 1, inverted = false },
            fuelVault = "create:item_vault_3",
            steamStressometer = "Create_Stressometer_5",
            backupStressometer = "Create_Stressometer_6"
        },
        {
            id = "reactor_4",
            label = "Reactor 4",
            enabled = true,
            relay = { peripheral = "CHANGE_ME_RELAY_4", side = "back", threshold = 1, inverted = false },
            fuelVault = "create:item_vault_4",
            steamStressometer = "Create_Stressometer_7",
            backupStressometer = "Create_Stressometer_8"
        }
    }
}
