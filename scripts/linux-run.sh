#!/bin/bash
# Run the title on Linux/Wine and print a one-screen summary of what happened.
#
#   scripts/linux-run.sh <game exe> [seconds to watch] [wine runner]
#
# The wine runner is a script that execs wine with "$@" (see docs/linux-8gb.md);
# it must already export WINEPREFIX, the Vulkan ICD and DISPLAY/XAUTHORITY.
# Everything goes to ./ztrx-run.log and ./ztrx-run-summary.txt next to the exe.
set -u
EXE=${1:?usage: linux-run.sh <game exe> [seconds] [wine runner]}
WATCH=${2:-300}
RUNNER=${3:-$PWD/wine-run.sh}
[ -x "$RUNNER" ] || { echo "runner not executable: $RUNNER" >&2; exit 2; }

LOG=$PWD/ztrx-run.log
SUM=$PWD/ztrx-run-summary.txt
: > "$LOG"

export VICTORY_SHADER_LOOP_LIMIT=${VICTORY_SHADER_LOOP_LIMIT:-256}
export VICTORY_RELAY=${VICTORY_RELAY:-2}
export VICTORY_LATE_WAIT=${VICTORY_LATE_WAIT:-3}
export VICTORY_WIDE_BACK=${VICTORY_WIDE_BACK:-1}
export VICTORY_TEXTURE_NO_WAIT=${VICTORY_TEXTURE_NO_WAIT:-1}
export VICTORY_CACHE_DIR=${VICTORY_CACHE_DIR:-$HOME/ztrx-cache}
export VICTORY_DATA_DIR=${VICTORY_DATA_DIR:-$HOME/ztrx-data}
mkdir -p "$VICTORY_CACHE_DIR" "$VICTORY_DATA_DIR"

XID_BEFORE=$(journalctl -k --no-pager 2>/dev/null | grep -c Xid || true)
setsid nohup "$RUNNER" victory.exe run "$EXE" --execute >>"$LOG" 2>&1 </dev/null &
PID=$!
sleep "$WATCH"
ALIVE=$(pgrep -c -f "victory.exe run" || true)
XID_AFTER=$(journalctl -k --no-pager 2>/dev/null | grep -c Xid || true)

{
  echo "run: $(date -Is), watched ${WATCH}s, still running: ${ALIVE:-0}"
  echo "settings: loop=${VICTORY_SHADER_LOOP_LIMIT} relay=${VICTORY_RELAY} late_wait=${VICTORY_LATE_WAIT} wide_back=${VICTORY_WIDE_BACK} texture_no_wait=${VICTORY_TEXTURE_NO_WAIT}"
  echo "xid lines: $((XID_AFTER - XID_BEFORE)) new"
  echo "swapchain failures: $(grep -ac 'Failed to create swapchain' "$LOG" || true)"
  echo "pipeline library: $(grep -a 'pipeline library' "$LOG" | tail -1 | sed 's/.*INFO //' || true)"
  echo "asserts: $(grep -acE '_wassert|unhandled exception' "$LOG" || true)"
  echo "fps samples (first, worst, last):"
  grep -aoE "[0-9.]+ fps, [0-9.]+ ms/frame" "$LOG" | head -1 | sed 's/^/  first /'
  grep -aoE "[0-9.]+ ms/frame" "$LOG" | sort -t. -k1 -rn | head -1 | sed 's/^/  worst /'
  grep -aoE "[0-9.]+ fps, [0-9.]+ ms/frame" "$LOG" | tail -1 | sed 's/^/  last  /'
  echo "draws/frame: $(grep -aoE '[0-9]+ draws/frame' "$LOG" | sort -rn | head -1 | sed 's/ draws.*//') max"
  echo "shaders translated: $(grep -ac 'shader translated' "$LOG" || true)"
  echo "audio streams open: $(pactl list short sink-inputs 2>/dev/null | grep -c victory || true)"
} | tee "$SUM"

[ "${ALIVE:-0}" -gt 0 ] && echo "left running (pid group $PID); stop with: pkill -f 'victory.exe run'"
