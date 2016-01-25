#!/usr/bin/env sh

if test -n "$(git status --porcelain)"; then
  echo 'Unclean working tree. Commit or stash changes first.' >&2;
  exit 128;
fi

if ! git fetch --quiet 2> /dev/null; then
  echo 'There was a problem fetching your branch.' >&2;
  exit 128;
fi

EXCLUDE_BRANCHS="*|master"
NEGATIVE_GREP="^\\"
GREP_CMD=$NEGATIVE_GREP$EXCLUDE_BRANCHS
BRANCHES=$(git branch --merged | egrep -v "$GREP_CMD")

[[ -z  $BRANCHES  ]] && echo "\n  Nothing to garbage." && exit

echo
echo "$BRANCHES"
echo

read -rp "  Will be removed. Continue? (y/N) " -n 1

if [[ $REPLY =~ ^[Yy]$ ]]; then
  MESSAGE=$(git for-each-ref --format "%(refname:short)" refs/heads/ --merged | egrep -v "$GREP_CMD" | xargs git branch -d)
  echo && echo && echo "$MESSAGE" | sed 's/Deleted/  Deleted/g'
fi
