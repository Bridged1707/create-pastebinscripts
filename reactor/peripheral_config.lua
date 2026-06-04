-- Manual mapping for every reactor component.
-- Peripheral numbers do not need to match reactor numbers.
--
-- Create Smart Chutes and Clutches are commonly disabled when powered.
-- The default poweredMeansEnabled = false reflects that behavior.
-- Flip it to true for any control where a redstone signal should mean ON.
return {
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
            fuelVault = "create:item_vault_1",

            primaryStressometer = "Create_Stressometer_1",
            backupStressometer = "Create_Stressometer_2",
            primarySpeedometer = "CHANGE_ME_R1_PRIMARY_SPEEDOMETER",
            backupSpeedometer = "CHANGE_ME_R1_BACKUP_SPEEDOMETER",

            fuelChutes = {
                { label = "Rod 1", relay = { peripheral = "CHANGE_ME_R1_CHUTE_1_RELAY", outputSide = "back", poweredMeansEnabled = false } },
                { label = "Rod 2", relay = { peripheral = "CHANGE_ME_R1_CHUTE_2_RELAY", outputSide = "back", poweredMeansEnabled = false } },
                { label = "Rod 3", relay = { peripheral = "CHANGE_ME_R1_CHUTE_3_RELAY", outputSide = "back", poweredMeansEnabled = false } }
            },

            clutches = {
                primary = { label = "Primary Pump", relay = { peripheral = "CHANGE_ME_R1_PRIMARY_CLUTCH_RELAY", outputSide = "back", poweredMeansEnabled = false } },
                backup = { label = "Backup Pump", relay = { peripheral = "CHANGE_ME_R1_BACKUP_CLUTCH_RELAY", outputSide = "back", poweredMeansEnabled = false } }
            }
        },
        {
            id = "reactor_2",
            label = "Reactor 2",
            enabled = true,
            fuelVault = "create:item_vault_2",

            primaryStressometer = "Create_Stressometer_3",
            backupStressometer = "Create_Stressometer_4",
            primarySpeedometer = "CHANGE_ME_R2_PRIMARY_SPEEDOMETER",
            backupSpeedometer = "CHANGE_ME_R2_BACKUP_SPEEDOMETER",

            fuelChutes = {
                { label = "Rod 1", relay = { peripheral = "CHANGE_ME_R2_CHUTE_1_RELAY", outputSide = "back", poweredMeansEnabled = false } },
                { label = "Rod 2", relay = { peripheral = "CHANGE_ME_R2_CHUTE_2_RELAY", outputSide = "back", poweredMeansEnabled = false } },
                { label = "Rod 3", relay = { peripheral = "CHANGE_ME_R2_CHUTE_3_RELAY", outputSide = "back", poweredMeansEnabled = false } }
            },

            clutches = {
                primary = { label = "Primary Pump", relay = { peripheral = "CHANGE_ME_R2_PRIMARY_CLUTCH_RELAY", outputSide = "back", poweredMeansEnabled = false } },
                backup = { label = "Backup Pump", relay = { peripheral = "CHANGE_ME_R2_BACKUP_CLUTCH_RELAY", outputSide = "back", poweredMeansEnabled = false } }
            }
        },
        {
            id = "reactor_3",
            label = "Reactor 3",
            enabled = true,
            fuelVault = "create:item_vault_3",

            primaryStressometer = "Create_Stressometer_5",
            backupStressometer = "Create_Stressometer_6",
            primarySpeedometer = "CHANGE_ME_R3_PRIMARY_SPEEDOMETER",
            backupSpeedometer = "CHANGE_ME_R3_BACKUP_SPEEDOMETER",

            fuelChutes = {
                { label = "Rod 1", relay = { peripheral = "CHANGE_ME_R3_CHUTE_1_RELAY", outputSide = "back", poweredMeansEnabled = false } },
                { label = "Rod 2", relay = { peripheral = "CHANGE_ME_R3_CHUTE_2_RELAY", outputSide = "back", poweredMeansEnabled = false } },
                { label = "Rod 3", relay = { peripheral = "CHANGE_ME_R3_CHUTE_3_RELAY", outputSide = "back", poweredMeansEnabled = false } }
            },

            clutches = {
                primary = { label = "Primary Pump", relay = { peripheral = "CHANGE_ME_R3_PRIMARY_CLUTCH_RELAY", outputSide = "back", poweredMeansEnabled = false } },
                backup = { label = "Backup Pump", relay = { peripheral = "CHANGE_ME_R3_BACKUP_CLUTCH_RELAY", outputSide = "back", poweredMeansEnabled = false } }
            }
        },
        {
            id = "reactor_4",
            label = "Reactor 4",
            enabled = true,
            fuelVault = "create:item_vault_4",

            primaryStressometer = "Create_Stressometer_7",
            backupStressometer = "Create_Stressometer_8",
            primarySpeedometer = "CHANGE_ME_R4_PRIMARY_SPEEDOMETER",
            backupSpeedometer = "CHANGE_ME_R4_BACKUP_SPEEDOMETER",

            fuelChutes = {
                { label = "Rod 1", relay = { peripheral = "CHANGE_ME_R4_CHUTE_1_RELAY", outputSide = "back", poweredMeansEnabled = false } },
                { label = "Rod 2", relay = { peripheral = "CHANGE_ME_R4_CHUTE_2_RELAY", outputSide = "back", poweredMeansEnabled = false } },
                { label = "Rod 3", relay = { peripheral = "CHANGE_ME_R4_CHUTE_3_RELAY", outputSide = "back", poweredMeansEnabled = false } }
            },

            clutches = {
                primary = { label = "Primary Pump", relay = { peripheral = "CHANGE_ME_R4_PRIMARY_CLUTCH_RELAY", outputSide = "back", poweredMeansEnabled = false } },
                backup = { label = "Backup Pump", relay = { peripheral = "CHANGE_ME_R4_BACKUP_CLUTCH_RELAY", outputSide = "back", poweredMeansEnabled = false } }
            }
        }
    }
}
