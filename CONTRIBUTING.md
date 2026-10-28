# Contributing

Issues and focused pull requests are welcome. Include your Neovim version,
terminal, book format, and steps to reproduce. Use a small original or public
domain fixture; do not upload private books, reading history, or credentials.

Run the core checks from the repository root:

```sh
sh scripts/test.sh
```

Python 3 and Poppler (`pdftotext`) are needed for format tests. The fzf integration
test runs when `fzf` is installed. Optional integration checks:

```sh
LAZY_NVIM_PATH=/path/to/lazy.nvim sh scripts/test.sh --integrations
```

For lualine, also set `MOYU_TEST_PLUGINS` to the directory containing `lualine.nvim`
and optionally `nvim-web-devicons`. Personal lualine configuration can be tested
with `MOYU_TEST_LUALINE_CONFIG=/path/to/lualine.lua`.

Keep source files portable and preserve reader position, existing buffer mappings,
and the original code buffer. New format support should include an original
fixture and clear missing-dependency errors. Use Conventional Commit titles.
