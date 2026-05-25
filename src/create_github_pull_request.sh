#!/bin/sh

set -euf

# Required user inputs.
: "${COMMIT_MESSAGE:?COMMIT_MESSAGE is required}"
: "${PULL_REQUEST_HEAD_BRANCH:?PULL_REQUEST_HEAD_BRANCH is required}"
: "${PULL_REQUEST_BASE_BRANCH:?PULL_REQUEST_BASE_BRANCH is required}"
: "${GIT_USER_NAME:?GIT_USER_NAME is required}"
: "${GIT_USER_EMAIL:?GIT_USER_EMAIL is required}"

# GitHub Actions runtime environment.
: "${GH_TOKEN:?GH_TOKEN is unset, most likely during testing}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is unset, most likely during testing}"

# Required tools.
for utility in jq gh; do
  if ! command -v "${utility}" >/dev/null; then
    printf '%s is not installed. Unable to create a pull request.\n' "${utility}" >&2
    exit 1
  fi
done

# Derived defaults.
if [ -z "${PULL_REQUEST_TITLE:-}" ]; then
  PULL_REQUEST_TITLE="$(printf '%s' "${COMMIT_MESSAGE}" | head -n 1)"
fi

if [ -z "${PULL_REQUEST_BODY:-}" ]; then
  PULL_REQUEST_BODY="$(
    printf '%s' "${COMMIT_MESSAGE}" |
      tail -n +2 |
      sed '/./,$!d'
  )"
fi

if [ -z "$(git status --porcelain)" ]; then
  printf 'No working tree changes. Skipping pull request.\n'
  exit 0
fi

if gh pr list --head "${PULL_REQUEST_HEAD_BRANCH}" --state open --json number |
  jq -e 'length > 0' >/dev/null; then
  printf 'A pull request for %s already exists. Skipping.\n' "${PULL_REQUEST_HEAD_BRANCH}"
  exit 0
fi

git config user.name "${GIT_USER_NAME}"
git config user.email "${GIT_USER_EMAIL}"

git checkout -b "${PULL_REQUEST_HEAD_BRANCH}"
git add -A
git commit -m "${COMMIT_MESSAGE}"
git push -u origin "${PULL_REQUEST_HEAD_BRANCH}"

PULL_REQUEST_URL="$(
  gh pr create \
    --title "${PULL_REQUEST_TITLE}" \
    --body "${PULL_REQUEST_BODY}" \
    --base "${PULL_REQUEST_BASE_BRANCH}" \
    --head "${PULL_REQUEST_HEAD_BRANCH}"
)"

printf 'pull-request-url=%s\n' "${PULL_REQUEST_URL}" >>"${GITHUB_OUTPUT}"
printf 'pull-request-number=%s\n' "${PULL_REQUEST_URL##*/}" >>"${GITHUB_OUTPUT}"
