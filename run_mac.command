#!/bin/bash
task_project_dir="$(cd "$(dirname "$0")" && pwd)"
task_love_executable="/Applications/love.app/Contents/MacOS/love"

if [ ! -x "$task_love_executable" ]; then
    task_love_executable="$(command -v love)"
fi

if [ -z "$task_love_executable" ] || [ ! -x "$task_love_executable" ]; then
    echo "Move the LOVE application into Applications, then try again."
    echo "You can also drag the Snake_Neon_Runner_DEPLOY project folder onto the LOVE application."
    read -r -p "Press Enter to close... " task_reply
    exit 1
fi

exec "$task_love_executable" "$task_project_dir"
