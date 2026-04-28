# Dep branch resolution

Resolve the dependency branch chain so this issue stacks on the dep's in-flight branch.

**Single dep** (`$CONFLICTS` contains exactly one issue ID):

```sh
# Fetch that dep's frontmatter and read its `pr-branch`:
./tracker.sh issue view "$CONFLICTS" --json body
CONFLICT_PR_BRANCH="{from dep issue frontmatter pr-branch field}" # e.g. "auth-token-storage"
# Override `BASE_BRANCH` with the dep's pr-branch so this issue stacks on top of it:
BASE_BRANCH="$CONFLICT_PR_BRANCH"
```

Surface the branching implication in the conflict question to the diver:

> "This issue will branch off `$CONFLICT_PR_BRANCH` (the in-flight branch of `$CONFLICTS`) instead of `main`, so both PRs can land together."

**Multi dep** (`$CONFLICTS` contains 2 or more issue IDs):

Ask the diver for the landing order:

> "Multiple blockers found: `$CONFLICTS`. What order should they land in? (I'll use the scan order as the default.)"

Wait for the diver to confirm or reorder. The sorted list becomes `ORDERED_CONFLICTS` (space-separated, e.g. `"#77 #83"`).

Walk the sorted list and daisy-chain the dep issues:

```sh
PREV_DEP_ID="{ID of the first dep in ORDERED_CONFLICTS}" # e.g. "#77"
PREV_PR_BRANCH="{pr-branch of the first dep in ORDERED_CONFLICTS}" # fetch from its frontmatter
for each NEXT_DEP (second dep onward in ORDERED_CONFLICTS):
  ./tracker.sh issue view "$NEXT_DEP" --json body,title
  NEXT_DEP_TITLE="{from dep issue title, without any existing [await: ...] suffix}"
  NEXT_DEP_BODY="{from dep issue body}"
  NEXT_DEP_BODY_UPDATED="{NEXT_DEP_BODY with base-branch frontmatter field set to PREV_PR_BRANCH}"
  ./tracker.sh issue edit "$NEXT_DEP" --title "$NEXT_DEP_TITLE [await: $PREV_DEP_ID]" --body "$NEXT_DEP_BODY_UPDATED"
  PREV_PR_BRANCH="{pr-branch of NEXT_DEP}" # fetch from its frontmatter
  PREV_DEP_ID="$NEXT_DEP"
done
```

After the loop, set this issue's base-branch to the last dep's pr-branch and collapse `CONFLICTS` to just the last dep ID (so the title suffix carries a single `[await: ...]`):

```sh
BASE_BRANCH="$PREV_PR_BRANCH" # last dep's pr-branch
CONFLICTS="$PREV_DEP_ID"      # last dep ID only
```
