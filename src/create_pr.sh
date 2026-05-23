#!/bin/sh

set -euf

if [ -z "$(git status --porcelain)" ]; then
  printf 'No working tree changes. Skipping pull request.\n'
  exit 0
fi

if gh pr list --head "${BRANCH}" --state open --json number |
  jq -e 'length > 0' >/dev/null; then
  printf 'A pull request for %s already exists. Skipping.\n' "${BRANCH}"
  exit 0
fi

git config user.name "${GIT_USER_NAME}"
git config user.email "${GIT_USER_EMAIL}"

git checkout -b "${BRANCH}"
git add -A
git commit -m "${COMMIT_MESSAGE}"
git push -u origin "${BRANCH}"

PR_URL=$(gh pr create \
  --title "${TITLE}" \
  --body "${BODY}" \
  --base "${BASE}" \
  --head "${BRANCH}")

PR_NUMBER=$(printf '%s\n' "${PR_URL}" | sed 's|.*/||')

printf 'pull-request-url=%s\n' "${PR_URL}" >>"${GITHUB_OUTPUT}"
printf 'pull-request-number=%s\n' "${PR_NUMBER}" >>"${GITHUB_OUTPUT}"
