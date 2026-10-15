#!/bin/bash
set -e
task_project_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$task_project_dir"
node scripts/build-web.mjs
