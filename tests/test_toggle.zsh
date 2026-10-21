#!/bin/zsh
# Tests for toggle_startup_cam.sh. Run: zsh tests/test_toggle.zsh
set -u

REPO_DIR="${0:A:h:h}"
PLIST_NAME="com.paranoidjarvis.startupcam.plist"

FAILURES=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1"; FAILURES=$((FAILURES + 1)); }
pass() { echo "ok:   $1"; }

# Build a sandbox checkout with a rendered plist, a fake launchctl that records
# its arguments, and an empty LaunchAgents dir; then source the toggle script.
# Usage: setup_sandbox <name>   (sets SANDBOX, LAUNCH_AGENTS_DIR, LAUNCHCTL, LAUNCHCTL_LOG)
setup_sandbox() {
    SANDBOX="$TMP/$1"
    mkdir -p "$SANDBOX/repo" "$SANDBOX/LaunchAgents"
    cp "$REPO_DIR/toggle_startup_cam.sh" "$SANDBOX/repo/"
    printf '<plist/>\n' > "$SANDBOX/repo/$PLIST_NAME"
    LAUNCHCTL_LOG="$SANDBOX/launchctl.log"
    : > "$LAUNCHCTL_LOG"
    LAUNCHCTL="$SANDBOX/launchctl"
    printf '#!/bin/sh\necho "$*" >> "%s"\n' "$LAUNCHCTL_LOG" > "$LAUNCHCTL"
    chmod +x "$LAUNCHCTL"
    LAUNCH_AGENTS_DIR="$SANDBOX/LaunchAgents"
    source "$SANDBOX/repo/toggle_startup_cam.sh"
}

test_enable_copies_plist_and_bootstraps() {
    setup_sandbox enable
    enable_agent >/dev/null

    [[ -f "$SANDBOX/repo/$PLIST_NAME" ]] || { fail "enable moved the repo plist instead of copying"; return; }
    cmp -s "$SANDBOX/repo/$PLIST_NAME" "$LAUNCH_AGENTS_DIR/$PLIST_NAME" || { fail "enable did not copy plist to LaunchAgents"; return; }
    local calls="$(<"$LAUNCHCTL_LOG")"
    [[ "$calls" == "bootstrap gui/$UID $LAUNCH_AGENTS_DIR/$PLIST_NAME" ]] || { fail "unexpected launchctl calls: $calls"; return; }
    pass "enable copies plist and bootstraps it"
}

test_disable_boots_out_and_removes_copy() {
    setup_sandbox disable
    cp "$SANDBOX/repo/$PLIST_NAME" "$LAUNCH_AGENTS_DIR/$PLIST_NAME"
    disable_agent >/dev/null

    [[ ! -e "$LAUNCH_AGENTS_DIR/$PLIST_NAME" ]] || { fail "disable left the LaunchAgents copy"; return; }
    [[ -f "$SANDBOX/repo/$PLIST_NAME" ]] || { fail "disable removed the repo plist"; return; }
    local calls="$(<"$LAUNCHCTL_LOG")"
    [[ "$calls" == "bootout gui/$UID $LAUNCH_AGENTS_DIR/$PLIST_NAME" ]] || { fail "unexpected launchctl calls: $calls"; return; }
    pass "disable boots out and removes the copy"
}

test_git_status_clean_after_enable_and_disable() {
    setup_sandbox git
    cp "$REPO_DIR/.gitignore" "$SANDBOX/repo/"
    git -C "$SANDBOX/repo" init -q
    git -C "$SANDBOX/repo" add -A
    git -C "$SANDBOX/repo" -c user.name=t -c user.email=t@t commit -qm init

    enable_agent >/dev/null
    local after_enable="$(git -C "$SANDBOX/repo" status --porcelain --ignored)"
    disable_agent >/dev/null
    local after_disable="$(git -C "$SANDBOX/repo" status --porcelain --ignored)"

    local expected="!! $PLIST_NAME"
    [[ "$after_enable" == "$expected" ]] || { fail "git status after enable: $after_enable"; return; }
    [[ "$after_disable" == "$expected" ]] || { fail "git status after disable: $after_disable"; return; }
    pass "git status stays clean after enable and disable"
}

test_enable_copies_plist_and_bootstraps
test_git_status_clean_after_enable_and_disable
test_disable_boots_out_and_removes_copy

if [[ $FAILURES -eq 0 ]]; then
    echo "All tests passed."
else
    echo "$FAILURES test(s) failed."
    exit 1
fi
