# 002 GitHub API PR Attribution

**Issue**: #201  
**Parent**: #48 — AI-authored PRs: enable proper self-review  
**Question**: Can the GitHub REST or GraphQL API open a pull request attributed to a different author than the authenticated token owner — and if so, would that make the PR reviewable by the token owner?

## Finding: Both APIs are dead ends for author override

Neither the REST API nor the GraphQL API exposes any mechanism to attribute a PR to a user other than the authenticated token owner.

### REST API — `POST /repos/{owner}/{repo}/pulls`

The endpoint accepts these body parameters:

| Parameter | Type | Required |
| --- | --- | --- |
| `title` | string | yes (or `issue`) |
| `head` | string | yes |
| `head_repo` | string | no |
| `base` | string | yes |
| `body` | string | no |
| `maintainer_can_modify` | boolean | no |
| `draft` | boolean | no |
| `issue` | integer | no |

No `author`, `user`, or any attribution field exists. The PR `user` field in the response is always set to the account whose token made the request.

Source: https://docs.github.com/en/rest/pulls/pulls#create-a-pull-request

### GraphQL API — `createPullRequest` mutation

The `CreatePullRequestInput` object accepts:

| Field | Type | Required |
| --- | --- | --- |
| `repositoryId` | ID | yes |
| `baseRefName` | String | yes |
| `headRefName` | String | yes |
| `title` | String | yes |
| `body` | String | no |
| `headRepositoryId` | ID | no |
| `maintainerCanModify` | Boolean | no |
| `draft` | Boolean | no |
| `clientMutationId` | String | no |

No author field exists. GitHub's own docs for the related `createCommitOnBranch` mutation make the policy explicit: "this mutation does not support specifying the author or committer of the commit and will not add support for this in the future. A commit created by a successful execution of this mutation will be authored by the owner of the credential which authenticates the API request." The same policy applies to `createPullRequest`.

Source: https://docs.github.com/en/graphql/reference/input-objects#createpullrequestinput

## Finding: The self-review restriction is enforced by PR opener identity, not commit authorship

GitHub determines review eligibility from the account that opened the PR (the API token owner), not from the git commit author field. This is confirmed by:

- GitHub Docs: "Pull request authors cannot approve their own pull requests."
- Community discussions confirm: the restriction applies to "the person who created the PR", not the person who authored the commits.
- The `peter-evans/create-pull-request` action docs state explicitly: "the user account [whose PAT opened the PR] will be unable to perform actions such as request changes or approve the pull request."

Source: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/approving-a-pull-request-with-required-reviews  
Source: https://github.com/peter-evans/create-pull-request/blob/main/docs/concepts-guidelines.md  
Source: https://github.com/orgs/community/discussions/6292

## Answer to the acceptance criteria

**Can `POST /repos/{owner}/{repo}/pulls` create a PR whose "author" differs from the authenticated token?**  
No. There is no `author` parameter. The PR opener is always the token owner.

**Does the GraphQL `createPullRequest` mutation support author override?**  
No. The `CreatePullRequestInput` has no author field. GitHub's stated policy is that the authenticated credential owner is always the attributed actor, and the API will not add author override support.

**If both paths are dead ends: why does the API always pin PR authorship to the token owner?**  
GitHub's authentication model ties every write action to the authenticated identity — the account associated with the token. There is no impersonation mechanism available to PATs or fine-grained tokens. Because PR authorship is a write action (creating the PR resource), it is always attributed to the token owner. This is by design and is not circumventable via the API without a separate identity (e.g., a GitHub App acting on behalf of a user, or a second PAT from a different account).

## Implications for the reef

Changing the git commit `--author` (covered in sibling issue #200) is orthogonal to this question: even if commits carry a different author name, the PR opener — and therefore the account blocked from self-review — is always the account whose token called `gh pr create`. No API trick can decouple these two identities using a single token.

The only lightweight path that keeps a single token and still allows the token owner to review the PR is one where someone or something else opens the PR. Options to explore in synthesis (#203): a GitHub App token acting on behalf of a user, or pushing via a second PAT from a dedicated machine account.
