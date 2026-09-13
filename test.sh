#!/usr/bin/env bash
set -uo pipefail

GARBAGE="$(cd "$(dirname "$0")" && pwd)/garbage.sh"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

failures=0

fail() {
  echo "  ✖ $1" >&2
  failures=$((failures + 1))
}

pass() {
  echo "  ✔ $1"
}

without_gh() {
  mkdir -p "$SANDBOX/bin"
  printf '#!/bin/sh\nexit 1\n' > "$SANDBOX/bin/gh"
  chmod +x "$SANDBOX/bin/gh"
  PATH="$SANDBOX/bin:$PATH"
}

git_quiet() {
  git -c init.defaultBranch=master -c user.name=test -c user.email=test@test "$@" > /dev/null 2>&1
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
branch_exists "$SANDBOX/clean" feature && fail "branch was not deleted: $output" || pass "branch deleted"
[[ -d "$SANDBOX/clean-wt" ]] && fail "worktree was not removed" || pass "worktree removed"
[[ "$output" == *"cannot delete branch"* ]] && fail "git branch -D errored: $output" || pass "no git error"

echo "merged branch checked out in a dirty linked worktree"
create_repo dirty
merge_pushed_branch "$SANDBOX/dirty" feature
git_quiet -C "$SANDBOX/dirty" worktree add "$SANDBOX/dirty-wt" feature
touch "$SANDBOX/dirty-wt/wip.txt"
output="$(run_garbage "$SANDBOX/dirty")"
branch_exists "$SANDBOX/dirty" feature && pass "branch kept" || fail "branch with uncommitted work was deleted"
[[ -f "$SANDBOX/dirty-wt/wip.txt" ]] && pass "worktree kept" || fail "worktree with uncommitted work was removed"
[[ "$output" == *"uncommitted changes"* ]] && pass "skip reason printed" || fail "no skip reason: $output"

echo "merged branch checked out in a locked worktree"
create_repo locked
merge_pushed_branch "$SANDBOX/locked" feature
git_quiet -C "$SANDBOX/locked" worktree add "$SANDBOX/locked-wt" feature
git_quiet -C "$SANDBOX/locked" worktree lock "$SANDBOX/locked-wt"
output="$(run_garbage "$SANDBOX/locked")"
branch_exists "$SANDBOX/locked" feature && pass "branch kept" || fail "branch of locked worktree was deleted"
[[ -d "$SANDBOX/locked-wt" ]] && pass "worktree kept" || fail "locked worktree was removed"

echo "run from a linked worktree never touches the main checkout branch"
create_repo linked
merge_pushed_branch "$SANDBOX/linked" feature
git_quiet -C "$SANDBOX/linked" worktree add "$SANDBOX/linked-wt" feature
output="$(run_garbage "$SANDBOX/linked-wt")"
branch_exists "$SANDBOX/linked" master && pass "main checkout branch kept" || fail "main checkout branch deleted: $output"
[[ -d "$SANDBOX/linked" ]] && pass "main checkout kept" || fail "main checkout removed"

echo "merged branch without worktree"
create_repo plain
merge_pushed_branch "$SANDBOX/plain" feature
output="$(run_garbage "$SANDBOX/plain")"
branch_exists "$SANDBOX/plain" feature && fail "branch was not deleted: $output" || pass "branch deleted"

echo "stale worktree whose directory is gone"
create_repo stale
merge_pushed_branch "$SANDBOX/stale" feature
git_quiet -C "$SANDBOX/stale" worktree add "$SANDBOX/stale-wt" feature
rm -rf "$SANDBOX/stale-wt"
output="$(run_garbage "$SANDBOX/stale")"
branch_exists "$SANDBOX/stale" feature && fail "branch was not deleted: $output" || pass "branch deleted"

if [[ $failures -gt 0 ]]; then
  echo && echo "$failures failure(s)" >&2
  exit 1
fi
