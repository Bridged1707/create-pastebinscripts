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

    -- If empty, the script counts all items in the vault as fuel.
    -- If you want only specific fuel items counted, add item IDs here.
    -- Example:
    -- fuelItems = {
    --     ["create_new_age:thorium"] = true,
    --     ["create_new_age:radioactive_thorium"] = true
    -- }
    fuelItems = {"create_new_age:nuclear_fuel"},

    -- Used only for rough warnings.
    -- Item vault capacity depends on size, so this is just your chosen target.
    expectedFuelPerVault = 1024,

    lowFuelPercent = 25,
    criticalFuelPercent = 10
}