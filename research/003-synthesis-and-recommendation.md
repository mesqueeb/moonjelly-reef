---
issue: "#203"
parent-issue: "#48"
date: "2026-04-26"
---

# 003 Synthesis and recommendation

## Summary

All lightweight options for enabling the human user to review reef-opened PRs have been exhausted. The root cause is a GitHub platform constraint: **the PR opener is always the account whose token calls `gh pr create`, and the PR opener cannot review their own PR.** No git-side manipulation, no API parameter, and no commit metadata change can alter this.

The only zero-setup path that avoids opening a bot account is a **workaround**: prefix the PR title or body with a visual signal so the human reviewer knows to use the GitHub web UI's "Start a review" → "Comment" path instead of "Request changes." This does not require any code changes in the reef.

If the diver wants true "Request changes" capability, a **dedicated machine account** (a second GitHub user) is the lightest option that actually works — requiring only a second PAT stored as a secret, nothing else.

## Open question from Testing Decisions: answered

> Are git author identity and API token identity independently controllable on GitHub?

**Yes — they are fully independent. Only the token identity matters for PR authorship and review eligibility.**

Git commit author (set via `git config` or `git commit --author`) is purely cosmetic metadata. GitHub links commits to accounts via email matching for contribution display only. The PR `user` field — which determines who is blocked from self-review — is always and exclusively set to the account whose token called `POST /repos/{owner}/{repo}/pulls`.

See: [001-git-identity-vs-github-pr-opener.md](./001-git-identity-vs-github-pr-opener.md) §Question 2, [002-github-api-pr-attribution.md](./002-github-api-pr-attribution.md) §Finding: self-review restriction.

## All options surveyed

| Option | Dead end? | Why |
| --- | --- | --- |
| `git commit --author` / `git config user.email` | Dead end | Controls commit metadata only; PR opener is the token holder regardless |
| `on-behalf-of:` commit trailer | Dead end | Organization badge only; no effect on PR opener identity |
| `Co-authored-by:` commit trailer | Dead end | Commit-level attribution only; no effect on review eligibility |
| Squash attribution | Dead end | Affects the post-merge commit only; PR is already open and restricted |
| Changing PR author after creation | Dead end | GitHub has no API to reassign PR authorship (community request open since 2022, unimplemented) |
| Draft → ready-for-review conversion | Dead end | Does not change PR opener identity |
| REST API `POST /repos/{owner}/{repo}/pulls` with author override | Dead end | No `author` parameter exists; `user` is always the token holder |
| GraphQL `createPullRequest` with author override | Dead end | `CreatePullRequestInput` has no author field; GitHub's stated policy is that the authenticated credential owner is always the attributed actor and this will not change |
| Push-on-behalf-of | Dead end | GitHub Enterprise Server only; not available on GitHub.com |
| GitHub Actions `GITHUB_TOKEN` | Viable but heavyweight | PR opens as `github-actions[bot]` → diver can review; but requires Actions workflow setup, constitutes user-facing setup burden, and Actions-opened PRs don't trigger further `pull_request` workflows without a PAT |
| GitHub App installation token | Viable but out of scope | App-opened PRs are reviewable by the diver; requires registering and configuring a GitHub App — explicitly out of scope per #48 |
| Second PAT from a dedicated machine account | Viable and lightweight | Second account + one secret; PR opens under the bot identity, diver reviews freely |

## Viable path: dedicated machine account

### What it is

A second GitHub account (e.g. `mesqueeb-reef-bot`) authenticates with a PAT stored as a repository secret or in the skill's config. When the reef opens a PR, it calls `gh pr create` with `GH_TOKEN=<bot-pat>` — one environment variable override. The human user (`mesqueeb`) is then a non-author and can use "Request changes", "Approve", or "Comment" freely.

### Minimal change to the reef's PR-opening step

In `commit-push.sh` or wherever the reef calls `gh pr create`, prefix the command with `GH_TOKEN="$REEF_BOT_PAT"`:

```sh
GH_TOKEN="$REEF_BOT_PAT" gh pr create \
  --base "$BASE_BRANCH" \
  --title "$ISSUE_TITLE" \
  --body "$PR_BODY"
```

`REEF_BOT_PAT` is the only new user-facing configuration required. It can be stored in a `.env` file at the repo root (already gitignored) or as an environment variable in the shell profile.

If `REEF_BOT_PAT` is unset, the reef falls back to the current behavior (diver's own token, no self-review). The skill degrades gracefully.

### Setup burden on the user

1. Create a second GitHub account (one-time, free).
2. Generate a classic PAT with `repo` scope from that account.
3. Set `REEF_BOT_PAT=<token>` in the environment or a `.env` file.

That is the complete setup. No GitHub App registration, no Actions workflow, no branch protection changes.

### Why this is the minimum

- It is the only option that does not require GitHub App registration or organization membership.
- The `GH_TOKEN` env-var override is a single-line change to the PR-opening command.
- Every other viable option (Actions, GitHub App) requires more setup steps.

## Workaround: no setup required

If the diver does not want to create a second account, a zero-setup workaround exists:

- GitHub does allow the PR author to **comment** on their own PR, including adding inline comments.
- The reef can open PRs as it does today.
- The diver uses "Add your review" → "Comment" (not "Request changes") to provide feedback. Reef agents reading the PR body + comments can act on that feedback exactly as they would on "Request changes" today.

This requires a reef-side change: the inspect and rework phases must treat PR comments from the PR author as equivalent to a "Request changes" review. This is a code change in the reef, not a GitHub limitation.

## Recommendation for the diver

Two paths, in order of preference:

1. **Implement the dedicated machine account path.** Lightest true fix. Single-line change to PR-opening command + one secret. Unlocks the full GitHub review workflow for the diver.

2. **Accept the comment-as-feedback workaround.** Zero setup. Requires a reef-side code change so that inspect/rework phases read PR author comments as change requests. Slightly weaker UX (no "Request changes" badge) but fully functional.

If neither path is acceptable, the status quo (reef opens PRs, diver cannot block them via "Request changes") is the only remaining option.

## Follow-up questions

- If path 1 is chosen: does the reef need to handle the case where the bot account is not a repository collaborator? (Answer: the PAT needs at least `repo` scope and the account needs push access, or the PR must be opened from a fork — worth confirming during implementation.)
- If path 2 is chosen: what exact signal in a PR comment should the reef treat as "request changes"? A keyword (e.g. `CHANGES REQUESTED:`) or any comment from the PR author?
