vim.opt.rtp:prepend(vim.fn.getcwd())
local reader = require('moyu')
local stealth = require('moyu.stealth')
reader.setup({ stealth = { layout = 'spread' } })
local directory = vim.fn.stdpath('data')
vim.fn.mkdir(directory, 'p')
local path = directory .. '/viewport.txt'
local lines = {}
for index = 1, 100 do lines[index] = '第 ' .. index .. ' 段' end
vim.fn.writefile(lines, path)
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
local ns = vim.api.nvim_create_namespace('moyu.stealth')
local function marks()
  return vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
end
local function rows()
  local out = {}
  for _, mark in ipairs(marks()) do
    for _, line in ipairs(mark[4].virt_lines or {}) do out[#out + 1] = line end
  end
  return out
end
local function saved_line()
  local state = vim.json.decode(table.concat(vim.fn.readfile(directory .. '/moyu/progress.json'), '\n'))
  return state.books[path].line
end
reader.stealth(path)
assert(#rows() == 4, 'default should display 4 lines')
assert(#marks() == 4, 'each reading row should sit on its own code line')
local anchors = {}
for index, mark in ipairs(marks()) do
  anchors[index] = mark[2]
  assert(#mark[4].virt_lines == 1, 'each anchor must contain only one comment')
  if index > 1 then assert(mark[2] - anchors[index - 1] >= 2, 'leave code between comments') end
end
stealth.next()
for index, mark in ipairs(marks()) do
  assert(mark[2] == anchors[index], 'page turns must keep comment anchors stable')
end
assert(saved_line() == 5, 'next segment must start after all visible rows')
reader.close()
vim.cmd('split')
vim.api.nvim_win_set_height(0, 5)
reader.stealth(path)
local visible = #rows()
assert(visible >= 1 and visible <= 4, 'small window should reduce visible rows')
local before = saved_line()
stealth.next()
assert(saved_line() == before + visible, 'reduced segment must not skip text')
vim.api.nvim_win_set_height(0, 3)
vim.api.nvim_exec_autocmds('VimResized', {})
assert(#rows() <= 2, 'resize must recompute available reading space')
reader.close()
-- A sparse code buffer must reduce the page rather than stack virtual rows.
vim.cmd('only')
vim.api.nvim_buf_set_lines(0, 0, -1, false, { '  local value = 1' })
reader.stealth(path)
assert(#marks() == 1 and #rows() == 1, 'one code line should have one comment')
local before_sparse = saved_line()
stealth.next()
assert(saved_line() == before_sparse + 1, 'sparse buffers must not skip book text')
reader.close()
-- Short comments wrap Chinese paragraphs without losing UTF-8 characters.
local saved
local paragraph = string.rep('天地玄黄宇宙洪荒', 20)
stealth.open({ paragraph }, { line = 1, char = 0 }, { lines = 4, keys_per_step = 3, layout = 'spread' }, function(pos) saved = pos end)
local text = rows()[1][1][1]
assert(vim.fn.strdisplaywidth(text) <= 42, 'comments should stay short, including indentation')
local first = text
stealth.next()
assert(saved.line == 1 and saved.char > 0, 'wrapped text must persist its character offset')
stealth.previous()
assert(rows()[1][1][1] == first, 'backtracking should restore the same short comment')
stealth.close()
print('PASS: 默认 4 行、小窗口自适应、缩放重排与连续翻段')
vim.cmd('qa!')
