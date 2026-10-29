vim.opt.rtp:prepend(vim.fn.getcwd())
local reader = require('moyu')
local code = {}
for index = 1, 100 do code[index] = 'local value = ' .. index end
vim.api.nvim_buf_set_lines(0, 0, -1, false, code)
local directory = vim.fn.stdpath('data')
vim.fn.mkdir(directory, 'p')
local path = directory .. '/lines.txt'
local lines = {}
for index = 1, 100 do lines[index] = '段落 ' .. index end
vim.fn.writefile(lines, path)
local original_calls = 0
vim.keymap.set('n', '=', function() original_calls = original_calls + 1 end, { buffer = 0 })
local function press(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'xt', false)
end
local function saved()
  return vim.json.decode(table.concat(vim.fn.readfile(directory .. '/moyu/progress.json'), '\n'))
end
local function rows()
  local ns = vim.api.nvim_get_namespaces()['moyu.stealth']
  return #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
end
reader.stealth(path)
local position = saved().books[path].stealth
press('=+')
assert(rows() == 6 and saved().settings.lines == 6)
assert(original_calls == 0 and vim.deep_equal(saved().books[path].stealth, position))
press('-')
assert(rows() == 5)
press('j')
assert(saved().books[path].line == 6, 'advance must follow adjusted segment size')
for _ = 1, 12 do press('-') end
assert(rows() == 1 and saved().settings.lines == 1)
press('==')
reader.close()
press('=')
assert(original_calls == 1)
reader.toggle()
assert(rows() == 3)
reader.close()
print('PASS: 动态增减、最小值、位置保持、连续翻段、映射恢复与设置保存')
vim.cmd('qa!')
