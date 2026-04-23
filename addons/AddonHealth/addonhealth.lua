_addon.name = 'AddonHealth'
_addon.author = 'boostie'
_addon.version = '0.1.0'
_addon.commands = {'addonhealth', 'ahealth'}
_addon.description = 'Unified health dashboard for Windower addon stack status and diagnostics.'

local REPORT_DIR = (windower.addon_path or '') .. 'data/'
local KNOWN_ADDONS = {
    'TravelRouter', 'SessionConductor', 'GearSwap', 'Shortcuts',
    'DressUp', 'FastCS', 'Treasury', 'Config', 'Cancel', 'Enternity',
}

local KNOWN_DEPS = {
    TravelRouter = {},
    SessionConductor = { 'TravelRouter' },
    GearSwap = {},
    Shortcuts = {},
}

local state = {
    watchEnabled = false,
    watchInterval = 30,
    lastCheck = 0,
    lastReport = nil,
}

local function msg(text)
    windower.add_to_chat(200, ('[AddonHealth] %s'):format(text))
end

local function now()
    return os.time()
end

local function get_loaded_addons()
    local loaded = {}
    if windower.get_addons then
        local addons = windower.get_addons() or {}
        for k, v in pairs(addons) do
            if type(v) == 'string' then
                loaded[v:lower()] = true
            elseif type(v) == 'table' then
                local name = v.name or v.addon or v.short_name
                if type(name) == 'string' then
                    loaded[name:lower()] = true
                end
                if v.path then
                    local inferred = tostring(v.path):match('([^/\]+)[/\]?$')
                    if inferred then loaded[inferred:lower()] = true end
                end
                if v.loaded == false and name then
                    loaded[name:lower()] = nil
                end
            elseif type(k) == 'string' and v then
                loaded[k:lower()] = true
            end
        end
    end
    return loaded
end

local function check_loaded()
    local loaded = get_loaded_addons()
    local results = {}
    for _, name in ipairs(KNOWN_ADDONS) do
        results[#results+1] = {
            addon = name,
            loaded = loaded[name:lower()] or false,
        }
    end
    return results
end

local function check_dependencies()
    local loaded = get_loaded_addons()
    local issues = {}
    for addon, deps in pairs(KNOWN_DEPS) do
        if loaded[addon:lower()] then
            for _, dep in ipairs(deps) do
                if not loaded[dep:lower()] then
                    issues[#issues+1] = {
                        addon = addon,
                        missing_dep = dep,
                        severity = 'warn',
                    }
                end
            end
        end
    end
    return issues
end

local function check_files()
    local issues = {}
    local paths = {
        { label = 'TravelRouter routes', path = (windower.addon_path or '') .. '../TravelRouter/data/routes.lua' },
        { label = 'SessionConductor rules', path = (windower.addon_path or '') .. '../SessionConductor/data/rules.default.lua' },
    }
    for _, entry in ipairs(paths) do
        local f = io.open(entry.path, 'r')
        if f then
            f:close()
        else
            issues[#issues+1] = {
                label = entry.label,
                path = entry.path,
                status = 'missing',
            }
        end
    end
    return issues
end

local function run_diagnostics()
    local report = {
        timestamp = now(),
        player = (windower.ffxi.get_player() or {}).name or 'unknown',
        zone = (windower.ffxi.get_info() or {}).zone or 0,
        loaded = check_loaded(),
        dep_issues = check_dependencies(),
        file_issues = check_files(),
    }
    state.lastReport = report
    state.lastCheck = now()
    return report
end

local function display_report(report)
    msg(('--- Health Check @ %s ---'):format(os.date('%H:%M:%S', report.timestamp)))
    msg(('Player: %s | Zone: %d'):format(report.player, report.zone))

    msg('Addon Status:')
    for _, entry in ipairs(report.loaded) do
        local icon = entry.loaded and '+' or '-'
        msg(('  [%s] %s'):format(icon, entry.addon))
    end

    if #report.dep_issues > 0 then
        msg('Dependency Issues:')
        for _, issue in ipairs(report.dep_issues) do
            msg(('  %s requires %s (not loaded)'):format(issue.addon, issue.missing_dep))
        end
    end

    if #report.file_issues > 0 then
        msg('File Issues:')
        for _, issue in ipairs(report.file_issues) do
            msg(('  %s: %s (%s)'):format(issue.label, issue.status, issue.path))
        end
    end

    local total_issues = #report.dep_issues + #report.file_issues
    if total_issues == 0 then
        msg('All checks passed.')
    else
        msg(('%d issue(s) found.'):format(total_issues))
    end
    msg('---')
end

local function export_report(report)
    local filename = ('addonhealth-report-%s.txt'):format(os.date('%Y%m%d-%H%M%S', report.timestamp))
    local path = REPORT_DIR .. filename
    local f = io.open(path, 'w')
    if not f then
        msg('Failed to write report file: ' .. path)
        return
    end

    f:write(('AddonHealth Report - %s\n'):format(os.date('%Y-%m-%d %H:%M:%S', report.timestamp)))
    f:write(('Player: %s | Zone: %d\n\n'):format(report.player, report.zone))

    f:write('Addon Status:\n')
    for _, entry in ipairs(report.loaded) do
        f:write(('  [%s] %s\n'):format(entry.loaded and 'OK' or 'NOT LOADED', entry.addon))
    end

    if #report.dep_issues > 0 then
        f:write('\nDependency Issues:\n')
        for _, issue in ipairs(report.dep_issues) do
            f:write(('  %s requires %s (not loaded)\n'):format(issue.addon, issue.missing_dep))
        end
    end

    if #report.file_issues > 0 then
        f:write('\nFile Issues:\n')
        for _, issue in ipairs(report.file_issues) do
            f:write(('  %s: %s\n'):format(issue.label, issue.status))
        end
    end

    f:write(('\nTotal issues: %d\n'):format(#report.dep_issues + #report.file_issues))
    f:close()
    msg('Report exported: ' .. path)
end

local function watch_tick()
    if not state.watchEnabled then return end
    if now() - state.lastCheck < state.watchInterval then return end
    local report = run_diagnostics()
    local total_issues = #report.dep_issues + #report.file_issues
    if total_issues > 0 then
        msg(('[watch] %d issue(s) detected'):format(total_issues))
    end
end

windower.register_event('prerender', watch_tick)

windower.register_event('addon command', function(...)
    local args = {...}
    local cmd = (args[1] or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')

    if cmd == '' or cmd == 'help' then
        msg('Commands: check | watch on|off [interval] | export | status')
        return
    end

    if cmd == 'check' or cmd == 'run' then
        local report = run_diagnostics()
        display_report(report)
        return
    end

    if cmd == 'watch' then
        local flag = (args[2] or ''):lower()
        if flag == 'on' then
            state.watchEnabled = true
            local interval = tonumber(args[3])
            if interval and interval >= 10 then state.watchInterval = interval end
            msg(('Watch enabled (interval=%ds)'):format(state.watchInterval))
        elseif flag == 'off' then
            state.watchEnabled = false
            msg('Watch disabled.')
        else
            msg(('Watch: %s (interval=%ds)'):format(state.watchEnabled and 'on' or 'off', state.watchInterval))
        end
        return
    end

    if cmd == 'export' then
        local report = state.lastReport or run_diagnostics()
        export_report(report)
        return
    end

    if cmd == 'status' then
        if state.lastReport then
            display_report(state.lastReport)
        else
            msg('No report yet. Run //addonhealth check first.')
        end
        return
    end

    msg(('Unknown command "%s". Try //addonhealth help'):format(cmd))
end)
