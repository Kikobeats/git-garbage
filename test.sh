#!/usr/bin/env bash
set -uo pipefail

GARBAGE="${GARBAGE:-$(cd "$(dirname "$0")" && pwd)/garbage.sh}"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

failures=0

assert() {
  local message="$1"
  shift
  if "$@"; then
    echo "  ✔ $message"
  else
    echo "  ✖ $message" >&2
    printf '%s\n' "${output:-}" >&2
    failures=$((failures + 1))
  fi
}

refute() {
  local message="$1"
  shift
  if "$@"; then
    echo "  ✖ $message" >&2
    printf '%s\n' "${output:-}" >&2
    failures=$((failures + 1))
  else
    echo "  ✔ $message"
  fi
}

contains() {
  case "$1" in
    *"$2"*) return 0 ;;
    *) return 1 ;;
  esac
}

without_gh() {
  mkdir -p "$SANDBOX/bin"
  printf '#!/bin/sh\nexit 1\n' > "$SANDBOX/bin/gh"
  chmod +x "$SANDBOX/bin/gh"
  PATH="$SANDBOX/bin:$PATH"
}

git_quiet() {
  if ! git -c init.defaultBranch=master -c user.name=test -c user.email=test@test "$@" > /dev/null 2>&1; then
    echo "  fixture failed: git $*" >&2
    exit 1
  fi
}

create_repo() {
  local name="$1"
  git_quiet init --bare "$SANDBOX/$name.git"
  git_quiet clone "$SANDBOX/$name.git" "$SANDBOX/$name"
  git_quiet -C "$SANDBOX/$name" commit --allow-empty -m init
  git_quiet -C "$SANDBOX/$name" push -u origin master
}

merge_pushed_branch() {
  local repo="$1" branch="$2"
  git_quiet -C "$repo" switch -c "$branch"
  git_quiet -C "$repo" commit --allow-empty -m "$branch"
  git_quiet -C "$repo" push -u origin "$branch"
  git_quiet -C "$repo" switch master
  git_quiet -C "$repo" merge --ff-only "$branch"
  git_quiet -C "$repo" push origin master
  git_quiet -C "$repo" push origin --delete "$branch"
}

branch_exists() {
  git -C "$1" show-ref --verify --quiet "refs/heads/$2"
}

run_garbage() {
  (cd "$1" && printf 'y' | bash "$GARBAGE" 2>&1)
}

without_gh

echo "merged branch checked out in a clean linked worktree"
create_repo clean
merge_pushed_branch "$SANDBOX/clean" feature
git_quiet -C "$SANDBOX/clean" worktree add "$SANDBOX/clean-wt" feature
output="$(run_garbage "$SANDBOX/clean")"
refute "branch deleted" branch_exists "$SANDBOX/clean" feature
refute "worktree removed" test -d "$SANDBOX/clean-wt"
refute "no git error" contains "$output" "cannot delete branch"

echo "merged branch checked out in a dirty linked worktree"
create_repo dirty
merge_pushed_branch "$SANDBOX/dirty" feature
git_quiet -C "$SANDBOX/dirty" worktree add "$SANDBOX/dirty-wt" feature
touch "$SANDBOX/dirty-wt/wip.txt"
output="$(run_garbage "$SANDBOX/dirty")"
assert "branch kept" branch_exists "$SANDBOX/dirty" feature
assert "worktree kept" test -f "$SANDBOX/dirty-wt/wip.txt"
assert "skip reason printed" contains "$output" "uncommitted changes"

echo "merged branch checked out in a locked worktree"
create_repo locked
merge_pushed_branch "$SANDBOX/locked" feature
git_quiet -C "$SANDBOX/locked" worktree add "$SANDBOX/locked-wt" feature
git_quiet -C "$SANDBOX/locked" worktree lock "$SANDBOX/locked-wt"
output="$(run_garbage "$SANDBOX/locked")"
assert "branch kept" branch_exists "$SANDBOX/locked" feature
assert "worktree kept" test -d "$SANDBOX/locked-wt"
assert "skip reason printed" contains "$output" "locked worktree"
refute "not announced for removal" contains "$output" "and worktree"

echo "run from a linked worktree never touches the main checkout branch"
create_repo linked
merge_pushed_branch "$SANDBOX/linked" feature
git_quiet -C "$SANDBOX/linked" worktree add "$SANDBOX/linked-wt" feature
output="$(run_garbage "$SANDBOX/linked-wt")"
assert "main checkout branch kept" branch_exists "$SANDBOX/linked" master
assert "main checkout kept" test -d "$SANDBOX/linked"

echo "merged branch without worktree"
create_repo plain
merge_pushed_branch "$SANDBOX/plain" feature
output="$(run_garbage "$SANDBOX/plain")"
refute "branch deleted" branch_exists "$SANDBOX/plain" feature

echo "stale worktree whose directory is gone"
create_repo stale
merge_pushed_branch "$SANDBOX/stale" feature
git_quiet -C "$SANDBOX/stale" worktree add "$SANDBOX/stale-wt" feature
rm -rf "$SANDBOX/stale-wt"
output="$(run_garbage "$SANDBOX/stale")"
refute "branch deleted" branch_exists "$SANDBOX/stale" feature

if [[ $failures -gt 0 ]]; then
  echo && echo "$failures failure(s)" >&2
  exit 1
fi
