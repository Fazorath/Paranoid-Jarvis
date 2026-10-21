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

# Build a sandbox checkout with a rendered plist, an empty LaunchAgents dir and
# a fake launchctl that models launchd: $LAUNCHD_STATE holds the loaded plist
# path (empty = not loaded); bootstrap fails if loaded, bootout fails if not.
# Touch $LAUNCHD_STATE.fail-<verb> to make that verb fail.
# Usage: setup_sandbox <name>   (sets SANDBOX, LAUNCH_AGENTS_DIR, LAUNCHCTL, LAUNCHD_STATE)
setup_sandbox() {
    SANDBOX="$TMP/$1"
    mkdir -p "$SANDBOX/repo" "$SANDBOX/LaunchAgents"
    cp "$REPO_DIR/toggle_startup_cam.sh" "$SANDBOX/repo/"
    printf '<plist/>\n' > "$SANDBOX/repo/$PLIST_NAME"
    LAUNCHD_STATE="$SANDBOX/launchd.state"
    : > "$LAUNCHD_STATE"
    LAUNCHCTL="$SANDBOX/launchctl"
    cat > "$LAUNCHCTL" <<EOF
#!/bin/sh
state="$LAUNCHD_STATE"
[ -e "\$state.fail-\$1" ] && exit 5
case "\$1" in
    bootstrap) [ -s "\$state" ] && exit 5; echo "\$3" > "\$state" ;;
    bootout) [ -s "\$state" ] || exit 3; : > "\$state" ;;
    print) [ -s "\$state" ] ;;
esac
EOF
    chmod +x "$LAUNCHCTL"
    LAUNCH_AGENTS_DIR="$SANDBOX/LaunchAgents"
    source "$SANDBOX/repo/toggle_startup_cam.sh"
}

test_enable_copies_plist_and_bootstraps() {
    setup_sandbox enable
    enable_agent >/dev/null 2>&1

    [[ -f "$SANDBOX/repo/$PLIST_NAME" ]] || { fail "enable moved the repo plist instead of copying"; return; }
    cmp -s "$SANDBOX/repo/$PLIST_NAME" "$LAUNCH_AGENTS_DIR/$PLIST_NAME" || { fail "enable did not copy plist to LaunchAgents"; return; }
    [[ "$(<"$LAUNCHD_STATE")" == "$LAUNCH_AGENTS_DIR/$PLIST_NAME" ]] || { fail "enable did not bootstrap the copy"; return; }
    pass "enable copies plist and bootstraps it"
}

test_enable_refreshes_stale_loaded_copy() {
    setup_sandbox stale
    printf '<plist>old</plist>\n' > "$LAUNCH_AGENTS_DIR/$PLIST_NAME"
    echo "$LAUNCH_AGENTS_DIR/$PLIST_NAME" > "$LAUNCHD_STATE"
    enable_agent >/dev/null 2>&1 || { fail "enable failed over a stale loaded copy"; return; }

    cmp -s "$SANDBOX/repo/$PLIST_NAME" "$LAUNCH_AGENTS_DIR/$PLIST_NAME" || { fail "enable left the stale copy in place"; return; }
    [[ -s "$LAUNCHD_STATE" ]] || { fail "agent not loaded after refresh"; return; }
    pass "enable refreshes a stale, already-loaded copy"
}

test_disable_boots_out_and_removes_copy() {
    setup_sandbox disable
    cp "$SANDBOX/repo/$PLIST_NAME" "$LAUNCH_AGENTS_DIR/$PLIST_NAME"
    echo "$LAUNCH_AGENTS_DIR/$PLIST_NAME" > "$LAUNCHD_STATE"
    disable_agent >/dev/null 2>&1

    [[ ! -e "$LAUNCH_AGENTS_DIR/$PLIST_NAME" ]] || { fail "disable left the LaunchAgents copy"; return; }
    [[ -f "$SANDBOX/repo/$PLIST_NAME" ]] || { fail "disable removed the repo plist"; return; }
    [[ ! -s "$LAUNCHD_STATE" ]] || { fail "disable did not boot out the agent"; return; }
    pass "disable boots out and removes the copy"
}

test_disable_keeps_copy_when_bootout_fails() {
    setup_sandbox bootout-fails
    cp "$SANDBOX/repo/$PLIST_NAME" "$LAUNCH_AGENTS_DIR/$PLIST_NAME"
    echo "$LAUNCH_AGENTS_DIR/$PLIST_NAME" > "$LAUNCHD_STATE"
    touch "$LAUNCHD_STATE.fail-bootout"

    if disable_agent >/dev/null 2>&1; then fail "disable should fail when bootout fails"; return; fi
    [[ -f "$LAUNCH_AGENTS_DIR/$PLIST_NAME" ]] || { fail "disable removed the copy although the agent is still loaded"; return; }
    pass "disable keeps the copy and fails when bootout fails"
}

test_git_status_clean_after_enable_and_disable() {
    setup_sandbox git
    cp "$REPO_DIR/.gitignore" "$SANDBOX/repo/"
    git -C "$SANDBOX/repo" init -q
    git -C "$SANDBOX/repo" add -A
    git -C "$SANDBOX/repo" -c user.name=t -c user.email=t@t commit -qm init

    enable_agent >/dev/null 2>&1
    local after_enable="$(git -C "$SANDBOX/repo" status --porcelain --ignored)"
    disable_agent >/dev/null 2>&1
    local after_disable="$(git -C "$SANDBOX/repo" status --porcelain --ignored)"

    local expected="!! $PLIST_NAME"
    [[ "$after_enable" == "$expected" ]] || { fail "git status after enable: $after_enable"; return; }
    [[ "$after_disable" == "$expected" ]] || { fail "git status after disable: $after_disable"; return; }
    pass "git status stays clean after enable and disable"
}

test_enable_copies_plist_and_bootstraps
test_enable_refreshes_stale_loaded_copy
test_disable_boots_out_and_removes_copy
test_disable_keeps_copy_when_bootout_fails
test_git_status_clean_after_enable_and_disable

if [[ $FAILURES -eq 0 ]]; then
    echo "All tests passed."
else
    echo "$FAILURES test(s) failed."
    exit 1
fi
