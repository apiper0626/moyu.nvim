#!/bin/sh
# Publish the reviewed public files, then install the GitHub-backed lazy spec.
set -eu
cd "$(dirname "$0")/.."
repo='apiper0626/moyu.nvim'
gh api user --jq .login >/dev/null
release_parent=$(mktemp -d)
release_dir="$release_parent/moyu.nvim"
python3 scripts/export_release.py "$release_dir"
sh "$release_dir/scripts/test.sh"
if gh repo view "$repo" --json nameWithOwner >/dev/null 2>&1; then
  if [ "$(gh repo view "$repo" --json isEmpty --jq .isEmpty)" != 'true' ]; then
    printf '%s\n' 'Repository is not empty; stopping without changing remote history.' >&2
    exit 1
  fi
else
  gh repo create "$repo" --public --description 'Read books discreetly inside Neovim with virtual comments, fzf and automatic resume.'
fi
if [ "$(gh repo view "$repo" --json visibility --jq .visibility)" != 'PUBLIC' ]; then
  printf '%s\n' 'Repository is not public; stopping before publishing.' >&2
  exit 1
fi
git -C "$release_dir" init -b main
git -C "$release_dir" add README.md LICENSE CONTRIBUTING.md .gitignore lua plugin scripts tests doc integration books .github
git -C "$release_dir" diff --cached --check
git -C "$release_dir" commit -m 'feat(moyu): add keyboard-driven book reading in Neovim' \
  -m 'Render book text as virtual code comments, preserve editing state, and resume each book from its saved position. Include fzf discovery, reading history, common format extraction and a GitHub-backed lazy.nvim specification.'
git -C "$release_dir" remote add origin "https://github.com/$repo.git"
git -C "$release_dir" -c credential.helper= -c 'credential.helper=!gh auth git-credential' push -u origin main
local_sha=$(git -C "$release_dir" rev-parse HEAD)
remote_sha=$(git -C "$release_dir" -c credential.helper= -c 'credential.helper=!gh auth git-credential' ls-remote origin refs/heads/main | cut -f1)
[ "$local_sha" = "$remote_sha" ]
config_file="${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lua/plugins/moyu.lua"
mkdir -p "$(dirname "$config_file")"
if [ -f "$config_file" ]; then
  cp -p "$config_file" "$config_file.bak.$(date +%Y%m%d%H%M%S)"
fi
cp "$release_dir/integration/moyu.lua" "$config_file"
cmp "$release_dir/integration/moyu.lua" "$config_file"
printf 'Published https://github.com/%s at %s\nInstalled %s\nRestart Neovim to install from GitHub. Press <leader>my to resume reading.\nRelease checkout: %s\n' "$repo" "$local_sha" "$config_file" "$release_dir"
