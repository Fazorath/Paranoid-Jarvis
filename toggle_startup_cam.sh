#!/bin/zsh



PLIST_NAME="com.paranoidjarvis.startupcam.plist"
SCRIPT_PATH="$0"
PLIST_PROJECT="${0:A:h}/$PLIST_NAME"
# Overridable so tests can use a sandbox and a fake launchctl.
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
LAUNCHCTL="${LAUNCHCTL:-launchctl}"
PLIST_LAUNCHAGENTS="$LAUNCH_AGENTS_DIR/$PLIST_NAME"
LOG_PATH="$HOME/ParanoidJarvisLogs/startup_log.txt"



function enable_agent() {
    if [ -f "$PLIST_LAUNCHAGENTS" ]; then
        echo "Already enabled."
    elif [ -f "$PLIST_PROJECT" ]; then
        mkdir -p "$LAUNCH_AGENTS_DIR"
        cp "$PLIST_PROJECT" "$PLIST_LAUNCHAGENTS"
        if "$LAUNCHCTL" bootstrap "gui/$UID" "$PLIST_LAUNCHAGENTS"; then
            echo "Startup camera logger ENABLED."
        else
            rm -f "$PLIST_LAUNCHAGENTS"
            echo "launchctl bootstrap failed; not enabled."
            return 1
        fi
    else
        echo "Plist not found in project folder. Run ./install.sh first."
    fi
}

function disable_agent() {
    if [ -f "$PLIST_LAUNCHAGENTS" ]; then
        # bootout fails if the agent isn't loaded; removing the copy still disables it.
        "$LAUNCHCTL" bootout "gui/$UID" "$PLIST_LAUNCHAGENTS" || echo "launchctl bootout failed (agent may not have been loaded)."
        rm -f "$PLIST_LAUNCHAGENTS"
        echo "Startup camera logger DISABLED."
    else
        echo "Already disabled."
    fi
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


main() {
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
