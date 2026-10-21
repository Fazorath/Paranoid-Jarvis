#!/bin/zsh



PLIST_NAME="com.paranoidjarvis.startupcam.plist"
# Captured here because inside a zsh function $0 is the function's name.
SCRIPT_PATH="$0"
PLIST_PROJECT="${0:A:h}/$PLIST_NAME"
# Overridable so tests can use a sandbox and a fake launchctl.
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
LAUNCHCTL="${LAUNCHCTL:-launchctl}"
PLIST_LAUNCHAGENTS="$LAUNCH_AGENTS_DIR/$PLIST_NAME"
LAUNCHD_DOMAIN="gui/$UID"
LAUNCHD_SERVICE="$LAUNCHD_DOMAIN/com.paranoidjarvis.startupcam"
LOG_PATH="$HOME/ParanoidJarvisLogs/startup_log.txt"



function agent_loaded() {
    "$LAUNCHCTL" print "$LAUNCHD_SERVICE" >/dev/null 2>&1
}

# Copy the rendered plist into LaunchAgents and bootstrap it. A stale or legacy
# copy (e.g. after re-running install.sh) is booted out and replaced.
function enable_agent() {
    if [ ! -f "$PLIST_PROJECT" ]; then
        echo "Plist not found in project folder. Run ./install.sh first." >&2
        return 1
    fi
    if cmp -s "$PLIST_PROJECT" "$PLIST_LAUNCHAGENTS" && agent_loaded; then
        echo "Already enabled."
        return 0
    fi
    # bootstrap fails if the label is already loaded, so unload the old agent first.
    if agent_loaded && ! "$LAUNCHCTL" bootout "$LAUNCHD_SERVICE"; then
        echo "launchctl bootout of the running agent failed; not enabled." >&2
        return 1
    fi
    mkdir -p "$LAUNCH_AGENTS_DIR"
    cp "$PLIST_PROJECT" "$PLIST_LAUNCHAGENTS"
    if ! "$LAUNCHCTL" bootstrap "$LAUNCHD_DOMAIN" "$PLIST_LAUNCHAGENTS"; then
        rm -f "$PLIST_LAUNCHAGENTS"
        echo "launchctl bootstrap failed; not enabled." >&2
        return 1
    fi
    echo "Startup camera logger ENABLED."
}

# Boot out the agent and remove the LaunchAgents copy. The copy is kept if
# bootout fails, so status keeps reporting the agent as enabled.
function disable_agent() {
    if agent_loaded; then
        if ! "$LAUNCHCTL" bootout "$LAUNCHD_SERVICE"; then
            echo "launchctl bootout failed; agent still loaded." >&2
            return 1
        fi
    elif [ ! -f "$PLIST_LAUNCHAGENTS" ]; then
        echo "Already disabled."
        return 0
    fi
    rm -f "$PLIST_LAUNCHAGENTS"
    echo "Startup camera logger DISABLED."
}

function status_agent() {
    if [ -f "$PLIST_LAUNCHAGENTS" ]; then
        echo "Status: ENABLED (plist copied to LaunchAgents)"
        echo "Location: $PLIST_LAUNCHAGENTS"
    elif [ -f "$PLIST_PROJECT" ]; then
        echo "Status: DISABLED (rendered plist in project folder)"
        echo "Location: $PLIST_PROJECT"
    else
        echo "Status: NOT INSTALLED (no rendered plist; run ./install.sh)"
    fi
    if [ -f "$LOG_PATH" ]; then
        echo -n "Last log entry: "
        tail -n 1 "$LOG_PATH"
    else
        echo "No log file found at $LOG_PATH."
    fi
}

function print_help() {
    echo "Usage: $SCRIPT_PATH"
    echo "A toggle utility for the Paranoid-Jarvis startup camera logger."
    echo "Options:"
    echo "  1) Enable   - Copy plist to LaunchAgents and bootstrap it"
    echo "  2) Disable  - Boot out the agent and remove the LaunchAgents copy"
    echo "  3) Status   - Show current status and last log entry"
    echo "  h) Help     - Show this help message"
    echo "  q) Quit     - Exit the script"
}


function main() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        print_help
        exit 0
    fi


    while true; do
        clear
        echo "Toggle Startup Camera Logger"
        echo "1) Enable"
        echo "2) Disable"
        echo "3) Status"
        echo "h) Help"
        echo "q) Quit"
        read "choice?Select an option: "
        clear
        case $choice in
            1)
                enable_agent
                ;;
            2)
                disable_agent
                ;;
            3)
                status_agent
                ;;
            h|H)
                print_help
                ;;
            q|Q)
                echo "Quitting."
                break
                ;;
            *)
                echo "Invalid option."
                ;;
        esac
        echo "\nPress Enter to continue..."
        read
    done
}

# Run main only when executed, not when sourced (tests source this file).
if [[ "$ZSH_EVAL_CONTEXT" == toplevel ]]; then
    main "$@"
fi
