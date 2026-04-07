# Squash Hint Hook Setup

Auto-detect squashable commits after every `git commit` via a Claude Code PostToolUse hook.

## Installation

```bash
# 1. Create the hooks directory
mkdir -p ~/.claude/hooks

# 2. Download the hook script
curl -fsSL -o ~/.claude/hooks/squash-hint.sh \
  https://raw.githubusercontent.com/wan-huiyan/git-squash/main/references/squash-hint.sh

# 3. Make it executable
chmod +x ~/.claude/hooks/squash-hint.sh

# 4. Add the hook config to your Claude Code settings
# Edit ~/.claude/settings.json (user-level) or .claude/settings.json (project-level)
```

## Hook Configuration

Add this to your `settings.json` (merge into existing `hooks` if you already have some):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/squash-hint.sh",
            "timeout": 5,
            "statusMessage": "Checking commit..."
          }
        ]
      }
    ]
  }
}
```

## How It Works

After every `git commit`, the hook scores the commit. If it scores 60+
(likely trivial), it injects a hint into the conversation suggesting `/squash`. The hook is
passive — it never modifies history, only suggests.

**Merge note:** If you already have `PostToolUse` hooks, add the Bash matcher entry to the
existing array — don't replace it.

## Hook Script Source

See [squash-hint.sh](./squash-hint.sh) for the full script.
