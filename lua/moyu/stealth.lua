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
  if s.options.layout == 'spread' then width = math.min(40, width) end
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

-- Screen rows of the visible lines, so reading rows can sit between code rows.
local function visible(win)
  local first = vim.api.nvim_win_call(win, function() return vim.fn.line('w0') end)
  local last = vim.api.nvim_win_call(win, function() return vim.fn.line('w$') end)
  local top = vim.fn.screenpos(win, first, 1).row
  local map = {}
  if top == 0 then return map end
  for line = first, last do
    local row = vim.fn.screenpos(win, line, 1).row
    if row > 0 then map[#map + 1] = { line = line, row = row - top } end
  end
  return map
end

-- Choose stable, ordered anchors across the viewport before adding virtual rows.
-- Reserve screen space for both the reading rows and the original code.
local function draw()
  local s = session
  if not s or not vim.api.nvim_buf_is_valid(s.buf) or not vim.api.nvim_win_is_valid(s.win) then return end
  vim.api.nvim_buf_clear_namespace(s.buf, ns, 0, -1)
  vim.cmd('redraw')
  local height = vim.api.nvim_win_get_height(s.win)
  if s.options.layout ~= 'spread' then
    local cursor_row = vim.api.nvim_win_call(s.win, function() return vim.fn.winline() end)
    local below, above = math.max(0, height - cursor_row), math.max(0, cursor_row - 1)
    local use_above = below < s.options.lines and above > below
    s.page_lines = math.max(1, math.min(s.options.lines, use_above and above or below))
    local rows, next_pos = page(s)
    s.next_pos, s.rendered_lines = next_pos, #rows
    vim.api.nvim_buf_set_extmark(s.buf, ns, vim.api.nvim_win_get_cursor(s.win)[1] - 1, 0, {
      virt_lines = rows, virt_lines_above = use_above,
    })
    return
  end
  local map = visible(s.win)
  local count = math.max(1, math.min(s.options.lines, #map, math.floor((height + 1) / 3)))
  -- Only anchor in the part of the viewport that remains visible after insertion.
  local candidates = {}
  for _, item in ipairs(map) do
    if item.row < height - count then candidates[#candidates + 1] = item end
  end
  count = math.max(1, math.min(count, #candidates))
  s.page_lines = count
  local rows, next_pos = page(s)
  s.next_pos, s.rendered_lines = next_pos, #rows
  for index, row in ipairs(rows) do
    local slot = #rows == 1 and 1 or 1 + math.floor((index - 1) * (#candidates - 1) / (#rows - 1))
    local item = candidates[slot]
    local line = item and item.line or vim.api.nvim_win_get_cursor(s.win)[1]
    local code = vim.api.nvim_buf_get_lines(s.buf, line - 1, line, false)[1] or ''
    -- Keep the surrounding code's indentation without consuming excessive width.
    local indent = code:match('^%s*') or ''
    if vim.fn.strdisplaywidth(indent) > 8 then indent = '' end
    row[1][1] = indent .. row[1][1]
    vim.api.nvim_buf_set_extmark(s.buf, ns, line - 1, 0, {
      virt_lines = { row }, virt_lines_above = true,
    })
  end
end

function M.active() return session ~= nil end

function M.toggle_layout()
  local s = session
  if not s then return end
  local value = s.options.layout == 'spread' and 'block' or 'spread'
  s.options.layout, s.presses = value, 0
  draw()
  if s.actions.layout_changed then s.actions.layout_changed(value) end
  vim.api.nvim_echo({ { '阅读布局：' .. (value == 'spread' and '分散' or '集中'), 'Comment' } }, false, {})
  return value
end

function M.toggle_background_pin()
  local s = session
  if not s then return end
  if not s.background then
    vim.api.nvim_echo({ { '背景轮换已在配置中关闭', 'Comment' } }, false, {})
    return
  end
  s.pinned, s.presses = not s.pinned, 0
  local message = s.pinned and ('已固定背景：' .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(s.buf), ':t'))
    or '已取消固定，下一段恢复背景轮换'
  vim.api.nvim_echo({ { message, 'Comment' } }, false, {})
  return s.pinned
end

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

local function detach_buffer(s)
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
end

local function attach_buffer(s)
  local buffer = s.buf
  s.keys, s.maps = {}, vim.api.nvim_buf_get_keymap(s.buf, 'n')
  s.modifiable, s.comment = vim.bo[s.buf].modifiable, vim.bo[s.buf].commentstring
  for _, map in ipairs(s.maps) do vim.keymap.del('n', map.lhs, { buffer = buffer }) end
  vim.bo[buffer].modifiable = false
  local function bind(key, callback, nowait)
    s.keys[#s.keys + 1] = key
    vim.keymap.set('n', key, callback, { buffer = buffer, nowait = nowait ~= false, silent = true })
  end
  local function type_key()
    s.presses = s.presses + 1
    if s.presses >= s.options.keys_per_step then s.presses = 0; M.next() end
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
  if s.actions.history then bind('<F2>', s.actions.history) end
  bind('<F3>', M.toggle_layout)
  bind('<leader>mp', M.toggle_background_pin)
  bind('<leader>my', M.close)
end

local function change_background(s)
  if not s.background or s.pinned then return end
  s.switching = true
  local ok, buffer = pcall(s.background.next, s.background, s.buf)
  if ok and buffer and buffer ~= s.buf then
    detach_buffer(s)
    s.background:show(buffer)
    s.buf = vim.api.nvim_win_get_buf(s.win)
    attach_buffer(s)
  end
  s.switching = false
end

function M.close()
  local s = session
  if not s then return end
  session = nil
  vim.api.nvim_del_augroup_by_id(s.group)
  if s.restore_status then s.restore_status() end
  detach_buffer(s)
  if s.background then s.background:restore() end
  s.persist(position(s.pos))
  vim.api.nvim_exec_autocmds('User', { pattern = 'MoyuModeChanged', data = { active = false, buffer = s.buf } })
end

function M.next()
  local s = session
  if s then s.presses = 0 end
  if not s or s.next_pos.line > #s.lines then return end
  s.history[#s.history + 1] = position(s.pos)
  s.pos = position(s.next_pos)
  change_background(s)
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
    options = options, persist = persist,
    history = {}, presses = 0, pinned = false, actions = actions or {} }
  if options.background ~= false then s.background = require('moyu.background').new(window, buffer) end
  session = s
  attach_buffer(s)
  s.group = vim.api.nvim_create_augroup('MoyuStealthSession', { clear = true })
  vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave', 'BufWipeout', 'InsertEnter', 'CmdlineEnter' }, {
    group = s.group, callback = function(event)
      if not s.switching and event.buf == s.buf then M.close() end
    end,
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
