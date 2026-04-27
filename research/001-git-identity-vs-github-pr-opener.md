---
issue: "#200"
parent-issue: "#48"
date: "2026-04-26"
---

# 001 Git identity vs GitHub PR opener

## Summary

Git commit author identity and GitHub PR opener identity are **fully independent and separately controllable**. The PR opener is determined solely by the GitHub API token used to call `POST /repos/{owner}/{repo}/pulls` (or `gh pr create`). No git-side manipulation changes who GitHub considers the PR opener. As a result, the self-review restriction ("Pull request authors can't approve their own pull request") applies to the **GitHub account that opened the PR**, not to any commit author listed in the branch history.

This means that if the reef opens a PR using the diver's personal access token, the diver is the PR opener and cannot use "Request changes" or "Approve" on that PR — regardless of what name or email appears in the git commits.

## Question 1 — Does `git commit --author` affect who GitHub considers the PR opener for review-eligibility purposes?

**Answer: No.**

The git author field (`git commit --author "Name <email>"` or `git config user.name / user.email`) is stored in the commit object and is purely cosmetic metadata from GitHub's identity system perspective. It controls:

- Who gets the green contribution square on the commits page
- Who appears in `git log --author`
- The "authored by" display on the commit detail page

It does **not** control:

- Which GitHub account is considered the PR opener
- Which account is subject to the self-review restriction
- Who GitHub's review eligibility checks run against

Evidence:
- GitHub CLI maintainer confirmed: "gh can only act as the user whose auth token it has… all actions will be taken on its behalf." (source: [cli/cli#6616](https://github.com/cli/cli/issues/6616), closed as not planned)
- The `gh pr create` command has no `--author` flag; a request to add one was rejected on security grounds — "it would be problematic if one user could create pull requests attributed to another user."
- The `POST /repos/{owner}/{repo}/pulls` REST API has no author-override parameter. The PR `user` field in the API response always reflects the token owner.

## Question 2 — Are git author identity and GitHub API token identity independently controllable?

**Answer: Yes — they are fully independent, and only the token identity matters for PR authorship.**

| Identity layer | What controls it | Affects PR review restriction? |
| --- | --- | --- |
| Git commit author name/email | `git config user.name/email` or `--author` flag | No |
| Git commit committer name/email | Signing config, merge operator | No |
| GitHub PR opener | API token used to call `gh pr create` or REST POST | Yes — this is the identity GitHub enforces |

You can set any arbitrary name and email in `git config` or via `--author` while being authenticated as a completely different GitHub account. The PR will open under the token account's identity no matter what the commit metadata says.

## Survey of lightweight tricks

### 1. `git commit --author "Name <email>"`

**Assessment: Dead end for PR opener identity.**

Changes the git commit's author metadata only. GitHub links commits to accounts via email matching (when the email matches a verified GitHub account email), but this affects commit attribution display only — not the PR opener. The review restriction is checked against the PR opener account, not commit authors.

### 2. `git config user.name / user.email`

**Assessment: Dead end for PR opener identity.**

Same as above. Setting `user.email` to a different user's verified GitHub email would attribute the commits to that user in the git graph, but the PR opener remains the token holder.

Note: if email privacy is enabled on the target account, GitHub may even block the push if the commit author email doesn't match the authenticated user's noreply address.

### 3. `on-behalf-of:` commit trailer

**Assessment: Dead end for PR opener identity.**

The `on-behalf-of: @org <name@organization.com>` trailer adds a badge to commits showing they were contributed on behalf of an organization. It does not affect which GitHub account is considered the PR opener, and no evidence exists that it affects review eligibility checks.

Sources: [GitHub Docs — Creating a commit on behalf of an organization](https://docs.github.com/en/pull-requests/committing-changes-to-your-project/creating-and-editing-commits/creating-a-commit-on-behalf-of-an-organization)

### 4. `Co-authored-by:` commit trailer

**Assessment: Dead end for PR opener identity.**

Adds co-authorship attribution to commits, which is reflected in the GitHub UI and contribution graphs. It does not change who opened the PR. Being listed as a co-author of commits does not make you a co-author of the PR for review-restriction purposes.

The GitHub community has discussed whether co-commit-authorship should affect PR review eligibility, but no such feature exists. (Source: community discussion #6292, #14866)

### 5. Squash attribution (`squash and merge` changing commit author)

**Assessment: Dead end for PR opener identity — affects merge commit only.**

Since September 2022, GitHub displays the git commit author before performing a squash merge. When squash merging, the PR branch author becomes the author of the resulting squash commit. But this is about the *resulting merge commit* — it has no effect on the PR's opener identity while the PR is open, and therefore does not affect who can review it.

Source: [GitHub Changelog, Sept 2022](https://github.blog/changelog/2022-09-15-git-commit-author-shown-when-squash-merging-a-pull-request/)

### 6. Push-on-behalf-of (GitHub Enterprise only)

**Assessment: Not applicable — enterprise-only, not a lightweight trick.**

GitHub Enterprise Server supports admin impersonation via `sudo` API tokens. This is not available on GitHub.com and requires Site Admin access. Not relevant to this problem.

### 7. GitHub Actions `GITHUB_TOKEN` as PR opener

**Assessment: Viable alternative identity — creates PRs as `github-actions[bot]`.**

If a GitHub Actions workflow opens a PR using the built-in `GITHUB_TOKEN`, the PR opener is `github-actions[bot]`, not the human user. This means the human user can review, approve, and request changes on such PRs.

Limitations:
- Requires a GitHub Actions workflow to trigger PR creation (not a pure reef-skill approach)
- PRs opened by `github-actions[bot]` do not themselves trigger `pull_request` workflows (requires a PAT to bypass)
- Constitutes a significant setup burden on the user (creating and wiring Actions workflows)

### 8. GitHub App installation token as PR opener

**Assessment: Viable but requires user setup — out of scope per parent issue #48.**

A GitHub App installation token opens PRs as `{app-name}[bot]`, making the human user the reviewer. However, this requires registering a GitHub App and configuring it on the repository, which the parent issue explicitly ruled out.

### 9. Changing the PR opener after creation

**Assessment: Not possible — GitHub has no API to reassign PR authorship.**

The GitHub community has requested a "change PR author" feature since at least April 2022 ([community/discussions#15067](https://github.com/orgs/community/discussions/15067)). It remains unimplemented. There is no REST or GraphQL API to reassign a PR's opener after creation.

### 10. Draft PR then convert to ready

**Assessment: Does not change PR author identity.**

Converting a draft PR to ready-for-review does not change which account is considered the PR opener.

## Self-review restriction: confirmed behavior

- GitHub's restriction reads: "Pull request authors can't request changes on their own pull request" and "Pull request authors cannot approve their own pull requests."
- This has been a stable, intentional design since at least 2021. As of April 2026, no GitHub-native feature exists to allow PR authors to review their own PRs.
- The restriction is enforced at the GitHub application layer based on the `user.login` stored when the PR was created — not based on git history.
- Community discussions (#6292, #46345, #14866) requesting this feature remain open and unanswered by GitHub staff.

## Follow-up questions surfaced

1. Can sibling issue #201's research (GitHub REST/GraphQL API PR attribution) uncover any undocumented parameter that overrides the `user` field? This research found none, but #201 should confirm via direct API call testing if possible.
2. What is the minimum viable alternative? The synthesis issue (#203) should evaluate whether the GitHub Actions `GITHUB_TOKEN` workflow approach (trick 7) is lightweight enough given the scope constraints — it is the only option that avoids a dedicated bot account while still enabling self-review.
