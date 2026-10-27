#!/usr/bin/env bash
# Check the upstream NewPipe branch for security-relevant changes since this fork.
#
# This is a heuristic monitor, not a CVE feed. It looks at upstream security
# advisories, release notes, and commit messages. It maintains one issue named
# "Upstream security watch" instead of creating a new issue every week.
set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-TeamNewPipe/NewPipe}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-dev}"
ISSUE_TITLE="${ISSUE_TITLE:-Upstream security watch}"
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--dry-run]" >&2
    exit 2
fi

command -v gh >/dev/null || { echo "gh is required" >&2; exit 2; }
command -v git >/dev/null || { echo "git is required" >&2; exit 2; }

REPORT="$(mktemp)"
trap 'rm -f "$REPORT" "$SEC_COMMITS"' EXIT
SEC_COMMITS="$(mktemp)"

if ! git remote get-url upstream >/dev/null 2>&1; then
    git remote add upstream "https://github.com/${UPSTREAM_REPO}.git"
fi

git fetch --quiet --no-tags upstream "$UPSTREAM_BRANCH"
UPSTREAM_REF="refs/remotes/upstream/${UPSTREAM_BRANCH}"
UPSTREAM_HEAD="$(git rev-parse "$UPSTREAM_REF")"
BASE="$(git merge-base HEAD "$UPSTREAM_REF")"
BASE_EPOCH="$(git show -s --format=%ct "$BASE")"
BASE_SHORT="$(git rev-parse --short "$BASE")"
HEAD_SHORT="$(git rev-parse --short HEAD)"
UPSTREAM_SHORT="$(git rev-parse --short "$UPSTREAM_HEAD")"
COMMIT_COUNT="$(git rev-list --count "$BASE".."$UPSTREAM_REF")"
COMPARE_URL="https://github.com/${UPSTREAM_REPO}/compare/${BASE}...${UPSTREAM_HEAD}"

SECURITY_RE='security|vulnerab|CVE-|GHSA-|exploit|sanitiz|injection|XSS|SSRF|CSRF|traversal|auth.*bypass|privilege escalation|overflow|use-after-free|race condition|denial of service|RCE'
git log --regexp-ignore-case --extended-regexp --grep="$SECURITY_RE" \
    --format="- [%h](https://github.com/${UPSTREAM_REPO}/commit/%H) %s" \
    "$BASE".."$UPSTREAM_REF" > "$SEC_COMMITS"

ADVISORIES="$(gh api "repos/${UPSTREAM_REPO}/security-advisories?per_page=100" \
    --jq --argjson base "$BASE_EPOCH" '
        [.[] | select((.updated_at | fromdateiso8601) >= $base) |
         "- [\(.ghsa_id)](\(.html_url)) \(.severity): \(.summary)"] | .[]' 2>/dev/null || true)"

RELEASES="$(gh api "repos/${UPSTREAM_REPO}/releases?per_page=30" \
    --jq --argjson base "$BASE_EPOCH" '
        [.[] | select((.published_at | fromdateiso8601) >= $base) |
         select(((.name // "") + " " + (.body // "")) |
                test("security|vulnerab|CVE-|GHSA-|exploit"; "i")) |
         "- [\(.tag_name)](\(.html_url)) \(.name // "")"] | .[]' 2>/dev/null || true)"

SEC_COMMIT_COUNT="$(grep -c '^- ' "$SEC_COMMITS" || true)"
FINDINGS=0
[[ "$SEC_COMMIT_COUNT" -gt 0 || -n "$ADVISORIES" || -n "$RELEASES" ]] && FINDINGS=1

{
    echo "## Upstream security check"
    echo
    echo "- Upstream: [${UPSTREAM_REPO}@${UPSTREAM_BRANCH}](https://github.com/${UPSTREAM_REPO}/tree/${UPSTREAM_BRANCH}) at \`${UPSTREAM_SHORT}\`"
    echo "- Fork merge base: \`${BASE_SHORT}\`"
    echo "- Fork HEAD: \`${HEAD_SHORT}\`"
    echo "- New upstream commits since the merge base: **${COMMIT_COUNT}**"
    echo "- Security-relevant commits: **${SEC_COMMIT_COUNT}**"
    echo
    if [[ "$COMMIT_COUNT" -eq 0 ]]; then
        echo "No new upstream commits."
        echo
    else
        echo "[Compare upstream changes](${COMPARE_URL})"
        echo
    fi

    if [[ "$SEC_COMMIT_COUNT" -gt 0 ]]; then
        echo "### Security-relevant commits"
        echo
        cat "$SEC_COMMITS"
        echo
    fi

    if [[ -n "$ADVISORIES" ]]; then
        echo "### New or updated upstream security advisories"
        echo
        printf '%s\n' "$ADVISORIES"
        echo
    fi

    if [[ -n "$RELEASES" ]]; then
        echo "### Upstream releases mentioning security"
        echo
        printf '%s\n' "$RELEASES"
        echo
    fi

    if [[ "$FINDINGS" -eq 0 ]]; then
        echo "**Status:** no unmerged security-relevant changes detected."
        echo
    else
        echo "**Status:** review and merge upstream security fixes."
        echo
        echo "Suggested action: \`git fetch upstream && git merge upstream/${UPSTREAM_BRANCH}\`, resolve conflicts, run tests, and release a new fork build."
        echo
    fi

    echo "> This check uses GitHub security advisories, release notes, and commit-message matching. It can miss a patch that does not mention security in its commit message."
} >> "$REPORT"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    cat "$REPORT" >> "$GITHUB_STEP_SUMMARY"
fi

if [[ "$DRY_RUN" == "1" ]]; then
    cat "$REPORT"
    exit 0
fi

REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
export GH_REPO="$REPO"

ensure_label() {
    gh label create "$1" --color "$2" --description "$3" --force >/dev/null 2>&1 || true
}

find_issue() {
    gh issue list --state all --limit 200 --json number,title,state \
        --jq ".[] | select(.title == \"${ISSUE_TITLE}\") | .number" | head -1
}

ISSUE_NUMBER="$(find_issue)"

if [[ "$FINDINGS" -eq 1 ]]; then
    ensure_label security d73a4a "Security-related work"
    ensure_label upstream 5319e7 "Upstream sync or security watch"
    if [[ -z "$ISSUE_NUMBER" ]]; then
        gh issue create --title "$ISSUE_TITLE" --body-file "$REPORT" \
            --label security --label upstream >/dev/null
        echo "Created issue: $ISSUE_TITLE"
    else
        CURRENT_BODY="$(gh issue view "$ISSUE_NUMBER" --json body --jq .body)"
        if [[ "$CURRENT_BODY" != "$(cat "$REPORT")" ]]; then
            gh issue edit "$ISSUE_NUMBER" --body-file "$REPORT" \
                --add-label security --add-label upstream >/dev/null
            echo "Updated issue #$ISSUE_NUMBER"
        else
            echo "Issue #$ISSUE_NUMBER already current"
        fi
        if [[ "$(gh issue view "$ISSUE_NUMBER" --json state --jq .state)" == "CLOSED" ]]; then
            gh issue reopen "$ISSUE_NUMBER" >/dev/null
            echo "Reopened issue #$ISSUE_NUMBER"
        fi
    fi
else
    if [[ -n "$ISSUE_NUMBER" && "$(gh issue view "$ISSUE_NUMBER" --json state --jq .state)" == "OPEN" ]]; then
        gh issue close "$ISSUE_NUMBER" \
            --comment "No unmerged upstream security-relevant changes detected by the weekly check."
        echo "Closed issue #$ISSUE_NUMBER"
    fi
    echo "No security-relevant upstream changes detected"
fi
