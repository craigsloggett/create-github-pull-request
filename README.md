# create-github-pull-request

A composite action that commits the current working tree changes to a new branch and opens a pull request.

It is a no-op when the working tree is clean or a pull request already exists for the branch, so it can be chained safely after the [`craigsloggett/bump-*`](https://github.com/craigsloggett?tab=repositories&q=bump-) actions or any other step that may or may not produce changes.

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
        with:
          token: ${{ secrets.GH_TOKEN }}

      - name: Bump govulncheck
        id: bump
        uses: craigsloggett/bump-govulncheck@v1
        with:
          file: Makefile
          match: '^GOVULNCHECK_VERSION'
          replace: 'GOVULNCHECK_VERSION   := {version}'

      - name: Open Pull Request
        uses: craigsloggett/create-github-pull-request@v1
        with:
          branch: update-govulncheck-${{ steps.bump.outputs.version }}
          title: 'build: Update govulncheck to ${{ steps.bump.outputs.version }}'
          commit-message: 'build: Update govulncheck to ${{ steps.bump.outputs.version }}'
          github-token: ${{ secrets.GH_TOKEN }}
```

### Inputs

| Input            | Required? | Default                                                       | Description                                                                                              |
| ---------------- | --------- | ------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `branch`         | `true`    |                                                               | The branch name to push the changes to.                                                                  |
| `base`           | `false`   | `main`                                                        | The base branch to open the pull request against.                                                        |
| `title`          | `true`    |                                                               | The pull request title.                                                                                  |
| `body`           | `false`   | `''`                                                          | The pull request body.                                                                                   |
| `commit-message` | `true`    |                                                               | The commit message for the working tree changes.                                                         |
| `github-token`   | `true`    |                                                               | The token used to authenticate with the GitHub API to create the pull request.                           |
| `git-user-name`  | `false`   | `github-actions[bot]`                                         | The git `user.name` used for the commit.                                                                 |
| `git-user-email` | `false`   | `41898282+github-actions[bot]@users.noreply.github.com`       | The git `user.email` used for the commit.                                                                |

### Outputs

| Output                | Description                                                              |
| --------------------- | ------------------------------------------------------------------------ |
| `pull-request-url`    | The URL of the created pull request, or empty if no pull request was created. |
| `pull-request-number` | The number of the created pull request, or empty if no pull request was created. |
