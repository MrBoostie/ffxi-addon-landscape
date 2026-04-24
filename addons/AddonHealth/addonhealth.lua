_addon.name = 'AddonHealth'
_addon.author = 'odin'
_addon.version = '0.2.0'
_addon.commands = {'addonhealth', 'ahealth'}
_addon.description = 'Unified health dashboard for Windower addon stack status and diagnostics.'

local REPORT_DIR = (windower.addon_path or '') .. 'data/'
local WATCH_EVENT_ID = nil

local DEFAULT_KNOWN_ADDONS = {
    { name = 'TravelRouter', critical = true, deps = {} },
    { name = 'SessionConductor', critical = true, deps = { 'TravelRouter' } },
    { name = 'GearSwap', critical = false, deps = {} },
    { name = 'Shortcuts', critical = false, deps = {} },
    { name = 'DressUp', critical = false, deps = {} },
    { name = 'FastCS', critical = false, deps = {} },
    { name = 'Treasury', critical = false, deps = {} },
    { name = 'Config', critical = false, deps = {} },
    { name = 'Cancel', critical = false, deps = {} },
    { name = 'Enternity', critical = false, deps = {} },
}

local USER_ADDONS_FILE = (windower.addon_path or '') .. 'data/addons.user.lua'

local FILE_CHECKS = {
    { label = 'TravelRouter routes', path = '../TravelRouter/data/routes.lua', severity = 'ok' },
    { label = 'SessionConductor rules', path = '../SessionConductor/data/rules.default.lua', severity = 'ok' },
}

local state = {
    watchEnabled = false,
    watchInterval = 30,
    lastCheck = 0,
    lastReport = nil,
    catalogEntries = {},
}

local function msg(text)
    windower.add_to_chat(200, ('[AddonHealth] %s'):format(text))
end

local function now()
    return os.time()
end

local function normalize(s)
    return (s or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
end

local function basename(path)
    if type(path) ~= 'string' or path == '' then return nil end
    local trimmed = path:gsub('[\\/]+$', '')
    return trimmed:match('([^\\/]+)$')
end

local function file_exists(path)
    local f = io.open(path, 'r')
    if not f then return false end
    f:close()
    return true
end

local function addon_base_path()
    return (windower.addon_path or ''):gsub('[\\/]+$', '')
end

local function sanitize_addon_entry(entry)
    if type(entry) ~= 'table' or type(entry.name) ~= 'string' or entry.name == '' then
        return nil
    end
    local deps = {}
    if type(entry.deps) == 'table' then
        for _, dep in ipairs(entry.deps) do
            if type(dep) == 'string' and dep ~= '' then
                deps[#deps+1] = dep
            end
        end
    end
    return {
        name = entry.name,
        critical = entry.critical == true,
        deps = deps,
    }
end

local function load_user_addons()
    if not file_exists(USER_ADDONS_FILE) then return {} end

    local ok, payload = pcall(dofile, USER_ADDONS_FILE)
    if not ok then
        msg(('Failed to load %s: %s'):format(USER_ADDONS_FILE, tostring(payload)))
        return {}
    end
    if type(payload) ~= 'table' then
        msg(('Ignoring %s (expected table return)'):format(USER_ADDONS_FILE))
        return {}
    end

    local cleaned = {}
    for _, entry in ipairs(payload) do
        local item = sanitize_addon_entry(entry)
        if item then cleaned[#cleaned+1] = item end
    end
    return cleaned
end

local function rebuild_catalog_entries()
    local merged = {}
    local by_key = {}

    for _, entry in ipairs(DEFAULT_KNOWN_ADDONS) do
        local item = sanitize_addon_entry(entry)
        if item then
            local key = normalize(item.name)
            by_key[key] = #merged + 1
            merged[#merged+1] = item
        end
    end

    for _, entry in ipairs(load_user_addons()) do
        local key = normalize(entry.name)
        local idx = by_key[key]
        if idx then
            merged[idx] = entry
        else
            by_key[key] = #merged + 1
            merged[#merged+1] = entry
        end
    end

    table.sort(merged, function(a, b) return a.name < b.name end)
    state.catalogEntries = merged
end

local function build_catalog()
    local catalog = {}
    for _, entry in ipairs(state.catalogEntries) do
        catalog[normalize(entry.name)] = {
            name = entry.name,
            critical = entry.critical,
            deps = entry.deps or {},
        }
    end
    return catalog
end

local function get_loaded_addons()
    local loaded = {}
    if not windower.get_addons then return loaded end

    local addons = windower.get_addons() or {}
    for k, v in pairs(addons) do
        local names = {}
        local is_loaded = true

        if type(v) == 'string' then
            names[#names+1] = v
        elseif type(v) == 'table' then
            names[#names+1] = v.name
            names[#names+1] = v.addon
            names[#names+1] = v.short_name
            names[#names+1] = basename(v.path)
            if v.loaded == false then
                is_loaded = false
            end
        elseif type(k) == 'string' and v then
            names[#names+1] = k
        end

        for _, name in ipairs(names) do
            if type(name) == 'string' and name ~= '' then
                loaded[normalize(name)] = is_loaded
            end
        end
    end

    return loaded
end

local function coverage_summary(loaded, catalog)
    local known_loaded, unknown_loaded = {}, {}
    for name, is_loaded in pairs(loaded) do
        if is_loaded then
            if catalog[name] then
                known_loaded[#known_loaded+1] = catalog[name].name
            else
                unknown_loaded[#unknown_loaded+1] = name
            end
        end
    end
    table.sort(known_loaded)
    table.sort(unknown_loaded)
    return known_loaded, unknown_loaded
end

local function check_loaded(catalog, loaded)
    local results = {}
    for _, entry in ipairs(state.catalogEntries) do
        results[#results+1] = {
            addon = entry.name,
            loaded = loaded[normalize(entry.name)] or false,
            critical = entry.critical,
        }
    end
    table.sort(results, function(a, b) return a.addon < b.addon end)
    return results
end

local function check_dependencies(catalog, loaded)
    local issues = {}
    for _, entry in ipairs(state.catalogEntries) do
        if loaded[normalize(entry.name)] then
            for _, dep in ipairs(entry.deps or {}) do
                if not loaded[normalize(dep)] then
                    issues[#issues+1] = {
                        addon = entry.name,
                        missing_dep = dep,
                        severity = entry.critical and 'alert' or 'warn',
                    }
                end
            end
        end
    end
    return issues
end

local function check_files()
    local issues = {}
    local base = addon_base_path()
    for _, entry in ipairs(FILE_CHECKS) do
        local path = base .. '/' .. entry.path
        if not file_exists(path) then
            issues[#issues+1] = {
                label = entry.label,
                path = path,
                status = 'missing',
                severity = entry.severity or 'warn',
            }
        end
    end
    return issues
end

local function summarize_severity(report)
    local severity = 'ok'
    local counts = { alert = 0, warn = 0, ok = 0 }

    for _, entry in ipairs(report.loaded) do
        if entry.loaded then
            counts.ok = counts.ok + 1
        elseif entry.critical then
            counts.alert = counts.alert + 1
            severity = 'alert'
        else
            counts.warn = counts.warn + 1
            if severity ~= 'alert' then severity = 'warn' end
        end
    end

    for _, issue in ipairs(report.dep_issues) do
        counts[issue.severity] = (counts[issue.severity] or 0) + 1
        if issue.severity == 'alert' then
            severity = 'alert'
        elseif issue.severity == 'warn' and severity ~= 'alert' then
            severity = 'warn'
        end
    end

    for _, issue in ipairs(report.file_issues) do
        local s = issue.severity or 'warn'
        counts[s] = (counts[s] or 0) + 1
        if s == 'alert' then
            severity = 'alert'
        elseif s == 'warn' and severity ~= 'alert' then
            severity = 'warn'
        end
    end

    return severity, counts
end

local function run_diagnostics()
    local player = windower.ffxi.get_player() or {}
    local info = windower.ffxi.get_info() or {}
    local catalog = build_catalog()
    local loaded = get_loaded_addons()
    local known_loaded, unknown_loaded = coverage_summary(loaded, catalog)
    local report = {
        timestamp = now(),
        player = player.name or 'unknown',
        zone = info.zone or -1,
        loaded = check_loaded(catalog, loaded),
        dep_issues = check_dependencies(catalog, loaded),
        file_issues = check_files(),
        known_loaded = known_loaded,
        unknown_loaded = unknown_loaded,
    }
    report.severity, report.counts = summarize_severity(report)
    state.lastReport = report
    state.lastCheck = now()
    return report
end

local function display_report(report)
    msg(('--- Health Check @ %s ---'):format(os.date('%H:%M:%S', report.timestamp)))
    msg(('Player: %s | Zone: %d | Severity: %s'):format(report.player, report.zone, report.severity))
    msg(('Coverage: %d known loaded, %d unknown loaded'):format(#report.known_loaded, #report.unknown_loaded))

    msg('Addon Status:')
    for _, entry in ipairs(report.loaded) do
        local icon = entry.loaded and '+' or (entry.critical and '!' or '-')
        msg(('  [%s] %s'):format(icon, entry.addon))
    end

    if #report.unknown_loaded > 0 then
        msg('Unknown Loaded Addons: ' .. table.concat(report.unknown_loaded, ', '))
    end

    if #report.dep_issues > 0 then
        msg('Dependency Issues:')
        for _, issue in ipairs(report.dep_issues) do
            msg(('  [%s] %s requires %s'):format(issue.severity, issue.addon, issue.missing_dep))
        end
    end

    if #report.file_issues > 0 then
        msg('File Issues:')
        for _, issue in ipairs(report.file_issues) do
            msg(('  [%s] %s: %s (%s)'):format(issue.severity, issue.label, issue.status, issue.path))
        end
    end

    msg(('Summary: ok=%d warn=%d alert=%d'):format(report.counts.ok or 0, report.counts.warn or 0, report.counts.alert or 0))
    msg('---')
end

local function export_report(report)
    local filename = ('addonhealth-report-%s.txt'):format(os.date('%Y%m%d-%H%M%S', report.timestamp))
    local path = REPORT_DIR .. filename
    local f = io.open(path, 'w')
    if not f then
        msg('Failed to write report file: ' .. path)
        return false
    end

    f:write(('AddonHealth Report - %s\n'):format(os.date('%Y-%m-%d %H:%M:%S', report.timestamp)))
    f:write(('Player: %s | Zone: %d | Severity: %s\n'):format(report.player, report.zone, report.severity))
    f:write(('Coverage: %d known loaded, %d unknown loaded\n\n'):format(#report.known_loaded, #report.unknown_loaded))

    f:write('Addon Status:\n')
    for _, entry in ipairs(report.loaded) do
        local status = entry.loaded and 'OK' or (entry.critical and 'ALERT' or 'WARN')
        f:write(('  [%s] %s\n'):format(status, entry.addon))
    end

    if #report.unknown_loaded > 0 then
        f:write('\nUnknown Loaded Addons:\n')
        for _, name in ipairs(report.unknown_loaded) do
            f:write(('  %s\n'):format(name))
        end
    end

    if #report.dep_issues > 0 then
        f:write('\nDependency Issues:\n')
        for _, issue in ipairs(report.dep_issues) do
            f:write(('  [%s] %s requires %s\n'):format(issue.severity, issue.addon, issue.missing_dep))
        end
    end

    if #report.file_issues > 0 then
        f:write('\nFile Issues:\n')
        for _, issue in ipairs(report.file_issues) do
            f:write(('  [%s] %s: %s (%s)\n'):format(issue.severity, issue.label, issue.status, issue.path))
        end
    end

    f:write(('\nSummary: ok=%d warn=%d alert=%d\n'):format(report.counts.ok or 0, report.counts.warn or 0, report.counts.alert or 0))
    f:close()
    msg('Report exported: ' .. path)
    return true
end

local function ensure_watch_registered()
    if WATCH_EVENT_ID then return end
    WATCH_EVENT_ID = windower.register_event('prerender', function()
        if not state.watchEnabled then return end
        if now() - state.lastCheck < state.watchInterval then return end
        local report = run_diagnostics()
        if report.severity ~= 'ok' then
            msg(('[watch] severity=%s warn=%d alert=%d'):format(report.severity, report.counts.warn or 0, report.counts.alert or 0))
        end
    end)
end

local function disable_watch()
    state.watchEnabled = false
end

windower.register_event('load', function()
    rebuild_catalog_entries()
    ensure_watch_registered()
end)
windower.register_event('unload', function()
    disable_watch()
    if WATCH_EVENT_ID and windower.unregister_event then
        windower.unregister_event(WATCH_EVENT_ID)
        WATCH_EVENT_ID = nil
    end
end)
rebuild_catalog_entries()
ensure_watch_registered()

windower.register_event('addon command', function(...)
    local args = {...}
    local cmd = normalize(args[1] or '')

    if cmd == '' or cmd == 'help' then
        msg('Commands: check | watch on|off [interval] | export | status | summary | reload')
        return
    end

    if cmd == 'check' or cmd == 'run' then
        display_report(run_diagnostics())
        return
    end

    if cmd == 'export' then
        local report = state.lastReport or run_diagnostics()
        export_report(report)
        return
    end

    if cmd == 'status' or cmd == 'summary' then
        local report = state.lastReport or run_diagnostics()
        msg(('status=%s watch=%s interval=%ss known=%d unknown=%d monitored=%d'):format(
            report.severity,
            state.watchEnabled and 'on' or 'off',
            state.watchInterval,
            #report.known_loaded,
            #report.unknown_loaded,
            #state.catalogEntries
        ))
        return
    end

    if cmd == 'reload' then
        rebuild_catalog_entries()
        state.lastReport = nil
        msg(('catalog reloaded (%d monitored addons)'):format(#state.catalogEntries))
        return
    end

    if cmd == 'watch' then
        local mode = normalize(args[2] or '')
        local interval = tonumber(args[3] or '')
        if mode == 'on' then
            state.watchEnabled = true
            if interval and interval >= 5 then
                state.watchInterval = math.floor(interval)
            end
            ensure_watch_registered()
            msg(('watch enabled (%ss)'):format(state.watchInterval))
        elseif mode == 'off' then
            disable_watch()
            msg('watch disabled')
        else
            msg('Usage: //addonhealth watch on|off [interval>=5]')
        end
        return
    end

    msg('Unknown command. Use //addonhealth help')
end)
