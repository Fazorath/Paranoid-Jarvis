#!/bin/zsh



PLIST_NAME="com.paranoidjarvis.startupcam.plist"
PLIST_PROJECT="$HOME/Desktop/Projects/Paranoid-Jarvis/$PLIST_NAME"
PLIST_LAUNCHAGENTS="$HOME/Library/LaunchAgents/$PLIST_NAME"
LOG_PATH="$HOME/ParanoidJarvisLogs/startup_log.txt"



function enable_agent() {
    if [ -f "$PLIST_PROJECT" ]; then
        mv "$PLIST_PROJECT" "$HOME/Library/LaunchAgents/"
        launchctl load "$PLIST_LAUNCHAGENTS"
        echo "Startup camera logger ENABLED."
    elif [ -f "$PLIST_LAUNCHAGENTS" ]; then
        echo "Already enabled."
    else
        echo "Plist not found in project folder. Cannot enable."
    fi
}

function disable_agent() {
    if [ -f "$PLIST_LAUNCHAGENTS" ]; then
        launchctl unload "$PLIST_LAUNCHAGENTS"
        mv "$PLIST_LAUNCHAGENTS" "$PLIST_PROJECT"
        echo "Startup camera logger DISABLED."
    elif [ -f "$PLIST_PROJECT" ]; then
        echo "Already disabled."
    else
        echo "Plist not found in LaunchAgents or project folder. Cannot disable."
    fi
}

function status_agent() {
    if [ -f "$PLIST_LAUNCHAGENTS" ]; then
        echo "Status: ENABLED (plist in LaunchAgents)"
        echo "Location: $PLIST_LAUNCHAGENTS"
    elif [ -f "$PLIST_PROJECT" ]; then
        echo "Status: DISABLED (plist in project folder)"
        echo "Location: $PLIST_PROJECT"
    else
        echo "Status: NOT FOUND (plist missing from both locations)"
    fi
    if [ -f "$LOG_PATH" ]; then
        echo -n "Last log entry: "
        tail -n 1 "$LOG_PATH"
    else
        echo "No log file found at $LOG_PATH."
    fi
}

function print_help() {
    echo "Usage: $0"
    echo "A toggle utility for the Paranoid-Jarvis startup camera logger."
    echo "Options:"
    echo "  1) Enable   - Move plist to LaunchAgents and load it"
    echo "  2) Disable  - Unload and move plist to project folder"
    echo "  3) Status   - Show current status and last log entry"
    echo "  h) Help     - Show this help message"
    echo "  q) Quit     - Exit the script"
}


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
