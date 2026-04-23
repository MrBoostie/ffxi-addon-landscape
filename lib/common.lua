local common = {}

function common.normalize(s)
    return (s or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
end

function common.join(tbl, sep, start_idx)
    local s = {}
    for i = start_idx or 1, #tbl do s[#s+1] = tbl[i] end
    return table.concat(s, sep or ' ')
end

function common.serialize_value(v, indent)
    indent = indent or ''
    if type(v) == 'string' then return string.format('%q', v) end
    if type(v) == 'number' or type(v) == 'boolean' then return tostring(v) end
    if type(v) == 'table' then
        local n = indent .. '  '
        local lines = {'{'}
        for k, vv in pairs(v) do
            local key = (type(k) == 'string' and k:match('^[%a_][%w_]*$')) and k or ('[' .. common.serialize_value(k) .. ']')
            lines[#lines+1] = n .. key .. ' = ' .. common.serialize_value(vv, n) .. ','
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

function common.load_table(path)
    local ok, t = pcall(dofile, path)
    if ok and type(t) == 'table' then return t end
    return nil
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

function common.copy_table(t)
    local out = {}
    for k, v in pairs(t or {}) do
        if type(v) == 'table' then out[k] = common.copy_table(v) else out[k] = v end
    end
    return out
end

function common.self_name()
    local p = windower.ffxi.get_player()
    return (p and p.name) or 'unknown'
end

function common.now()
    return os.time()
end

return common
