# 测试书籍

`基督山伯爵-中文试读.txt` 是依据 Project Gutenberg #1184 英文公版开篇重新翻译的中文节选，用于测试阅读交互；不是完整小说，也不冒充出版中译本。

来源与英文全文：https://www.gutenberg.org/ebooks/1184

在已加载插件的 Neovim 中，先打开代码文件，再执行：

```vim
:Moyu /path/to/moyu.nvim/books/基督山伯爵-中文试读.txt
```

未安装插件时，可在项目目录启动独立测试环境：

```sh
nvim -u NONE -i NONE --cmd 'set rtp+=/path/to/moyu.nvim' \
  -c 'runtime plugin/moyu.lua' \
  -c 'setlocal commentstring=--\ %s' \
  -c 'Moyu /path/to/moyu.nvim/books/基督山伯爵-中文试读.txt' \
  lua/moyu/init.lua
```

敲 3 次字母、数字或空格推进一段，Enter 立即下一段，Backspace 返回上一段，Esc 隐藏并恢复编辑。
