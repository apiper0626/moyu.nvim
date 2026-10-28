local M = {}
local ns = vim.api.nvim_create_namespace('moyu.stealth')
local session

local function position(value)
  return { line = value.line, char = value.char }
end

-- Read a small page without changing the source text or splitting UTF-8 bytes.
local function page(s, limit)
  local cursor = position(s.pos)
  local rows = {}
  local info = vim.fn.getwininfo(s.win)[1]
  local width = math.max(1, vim.api.nvim_win_get_width(s.win) - (info and info.textoff or 0) - 6)
  local prefix, suffix = s.comment:match('^(.-)%%s(.*)$')
  prefix, suffix = prefix or '// ', suffix or ''
  width = math.max(1, width - vim.fn.strdisplaywidth(prefix .. suffix))
  for _ = 1, limit or s.page_lines or s.options.lines do
    if cursor.line > #s.lines then break end
    local text, cells = '', 0
    local line = s.lines[cursor.line]
    local length = vim.fn.strchars(line)
    while cursor.char < length do
      local char = vim.fn.strcharpart(line, cursor.char, 1)
      local size = vim.fn.strdisplaywidth(char, cells)
      if cells + size > width and text ~= '' then break end
      text, cells = text .. char, cells + size
      cursor.char = cursor.char + 1
    end
    rows[#rows + 1] = { { prefix .. text .. suffix, 'Comment' } }
    if cursor.char >= length then cursor.line, cursor.char = cursor.line + 1, 0 end
  end
  return rows, cursor
end

local function draw()
  local s = session
  if not s or not vim.api.nvim_buf_is_valid(s.buf) or not vim.api.nvim_win_is_valid(s.win) then return end
  vim.api.nvim_buf_clear_namespace(s.buf, ns, 0, -1)
  s.anchor = vim.api.nvim_win_get_cursor(s.win)[1] - 1
  local cursor_row = vim.api.nvim_win_call(s.win, function() return vim.fn.winline() end)
  local height = vim.api.nvim_win_get_height(s.win)
  local below, above = math.max(0, height - cursor_row), math.max(0, cursor_row - 1)
  s.above = below < s.options.lines and above > below
  s.page_lines = math.max(1, math.min(s.options.lines, s.above and above or below))
  local rows, next_pos = page(s)
  s.next_pos = next_pos
  s.rendered_lines = #rows
  vim.api.nvim_buf_set_extmark(s.buf, ns, s.anchor, 0, {
    virt_lines = rows, virt_lines_above = s.above,
  })
end

function M.active() return session ~= nil end

function M.adjust_lines(delta)
  local s = session
  if not s then return end
  local value = math.max(1, s.options.lines + delta)
  s.options.lines, s.presses = value, 0
  draw()
  if s.actions.lines_changed then s.actions.lines_changed(value) end
  vim.api.nvim_echo({ { '阅读行数：' .. value .. '（当前显示 ' .. s.rendered_lines .. ' 行）', 'Comment' } }, false, {})
  return value
end

function M.close()
  local s = session
  if not s then return end
  session = nil
  vim.api.nvim_del_augroup_by_id(s.group)
  if s.restore_status then s.restore_status() end
  if vim.api.nvim_buf_is_valid(s.buf) then
    vim.api.nvim_buf_clear_namespace(s.buf, ns, 0, -1)
    for _, lhs in ipairs(s.keys) do pcall(vim.keymap.del, 'n', lhs, { buffer = s.buf }) end
    for _, map in ipairs(s.maps) do
      vim.keymap.set('n', map.lhs, map.callback or map.rhs, {
        buffer = s.buf, remap = map.noremap == 0, silent = map.silent == 1,
        expr = map.expr == 1, nowait = map.nowait == 1, desc = map.desc,
        script = map.script == 1,
      })
    end
    vim.bo[s.buf].modifiable = s.modifiable
  end
  s.persist(position(s.pos))
  vim.api.nvim_exec_autocmds('User', { pattern = 'MoyuModeChanged', data = { active = false, buffer = s.buf } })
end

function M.next()
  local s = session
  if s then s.presses = 0 end
  if not s or s.next_pos.line > #s.lines then return end
  s.history[#s.history + 1] = position(s.pos)
  s.pos = position(s.next_pos)
  draw()
  s.persist(position(s.pos))
end

function M.previous()
  local s = session
  if not s then return end
  s.presses = 0
  if #s.history > 0 then
    s.pos = table.remove(s.history)
  else
    -- Resume has no in-memory history. Reconstruct the preceding display rows
    -- from nearby source lines, including wrapped paragraphs.
    local count = s.page_lines or s.options.lines
    local cursor = { line = math.max(1, s.pos.line - count), char = 0 }
    local starts = {}
    while cursor.line < s.pos.line or (cursor.line == s.pos.line and cursor.char < s.pos.char) do
      starts[#starts + 1] = position(cursor)
      if #starts > count then table.remove(starts, 1) end
      local _, next_pos = page(setmetatable({ pos = cursor }, { __index = s }), 1)
      cursor = next_pos
    end
    if #starts == 0 then return end
    s.pos = starts[1]
  end
  draw()
  s.persist(position(s.pos))
end

function M.open(lines, pos, options, persist, actions)
  M.close()
  local buffer, window = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  if vim.bo[buffer].buftype ~= '' then
    vim.notify('当前是特殊缓冲区（' .. vim.bo[buffer].buftype
      .. '），请先打开任意代码文件，再执行 :MoyuStealth', vim.log.levels.WARN)
    return false
  end
  -- Commands and picker callbacks can still report Command-line/Terminal mode.
  -- Normal mappings become active as soon as control returns to the editor.
  vim.cmd('stopinsert')
  local line = math.max(1, math.min(#lines, tonumber(pos.line) or 1))
  local char = math.max(0, math.min(vim.fn.strchars(lines[line] or ''), tonumber(pos.char) or 0))
  local s = { buf = buffer, win = window, lines = lines, pos = { line = line, char = char },
    options = options, persist = persist, keys = {}, maps = vim.api.nvim_buf_get_keymap(buffer, 'n'),
    modifiable = vim.bo[buffer].modifiable, comment = vim.bo[buffer].commentstring,
    anchor = vim.api.nvim_win_get_cursor(window)[1] - 1, history = {}, presses = 0, actions = actions or {} }
  session = s
  for _, map in ipairs(s.maps) do vim.keymap.del('n', map.lhs, { buffer = buffer }) end
  vim.bo[buffer].modifiable = false
  local function bind(key, callback, nowait)
    s.keys[#s.keys + 1] = key
    vim.keymap.set('n', key, callback, { buffer = buffer, nowait = nowait ~= false, silent = true })
  end
  local function type_key()
    s.presses = s.presses + 1
    if s.presses >= options.keys_per_step then s.presses = 0; M.next() end
  end
  for code = 32, 126 do
    local key = string.char(code)
    bind(key == '<' and '<lt>' or key, type_key, key ~= (vim.g.mapleader or '\\'))
  end
  for code = 1, 26 do
    local key = '<C-' .. string.char(96 + code) .. '>'
    bind(key, function() end)
  end
  for _, key in ipairs({ '<Esc>', '<C-c>', '<C-[>' }) do bind(key, M.close) end
  for _, key in ipairs({ 'k', '<BS>', '<Left>', '<Up>', '<PageUp>', '<C-b>', '<C-u>', '<ScrollWheelUp>' }) do
    bind(key, M.previous)
  end
  for _, key in ipairs({ 'j', '<CR>', '<Tab>', '<Right>', '<Down>', '<PageDown>', '<C-f>', '<C-d>', '<ScrollWheelDown>' }) do
    bind(key, M.next)
  end
  for _, key in ipairs({ '+', '=', '<kPlus>' }) do bind(key, function() M.adjust_lines(1) end) end
  for _, key in ipairs({ '-', '<kMinus>' }) do bind(key, function() M.adjust_lines(-1) end) end
  if actions and actions.history then bind('<F2>', actions.history) end
  bind('<leader>my', M.close)
  s.group = vim.api.nvim_create_augroup('MoyuStealthSession', { clear = true })
  vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave', 'BufWipeout', 'InsertEnter', 'CmdlineEnter' }, {
    group = s.group, buffer = buffer, callback = M.close,
  })
  vim.api.nvim_create_autocmd({ 'FocusLost', 'VimLeavePre' }, { group = s.group, callback = M.close })
  vim.api.nvim_create_autocmd('VimResized', { group = s.group, callback = draw })
  s.restore_status = require('moyu.status').attach(window, s.group)
  draw()
  persist(position(s.pos))
  vim.api.nvim_exec_autocmds('User', { pattern = 'MoyuModeChanged', data = { active = true, buffer = buffer } })
  return true
end

return M
