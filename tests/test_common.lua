package.path = '../libs/?.lua;' .. package.path

local common = require('common')

local pass, fail, total = 0, 0, 0

local function check(label, cond)
    total = total + 1
    if cond then
        pass = pass + 1
    else
        fail = fail + 1
        io.stderr:write(('FAIL: %s\n'):format(label))
    end
end

-- normalize
check('normalize lowercases', common.normalize('HELLO') == 'hello')
check('normalize trims', common.normalize('  foo  ') == 'foo')
check('normalize nil safe', common.normalize(nil) == '')

-- normalize_command
check('normalize_command strips //', common.normalize_command('//send') == 'send')
check('normalize_command trims', common.normalize_command('  input /ma  ') == 'input /ma')

-- join
check('join default', common.join({'a','b','c'}) == 'a b c')
check('join from 2', common.join({'a','b','c'}, ' ', 2) == 'b c')
check('join custom sep', common.join({'a','b'}, ',') == 'a,b')

-- copy_table
local orig = {x = 1, sub = {y = 2}}
local c = common.copy_table(orig)
check('copy_table deep', c.sub.y == 2)
c.sub.y = 99
check('copy_table independent', orig.sub.y == 2)

-- serialize_value
check('serialize string', common.serialize_value('hi') == '"hi"')
check('serialize number', common.serialize_value(42) == '42')
check('serialize bool', common.serialize_value(true) == 'true')
check('serialize nil', common.serialize_value(nil) == 'nil')

-- enc/dec roundtrip
local encoded = common.enc('hello world!')
local decoded = common.dec(encoded)
check('enc/dec roundtrip', decoded == 'hello world!')

-- pack/unpack roundtrip
local packed = common.pack('TEST', {op = 'run', dest = 'jeuno'})
check('pack has prefix', packed:sub(1,5) == 'TEST|')
local _, payload = packed:match('^(TEST)|(.*)')
local unpacked = common.unpack_payload(payload)
check('unpack op', unpacked.op == 'run')
check('unpack dest', unpacked.dest == 'jeuno')

-- valid_name
check('valid_name ok', common.valid_name('Alice') == true)
check('valid_name with dash', common.valid_name('Alt-Char') == true)
check('valid_name numeric start', common.valid_name('1abc') == false)
check('valid_name nil', common.valid_name(nil) == false)
check('valid_name empty', common.valid_name('') == false)

-- get_field
local obj = {payload = {hp_pct = 25}, party = {size = 3}}
check('get_field simple', common.get_field(obj, 'payload.hp_pct') == 25)
check('get_field nested', common.get_field(obj, 'party.size') == 3)
check('get_field missing', common.get_field(obj, 'payload.missing') == nil)
check('get_field nil obj', common.get_field(nil, 'x') == nil)

-- compare
check('compare ==', common.compare('==', 'a', 'a') == true)
check('compare !=', common.compare('!=', 'a', 'b') == true)
check('compare >', common.compare('>', 10, 5) == true)
check('compare <=', common.compare('<=', 5, 5) == true)
check('compare contains', common.compare('contains', 'hello world', 'world') == true)
check('compare not_contains', common.compare('not_contains', 'hello', 'xyz') == true)
check('compare matches', common.compare('matches', 'abc123', '%d+') == true)
check('compare in', common.compare('in', 'b', {'a','b','c'}) == true)
check('compare not_in', common.compare('not_in', 'z', {'a','b'}) == true)

-- validate_rule
local good_rule = {
    id = 'test.rule', enabled = true, priority = 50, cooldown_sec = 5,
    when = { event = 'party.member.hp_low', where = {{ field = 'payload.hp_pct', op = '<=', value = 40 }} },
    then_actions = {{ kind = 'notify', text = 'Low HP' }},
}
check('validate_rule good', #common.validate_rule(good_rule) == 0)

local bad_rule = {
    id = 'bad.rule', priority = 'high',
    when = { where = {{ field = 'x', op = 'BOGUS' }} },
    then_actions = {{ kind = 'explode' }},
}
local errs = common.validate_rule(bad_rule)
check('validate_rule catches errors', #errs >= 2)

check('validate_rule no id', #common.validate_rule({}) > 0)

-- validate_route
local good_route = {
    candidates = {{ name = 'direct', score = 10, steps = {'say:go', 'cmd:warp'} }}
}
check('validate_route good', #common.validate_route('jeuno', good_route) == 0)

local bad_route = {
    candidates = {{ name = 'broken', steps = {} }}
}
check('validate_route empty steps', #common.validate_route('bad', bad_route) > 0)
check('validate_route not table', #common.validate_route('x', 'string') > 0)

-- simple list route
check('validate_route simple list', #common.validate_route('x', {'say:go', 'cmd:warp'}) == 0)

print(('\n%d/%d tests passed, %d failed'):format(pass, total, fail))
os.exit(fail > 0 and 1 or 0)
