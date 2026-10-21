#!/bin/bash
# Paranoid-Jarvis installer: creates the repo venv, renders the LaunchAgent
# plist for this checkout, and runs a test capture so macOS asks for camera access.
#
# Usage: ./install.sh            (set PYTHON=/path/to/python3 to pick an interpreter)

PLIST_NAME="com.paranoidjarvis.startupcam.plist"
MIN_PYTHON="3.11"

# Render the plist template, substituting the repo path and interpreter.
# Usage: render_plist <template> <output> <repo_dir> <python>
render_plist() {
    local template="$1" output="$2" repo_dir="$3" python="$4"
    python3 - "$template" "$output" "$repo_dir" "$python" <<'PY' || return 1
import sys
from xml.sax.saxutils import escape

template, output, repo_dir, python = sys.argv[1:]
with open(template) as f:
    text = f.read()
text = text.replace("__PYTHON__", escape(python)).replace("__REPO_DIR__", escape(repo_dir))
with open(output, "w") as f:
    f.write(text)
PY
    plutil -lint -s "$output" || return 1
    echo "Rendered $output"
}

# Run a capture command and check it wrote a new, non-empty JPG to output_dir.
# Usage: verify_capture <output_dir> <command> [args...]
verify_capture() {
    local output_dir="$1"; shift
    local marker status=0 new_jpg
    marker="$(mktemp)"
    # Ensure the marker's mtime is strictly older than anything the capture writes.
    sleep 1

    "$@" || status=$?
    new_jpg="$(find "$output_dir" -maxdepth 1 -name '*.jpg' -size +0 -newer "$marker" 2>/dev/null | head -n 1)"
    rm -f "$marker"

    if [[ $status -eq 0 && -n "$new_jpg" ]]; then
        echo "Test capture OK: $new_jpg"
        return 0
    fi

    echo "" >&2
    echo "Test capture FAILED (exit code $status, no new photo in $output_dir)." >&2
    echo "macOS has probably not granted camera access to Python. To fix:" >&2
    echo "  1. Open System Settings → Privacy & Security → Camera." >&2
    echo "  2. Enable the entry for Python (or your terminal app) and allow access." >&2
    echo "  3. Re-run ./install.sh to verify." >&2
    return 1
}

python_is_supported() {
    "$1" -c "import sys; sys.exit(sys.version_info < tuple(map(int, '$MIN_PYTHON'.split('.'))))" 2>/dev/null
}

# Output directory as the logger resolves it from paranoid_jarvis.conf.
conf_output_dir() {
    local python="$1" repo_dir="$2"
    "$python" - "$repo_dir/paranoid_jarvis.conf" <<'PY'
import configparser, os, sys
config = configparser.ConfigParser()
config.read(sys.argv[1])
print(os.path.expanduser(config.get('general', 'output_dir', fallback='~/ParanoidJarvisLogs')))
PY
}

main() {
    set -e
    local repo_dir python venv_python output_dir
    repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    python="${PYTHON:-python3}"

    if ! command -v "$python" >/dev/null 2>&1; then
        echo "Error: '$python' not found. Install Python $MIN_PYTHON+ (e.g. 'brew install python')." >&2
        exit 1
    fi
    if ! python_is_supported "$python"; then
        echo "Error: Python $MIN_PYTHON+ required; '$python' is $("$python" --version 2>&1)." >&2
        echo "Set PYTHON=/path/to/python3.11+ and re-run." >&2
        exit 1
    fi

    echo "==> Creating virtualenv in $repo_dir/.venv"
    "$python" -m venv "$repo_dir/.venv"
    venv_python="$repo_dir/.venv/bin/python"

    echo "==> Installing requirements"
    "$venv_python" -m pip install --quiet --upgrade pip
    "$venv_python" -m pip install --quiet -r "$repo_dir/requirements.txt"

    echo "==> Rendering LaunchAgent plist"
    render_plist "$repo_dir/$PLIST_NAME.template" "$repo_dir/$PLIST_NAME" "$repo_dir" "$venv_python"

    echo "==> Running test capture"
    echo "If macOS asks for camera access, click Allow."
    output_dir="$(conf_output_dir "$venv_python" "$repo_dir")"
    mkdir -p "$output_dir"
    set +e
    if ! verify_capture "$output_dir" "$venv_python" "$repo_dir/startup_cam_logger.py"; then
        exit 1
    fi

    echo ""
    echo "Install complete. Enable the login capture with: ./toggle_startup_cam.sh"
}

# Run main only when executed, not when sourced (tests source this file).
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
