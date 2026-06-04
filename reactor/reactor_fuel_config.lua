return {
    vaults = {
        {
            label = "Reactor Fuel 1",
            reactor = "Reactor 1",
            peripheral = "create:item_vault_1"
        },
        {
            label = "Reactor Fuel 2",
            reactor = "Reactor 2",
            peripheral = "create:item_vault_2"
        },
        {
            label = "Reactor Fuel 3",
            reactor = "Reactor 3",
            peripheral = "create:item_vault_3"
        },
        {
            label = "Reactor Fuel 4",
            reactor = "Reactor 4",
            peripheral = "create:item_vault_4"
        }
    },

    -- Leave this empty to count every item in the vault as fuel:
    -- fuelItems = {},
    --
    -- You can use either list style:
    -- fuelItems = { "create_new_age:nuclear_fuel" },
    --
    -- or map style:
    -- fuelItems = { ["create_new_age:nuclear_fuel"] = true },
    fuelItems = { "create_new_age:nuclear_fuel" },

    expectedFuelPerVault = 1024,

    lowFuelPercent = 25,
    criticalFuelPercent = 10
}
