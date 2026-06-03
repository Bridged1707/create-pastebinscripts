local user = "YOUR_USERNAME"
local repo = "YOUR_REPO"
local branch = "main"
local folder = "reactor"

local files = {
    "startup.lua",
    "stress.lua",
    "stress_config.lua",
    "reactor_fuel.lua",
    "reactor_fuel_config.lua",
    "monitor_config.lua",
    "scan_peripherals.lua",
    "check_vault_items.lua"
}

local baseUrl = "https://raw.githubusercontent.com/" ..
    user .. "/" .. repo .. "/" .. branch .. "/" .. folder .. "/"

local function downloadFile(file)
    local url = baseUrl .. file

    print("Downloading " .. file .. "...")

    local response = http.get(url)

    if not response then
        print("FAILED: " .. url)
        return false
    end

    local content = response.readAll()
    response.close()

    local handle = fs.open(file, "w")
    handle.write(content)
    handle.close()

    print("Saved " .. file)
    return true
end

if not http then
    error("HTTP API is disabled. Enable it in ComputerCraft config.")
end

print("Installing reactor monitor scripts...")
print("------------------------------------")

local failed = 0

for _, file in ipairs(files) do
    local ok = downloadFile(file)

    if not ok then
        failed = failed + 1
    end
end

print("------------------------------------")

if failed > 0 then
    print("Install finished with " .. failed .. " failed downloads.")
else
    print("Install complete.")
    print("Run: reboot")
end