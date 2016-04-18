#!/usr/bin/env sh

if test -n "$(git status --porcelain)"; then
  echo 'Unclean working tree. Commit or stash changes first.' >&2;
  exit 128;
fi

if ! git fetch --quiet 2> /dev/null; then
  echo 'There was a problem fetching your branch.' >&2;
  exit 128;
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

garbage() {
  git for-each-ref --format "${1:-}%(refname:short)" refs/heads/ --merged | egrep -v "$CURRENT_BRANCH"
}

BRANCHES=$(garbage "  ")

if [[ -z  $BRANCHES ]]; then
  printf "\n  Nothing to garbage."
  exit
fi

echo && echo "$BRANCHES" && echo
read -rp "  Will be removed. Continue? (y/N) " -n 1

if [[ $REPLY =~ ^[Yy]$ ]]; then
  MESSAGE=$(garbage | xargs git branch -d)
  echo && echo && echo "$MESSAGE" | sed 's/Deleted/  Deleted/g'
fi
