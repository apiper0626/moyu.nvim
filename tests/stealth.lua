vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd('runtime plugin/moyu.lua')
local reader = require('moyu')
local stealth = require('moyu.stealth')
reader.setup({ stealth = { lines = 2, keys_per_step = 3 } })
local dir = vim.fn.stdpath('data') .. '/fixtures'
vim.fn.mkdir(dir, 'p')
local path = dir .. '/stealth.txt'
vim.fn.writefile({ '第一段中文。', '第二段中文。', '第三段中文。', '第四段中文。', '最后一段。' }, path)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local answer = 42', 'return answer' })
vim.bo.commentstring = '-- %s'
local buffer, window = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
local original = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
local modified = vim.bo.modified
local called = false
local navigation_conflicts = 0
local navigation_keys = { 'j', 'k', '<Up>', '<Down>', '<C-u>', '<C-d>', '<C-b>', '<C-f>', '<PageUp>', '<PageDown>', '<ScrollWheelUp>', '<ScrollWheelDown>' }
for _, key in ipairs(navigation_keys) do
  vim.keymap.set('n', key, function() navigation_conflicts = navigation_conflicts + 1 end)
end
vim.keymap.set('n', 'k', function() navigation_conflicts = navigation_conflicts + 1 end, { buffer = buffer })
vim.keymap.set('n', 'x', function() called = true end, { buffer = buffer, desc = 'original mapping' })
vim.keymap.set('n', 'zz', 'gg', { buffer = buffer, silent = true })
local function text()
  local ns = vim.api.nvim_get_namespaces()['moyu.stealth']
  local marks = vim.api.nvim_buf_get_extmarks(buffer, ns, 0, -1, { details = true })
  return marks[1] and marks[1][4].virt_lines[1][1][1], #marks
end
local function press(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'xt', false)
end
-- Command/picker callbacks may report a transient mode before returning to Normal.
local get_mode = vim.api.nvim_get_mode
vim.api.nvim_get_mode = function() return { mode = 'c', blocking = false } end
reader.stealth(path)
vim.api.nvim_get_mode = get_mode
assert(stealth.active())
assert(vim.api.nvim_get_current_win() == window)
assert(#vim.api.nvim_list_wins() == 1)
assert(text() == '-- 第一段中文。')
for _, pair in ipairs({ { 'j', 'k' }, { '<Down>', '<Up>' }, { '<C-d>', '<C-u>' },
  { '<C-f>', '<C-b>' }, { '<PageDown>', '<PageUp>' }, { '<ScrollWheelDown>', '<ScrollWheelUp>' } }) do
  press(pair[1])
  assert(text() == '-- 第三段中文。', pair[1] .. ' must advance')
  press(pair[2])
  assert(text() == '-- 第一段中文。', pair[2] .. ' must go back')
end
assert(navigation_conflicts == 0, 'reading keys must override existing mappings')
press('ab')
assert(text() == '-- 第一段中文。')
press('x')
assert(text() == '-- 第三段中文。' and not called)
press('<BS>')
assert(text() == '-- 第一段中文。')
press('<Right>')
assert(text() == '-- 第三段中文。')
press('<Esc>')
assert(not stealth.active())
local _, count = text()
assert(count == 0 and vim.bo.modifiable)
assert(vim.deep_equal(original, vim.api.nvim_buf_get_lines(buffer, 0, -1, false)))
assert(vim.bo.modified == modified)
press('x')
assert(called)
assert(vim.fn.maparg('zz', 'n', false, true).rhs == 'gg')
press('jk')
assert(navigation_conflicts == 2, 'original global and buffer mappings must work after hiding')
reader.stealth()
assert(text() == '-- 第三段中文。')
press('k')
assert(text() == '-- 第一段中文。', 'must go back immediately after resume')
press('j')
vim.cmd('vsplit')
assert(not stealth.active(), 'switching windows must hide reading')
vim.cmd('close')
reader.stealth()
vim.api.nvim_exec_autocmds('FocusLost', {})
assert(not stealth.active())
reader.stealth()
reader.open(path)
assert(not stealth.active(), 'floating reader must close stealth mode')
reader.close()
local notify, warning = vim.notify, nil
vim.notify = function(message) warning = message end
vim.bo.buftype = 'nofile'
reader.stealth(path)
assert(not stealth.active() and warning:find('nofile', 1, true))
vim.bo.buftype = ''
vim.notify = notify
-- Long Chinese paragraphs must wrap at character boundaries and persist offsets.
local long_path = dir .. '/long.txt'
vim.fn.writefile({ string.rep('天地玄黄宇宙洪荒', 100) }, long_path)
reader.stealth(long_path)
local first_page = text()
press('<Right>')
local state_path = vim.fn.stdpath('data') .. '/moyu/progress.json'
local saved = vim.json.decode(table.concat(vim.fn.readfile(state_path), '\n'))
local offset = saved.books[long_path].stealth.char
assert(offset > 0 and saved.books[long_path].stealth.line == 1)
press('<BS>')
assert(text() == first_page)
press('<Right>')
reader.close()
reader.stealth(long_path)
press('k')
assert(text() == first_page, 'wrapped paragraph must support reverse navigation after resume')
press('j')
reader.close()
print('PASS: 注释阅读、按键推进、回退、映射恢复、代码保护、自动隐藏与续读')
vim.cmd('qa!')
