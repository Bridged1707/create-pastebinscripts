return {
    refreshRate = 1,

    warningPercent = 85,
    criticalPercent = 95,

    outputs = {
        stress_full = {
            enabled = true,
            monitor = "monitor_5",
            textScale = 0.5,
            mode = "full"
        },

        reactor_fuel = {
            enabled = true,
            monitor = "monitor_6",
            textScale = 0.5,
            mode = "reactor_fuel"
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
