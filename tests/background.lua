vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd('filetype plugin on')
vim.o.hidden = false
local reader = require('moyu')
local stealth = require('moyu.stealth')
local root = vim.fn.stdpath('data') .. '/project'
vim.fn.mkdir(root, 'p')
vim.fn.mkdir(root .. '/.git', 'p')
local code = {}
for index = 1, 100 do code[index] = 'local value = ' .. index end
local a, b, c = root .. '/a.lua', root .. '/b.lua', root .. '/c.py'
for _, path in ipairs({ a, b, c }) do vim.fn.writefile(code, path) end
vim.fn.writefile({ 'ignored' }, root .. '/notes.txt')
vim.fn.mkdir(root .. '/node_modules', 'p')
vim.fn.writefile(code, root .. '/node_modules/ignored.lua')
local book = root .. '/book.txt'
local paragraphs = {}
for index = 1, 100 do paragraphs[index] = '正文 ' .. index end
vim.fn.writefile(paragraphs, book)
vim.cmd('edit ' .. vim.fn.fnameescape(a))
local original = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(original, 0, 1, false, { 'local unsaved = true' })
vim.bo[original].bufhidden = 'wipe'
local loaded = vim.fn.bufadd(b)
vim.fn.bufload(loaded)
vim.bo[loaded].buflisted = true
vim.api.nvim_buf_set_lines(loaded, 0, 1, false, { 'local other_unsaved = true' })
vim.bo[loaded].modifiable = false
local called = 0
vim.keymap.set('n', '<F3>', function() called = called + 1 end, { buffer = loaded, desc = 'original F3' })
vim.api.nvim_win_set_cursor(0, { 42, 4 })
vim.cmd('normal! zt')
vim.cmd('redraw')
local view, alternate = vim.fn.winsaveview(), vim.fn.bufnr('#')
local function press(key)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), 'xt', false)
end
local function saved_line()
  local state = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath('data') .. '/moyu/progress.json'), '\n'))
  return state.books[book].line
end
reader.stealth(book)
press('j')
assert(reader.is_active() and vim.api.nvim_get_current_buf() == loaded, 'next page must switch code files without closing Moyu Mode')
assert(saved_line() == 5 and vim.bo[original].modifiable, 'progress should advance and the old buffer should be released')
press('<F3>')
assert(called == 0 and reader.is_active(), 'the new background must have temporary mode mappings')
press('j')
local temporary = vim.api.nvim_get_current_buf()
assert(vim.api.nvim_buf_get_name(temporary) == c and saved_line() == 9, 'discover nearby code files and keep book progress continuous')
assert(vim.bo[temporary].commentstring == '# %s', 'comments must follow the new background language')
assert(vim.bo[loaded].modifiable == false and vim.fn.maparg('<F3>', 'n', false, true).buffer == 1)
press('k')
assert(vim.api.nvim_get_current_buf() == temporary and saved_line() == 5, 'previous page must not rotate the background')
press('j')
assert(vim.api.nvim_get_current_buf() == original, 'rotation should cycle back to the original file')
press('j')
assert(vim.api.nvim_get_current_buf() == loaded)
press('j')
assert(vim.api.nvim_get_current_buf() == temporary, 'revisiting files must preserve mode mappings')
press('<Esc>')
assert(not reader.is_active() and vim.api.nvim_get_current_buf() == original)
vim.cmd('redraw')
assert(vim.deep_equal(view, vim.fn.winsaveview()), 'exit must restore the original cursor and viewport')
assert(vim.fn.bufnr('#') == alternate, 'switching must preserve the alternate buffer')
assert(vim.bo[original].bufhidden == 'wipe', 'temporary hiding must restore buffer options')
assert(vim.bo[original].modified and vim.bo[loaded].modified and not vim.bo[loaded].modifiable)
assert(vim.api.nvim_buf_get_lines(original, 0, 1, false)[1] == 'local unsaved = true')
assert(vim.api.nvim_buf_get_lines(loaded, 0, 1, false)[1] == 'local other_unsaved = true')
assert(vim.deep_equal(code, vim.fn.readfile(a)) and vim.deep_equal(code, vim.fn.readfile(b)), 'background rotation must never write source files')
assert(not vim.api.nvim_buf_is_valid(temporary), 'clean buffers loaded for disguise should be cleaned up')
local original_map = vim.api.nvim_buf_get_keymap(loaded, 'n')
assert(#original_map == 1 and original_map[1].desc == 'original F3', 'the target buffer mapping must be restored')
-- Configuration can disable rotation without changing reading or the layout key.
reader.setup({ stealth = { background = false } })
reader.stealth(book)
press('j')
assert(vim.api.nvim_get_current_buf() == original and reader.is_active())
reader.close()
-- Auto-hide must restore the initial file even after rotating to another buffer.
reader.setup({ stealth = { background = true } })
reader.stealth(book)
press('j')
assert(vim.api.nvim_get_current_buf() == loaded)
vim.api.nvim_exec_autocmds('FocusLost', {})
assert(not reader.is_active() and vim.api.nvim_get_current_buf() == original)
-- Reaching the end must not switch the background or advance the saved position.
stealth.open({ '最后一段' }, { line = 1, char = 0 }, { lines = 4, keys_per_step = 3 }, function() end)
press('j')
assert(vim.api.nvim_get_current_buf() == original)
stealth.close()
vim.fn.delete(b)
vim.fn.delete(c)
reader.stealth(book)
press('j')
assert(reader.is_active() and vim.api.nvim_get_current_buf() == original, 'missing candidates must leave reading active in the current file')
reader.close()
print('PASS: 翻段换代码、进度连续、跨文件快捷键、未保存代码保护、退出恢复与关闭配置')
vim.cmd('qa!')
