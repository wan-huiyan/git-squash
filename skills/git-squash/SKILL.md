---
name: git-squash
description: |
  Squash the last N git commits into one, or amend the last commit with staged changes.
  Use when the user says "squash", "amend", "merge commits", "combine commits", "fold into
  previous commit", "that commit was trivial", or invokes /squash. Also trigger when the user
  says "clean up the commits", "too many small commits", "squash before pushing",
  "collapse commits", "condense commits", or "compress commit history".
  Trigger on the slash commands /squash, /squash N, and /squash amend.
  Also trigger for "condense my history", "flatten commits", "tidy up commits",
  "consolidate commits", "roll up commits", and "compact the commit log".
  Trigger for "interactive rebase to clean up commits", "merge my last two commits into
  one with a better message", "fixups", and "already pushed" squash scenarios.
  Trigger for "I made a typo fix", "commits are all related", "merge them together",
  "into a single commit", and similar phrasing about combining commits together.
---

# Git Squash

USE this skill when the user wants to squash, combine, amend, fold, collapse, or condense git commits. This includes `/squash`, `/squash N`, `/squash amend`, and natural-language equivalents like "clean up commits" or "too many small commits."

## Do NOT use for

Do NOT use for regular commits, git push, git pull, git fetch, reverts, stash, cherry-pick, branch creation, rebasing without squash context, code review, git tagging, merge conflict resolution, git hooks setup, or merging branches. Do NOT trigger for "fixup! ..." commit messages, "create a new feature branch", "revert the last commit", "stash my current changes", "show me the git log", or "tag this release".

## Prerequisites

Requires git CLI >= 2.0 (must support `reset --soft` and `commit --amend`). Depends on a valid git repository being present. Works with any git hosting provider (GitHub, GitLab, Bitbucket).

To install this skill in Claude Code:

```bash
claude install-skill https://github.com/wan-huiyan/git-squash
```

## Scope and Safety

Input: user request to squash/amend commits, optionally with count N. Output: modified git history with fewer commits plus a confirmation message.

This skill is not idempotent — running twice doubles the effect because each invocation rewrites history. It is not safe to re-run without checking results first.

For interactive rebase workflows beyond simple squash, suggest `git rebase -i` documentation. For assigning staged hunks to the correct ancestor commit, suggest git-absorb instead. The `git-squash` namespace is scoped to this skill's slash commands only.

## Mode 1: Amend (fold into previous commit)

When the user has just made a trivial change and wants to fold it into the previous commit.

```
/squash        → amend last commit with any staged changes
/squash amend  → same as above
```

**Steps:**
1. Run `git log --oneline -5` to show recent commits
2. Run `git status` to check for staged/unstaged changes
3. If there are unstaged changes, ask what to stage
4. Run `git commit --amend` with the previous commit message (or a new one if the user provides it)
5. Show the result

**Safety checks:**
- NEVER amend if the commit has already been pushed to a remote AND others may have pulled it
- Check with `git log --oneline @{u}..HEAD` — if empty, the commit is already on the remote
- If already pushed: warn the user that amending requires a force push, and ask for confirmation
- If on main/master with upstream: REFUSE and suggest a rebase workflow instead

## Mode 2: Squash N commits

When the user wants to combine the last N commits into one.

```
/squash 3      → squash last 3 commits into one
/squash N      → squash last N commits into one
```

**Steps:**
1. Run `git log --oneline -N` to show the commits that will be squashed
2. Confirm with the user: "Squash these N commits into one?"
3. Compose a combined commit message:
   - If all commits are related (same topic), write a single summary
   - If mixed, list the key changes as bullet points
   - Preserve any Co-Authored-By lines from the original commits
4. Run `git reset --soft HEAD~N` then `git commit -m "..."` with the new message
5. Show the result

**Safety checks:**
- Same push/remote checks as Mode 1
- If N > 10, warn and confirm ("You're about to squash 15 commits — are you sure?")
- Never squash past a merge commit without warning

## Mode 3: Auto-detect (default)

When the user just says `/squash` with no arguments and there are no staged changes:

1. Show `git log --oneline -10`
2. Run the squash detection heuristics (see [references/scoring-heuristics.md](references/scoring-heuristics.md)) on each commit
3. Group adjacent squashable commits
4. Suggest: "These N commits look squashable. Combine them?"
5. If the user confirms, proceed with Mode 2

Score each commit 0-100. Commits scoring **60+** are "likely squashable." Signals span three categories: message patterns (cheapest), diff analysis, and contextual signals (author timing, file overlap). Full scoring tables and detection procedures are in [references/scoring-heuristics.md](references/scoring-heuristics.md).

## Force Push Handling

After squashing commits that were already pushed:
- Ask: "These commits were already pushed. Force push to update the remote?"
- If on a feature branch: `git push --force-with-lease` (safer than `--force`)
- If on main/master: REFUSE unless the user explicitly says "force push to main"
- Always use `--force-with-lease` over `--force` to avoid overwriting others' work

## Edge Cases and Error Handling

| Scenario | Behavior |
|----------|----------|
| Not a git repository | Report error: "This directory is not a git repository." Stop. |
| No commits in repository | Report error: "No commits to squash." Stop. |
| N exceeds total commits | Report: "Only M commits exist." Offer to squash all M instead. |
| Squash range includes merge commit | Warn: "This range crosses a merge boundary." Ask to confirm or reduce N. |
| N > 10 | Warn about large operation, require explicit confirmation. |
| N > 50 | Strongly warn, suggest doing it in smaller batches. |
| Malformed input (non-numeric N) | Report: "Expected a number. Usage: /squash N" |
| Missing git CLI | Report: "git is not installed or not in PATH." Stop. |
| Protected branch (main/master) | REFUSE unless user explicitly overrides. Suggest feature branch. |
| Dirty working tree with conflicts | Report conflicts, ask user to resolve before squashing. |

## Examples

```
User: "that rename commit is trivial, can you squash it into the previous one?"
→ Mode 1: amend

User: "/squash 3"
→ Mode 2: squash last 3

User: "clean up the commit history before we push"
→ Mode 3: auto-detect, suggest squashable groups

User: "/squash" (with staged changes)
→ Mode 1: amend with staged changes
```

## Hook: Auto-detect after every commit

A PostToolUse hook can automatically score commits and suggest `/squash` when appropriate. See [references/squash-hint-hook.md](references/squash-hint-hook.md) for installation instructions and the full hook script.

## Related Tools

| Tool | What it does | When to use instead |
|------|-------------|-------------------|
| [git-absorb](https://github.com/tummychow/git-absorb) | Automatically assigns staged hunks to the right ancestor commit via patch commutativity | When you have staged changes and want to fold them into the *correct* prior commit (not just the last one) |
| [git-autosquash](https://andrewleech.github.io/git-autosquash/) | Uses `git blame` to detect which commit a change belongs to, with green/yellow/red confidence | Similar to git-absorb but with confidence scoring |
| `git commit --fixup=<sha>` | Creates a `fixup!` commit that `git rebase --autosquash` will squash later | When working on a branch you'll rebase before merging |

## References

- [git-absorb — patch commutativity approach](https://github.com/tummychow/git-absorb)
- [Atomic Commits Guide — Aleksandr Hovhannisyan](https://www.aleksandrhovhannisyan.com/blog/atomic-git-commits/)
- [Commit Message Quality Checker — Faerber et al. COMPSAC 2023](https://faerber-lab.github.io/assets/pdf/publications/Commit-Message-Quality-Checker_COMPSAC2023.pdf)
- [Conventional Commits Spec](https://www.conventionalcommits.org/en/v1.0.0/)
- [commitlint](https://commitlint.js.org/) / [gitlint](https://github.com/jorisroovers/gitlint)
