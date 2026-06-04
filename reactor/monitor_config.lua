return {
    refreshRate = 1,

    warningPercent = 85,
    criticalPercent = 95,

    -- History settings used by both graph programs unless overridden per output.
    graphDefaults = {
        sampleSeconds = 30,
        historyPoints = 120
    },

    outputs = {
        stress_full = {
            enabled = true,
            monitor = "monitor_2",
            textScale = 0.5,
            mode = "full"
        },

        reactor_fuel = {
            enabled = true,
            monitor = "monitor_3",
            textScale = 0.5,
            mode = "reactor_fuel"
        },

        -- Change these monitor names and enable them when the graph monitors exist.
        reactor_fuel_graph = {
            enabled = false,
            monitor = "monitor_4",
            textScale = 0.5,
            sampleSeconds = 30,
            historyPoints = 120
        },

        stress_graph = {
            enabled = false,
            monitor = "monitor_5",
            textScale = 0.5,
            sampleSeconds = 30,
            historyPoints = 120
        },

        stress_alerts = {
            enabled = false,
            monitor = "monitor_2",
            textScale = 1,
            mode = "alerts"
        },

        stress_summary = {
            enabled = false,
            monitor = "monitor_3",
            textScale = 1,
            mode = "summary"
        }
    }
}
