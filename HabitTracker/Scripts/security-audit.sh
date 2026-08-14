#!/bin/bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

failed=0

credential_pattern='AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|gh[pousr]_[0-9A-Za-z]{20,}|github_pat_[0-9A-Za-z_]{20,}|xox[baprs]-[0-9A-Za-z-]{10,}|sk_(live|test)_[0-9A-Za-z]{16,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
suspicious_file_pattern='(^|/)(\.env($|\.)|[^/]*(secret|credential)[^/]*|GoogleService-Info\.plist|AuthKey_[^/]*\.p8|[^/]*\.(p12|mobileprovision|cer|pem|key))$'

echo "Checking tracked filenames..."
tracked_files="$(git ls-files | grep -Ei "$suspicious_file_pattern" || true)"
if [[ -n "$tracked_files" ]]; then
    echo "Potential credential files are tracked:"
    echo "$tracked_files"
    failed=1
fi

echo "Checking the current tracked tree..."
current_matches="$(git grep -IlE "$credential_pattern" -- . ':(exclude)HabitTracker/Scripts/security-audit.sh' 2>/dev/null || true)"
if [[ -n "$current_matches" ]]; then
    echo "High-confidence credential signatures found in:"
    echo "$current_matches"
    failed=1
fi

echo "Checking reachable Git history..."
history_matches=""
while IFS= read -r commit; do
    matches="$(git grep -IlE "$credential_pattern" "$commit" -- . ':(exclude)HabitTracker/Scripts/security-audit.sh' 2>/dev/null || true)"
    if [[ -n "$matches" ]]; then
        history_matches+="$matches"$'\n'
    fi
done < <(git rev-list --all)

if [[ -n "$history_matches" ]]; then
    echo "High-confidence credential signatures exist in Git history:"
    printf '%s' "$history_matches" | sort -u
    failed=1
fi

if [[ "$failed" -ne 0 ]]; then
    echo "Security audit failed. Revoke exposed credentials before removing them from source or history."
    exit 1
fi

echo "Security audit passed: no high-confidence credentials or suspicious tracked credential files found."
