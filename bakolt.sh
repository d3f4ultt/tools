#!/usr/bin/env bash
#
# bakolt.sh
# ------------------------------------------------------------------
# Quickly compress multiple directories/files using tar + pigz for
# parallel compression. Produces a .tar.gz archive.
# User specifies an output directory with -o, and the script will
# place the archive inside it (creating the folder if needed).
#
# Usage:
#   ./bakolt.sh -o /root/backup -t "/path/one,/path/two" \
#               [-x "exclude1,exclude2"] [-n "myarchive.tar.gz"] [-v]
#
#   -o   Output directory (e.g., /root/backup)
#   -t   Comma-separated list of directories/files to include
#   -x   Comma-separated list of paths to exclude (optional)
#   -n   Base name for the archive (defaults to backup.tar.gz)
#   -v   Verbose mode (displays tar progress)
#
# Example:
#   ./bakolt.sh -o /root/backup -t "/etc,/var/www" -n "config_www.tar.gz"
# ------------------------------------------------------------------

set -euo pipefail

# Defaults
OUTPUT_DIR="/tmp"
ARCHIVE_NAME="backup.tar.gz"
declare -a TARGETS
declare -a EXCLUDES
VERBOSE=""

usage() {
  echo "Usage: $0 -o <output_dir> -t \"dir1,dir2\" [-x \"exclude1,exclude2\"] [-n <archive_name>] [-v]"
  exit 1
}

while getopts ":o:t:x:n:v" opt; do
  case "$opt" in
    o)
      OUTPUT_DIR="$OPTARG"
      ;;
    t)
      IFS=',' read -ra TARGS <<< "$OPTARG"
      TARGETS=("${TARGS[@]}")
      ;;
    x)
      IFS=',' read -ra EXCS <<< "$OPTARG"
      EXCLUDES=("${EXCS[@]}")
      ;;
    n)
      ARCHIVE_NAME="$OPTARG"
      ;;
    v)
      VERBOSE="v"
      ;;
    \?)
      echo "Error: Invalid option -$OPTARG"
      usage
      ;;
    :)
      echo "Error: Option -$OPTARG requires an argument."
      usage
      ;;
  esac
done

# Validate we have targets
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "Error: No targets specified with -t"
  usage
fi

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Construct full archive path
ARCHIVE_PATH="${OUTPUT_DIR%/}/${ARCHIVE_NAME}"

# Construct exclude args for tar
declare -a EXCLUDE_ARGS
for e in "${EXCLUDES[@]}"; do
  EXCLUDE_ARGS+=( "--exclude=${e}" )
done

# Ensure pigz is installed
if ! command -v pigz &>/dev/null; then
  echo "Error: pigz is not installed. Install pigz for parallel compression."
  exit 1
fi

# Announce what's being backed up
echo "==> Backing up: ${TARGETS[*]}"
echo "==> Excluding:  ${EXCLUDES[*]:-none}"
echo "==> Output Dir: $OUTPUT_DIR"
echo "==> Archive:    $ARCHIVE_PATH"

# Execute tar + pigz
tar \
  -c${VERBOSE}f - \
  "${EXCLUDE_ARGS[@]}" \
  "${TARGETS[@]}" \
  | pigz -9 > "$ARCHIVE_PATH"

# Verify archive presence
if [[ -f "$ARCHIVE_PATH" ]]; then
  echo "==> Backup archive created: $ARCHIVE_PATH"
  ls -lh "$ARCHIVE_PATH"
else
  echo "==> Backup failed. Archive not found!"
  exit 1
fi

# Fun ASCII flourish at the end, displaying "BAKOLT"
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No color

echo -e "${YELLOW}\n   ~~~~~~~~~~~~~~~~~~~~~~~~"
echo -e "   ____             _    _ "
echo -e "  | __ )  __ _  ___| | _| |"
echo -e "  |  _ \\ / _\` |/ __| |/ / |"
echo -e "  | |_) | (_| | (__|   <|_|"
echo -e "  |____/ \\__,_|\\___|_|\\_(_)"
echo -e "   ~~~~~~~~~~~~~~~~~~~~~~~~${NC}"
echo -e "${BLUE}==> Done. Happy backups!${NC}\n"
