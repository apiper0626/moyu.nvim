-- Copy to ~/.config/nvim/lua/plugins/moyu.lua.
return {
  {
    'apiper0626/moyu.nvim',
    name = 'moyu.nvim',
    main = 'moyu',
    cmd = {
      'Moyu', 'MoyuToggle', 'MoyuClose', 'MoyuBooks',
      'MoyuStealth', 'MoyuStealthToggle',
      'MoyuFloat', 'MoyuFloatToggle',
      'MoyuHistory',
    },
    keys = {
      { '<leader>my', '<cmd>MoyuToggle<cr>', desc = 'Moyu Mode 续读 / 退出' },
      { '<leader>mb', '<cmd>Moyu<cr>', desc = 'Moyu Mode 搜书' },
    },
    opts = {},
  },
}
