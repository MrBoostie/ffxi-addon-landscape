local common = {}

function common.normalize(s)
    return (s or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
end

function common.normalize_command(raw)
    return (raw or ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('^//', '')
end

function common.join(tbl, sep, start_idx)
    local s = {}
    for i = start_idx or 1, #tbl do s[#s+1] = tbl[i] end
    return table.concat(s, sep or ' ')
end

function common.copy_table(t)
    local out = {}
    for k, v in pairs(t or {}) do
        if type(v) == 'table' then out[k] = common.copy_table(v) else out[k] = v end
    end
    return out
end

function common.safe_load(path)
    local ok, chunk = pcall(dofile, path)
    if ok and type(chunk) == 'table' then return chunk end
    return nil
end

function common.serialize_value(v, indent)
    indent = indent or ''
    if type(v) == 'string' then return string.format('%q', v) end
    if type(v) == 'number' or type(v) == 'boolean' then return tostring(v) end
    if type(v) == 'table' then
        local next_indent = indent .. '  '
        local lines = {'{'}
        for k, vv in pairs(v) do
            local key = (type(k) == 'string' and k:match('^[%a_][%w_]*$')) and k or ('[' .. common.serialize_value(k) .. ']')
            lines[#lines+1] = next_indent .. key .. ' = ' .. common.serialize_value(vv, next_indent) .. ','
        end
        lines[#lines+1] = indent .. '}'
        return table.concat(lines, '\n')
    end
    return 'nil'
end

function common.write_table_file(path, t)
    local f = io.open(path, 'w')
    if not f then return false end
    f:write('return ', common.serialize_value(t), '\n')
    f:close()
    return true
end

function common.enc(s)
    return tostring(s or ''):gsub('([^%w%-_%.~ ])', function(c) return string.format('%%%02X', string.byte(c)) end):gsub(' ', '+')
end

function common.dec(s)
    s = (s or ''):gsub('+', ' ')
    return s:gsub('%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
end

function common.pack(prefix, t)
    local parts = {}
    for k, v in pairs(t or {}) do parts[#parts+1] = common.enc(k) .. '=' .. common.enc(v) end
    return prefix .. '|' .. table.concat(parts, '&')
end

function common.unpack_payload(s)
    local out = {}
    for pair in (s or ''):gmatch('([^&]+)') do
        local k, v = pair:match('([^=]+)=(.*)')
        if k then out[common.dec(k)] = common.dec(v or '') end
    end
    return out
end

function common.valid_name(name)
    return type(name) == 'string' and name:match('^[A-Za-z][A-Za-z0-9_%-]+$') ~= nil
end

function common.get_field(obj, path)
    if not obj or not path then return nil end
    local cur = obj
    for part in tostring(path):gmatch('[^%.]+') do
        if type(cur) ~= 'table' then return nil end
        cur = cur[part]
    end
    return cur
end

function common.compare(op, left, right)
    if op == '==' then return left == right end
    if op == '!=' then return left ~= right end
    if op == '>' then return tonumber(left) and tonumber(right) and tonumber(left) > tonumber(right) end
    if op == '>=' then return tonumber(left) and tonumber(right) and tonumber(left) >= tonumber(right) end
    if op == '<' then return tonumber(left) and tonumber(right) and tonumber(left) < tonumber(right) end
    if op == '<=' then return tonumber(left) and tonumber(right) and tonumber(left) <= tonumber(right) end
    if op == 'contains' then return tostring(left or ''):find(tostring(right or ''), 1, true) ~= nil end
    if op == 'not_contains' then return tostring(left or ''):find(tostring(right or ''), 1, true) == nil end
    if op == 'matches' then return tostring(left or ''):match(tostring(right or '')) ~= nil end
    if op == 'in' and type(right) == 'table' then
        for _, v in ipairs(right) do if left == v then return true end end
        return false
    end
    if op == 'not_in' and type(right) == 'table' then
        for _, v in ipairs(right) do if left == v then return false end end
        return true
    end
    return false
end

local VALID_OPS = {
    ['=='] = true, ['!='] = true, ['>'] = true, ['>='] = true,
    ['<'] = true, ['<='] = true, ['contains'] = true, ['not_contains'] = true,
    ['matches'] = true, ['in'] = true, ['not_in'] = true,
}

local VALID_ACTION_KINDS = {
    ['mode.set'] = true, ['broadcast.travel'] = true, ['broadcast.command'] = true,
    ['roster.target_set'] = true, ['notify'] = true, ['rule.disable'] = true,
}

function common.validate_rule(rule)
    local errors = {}
    if type(rule) ~= 'table' then return {'rule is not a table'} end
    if type(rule.id) ~= 'string' or rule.id == '' then
        errors[#errors+1] = 'rule missing id'
    end
    if rule.priority ~= nil and type(rule.priority) ~= 'number' then
        errors[#errors+1] = ('rule %s: priority must be a number'):format(rule.id or '?')
    end
    if rule.cooldown_sec ~= nil and (type(rule.cooldown_sec) ~= 'number' or rule.cooldown_sec < 0) then
        errors[#errors+1] = ('rule %s: cooldown_sec must be a non-negative number'):format(rule.id or '?')
    end
    if rule.when then
        if type(rule.when) ~= 'table' then
            errors[#errors+1] = ('rule %s: when must be a table'):format(rule.id or '?')
        else
            if rule.when.where then
                if type(rule.when.where) ~= 'table' then
                    errors[#errors+1] = ('rule %s: when.where must be a table'):format(rule.id or '?')
                else
                    for j, cond in ipairs(rule.when.where) do
                        if type(cond) ~= 'table' then
                            errors[#errors+1] = ('rule %s: where[%d] not a table'):format(rule.id or '?', j)
                        elseif not cond.field then
                            errors[#errors+1] = ('rule %s: where[%d] missing field'):format(rule.id or '?', j)
                        elseif not cond.op or not VALID_OPS[cond.op] then
                            errors[#errors+1] = ('rule %s: where[%d] invalid op "%s"'):format(rule.id or '?', j, tostring(cond.op))
                        end
                    end
                end
            end
        end
    end
    if rule.then_actions then
        if type(rule.then_actions) ~= 'table' then
            errors[#errors+1] = ('rule %s: then_actions must be a table'):format(rule.id or '?')
        else
            for j, action in ipairs(rule.then_actions) do
                if type(action) ~= 'table' then
                    errors[#errors+1] = ('rule %s: action[%d] not a table'):format(rule.id or '?', j)
                elseif not action.kind or not VALID_ACTION_KINDS[action.kind] then
                    errors[#errors+1] = ('rule %s: action[%d] invalid kind "%s"'):format(rule.id or '?', j, tostring(action.kind))
                end
            end
        end
    end
    return errors
end

function common.validate_route(dest, route)
    local errors = {}
    if type(route) ~= 'table' then
        return {('route "%s" is not a table'):format(dest)}
    end
    local candidates = route.candidates
    if not candidates then
        if route[1] and type(route[1]) == 'string' then
            return errors
        end
        if route.steps then
            candidates = { route }
        else
            errors[#errors+1] = ('route "%s": no candidates or steps found'):format(dest)
            return errors
        end
    end
    for i, c in ipairs(candidates) do
        if type(c) ~= 'table' then
            errors[#errors+1] = ('route "%s" candidate[%d]: not a table'):format(dest, i)
        else
            if not c.steps or type(c.steps) ~= 'table' or #c.steps == 0 then
                errors[#errors+1] = ('route "%s" candidate "%s": empty or missing steps'):format(dest, c.name or i)
            else
                for j, step in ipairs(c.steps) do
                    if type(step) ~= 'string' or step == '' then
                        errors[#errors+1] = ('route "%s" candidate "%s" step[%d]: invalid'):format(dest, c.name or i, j)
                    end
                end
            end
        end
    end
    return errors
end

return common
