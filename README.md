# create-github-pull-request

A composite action that commits the current working tree changes to a new branch
and opens a pull request.

If there are no working tree changes, or an open pull request already exists for
the head branch, the action exits successfully without creating anything. This
makes it safe to run on a schedule or after a generator step.

## Usage

```yaml
name: Update govulncheck

on:
  schedule:
    - cron: '0 10 * * 1'
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  update:
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout
        uses: actions/checkout@v6

      - name: Bump govulncheck
        id: bump-govulncheck
        uses: craigsloggett/bump-govulncheck@v1
        with:
          file: Makefile
          match: '^GOVULNCHECK_VERSION'
          replace: 'GOVULNCHECK_VERSION   := {version}'

      - name: Open Pull Request
        uses: craigsloggett/create-github-pull-request@v1
        with:
          pull-request-head-branch: update-govulncheck-${{ steps.bump-govulncheck.outputs.version }}
          commit-message: 'chore(build): Update govulncheck to ${{ steps.bump-govulncheck.outputs.version }}'
```

In the minimal case shown above, the action derives:

- The pull request title from the first line of `commit-message`.
- The pull request body from any subsequent lines (empty if the commit message is single-line).
- The base branch from the repository's default branch (`github.event.repository.default_branch`).
- The authentication token from `github.token`, which the runner provides automatically when the workflow grants the appropriate permissions.

The workflow's `permissions:` block must grant `contents: write` (to push the
branch) and `pull-requests: write` (to open the PR). The default `github.token`
is sufficient for both.

## Triggering Pull Request Checks

PRs created by this action using the default `GITHUB_TOKEN` will **not** trigger
`on: pull_request` or `on: push` workflows. This is [a deliberate GitHub safety measure](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#using-the-github_token-in-a-workflow)
to prevent recursive workflow runs.

If you need CI to run on the opened PR, authenticate with one of:

1. A fine-grained Personal Access Token (PAT):

```yaml
- name: Checkout
  uses: actions/checkout@v6
  with:
    token: ${{ secrets.GH_TOKEN }}

- name: Open Pull Request
  uses: craigsloggett/create-github-pull-request@v1
  with:
    pull-request-head-branch: my-branch
    commit-message: 'chore: update something'
    github-token: ${{ secrets.GH_TOKEN }}
```

The PAT needs `Contents: Read/Write` and `Pull Requests: Read/Write` on the
target repo.

2. A GitHub App installation token:

```yaml
- name: Get App token
  id: app-token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ vars.APP_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}

- name: Checkout
  uses: actions/checkout@v6
  with:
    token: ${{ steps.app-token.outputs.token }}

- name: Open Pull Request
  uses: craigsloggett/create-github-pull-request@v1
  with:
    pull-request-head-branch: my-branch
    commit-message: 'chore: update something'
    github-token: ${{ steps.app-token.outputs.token }}
```

The App needs `Contents: Read/Write` and `Pull Requests: Read/Write` permissions
on the repos it's installed in.

### Security

If you provide a PAT or App token to this action so downstream workflows trigger
on the PRs it opens, be aware that **those downstream workflows also have access
to the elevated token** if they use the same secret.

Two specific patterns to avoid:

1. `pull_request_target` checking out the PR's head ref.

`pull_request_target` runs in the base repo's context with full secrets,
including secrets a fork would not normally see. If you combine it with
`actions/checkout` configured to check out `github.event.pull_request.head.sha`
(or `head.ref`), you are running untrusted fork code with trusted credentials.
Don't do this unless you have a specific reason and you've stripped secrets from
the environment first.

2. Workflows triggered by this action's PRs running without an owner check.

If your CI workflow uses `on: pull_request` and one of your jobs needs the
elevated token (e.g., to comment on the PR or update a status), guard the job so
it only runs for PRs from the repository itself, not forks:

```yaml
jobs:
  privileged:
    if: github.event.pull_request.head.repo.full_name == github.repository
    runs-on: ubuntu-24.04
    steps:
      # ... steps that use secrets
```

`github.event.pull_request.head.repo.full_name` is the `owner/repo` of where the
PR's branch lives. Comparing it to `github.repository` (the base repo) returns
true only when the PR comes from a branch in the same repository. PRs from forks
have a different `head.repo.full_name`, so the job is skipped.

This action itself only opens PRs from branches within the repository, so its
PRs always pass this check. The guard exists to protect *any* workflow that
might run privileged steps on a PR, not just this action's output.

## Inputs

| Input                      | Required | Default                                                 | Description                                         |
| -------------------------- | -------- | ------------------------------------------------------- | --------------------------------------------------- |
| `pull-request-title`       | No       | First line of `commit-message`                          | The pull request title.                             |
| `pull-request-body`        | No       | Remainder of `commit-message` after the first line      | The pull request body.                              |
| `pull-request-head-branch` | Yes      |                                                         | The branch name to push the changes to.             |
| `pull-request-base-branch` | No       | Repository default branch                               | The base branch to open the pull request against.   |
| `commit-message`           | Yes      |                                                         | The commit message for the working tree changes.    |
| `git-user-name`            | No       | `github-actions[bot]`                                   | The git `user.name` used for the commit.            |
| `git-user-email`           | No       | `41898282+github-actions[bot]@users.noreply.github.com` | The git `user.email` used for the commit.           |
| `github-token`             | No       | `${{ github.token }}`                                   | The token used to authenticate with the GitHub API. |

## Outputs

| Output                | Description                                                                   |
| --------------------- | ----------------------------------------------------------------------------- |
| `pull-request-url`    | The URL of the created pull request. Empty if no pull request was created.    |
| `pull-request-number` | The number of the created pull request. Empty if no pull request was created. |
