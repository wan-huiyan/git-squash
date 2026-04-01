# Squash Detection Scoring Heuristics

Score each commit 0-100. Commits scoring **60+** are "likely squashable." Combine signals
from multiple categories for higher confidence.

## Category 1: Message signals (check first — cheapest)

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

## Category 2: Diff signals (run `git show --stat` and `git show --diff-filter`)

| Signal | Score | How to detect |
|--------|-------|---------------|
| Whitespace-only | **+90** | `git show <sha> --ignore-all-space` produces empty diff |
| Rename-only | **+60** | `git show <sha> --diff-filter=R --name-only` matches all changes |
| Very small diff (<=3 lines) | **+40** | Parse `git show --stat` — total insertions+deletions <= 3 |
| Small diff (<=10 lines) | **+20** | Total insertions+deletions <= 10 |
| Comment-only changes | **+50** | All changed lines are comments (`//`, `#`, `/*`, `<!--`) |
| Import-only changes | **+50** | All changed lines are imports/requires |
| Single file touched | **+15** | Only 1 file in `--name-only` |

## Category 3: Contextual signals (compare with adjacent commits)

| Signal | Score | How to detect |
|--------|-------|---------------|
| Same files as previous commit | **+40** | `git show --name-only <sha>` overlaps with previous commit |
| Same author, < 60 sec apart | **+50** | Compare author dates |
| Same author, < 15 sec apart | **+70** | Almost certainly a fixup |
| Same author + same files + < 5 min | **+60** | Combine authorship, file set, and timing |
| Burst: 3+ tiny commits in 10 min | **+30** per commit | Same author, each <= 10 lines |

## Scoring rules

- **Score 80+**: Almost certainly squashable -> suggest without hesitation
- **Score 60-79**: Likely squashable -> suggest with brief explanation
- **Score 40-59**: Possibly squashable -> mention but don't push
- **Score < 40**: Probably intentional -> don't suggest

Combine scores additively but cap at 100. A commit matching signals from 2+ categories
is almost always squashable.

## Squashable message regex (for quick scan)

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

## Auto-detect procedure

```bash
# For each of the last 10 commits:
for sha in $(git log --format=%H -10); do
  score=0

  # 1. Message check (cheapest)
  msg=$(git log --format=%s -1 $sha)
  # Match against SQUASHABLE_PATTERNS -> add score

  # 2. Diff size check
  stat=$(git show --stat --format="" $sha | tail -1)
  # Parse "N insertions, M deletions" -> add score if small

  # 3. Context check (compare with previous commit)
  prev=$(git log --format=%H -1 --skip=1 $sha)
  # Compare author, timestamp, file sets -> add score

  # Report: "Commit abc1234 'fix typo' — score 85 (message: +60, diff: +15, timing: +10)"
done
```
