local M = {}
local active

function M.select(paths, format_item, callback)
  if active and vim.api.nvim_win_is_valid(active) then
    vim.api.nvim_set_current_win(active)
    return
  end
  if vim.fn.executable('fzf') ~= 1 then
    vim.ui.select(paths, { prompt = '选择书籍', format_item = format_item }, function(path)
      if path then callback(path) end
    end)
    return
  end
  local input, output = vim.fn.tempname(), vim.fn.tempname()
  local entries = {}
  for index, path in ipairs(paths) do
    entries[#entries + 1] = tostring(index) .. '\t' .. format_item(path):gsub('[\r\n\t]', ' ')
  end
  -- NUL records keep selection independent of whitespace and shell characters.
  local file = assert(io.open(input, 'wb'))
  file:write(table.concat(entries, '\0') .. '\0')
  file:close()
  local origin = vim.api.nvim_get_current_win()
  local origin_buffer = vim.api.nvim_get_current_buf()
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = 'wipe'
  local width = math.max(1, math.min(vim.o.columns - 2, math.floor(vim.o.columns * 0.8)))
  local height = math.max(1, math.min(vim.o.lines - 4, math.floor(vim.o.lines * 0.65)))
  local window = vim.api.nvim_open_win(buffer, true, {
    relative = 'editor', style = 'minimal', border = 'rounded',
    width = width, height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2) - 1),
  })
  active = window
  local command = table.concat({ vim.fn.shellescape(vim.fn.exepath('fzf')),
    '--read0 --print0 --no-multi --layout=reverse --info=inline',
    '--delimiter=' .. vim.fn.shellescape('\t'), '--with-nth=2..',
    '--prompt=' .. vim.fn.shellescape('找书 > '),
    '--bind=' .. vim.fn.shellescape('esc:abort'),
    '< ' .. vim.fn.shellescape(input), '> ' .. vim.fn.shellescape(output),
  }, ' ')
  local function finish(code)
    local selected
    if code == 0 and vim.fn.filereadable(output) == 1 then
      local result = table.concat(vim.fn.readfile(output, 'b'), '\n')
      local index = tonumber(result:match('^(%d+)\t'))
      selected = index and paths[index] or nil
    end
    vim.fn.delete(input)
    vim.fn.delete(output)
    if active == window then active = nil end
    -- fzf runs in Terminal mode. Leave it before returning to the code window.
    vim.cmd('stopinsert')
    if vim.api.nvim_win_is_valid(window) then vim.api.nvim_win_close(window, true) end
    if vim.api.nvim_buf_is_valid(buffer) then vim.api.nvim_buf_delete(buffer, { force = true }) end
    if vim.api.nvim_win_is_valid(origin) then
      vim.api.nvim_set_current_win(origin)
      if selected and vim.api.nvim_win_get_buf(origin) == origin_buffer then
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(origin) and vim.api.nvim_win_get_buf(origin) == origin_buffer then
            vim.api.nvim_set_current_win(origin)
            callback(selected)
          end
        end)
      end
    end
  end
  local ok, job = pcall(vim.fn.termopen, command, {
    env = { FZF_DEFAULT_OPTS = '', FZF_DEFAULT_OPTS_FILE = '', FZF_DEFAULT_COMMAND = '' },
    on_exit = function(_, code) vim.schedule(function() finish(code) end) end,
  })
  if not ok or job <= 0 then
    finish(1)
    vim.notify('无法启动 fzf：' .. tostring(job), vim.log.levels.ERROR)
    return
  end
  vim.api.nvim_create_autocmd('BufWipeout', { buffer = buffer, once = true, callback = function()
    pcall(vim.fn.jobstop, job)
  end })
  vim.cmd('startinsert')
end

return M
