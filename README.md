# moyu.nvim

Moyu Mode：保留 Neovim 的代码界面，以虚拟注释阅读本地书籍，敲键盘推进，Esc 恢复编辑。状态栏低调显示“鱼”，退出后恢复原状态栏。也保留独立浮窗阅读模式。需要 Neovim 0.9+；fzf 搜索使用 PATH 中的 `fzf` 程序，无需安装 fzf.vim / fzf-lua，缺少程序时回退到 `vim.ui.select`。

## 书籍格式

两种阅读模式和 fzf 书架使用同一套格式支持，扩展名不区分大小写。

| 格式 | 正文处理与依赖 |
| --- | --- |
| TXT / TEXT / Markdown (`.md`, `.markdown`) | UTF-8 直接读取；Markdown 保留原文标记 |
| GB18030 / GBK、带 BOM 的 UTF-16 文本 | Python 3 转成 UTF-8 |
| EPUB | Python 3 标准库，按 spine 顺序提取正文，跳过非线性资源 |
| HTML / HTM / XHTML | Python 3 标准库，去掉标签、脚本、样式和导航 |
| DOCX / ODT / FB2 | Python 3 标准库，提取正文段落 |
| PDF（含文字层） | Python 3 + Poppler 的 `pdftotext` |
| MOBI / AZW / AZW3 | Python 3 + Calibre 的 `ebook-convert` |
| RTF | Python 3 + Pandoc；未安装 Pandoc 时尝试 Calibre |

非纯 UTF-8 文本的提取在后台执行，期间可正常使用编辑器；关闭阅读或切到别的窗口时，迟到的结果不会抢回界面。转换结果在当前 Neovim 进程内缓存，原文件的大小或修改时间变化后重新提取。阅读进度以原始书籍路径记录，不会修改原文件。

这是一种文字阅读模式，会丢弃图片和原始排版。扫描版 PDF、图片漫画需先 OCR；加密或 DRM 书籍无法直接读取。损坏、无正文、缺少转换器或未知格式会明确报错，不把二进制当小说显示。PDF 的多栏阅读顺序和断行取决于文字层质量。转换器单次超时为 60 秒，EPUB/DOCX/ODT 的内部单个文件限制为 32 MiB。

Fedora 可按实际需求安装依赖：

```sh
sudo dnf install python3 poppler-utils calibre pandoc
```

UTF-8 TXT 不依赖 Python；EPUB、HTML、DOCX、ODT、FB2 不需要 Calibre、Pandoc 或额外 Python 包。Calibre 转换接口见[官方说明](https://manual.calibre-ebook.com/generated/en/ebook-convert.html)。

## 安装

使用 lazy.nvim 从 GitHub 安装：

```lua
{
  'apiper0626/moyu.nvim',
  name = 'moyu.nvim',
  main = 'moyu',
  cmd = {
    'Moyu', 'MoyuToggle', 'MoyuClose', 'MoyuBooks',
    'MoyuFloat', 'MoyuFloatToggle', 'MoyuStealth', 'MoyuStealthToggle',
    'MoyuHistory',
  },
  keys = {
    { '<leader>my', '<cmd>MoyuToggle<cr>', desc = 'Moyu Mode 续读 / 退出' },
    { '<leader>mb', '<cmd>Moyu<cr>', desc = 'Moyu Mode 搜书' },
  },
  opts = {
    book_dir = '~/Books/moyu', -- 独立书库，默认值；递归扫描支持的书籍格式
    width = 0.65,        -- 占编辑器宽度的比例
    height = 0.7,
    border = 'rounded',
    title = ' 阅读 ',
    stealth = {
      lines = 4,         -- 默认每段 4 行；小窗口按可用空间自动缩减
      keys_per_step = 3, -- 每敲几次可打印 ASCII 键推进一段
      background = true, -- 下一段时自动切换背景代码文件；false 关闭
      -- layout = 'block', -- 可选：指定启动布局，block 集中 / spread 分散
    },
  },
}
```

开发本地版本时可以将仓库加入 `runtimepath`，然后调用 `require('moyu').setup({...})`。

按上面的配置，`<leader>my` 直接进入/退出 Moyu Mode：有历史时自动续读，首次使用会选书。如果你的 leader 是空格，就是依次按 `Space`、`m`、`y`。插件不自行安装全局快捷键；阅读中临时接管同一组合键，以便再次按它退出。退出后恢复原映射。

## 使用

### fzf 搜书

执行 `:Moyu`，输入书名或路径中的部分文字模糊搜索，Enter 打开，Esc / Ctrl-C 取消。候选包含 `book_dir` 下所有支持的书籍文件及仍可读取的阅读历史，显示书名、已有进度和完整路径，同名书籍也能区分。

选中后直接进入 Moyu Mode。默认书库为 `~/Books/moyu`，与插件安装目录分开，插件更新不会碰你的书。先创建目录，再放入自己的书籍：

```sh
mkdir -p ~/Books/moyu
```

仓库的 `books/` 仅保留试读示例，不作为默认个人书库；需要试读时将示例复制到上述目录。已有书籍目录可以通过 `book_dir` 指定。阅读历史保存在 Neovim 数据目录，独立于书库和插件代码。

想直接续读而不搜索，使用 `:MoyuToggle`。显式指定路径仍可直接打开。旧命令 `:MoyuStealth` / `:MoyuStealthToggle` 继续兼容，因此已有本地插件加载配置无需修改即可使用新的主入口。

### Moyu Mode

先打开一个代码文件，在 Normal 模式执行：

```vim
:Moyu
```

原代码、语法高亮、行号和窗口布局保持原样。首次使用默认集中布局，在光标附近连续显示一段虚拟注释；在 Moyu Mode 内按 `F3` 切换集中 / 分散布局。分散布局从上到下穿插短注释，默认 4 处，每处约 40 个显示单元（中文约 18 字），沿用所在代码行的缩进；窗口较小或代码行较少时减少显示数量。正文不会写入代码文件，也不会进入撤销历史。注释样式取自当前缓冲区的 `commentstring`（例如 Lua 的 `--`、Java 的 `//`），未设置时使用 `//`。

| 按键 | 功能 |
| --- | --- |
| 字母（除 `j/k`）、数字、空格、ASCII 标点 | 默认每敲 3 次推进一段；按键被拦截，不执行编辑 |
| `j` / `Enter` / `Tab` / `→` / `↓` / `PageDown` / `Ctrl-D` / `Ctrl-F` / 滚轮向下 | 立即下一段 |
| `k` / `Backspace` / `←` / `↑` / `PageUp` / `Ctrl-U` / `Ctrl-B` / 滚轮向上 | 上一段，支持刚恢复阅读时回翻 |
| `Esc` / `Ctrl-C` | 隐藏正文，恢复正常编辑和原缓冲区快捷键 |
| `F2` | 搜索历史阅读记录 |
| `F3` | 切换集中 / 分散布局，不改变当前阅读位置，并保存选择 |
| `F4` | 固定 / 取消固定当前背景文件；固定时翻段不换背景 |
| `+` / `=`（或小键盘 `+`） | 显示行数增加 1，立即重排 |
| `-`（或小键盘 `-`） | 显示行数减少 1，最少 1 行 |

`:Moyu [路径]` 搜书或直接进入；`:MoyuToggle` 继续上次阅读或退出；`:MoyuClose` 保存并退出；`:MoyuBooks` 搜书换书。到达末尾会停留在最后一段。模式会记录段落内的字符位置，可以从长段落中间继续。

默认每次推进到下一段，背景会轮换到另一个代码文件，正文阅读进度继续。候选来自已打开的普通代码缓冲区，以及当前代码所在项目附近的源码文件；目录扫描最多向下 3 层、检查 2000 个条目、保留约 40 个候选，跳过隐藏目录及 `node_modules`、`target`、`dist`、`build`、`vendor` 等目录。没有其他可用代码文件时保持当前背景；未命名缓冲区不扫描目录。回翻正文、调整行数、切换布局不会换背景，到达书末也不再切换。

背景轮换仅在 Moyu Mode 内由翻段触发。退出或自动隐藏时回到进入前的文件、光标和视口，恢复各文件原映射及可编辑状态，保留未保存的代码；临时加载且未修改的背景缓冲区会清理。可设置 `stealth.background = false` 关闭轮换。浮窗阅读不轮换代码。

遇到合适的背景时，在 Moyu Mode 内按 `F4` 固定当前文件，继续翻段只更新正文；再次按 `F4` 取消固定，下一段恢复轮换。切换布局或调整行数不会取消固定。固定只在本次阅读期间有效，退出或自动隐藏后清除；`F4` 临时绑定在当前缓冲区，退出后恢复原映射。配置已关闭背景轮换时，`F4` 会提示，不会启用轮换。

模式开启时在当前窗口状态栏显示“鱼”，兼容普通及表达式状态栏（例如 lualine），自动隐藏时同时清除标记。程序可调用 `require('moyu').is_active()` 查询状态，`require('moyu').status()` 获取“鱼”或空字符串；进入和退出会触发 `User MoyuModeChanged`，事件数据为 `{ active = true/false, buffer = 缓冲区编号 }`。

行数调整不改变当前阅读位置，小窗口仍按可用空间显示。行数和布局分别保存在阅读数据的 `settings.lines` 和 `settings.layout` 中，重启后沿用；如果配置中显式设置了 `stealth.lines` 或 `stealth.layout`，则以对应配置值作为启动设置。`F3` 仅在 Moyu Mode 中临时接管当前缓冲区的按键，不在普通编辑或浮窗阅读中安装映射；退出或自动隐藏后恢复原映射。退出阅读后，`+` / `=` / `-` 也恢复原来的编辑功能。

### 阅读历史与自动续读

阅读时自动记录每本书的行和 Unicode 字符位置。再次从书架或历史打开同一本书，会直接回到上次的位置，重启 Neovim 后也有效，无需手动定位。

- `:MoyuHistory` 或阅读中按 `F2`：查看阅读历史，最近阅读排在前面，显示进度、行号和阅读时间；选书即可续读。
- `:MoyuToggle`：直接继续上次阅读。

已有 lazy.nvim 配置若只声明旧命令，先运行一次 `:Moyu` 加载插件即可注册历史命令；也可直接在阅读中按 `F2`。

记录保存在 `stdpath('data')/moyu/progress.json`，按书籍原始绝对路径区分。缺失文件仍在历史里标记“文件不存在”。移动、重命名或修改原书后，旧位置不会自动迁移或校正。进度基于提取后的正文，不对应 PDF 原页码。

这是专门的阅读模式：开启时临时接管当前缓冲区 Normal 模式快捷键，并将缓冲区设为不可编辑。翻段键优先于已有全局和缓冲区映射，隐藏后恢复原映射；上下翻段会重置敲字计数。先按 `Esc` 再执行原有快捷键或命令。切换窗口、缓冲区、进入插入或命令行模式、编辑器失焦时自动隐藏。终端是否上报失焦和滚轮事件取决于终端设置。仅支持普通代码缓冲区；中文输入法组合键及终端特殊功能键不作为推进按键。

### 浮窗阅读

- `:MoyuFloat ~/Books/小说.txt`：浮窗打开文件，支持路径补全。
- `:MoyuFloat`：打开 fzf 搜书，选中后浮窗阅读。
- `:MoyuFloatToggle`：打开 / 隐藏浮窗。
- `:MoyuClose`：保存并关闭当前阅读模式。

使用旧版 lazy.nvim 加载配置时，先执行一次 `:Moyu` 加载插件即可注册新的浮窗命令；也可以更新安装示例中的 `cmd` 列表。

阅读窗口内：

| 按键 | 功能 |
| --- | --- |
| `j` / `k` 或方向键 | 按屏幕显示行移动，适合小说长段落 |
| `Space` / `Backspace` | 下一页 / 上一页 |
| `/`、`n`、`N` | 使用 Neovim 原生搜索 |
| `gg` / `G` | 开头 / 结尾 |
| `B` | 书架 |
| `q` / `Esc` / `<leader>q` | 保存进度并立即隐藏 |

进度保存在 `stdpath('data')/moyu/progress.json`，按文件绝对路径记录原文行号；移动光标、离开窗口和退出时自动保存。长段落内部的屏幕行位置不会单独保存。隐藏会关闭阅读浮窗，回到原编辑窗口。

正文整体加载到内存，超大文件可能影响响应。同一数据目录的多个 Neovim 进程同时阅读时，进度以最后写入的进程为准。

## 验证

```sh
test_dir=$(mktemp -d)
XDG_DATA_HOME="$test_dir" nvim --headless -u NONE -i NONE -l tests/smoke.lua
XDG_DATA_HOME="$test_dir" nvim --headless -u NONE -i NONE -l tests/restore.lua
XDG_DATA_HOME="$test_dir" nvim --headless -u NONE -i NONE -l tests/stealth.lua
XDG_DATA_HOME="$test_dir" nvim --headless -u NONE -i NONE -l tests/stealth_restore.lua
XDG_DATA_HOME="$(mktemp -d)" nvim --headless -u NONE -i NONE -l tests/picker.lua
XDG_DATA_HOME="$(mktemp -d)" nvim --headless -u NONE -i NONE -l tests/mode.lua
PYTHONDONTWRITEBYTECODE=1 python3 tests/test_formats.py
XDG_DATA_HOME="$(mktemp -d)" nvim --headless -u NONE -i NONE -l tests/formats.lua
history_dir=$(mktemp -d)
XDG_DATA_HOME="$history_dir" nvim --headless -u NONE -i NONE -l tests/history.lua
XDG_DATA_HOME="$history_dir" nvim --headless -u NONE -i NONE -l tests/history_restore.lua
```

手动验收：打开中文长段落，检查自动换行、翻页、搜索和隐藏后返回原窗口；缩放终端检查浮窗尺寸；重启 Neovim 后检查续读位置。

代码区模式另请检查：Lua / Java 等文件的注释外观、窄分屏与光标靠近窗口底部时的正文位置；敲键推进、回退、Esc 隐藏与原快捷键恢复；切窗、切缓冲区与失焦隐藏。自动化测试仅验证行为，视觉效果由实际终端验收。

搜书请手动检查：`:Moyu` 的搜索框、中文书名筛选、Enter 打开与 Esc 取消，以及自定义 `book_dir` 后的候选内容。模式请检查：状态栏“鱼”出现和清除、Esc 后正常写代码、再次切换恢复进度；浮窗入口使用 `:MoyuFloat`。

多格式请使用自己的 EPUB/PDF/DOCX 检查正文顺序、中文和续读位置。自动化验证覆盖生成样书的 EPUB、HTML、DOCX、ODT、FB2、文字 PDF 和编码转换；MOBI/AZW/RTF 依赖外部转换器，转换能力取决于工具版本和原书内容。

请手动检查阅读历史的显示；关闭再打开同一本书，以及重启后从历史选书，确认都回到上次阅读位置。

## 灵感来源

- [Thief-Book](https://github.com/niuxianghui/Thief-Book) 与 [Thief-Book-VSCode](https://github.com/cteamx/Thief-Book-VSCode)：在工作界面中低调阅读、快捷隐藏和进度记忆的交互思路。
- [read-on-bush](https://github.com/moyuderen/read-on-bush)：将阅读内容融入开发界面、使用伪装展示的思路。

Moyu.nvim 将这些交互灵感结合 Neovim 的虚拟注释、临时按键接管和状态栏提示实现；本项目不是上述项目的官方版本，也没有复制其源代码。感谢原作者。

## 开源与贡献

代码使用 [MIT License](LICENSE)。试读文本的来源说明见 [books/README.md](books/README.md)。提交问题或改进前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。Neovim 内可查看 `:help moyu.nvim`。

维护者首次发布可运行 `sh scripts/publish.sh`：检查 GitHub 连接、运行测试、发布到 `apiper0626/moyu.nvim` 的 `main`，核验远端提交后备份并替换本机 lazy.nvim 配置。脚本遇到非空远端仓库会停止，不会覆盖已有历史。常规开发验证请使用 `sh scripts/test.sh`。
