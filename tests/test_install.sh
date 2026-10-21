#!/bin/bash
# Tests for install.sh. Run: bash tests/test_install.sh
set -u

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../install.sh
source "$REPO_DIR/install.sh"

FAILURES=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1"; FAILURES=$((FAILURES + 1)); }
pass() { echo "ok:   $1"; }

test_render_plist_substitutes_repo_and_python() {
    local repo="$TMP/My Repo & <Co>"
    local out="$TMP/rendered.plist"
    render_plist "$REPO_DIR/com.paranoidjarvis.startupcam.plist.template" "$out" "$repo" "$repo/.venv/bin/python" >/dev/null

    plutil -lint -s "$out" || { fail "rendered plist is not valid"; return; }
    local python args wd keepalive
    python="$(plutil -extract ProgramArguments.0 raw -o - "$out")"
    args="$(plutil -extract ProgramArguments.1 raw -o - "$out") $(plutil -extract ProgramArguments.2 raw -o - "$out")"
    keepalive="$(plutil -extract KeepAlive raw -o - "$out")"
    wd="$(plutil -extract WorkingDirectory raw -o - "$out")"
    [[ "$python" == "$TMP/My Repo & <Co>/.venv/bin/python" ]] || { fail "python path wrong: $python"; return; }
    [[ "$args" == "-m paranoid_jarvis.agent" ]] || { fail "agent module args wrong: $args"; return; }
    [[ "$keepalive" == "true" ]] || { fail "KeepAlive should be true, got: $keepalive"; return; }
    [[ "$wd" == "$TMP/My Repo & <Co>" ]] || { fail "WorkingDirectory wrong: $wd"; return; }
    if grep -qE "__(PYTHON|REPO_DIR)__" "$out"; then fail "placeholder left in rendered plist"; return; fi
    pass "render_plist substitutes repo and python"
}

test_verify_capture_passes_when_new_jpg_written() {
    local dir="$TMP/out-ok"; mkdir -p "$dir"
    if verify_capture "$dir" bash -c "printf 'jpg' > '$dir/startup_image_1.jpg'" >/dev/null 2>&1; then
        pass "verify_capture passes when a new JPG is written"
    else
        fail "verify_capture should pass when a new JPG is written"
    fi
}

test_verify_capture_fails_with_tcc_hint_when_no_jpg() {
    local dir="$TMP/out-none"; mkdir -p "$dir"
    printf 'old' > "$dir/startup_image_0.jpg"
    local output
    if output="$(verify_capture "$dir" true 2>&1)"; then
        fail "verify_capture should fail when no new JPG is written"
    elif [[ "$output" != *"Privacy & Security"*"Camera"* ]]; then
        fail "verify_capture failure should print TCC remediation, got: $output"
    else
        pass "verify_capture fails with TCC hint when no new JPG"
    fi
}

test_verify_capture_fails_when_command_fails() {
    local dir="$TMP/out-err"; mkdir -p "$dir"
    if verify_capture "$dir" bash -c "printf 'jpg' > '$dir/startup_image_2.jpg'; exit 1" >/dev/null 2>&1; then
        fail "verify_capture should fail when the capture command fails"
    else
        pass "verify_capture fails when the capture command fails"
    fi
}

test_render_plist_substitutes_repo_and_python
test_verify_capture_passes_when_new_jpg_written
test_verify_capture_fails_with_tcc_hint_when_no_jpg
test_verify_capture_fails_when_command_fails

if [[ $FAILURES -eq 0 ]]; then
    echo "All tests passed."
else
    echo "$FAILURES test(s) failed."
    exit 1
fi
