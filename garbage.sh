#!/usr/bin/env bash

if test -n "$(git status --porcelain)"; then
  echo 'Unclean working tree. Commit or stash changes first.' >&2;
  exit 1;
fi

if ! git fetch --prune --quiet 2> /dev/null; then
  echo 'There was a problem fetching your branch.' >&2;
  exit 1;
fi

current="$(git rev-parse --abbrev-ref HEAD)"

declare -a branches

# merged
for branch in $(git for-each-ref --format "%(refname:short)" refs/heads/ --merged); do
  if [[ "$branch" != "$current" ]]; then
    branches+=("$branch")
  fi
done

# squashed
for branch in $(git for-each-ref --format "%(refname:short)" refs/heads/); do
  if [[ "$branch" != "$current" ]]; then
    mergeBase=$(git merge-base "$current" "$branch")
    if [[ $(git cherry "$current" "$(git commit-tree "$(git rev-parse "$branch^{tree}")" -p "$mergeBase" -m _)") == "-"* ]]; then
      branches+=("$branch")
    fi
  fi
done

# branches that were part of PR workflow (feature branches with remote deleted)
for branch in $(git for-each-ref --format "%(refname:short)" refs/heads/); do
  if [[ "$branch" != "$current" ]]; then
    # Check if branch has commits not in main (indicating it was a feature branch)
    if [[ $(git rev-list --count "$current..$branch" 2>/dev/null) -gt 0 ]]; then
      # Check if remote branch doesn't exist (indicating PR was closed and branch deleted)
      if ! git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        # Check if branch is already in our list to avoid duplicates
        branch_exists=false
        for existing_branch in "${branches[@]}"; do
          if [[ "$existing_branch" == "$branch" ]]; then
            branch_exists=true
            break
          fi
        done
        if [[ "$branch_exists" == false ]]; then
          branches+=("$branch")
        fi
      fi
    fi
  fi
done

if [[ ${#branches[@]} -eq 0 ]]; then
  printf "\n  Nothing to garbage."
  exit
fi

echo
printf '  %s\n' "${branches[@]}"
echo

read -rp "  Will be removed. Continue? (y/N) " -n 1

if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo && echo
  message=$(git branch -D "${branches[@]}")
  echo "${message//Deleted/  Deleted}"
fi
