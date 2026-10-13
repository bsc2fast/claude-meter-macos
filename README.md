# Claude Meter

A tiny macOS menu bar app that shows your Claude plan usage (current 5-hour session,
weekly limit, and any model-specific weekly limits such as Fable), the same numbers as
claude.ai → Settings → Usage.

> Unofficial. Not affiliated with or endorsed by Anthropic.

## Install

You need macOS 14+ and [Claude Code](https://claude.com/claude-code) signed in with your
Claude Pro or Max account (run `claude` once and log in).

**Option 1: one line in Terminal**

```sh
curl -fsSL https://raw.githubusercontent.com/bsc2fast/claude-meter-macos/main/scripts/install.sh | sh
```

**Option 2: download**

Download [ClaudeMeter.dmg](https://github.com/bsc2fast/claude-meter-macos/releases/latest/download/ClaudeMeter.dmg),
open it and drag **ClaudeMeter** into **Applications**. The build isn't notarized, so the first
time you open it macOS will refuse. Go to **System Settings → Privacy & Security** and click
**Open Anyway**, or run `xattr -dr com.apple.quarantine /Applications/ClaudeMeter.app`.

Download page: https://aimeter.sankhacooray.com

## How it gets data

It reuses your **Claude Code** login. It reads the OAuth token Claude Code stores in the
macOS Keychain (`Claude Code-credentials`), or `~/.claude/.credentials.json`, and calls
`https://api.anthropic.com/api/oauth/usage`, the endpoint behind Claude Code's `/usage`.
It never refreshes the token itself, because doing that would rotate Claude Code's refresh
token. If the token expires, run `claude` once and the meter picks up the new token.

The endpoint is undocumented, so it may change without notice.

## Build & run

Requires macOS 14+ and Xcode 15+ command line tools.

```sh
scripts/build-app.sh            # → build/ClaudeMeter.app
scripts/build-app.sh --install  # also copies to /Applications and launches
scripts/build-app.sh --zip      # packs dist/ClaudeMeter.zip (used by install.sh)
scripts/build-app.sh --dmg      # packs dist/ClaudeMeter.dmg (drag-to-Applications)
```

macOS adds new menu bar items on the left. To move it next to battery/Wi-Fi,
hold ⌘ and drag it.

## Options (in the dropdown)

- Menu bar label: session %, session · week, or icon only
- Refresh interval: 1 / 2 / 5 / 15 min. It also refreshes when you open the panel.
- Launch at login (works when run from `/Applications`)
