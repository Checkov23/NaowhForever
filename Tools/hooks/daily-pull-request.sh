#!/usr/bin/env bash
# The daily watch's one pull request (.github/workflows/daily-watch.yml). Its checks run one
# after another on one branch; each that changed something adds it:
#   bash Tools/hooks/daily-pull-request.sh add NAME SHORT REPORT CHANGELOG PATH...
# commits what changed under the paths, for a check that fails after it to go back to, and
# notes SHORT (what it is, a few words for the title), CHANGELOG (its lines for players, one per
# line, each starting Added:, Changed: or Fixed:, for "## Changelog" in the description; empty
# for none), its lines for the list (CHANGELOG's, else SHORT) and REPORT (for the description).
# CHANGELOG.md is left alone: the release copies the description's lines into it. A check adds
# only when it found a change, so nothing changed under the paths means CI could not make it
# (it may not read Wowhead): that is noted as stuck, for the issue below.
#   bash Tools/hooks/daily-pull-request.sh hold REASON_FILE
# keeps the pull request a draft, REASON_FILE's text at the top of its description: what must
# be done on our machines before it can be merged (a BiS pick CI could not find a source for).
#   bash Tools/hooks/daily-pull-request.sh open BRANCH
# squashes what was added into one commit (it is merged as one: its title and short list are
# the squash's message), pushes BRANCH and opens the pull request, or brings the one already
# open up to date, labelled "no changelog" when no check has a line for players. Where the
# organization does not let workflows open pull requests, one issue with a link that opens it
# in one click, kept up to date. Nothing added: nothing.
#   bash Tools/hooks/daily-pull-request.sh merge BRANCH
# the scheduled run's way, once the workflow's own checks passed: the same commit, its changelog
# lines added to CHANGELOG.md, pushed straight to main; open's pull request when it is held.
# Either way, what is stuck goes in one issue, "Daily data: changes that need a run on our
# machines" (each check's report, and what to run), kept up to date and closed by the first
# run with nothing stuck.
# Needs BASE (the commit the run started from) and, for open, GH_TOKEN, REPO, SERVER, RUN_ID;
# merge also RELEASE_DEPLOY_KEY.
set -euo pipefail

notes="${RUNNER_TEMP:-/tmp}/daily-changes"
mkdir -p "$notes"
REPORT_LINES=120   # each report in the description, at most; the run has them whole

add() {
  local name="$1" short="$2" report="$3" changelog="$4"
  shift 4
  if [ -z "$(git status --porcelain -- "$@")" ]; then
    echo "$name: its check found changes CI could not make; noted for a run on our machines."
    printf '%s\t%s\n' "$name" "$short" >> "$notes/stuck"
    cp "$report" "$notes/$name.stuck.md"
    return 0
  fi
  git add -- "$@"
  git commit -q -m "daily: $name"
  local entry listed=false
  while IFS= read -r entry; do
    if [ -z "$entry" ]; then continue; fi
    if ! grep -qxF -- "$entry" "$notes/changelog" 2> /dev/null; then
      printf '%s\n' "$entry" >> "$notes/changelog"
      printf '%s\n' "${entry#*: }" >> "$notes/items"
      listed=true
    fi
  done <<< "$changelog"
  if [ "$listed" = false ]; then printf '%s\n' "$short" >> "$notes/items"; fi
  printf '%s\t%s\n' "$name" "$short" >> "$notes/list"
  cp "$report" "$notes/$name.md"
  echo "$name: added ($short)."
}

hold() {
  cat "$1" >> "$notes/hold.md"
  echo "Held as a draft: $(head -n 1 "$1")"
}

# What to run on our machines for a check's stuck changes (Tools/README.md has the rest).
how_to_make() {
  case "$1" in
    bis) echo '`python Tools/build/bis_data.py` (it asks Wowhead for the items the game'"'"'s tables do not have), then `lua Tools/regression/test-bis-dungeon-drops.lua` for their sources' ;;
    loot) echo '`python Tools/sources/wowsrc.py --resolve`, then `python Tools/build/journal.py`' ;;
    *) echo "its tool without \`--offline\` (see Tools/README.md)" ;;
  esac
}

# One issue for the changes CI could not make: up to date while any are, closed when none are.
stuck_issue() {
  local issue_title="Daily data: changes that need a run on our machines"
  local issue
  issue="$(gh issue list --state open --search "author:app/github-actions in:title \"$issue_title\"" \
    --json number --jq '.[0].number // empty')"
  if [ ! -s "$notes/stuck" ]; then
    if [ -n "$issue" ]; then
      gh issue close "$issue" --comment "Nothing is stuck as of $SERVER/$REPO/actions/runs/$RUN_ID."
    fi
    return 0
  fi
  {
    echo "The daily watch's checks found changes it cannot make in CI (it may not read Wowhead)."
    echo "Make them on our machines, on a branch from main, and open a pull request:"
    echo
    while IFS=$'\t' read -r name short; do
      echo "- **$short**: $(how_to_make "$name")"
    done < "$notes/stuck"
    while IFS=$'\t' read -r name short; do
      echo
      echo "<details><summary>$short: what changed</summary>"
      echo
      head -n "$REPORT_LINES" "$notes/$name.stuck.md"
      echo
      echo "</details>"
    done < "$notes/stuck"
    echo
    echo "---"
    echo "Kept up to date by the daily watch (.github/workflows/daily-watch.yml); last run:"
    echo "$SERVER/$REPO/actions/runs/$RUN_ID. Closed by the first run with nothing stuck."
  } > "$notes/stuck-issue.md"
  if [ -n "$issue" ]; then
    gh issue edit "$issue" --body-file "$notes/stuck-issue.md"
    echo "Stuck changes: issue #$issue up to date."
  else
    gh issue create --title "$issue_title" --body-file "$notes/stuck-issue.md"
  fi
}

# "no changelog" on the pull request exactly when no check has a line for players. Its own call
# once the pull request exists: given with the create, pr-rules can read the pull request first.
label_pr() {
  local pr="$1" labelled
  labelled="$(gh pr view "$pr" --json labels --jq 'any(.labels[]; .name == "no changelog")')"
  if [ -s "$notes/changelog" ] && [ "$labelled" = true ]; then
    gh pr edit "$pr" --remove-label "no changelog"
  elif [ ! -s "$notes/changelog" ] && [ "$labelled" = false ]; then
    gh pr edit "$pr" --add-label "no changelog"
  fi
}

# "a", "a and b", "a, b and c".
join() {
  local out="" i=0 n=$#
  for part in "$@"; do
    i=$((i + 1))
    if [ "$i" -eq 1 ]; then out="$part"
    elif [ "$i" -eq "$n" ]; then out="$out and $part"
    else out="$out, $part"; fi
  done
  printf '%s' "$out"
}

# One commit from BASE: the title, and what is in it. Sets names, shorts, title and list.
squash() {
  names=() shorts=()
  local name short line
  while IFS=$'\t' read -r name short; do
    names+=("$name")
    shorts+=("$short")
  done < "$notes/list"
  title="chore(data): $(join "${shorts[@]}")"
  list=""
  while IFS= read -r line; do list="$list- $line"$'\n'; done < "$notes/items"
  git reset -q --soft "$BASE"
  if [ "${1:-}" = changelog ] && [ -s "$notes/changelog" ]; then
    python3 Tools/release/release.py add-unreleased < "$notes/changelog" > /dev/null
    git add CHANGELOG.md
  fi
  git commit -q -m "$title" -m "${list%$'\n'}"
}

# Straight to main with RELEASE_DEPLOY_KEY (Protect main's bypass), its changelog lines in
# CHANGELOG.md since there is no pull request for the release to read them from; the open pull
# request is closed. Held, or main moved in a way it does not rebase onto: the pull request
# instead. Writes merged=true to GITHUB_OUTPUT when it went in, and changelog=true when it brought
# lines for players (the workflow then releases it).
merge() {
  local branch="$1"
  if [ ! -s "$notes/list" ] || [ -s "$notes/hold.md" ]; then
    open_pr "$branch"
    return 0
  fi
  local head
  head="$(git rev-parse HEAD)"
  squash changelog

  local key="$RUNNER_TEMP/release_deploy_key" hosts="$RUNNER_TEMP/known_hosts" remote
  remote="git@github.com:$REPO.git"
  (umask 077 && printf '%s\n' "$RELEASE_DEPLOY_KEY" > "$key")
  echo "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" > "$hosts"
  export GIT_SSH_COMMAND="ssh -i $key -o IdentitiesOnly=yes -o UserKnownHostsFile=$hosts"
  local pushed=false
  if git fetch -q "$remote" main && git rebase -q FETCH_HEAD && git push -q "$remote" HEAD:main; then
    pushed=true
  fi
  rm -f "$key"
  unset GIT_SSH_COMMAND
  if [ "$pushed" = false ]; then
    git rebase --abort 2> /dev/null || true
    echo "::warning::Could not push to main: the pull request instead."
    git reset -q --hard "$head"
    open_pr "$branch"
    return 0
  fi

  local commit
  commit="$(git rev-parse HEAD)"
  echo "Merged to main: $commit ($title)"
  echo "merged=true" >> "$GITHUB_OUTPUT"
  if [ -s "$notes/changelog" ]; then echo "changelog=true" >> "$GITHUB_OUTPUT"; fi
  stuck_issue
  local pr
  pr="$(gh pr list --head "$branch" --state open --json url --jq '.[0].url // empty')"
  if [ -n "$pr" ]; then
    gh pr close "$pr" --comment "Merged to main by the daily watch as $commit ($SERVER/$REPO/actions/runs/$RUN_ID)."
  fi
}

open_pr() {
  local branch="$1"
  stuck_issue
  if [ ! -s "$notes/list" ]; then
    echo "Nothing changed: no pull request."
    return 0
  fi
  squash

  # A draft while something must be done by hand first; ready once a run finds nothing.
  local draft=false
  if [ -s "$notes/hold.md" ]; then draft=true; fi

  # The description: what holds it, the list, the changelog lines for players, each check's
  # report folded away, the run. "## Reports" ends "## Changelog" for the release, which reads
  # up to the next "## ".
  {
    if [ "$draft" = true ]; then
      echo "> [!WARNING]"
      echo "> **A draft until this is done on our machines:**"
      sed 's/^/> /' "$notes/hold.md"
      echo
    fi
    echo "Today's data changes, in one pull request (it squash merges as one commit):"
    echo
    printf '%s' "$list"
    echo
    echo "## Changelog"
    echo
    if [ -s "$notes/changelog" ]; then
      cat "$notes/changelog"
    else
      echo "<!-- Nothing changes for players: labelled no changelog. -->"
    fi
    echo
    echo "## Reports"
    for i in "${!names[@]}"; do
      echo
      echo "<details><summary>${shorts[$i]}: its report</summary>"
      echo
      head -n "$REPORT_LINES" "$notes/${names[$i]}.md"
      if [ "$(wc -l < "$notes/${names[$i]}.md")" -gt "$REPORT_LINES" ]; then
        echo
        echo "_Cut short: the whole report is in the run below._"
      fi
      echo
      echo "</details>"
    done
    echo
    echo "---"
    echo "Opened by the daily watch (.github/workflows/daily-watch.yml); last run: $SERVER/$REPO/actions/runs/$RUN_ID."
    echo "Checks do not run on a pull request a workflow opens: close and reopen it to run them."
    echo "The branch is rebuilt from main by each run: merge or close it, don't push to it."
  } > "$notes/pr.md"

  local link_label=""
  if [ ! -s "$notes/changelog" ]; then link_label="&labels=no+changelog"; fi

  gh auth setup-git
  git push --force origin "HEAD:refs/heads/$branch"

  local issue_title="Daily data update: open its pull request"
  local issue
  issue="$(gh issue list --state open --search "author:app/github-actions in:title \"$issue_title\"" \
    --json number --jq '.[0].number // empty')"
  local pr
  pr="$(gh pr list --head "$branch" --state open --json url --jq '.[0].url // empty')"
  if [ -n "$pr" ]; then
    gh pr edit "$pr" --title "$title" --body-file "$notes/pr.md"
    if [ "$draft" = true ]; then gh pr ready "$pr" --undo; else gh pr ready "$pr"; fi
    label_pr "$pr"
    echo "Brought up to date: $pr"
    return 0
  fi
  local as_draft=()
  if [ "$draft" = true ]; then as_draft=(--draft); fi
  if pr="$(gh pr create --base main --head "$branch" "${as_draft[@]}" --title "$title" \
      --body-file "$notes/pr.md" 2> "$notes/create.err")"; then
    echo "Opened: $pr"
    label_pr "$pr"
    if [ -n "$issue" ]; then
      gh issue close "$issue" --comment "Opened: $pr"
    fi
    return 0
  fi
  cat "$notes/create.err" >&2
  if ! grep -qi "not permitted to create" "$notes/create.err"; then
    echo "::error::The pull request could not be opened (see above)."
    return 1
  fi

  echo "::warning::Workflows may not open pull requests here: an issue instead."
  local link="$SERVER/$REPO/compare/main...$branch?quick_pull=1$link_label"
  link="$link&title=$(jq -rn --arg t "$title" '$t|@uri')"
  {
    echo "**[Open the pull request]($link)**: the branch \`$branch\` holds today's data changes."
    echo "This repository's workflows may not open pull requests themselves (Settings, Actions,"
    echo "General: \"Allow GitHub Actions to create and approve pull requests\")."
    echo
    cat "$notes/pr.md"
  } > "$notes/issue.md"
  if [ -n "$issue" ]; then
    gh issue edit "$issue" --body-file "$notes/issue.md"
  else
    gh issue create --title "$issue_title" --body-file "$notes/issue.md"
  fi
}

case "${1:-}" in
  add) shift; add "$@" ;;
  hold) shift; hold "$@" ;;
  open) shift; open_pr "$@" ;;
  merge) shift; merge "$@" ;;
  *) echo "usage: daily-pull-request.sh add NAME SHORT REPORT CHANGELOG PATH... | hold REASON_FILE | open BRANCH | merge BRANCH" >&2
     exit 2 ;;
esac
