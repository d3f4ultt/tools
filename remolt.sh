#!/usr/bin/env bash
#
# remolt.sh
# -----------------------------------------------------------------------------
# Removes all subdirectories/files inside a parent folder except those listed
# in the exclusions. Includes a verbose mode to show every action and result.
#
# Usage:
#   ./remolt.sh [-p PARENT_FOLDER] [-x "excluded1,excluded2,..."] [-v]
#
# Examples:
#   ./remolt.sh
#       (Cleans up "/root" by default, with no exclusions, quiet mode)
#
#   ./remolt.sh -p /root -x "backup_manual,.parallel" -v
#       (Cleans everything in /root except /root/backup_manual and /root/.parallel,
#        prints every step of the process)
# -----------------------------------------------------------------------------

set -euo pipefail

# --------------------------------------------------------------------
# 1) Default Values
# --------------------------------------------------------------------
PARENT_FOLDER="/root"
VERBOSE=0
declare -a EXCLUSIONS=()

# ANSI color codes (for nice output)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No color

# --------------------------------------------------------------------
# 2) Usage Function
# --------------------------------------------------------------------
usage() {
  echo -e "${YELLOW}Usage:${NC} $0 [-p PARENT_FOLDER] [-x \"excluded1,excluded2,...\"] [-v]"
  echo
  echo "Options:"
  echo "  -p   Parent folder to clean up. Default: /root"
  echo "  -x   Comma-separated list of items (relative names) to exclude from deletion."
  echo "  -v   Verbose mode (print every deletion step)."
  echo
  echo "Example:"
  echo "  $0 -p /root -x \"backup_manual,.parallel\" -v"
  exit 1
}

# --------------------------------------------------------------------
# 3) Parse Command-Line Options
# --------------------------------------------------------------------
while getopts ":p:x:v" opt; do
  case "$opt" in
    p)
      PARENT_FOLDER="$OPTARG"
      ;;
    x)
      IFS=',' read -ra xarray <<< "$OPTARG"
      EXCLUSIONS=("${xarray[@]}")
      ;;
    v)
      VERBOSE=1
      ;;
    \?)
      echo -e "${RED}Error:${NC} Invalid option -$OPTARG"
      usage
      ;;
    :)
      echo -e "${RED}Error:${NC} Option -$OPTARG requires an argument."
      usage
      ;;
  esac
done

# --------------------------------------------------------------------
# 4) Validate Parent Folder
# --------------------------------------------------------------------
if [[ ! -d "$PARENT_FOLDER" ]]; then
  echo -e "${RED}Error:${NC} '$PARENT_FOLDER' is not a valid directory!"
  exit 1
fi

# --------------------------------------------------------------------
# 5) Build Exclusion Map
# --------------------------------------------------------------------
# We'll store absolute paths in a map for easy checking.
declare -A EXCLUDE_MAP
for name in "${EXCLUSIONS[@]}"; do
  # Trim whitespace
  local_name="$(echo -e "${name}" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g')"
  # Form the absolute path
  full_path="${PARENT_FOLDER%/}/${local_name}"
  EXCLUDE_MAP["$full_path"]=1
done

# --------------------------------------------------------------------
# 6) Verbose Utility Function
# --------------------------------------------------------------------
vprint() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo -e "$1"
  fi
}

# --------------------------------------------------------------------
# 7) The Actual Cleanup
# --------------------------------------------------------------------
vprint "${BLUE}Starting selective cleanup in:${NC} $PARENT_FOLDER"
vprint "${BLUE}Excluding the following items:${NC} ${EXCLUSIONS[*]:-none}"

# We'll iterate through * and .* so we cover hidden files/folders too.
# The expansions might throw an error if no files match, so we can ignore that.
shopt -s nullglob dotglob

FAIL_COUNT=0

for item in "$PARENT_FOLDER"/* "$PARENT_FOLDER"/.*; do
  # Skip the special directory entries . and ..
  base="$(basename "$item")"
  if [[ "$base" == "." || "$base" == ".." ]]; then
    continue
  fi

  # Check if it's in the exclusion map
  if [[ -n "${EXCLUDE_MAP["$item"]+exists}" ]]; then
    vprint "${YELLOW}Skipping excluded:${NC} $item"
    continue
  fi

  # Attempt removal
  if [[ $VERBOSE -eq 1 ]]; then
    echo -ne "${BLUE}Removing:${NC} $item ... "
  fi

  rm -rf "$item" &>/dev/null || true

  # Check if it still exists
  if [[ -e "$item" ]]; then
    # Something failed
    ((FAIL_COUNT++))
    if [[ $VERBOSE -eq 1 ]]; then
      echo -e "${RED}FAILED${NC}"
    fi
  else
    if [[ $VERBOSE -eq 1 ]]; then
      echo -e "${GREEN}OK${NC}"
    fi
  fi
done

shopt -u nullglob dotglob

# --------------------------------------------------------------------
# 8) Final Report
# --------------------------------------------------------------------
if [[ $FAIL_COUNT -gt 0 ]]; then
  echo -e "${RED}Cleanup finished with $FAIL_COUNT failures.${NC}"
else
  echo -e "${GREEN}Cleanup finished successfully with no failures.${NC}"
fi

vprint "\nRemaining items in $PARENT_FOLDER:"
vprint "$(ls -la "$PARENT_FOLDER" 2>/dev/null)"

# Fun ASCII (optional final flourish)
echo -e "${YELLOW}\n   ~~~~~~~~~~~~~~~~~~~~~~~~"
echo -e "      ____          __  __       _ _   "
echo -e "     |  _ \\ ___  ___|  \\/  | ___ | | |_ "
echo -e "     | |_) / _ \\/ _ \\ |\\/| |/ _ \\| | __|"
echo -e "     |  _ <  __/  __/ |  | | (_) | | |_ "
echo -e "     |_|_\\_\\___|\\___|_|  |_|\\___/|_|\\__| "
echo -e "   ~~~~~~~~~~~~~~~~~~~~~~~~${NC}"
