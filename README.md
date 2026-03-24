# Git Squash

A [Claude Code](https://claude.com/claude-code) skill that intelligently squashes git commits — with auto-detection of trivial commits via message patterns, diff size, and timing heuristics.

## Quick Start

```
You: /squash
Claude: Recent commits:
        a1b2c3d Fix review panel findings
        e4f5g6h fix typo in README        ← score 75 (message: +60, diff: +15)
        i7j8k9l Rename file               ← score 65 (rename-only: +60, 1 file: +15)
        m0n1o2p Initial commit

        Commits e4f5g6h and i7j8k9l look squashable (scores 75 and 65).
        Squash both into a1b2c3d?

You: yes
Claude: ✓ Squashed 3 commits into 1. New history:
        x9y8z7w Fix review panel findings (includes rename + typo fix)
        m0n1o2p Initial commit
```

## Installation

### Claude Code
```bash
git clone https://github.com/wan-huiyan/git-squash.git ~/.claude/skills/git-squash
```

### Cursor
```bash
mkdir -p .cursor/rules
# Create .cursor/rules/git-squash.mdc with SKILL.md content + alwaysApply: true
```

## Optional: Auto-hint after every commit

Add a Claude Code hook so you get automatic squash suggestions after every `git commit`. See [SKILL.md](SKILL.md#suggested-hook-auto-detect-after-every-commit) for the full setup (hook config + shell script).

**What it looks like:**
```
Claude: ✓ Committed "fix typo in README"
        Squash hint: commit 'fix typo in README' scores 85/100
        (trivial fix, tiny diff, 1 file). Consider /squash.
```

## Three Modes

| Mode | Trigger | What happens |
|------|---------|-------------|
| **Amend** | `/squash` with staged changes, or "fold into previous" | Amends the last commit with staged changes |
| **Squash N** | `/squash 3` | Combines last N commits into one with a merged message |
| **Auto-detect** | `/squash` with no staged changes | Scores recent commits, suggests squashable groups |

## How Auto-Detection Works

Each commit is scored 0-100 across three signal categories. Commits scoring **60+** are flagged as squashable.

### Message signals (cheapest — checked first)

| Signal | Score | Example |
|--------|-------|---------|
| `fixup!` / `squash!` prefix | +90 | `fixup! Add auth middleware` |
| WIP / oops / forgot | +80 | `oops forgot the test file` |
| Typo / whitespace / lint | +60 | `fix typo in README` |
| Minor / cleanup / polish | +50 | `minor cleanup` |
| Single-word message | +40 | `formatting` |

### Diff signals (run `git show --stat`)

| Signal | Score | How detected |
|--------|-------|-------------|
| Whitespace-only changes | +90 | `git show --ignore-all-space` is empty |
| Rename-only | +60 | All changes are file renames |
| Comment/import-only | +50 | All changed lines are comments or imports |
| ≤3 lines changed | +40 | From `--stat` output |
| ≤10 lines changed | +20 | From `--stat` output |

### Contextual signals (compare with neighbors)

| Signal | Score | How detected |
|--------|-------|-------------|
| Same author + same files + <5 min | +60 | Author date + file set comparison |
| Same author, <15 sec apart | +70 | Almost certainly a fixup |
| Same file set as adjacent commit | +40 | `--name-only` overlap |

Scores are additive (capped at 100). A commit matching signals from 2+ categories is almost always squashable.

## Safety

- **Never amends pushed commits without asking.** If a commit is already on the remote, it warns about force push and asks for confirmation.
- **Uses `--force-with-lease`** (not `--force`) to avoid overwriting others' work.
- **Refuses force push to main/master** unless you explicitly say so.
- **Warns before squashing past merge commits.**
- **Preserves Co-Authored-By lines** from original commits.

## What This Catches

- **"Fix typo" → "fix another typo" → "one more typo"** chains — squashes automatically
- **Rapid-fire commits** from the same author touching the same files — flags as likely fixups
- **Rename-then-fix** patterns — a rename followed by a reference update in the same files
- **Forgotten files** — "oops forgot to add X" commits that should have been in the previous
- **Review address commits** — "address code review" that belong with the original change

## Limitations

- **Cannot determine the "correct" ancestor commit** for a change. For that, use [git-absorb](https://github.com/tummychow/git-absorb) which tests patch commutativity.
- **Heuristics are not perfect.** A "minor" commit might actually be a meaningful small fix. Always confirm before squashing.
- **Does not handle interactive rebase.** For complex history rewriting (reordering, splitting), use `git rebase -i` directly.
- **Timing signals require local git history.** Shallow clones may not have accurate timestamps.

## Related Tools

| Tool | Approach | Best for |
|------|----------|---------|
| **This skill** | Message + diff + timing heuristics | Quick squash of obviously trivial commits |
| [git-absorb](https://github.com/tummychow/git-absorb) | Patch commutativity testing | Assigning staged hunks to the correct ancestor |
| [git-autosquash](https://andrewleech.github.io/git-autosquash/) | `git blame` frequency analysis | Confidence-scored assignment with green/yellow/red |
| `git commit --fixup` | Manual marking for `rebase --autosquash` | Pre-planned squash in branch workflows |

<details>
<summary>References</summary>

- [git-absorb — patch commutativity approach](https://github.com/tummychow/git-absorb)
- [Atomic Commits Guide — Aleksandr Hovhannisyan](https://www.aleksandrhovhannisyan.com/blog/atomic-git-commits/)
- [Commit Message Quality Checker — Faerber et al. COMPSAC 2023](https://faerber-lab.github.io/assets/pdf/publications/Commit-Message-Quality-Checker_COMPSAC2023.pdf)
- [Conventional Commits Spec](https://www.conventionalcommits.org/en/v1.0.0/)
- [commitlint](https://commitlint.js.org/) / [gitlint](https://github.com/jorisroovers/gitlint)
</details>

## Version History

| Version | Changes |
|---------|---------|
| 1.0.0 | Initial release: 3 modes (amend, squash N, auto-detect), 0-100 scoring with 3 signal categories, safety checks |

## License

MIT
