local M = {}
local marker = '%#Comment# 鱼 %*'

function M.attach(window, group)
  local saved = vim.api.nvim_get_option_value('statusline', { win = window, scope = 'local' })
  local updating = false
  local rendered
  local function show()
    if not vim.api.nvim_win_is_valid(window) then return end
    updating = true
    local base = saved ~= '' and saved or vim.go.statusline
    if base:sub(1, 2) == '%!' then
      rendered = "%!'" .. marker .. "' . (" .. base:sub(3) .. ')'
    else
      rendered = marker .. base
    end
    vim.wo[window].statusline = rendered
    updating = false
  end
  vim.api.nvim_create_autocmd('OptionSet', { group = group, pattern = 'statusline', callback = function()
    if updating or not vim.api.nvim_win_is_valid(window) then return end
    local value = vim.api.nvim_get_option_value('statusline', { win = window, scope = 'local' })
    if value ~= rendered then saved = value end
    show()
  end })
  show()
  vim.cmd('redrawstatus')
  return function()
    if vim.api.nvim_win_is_valid(window) then vim.wo[window].statusline = saved end
    vim.cmd('redrawstatus')
  end
end

return M
