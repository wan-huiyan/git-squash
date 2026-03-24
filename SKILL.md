---
name: git-squash
description: |
  Squash the last N git commits into one, or amend the last commit with staged changes.
  Use when the user says "squash", "amend", "merge commits", "combine commits", "fold into
  previous commit", "that commit was trivial", or invokes /squash. Also trigger when the user
  says "clean up the commits", "too many small commits", or "squash before pushing".
---

# Git Squash

Squash recent commits into a clean history. Two modes:

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
2. Run the squash detection heuristics (see below) on each commit
3. Group adjacent squashable commits
4. Suggest: "These N commits look squashable. Combine them?"
5. If the user confirms, proceed with Mode 2

### Squash Detection Heuristics

Score each commit 0-100. Commits scoring **60+** are "likely squashable." Combine signals
from multiple categories for higher confidence.

#### Category 1: Message signals (check first — cheapest)

| Signal | Score | Pattern |
|--------|-------|---------|
| Explicit fixup marker | **+90** | `^(fixup\|squash\|amend)!\s` |
| WIP | **+80** | `^wip\b` or `^wip:` |
| Oops/forgot family | **+80** | `^(oops\|whoops\|forgot\|missed\|doh\|argh)\b` |
| Fix-previous-commit | **+80** | `fix(ed\|es\|ing)?\s+(the\s+)?(last\|previous\|prior)\s+commit` |
| Trivial-fix vocabulary | **+60** | `^(fix\s+)?(typo\|spelling\|whitespace\|indent(ation)?\|formatting\|lint)\b` |
| Minor/cleanup family | **+50** | `^(minor\|small\|tiny\|trivial\|nit\|cleanup\|clean[\s-]?up\|polish)\b` |
| Address review | **+50** | `address(ed\|es\|ing)?\s+(code[\s-]?)?review` |
| Single word message | **+40** | 1 word only (excluding conventional commit prefix) |
| Very short message | **+30** | Subject < 10 characters |
| Temp/tmp | **+70** | `^(temp\|tmp)\b` |

#### Category 2: Diff signals (run `git show --stat` and `git show --diff-filter`)

| Signal | Score | How to detect |
|--------|-------|---------------|
| Whitespace-only | **+90** | `git show <sha> --ignore-all-space` produces empty diff |
| Rename-only | **+60** | `git show <sha> --diff-filter=R --name-only` matches all changes |
| Very small diff (≤3 lines) | **+40** | Parse `git show --stat` — total insertions+deletions ≤ 3 |
| Small diff (≤10 lines) | **+20** | Total insertions+deletions ≤ 10 |
| Comment-only changes | **+50** | All changed lines are comments (`//`, `#`, `/*`, `<!--`) |
| Import-only changes | **+50** | All changed lines are imports/requires |
| Single file touched | **+15** | Only 1 file in `--name-only` |

#### Category 3: Contextual signals (compare with adjacent commits)

| Signal | Score | How to detect |
|--------|-------|---------------|
| Same files as previous commit | **+40** | `git show --name-only <sha>` overlaps with previous commit |
| Same author, < 60 sec apart | **+50** | Compare author dates |
| Same author, < 15 sec apart | **+70** | Almost certainly a fixup |
| Same author + same files + < 5 min | **+60** | Combine authorship, file set, and timing |
| Burst: 3+ tiny commits in 10 min | **+30** per commit | Same author, each ≤ 10 lines |

#### Scoring rules

- **Score 80+**: Almost certainly squashable → suggest without hesitation
- **Score 60-79**: Likely squashable → suggest with brief explanation
- **Score 40-59**: Possibly squashable → mention but don't push
- **Score < 40**: Probably intentional → don't suggest

Combine scores additively but cap at 100. A commit matching signals from 2+ categories
is almost always squashable.

#### Squashable message regex (for quick scan)

```
SQUASHABLE_PATTERNS = [
  /^(fixup|squash|amend)!\s/i,
  /^wip\b/i,
  /^(oops|whoops|forgot|missed|doh|argh)\b/i,
  /^(fix\s+)?(typo|typos|spelling|whitespace|indent(ation)?|formatting|lint(ing)?)\b/i,
  /^(minor|small|tiny|trivial|nit|cleanup|clean[\s-]?up|polish)\b/i,
  /fix(ed|es|ing)?\s+(the\s+)?(last|previous|prior|earlier)\s+commit/i,
  /address(ed|es|ing)?\s+(code[\s-]?)?review/i,
  /^(temp|tmp)\b/i,
  /^[.!?]+$/,
]
```

### Auto-detect procedure

```bash
# For each of the last 10 commits:
for sha in $(git log --format=%H -10); do
  score=0

  # 1. Message check (cheapest)
  msg=$(git log --format=%s -1 $sha)
  # Match against SQUASHABLE_PATTERNS → add score

  # 2. Diff size check
  stat=$(git show --stat --format="" $sha | tail -1)
  # Parse "N insertions, M deletions" → add score if small

  # 3. Context check (compare with previous commit)
  prev=$(git log --format=%H -1 --skip=1 $sha)
  # Compare author, timestamp, file sets → add score

  # Report: "Commit abc1234 'fix typo' — score 85 (message: +60, diff: +15, timing: +10)"
done
```

## Force Push Handling

After squashing commits that were already pushed:
- Ask: "These commits were already pushed. Force push to update the remote?"
- If on a feature branch: `git push --force-with-lease` (safer than `--force`)
- If on main/master: REFUSE unless the user explicitly says "force push to main"
- Always use `--force-with-lease` over `--force` to avoid overwriting others' work

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
