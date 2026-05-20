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

# Check if a branch was part of remote workflow (pushed at some point)
was_pushed() {
  local branch="$1"
  # Has remote tracking configured
  git config --get "branch.$branch.remote" > /dev/null 2>&1 && return 0
  # Has a remote tracking branch
  git show-ref --verify --quiet "refs/remotes/origin/$branch" && return 0
  # Has merge commits referencing this branch (PR workflow evidence)
  [[ -n $(git log --oneline --grep="$branch" --merges -1 2>/dev/null) ]] && return 0
  return 1
}

# merged (no was_pushed check: remote may be gone after PR merge)
for branch in $(git for-each-ref --format "%(refname:short)" refs/heads/ --merged); do
  if [[ "$branch" != "$current" ]]; then
    branches+=("$branch")
  fi
done

# squashed
for branch in $(git for-each-ref --format "%(refname:short)" refs/heads/); do
  if [[ "$branch" != "$current" ]] && was_pushed "$branch"; then
    mergeBase=$(git merge-base "$current" "$branch")
    if [[ $(git cherry "$current" "$(git commit-tree "$(git rev-parse "$branch^{tree}")" -p "$mergeBase" -m _)") == "-"* ]]; then
      # Avoid duplicates
      if [[ ! " ${branches[*]} " =~ " $branch " ]]; then
        branches+=("$branch")
      fi
    fi
  fi
done

# branches that were part of PR workflow (feature branches with remote deleted)
for branch in $(git for-each-ref --format "%(refname:short)" refs/heads/); do
  if [[ "$branch" != "$current" ]] && was_pushed "$branch"; then
    if [[ $(git rev-list --count "$current..$branch" 2>/dev/null) -gt 0 ]]; then
      if ! git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        if [[ ! " ${branches[*]} " =~ " $branch " ]]; then
          branches+=("$branch")
        fi
      fi
    fi
  fi
done

# branches whose upstream tracking was deleted on remote
while IFS= read -r line; do
  branch="${line%% *}"
  if [[ "$branch" != "$current" ]] && [[ ! " ${branches[*]} " =~ " $branch " ]]; then
    branches+=("$branch")
  fi
done < <(git for-each-ref --format "%(refname:short) %(upstream:track)" refs/heads/ | grep '\[gone\]')

# branches with closed/merged PRs (requires gh CLI)
if command -v gh &> /dev/null && gh auth status &> /dev/null; then
  pr_branches=$(gh pr list --state all --json headRefName,state \
    --jq '[.[] | select(.state != "OPEN")] | .[].headRefName' \
    --limit 500 2>/dev/null | sort -u)
  if [[ -n "$pr_branches" ]]; then
    for branch in $(git for-each-ref --format "%(refname:short)" refs/heads/); do
      if [[ "$branch" != "$current" ]] && [[ ! " ${branches[*]} " =~ " $branch " ]]; then
        if echo "$pr_branches" | grep -qxF "$branch"; then
          branches+=("$branch")
        fi
      fi
    done
  fi
fi

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
