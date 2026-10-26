#!/usr/bin/env bash
# iPhone Duo simulator capture for Swoop (called by .github/workflows/duo.yml).
# Lessons inherited from Squish and Brim (their docs: DUO-CI.md, ci/duo.sh):
#  - `simctl io screenshot` needs --display on the Duo; we probe the names and keep the lit panel.
#  - The Duo sim starts in book pose: a landscape inner canvas with the fold running top to bottom. That is exactly
#    Swoop's play pose, so no orientation requests are needed here.
#  - Never run `simctl io … screenConfig` on the Duo (SpringBoard crash loop).
#  - Wait ~2.5 s after a hinge move for the display to settle; `hinge` occasionally fails a move, so retry.
# Env: UDID, OUT (duo-screens), PASSES ("hinge store ui").
#      STORE_LIST (optional): a scenario file (`name|demo args|wait|caption|expect`) for the store pass;
#      STORE_FILTER (regex on the name, default ".").
set -uo pipefail

APP="build/Build/Products/Debug-iphonesimulator/Swoop.app"
BUNDLE="com.pravegm.swoop"
OUT="${OUT:-duo-screens}"
PASSES="${PASSES:-hinge store ui}"
mkdir -p "$OUT/raw" "$OUT/logs"
OUT_ABS="$(cd "$OUT" && pwd)"
RUNLOG="$OUT_ABS/logs/run.txt"
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$RUNLOG" >&2; }
to() { local s="$1"; shift; gtimeout -k 5 "$s" "$@"; }

xcrun simctl install "$UDID" "$APP" || { log "install failed"; exit 1; }

INNER=""; COVER=""
for c in LCD-1 primary-1 3 internal; do
  to 30 xcrun simctl io "$UDID" screenshot --display="$c" "$OUT_ABS/raw/_p.png" >/dev/null 2>>"$RUNLOG" && { INNER="$c"; break; }
done
for c in LCD primary 1 external; do
  [[ "$c" == "$INNER" ]] && continue
  to 30 xcrun simctl io "$UDID" screenshot --display="$c" "$OUT_ABS/raw/_p.png" >/dev/null 2>>"$RUNLOG" && { COVER="$c"; break; }
done
rm -f "$OUT_ABS/raw/_p.png"
log "displays inner=$INNER cover=$COVER"

HAVE_HINGE=0; command -v hinge >/dev/null 2>&1 && HAVE_HINGE=1
CUR=180
hinge_set() { (( HAVE_HINGE )) || return 1; local a; for a in 1 2 3; do to 20 hinge -d "$UDID" -t 3 "$1" >>"$RUNLOG" 2>&1 && { CUR="$1"; return 0; }; sleep 1; done; log "WARN hinge set $1 failed"; return 1; }
hinge_sweep() {   # hinge_sweep <to> <seconds>: continuous 60 Hz stream so the app sees a real motion
  (( HAVE_HINGE )) || return 1
  to $(( ${2%.*} + 20 )) hinge -d "$UDID" sweep "$CUR" "$1" "$2" >>"$RUNLOG" 2>&1 || log "WARN sweep exited non-zero"
  CUR="$1"
}

# brightness of a PNG, 0-255 (sips → 16×16 BMP)
brightness() {
  local tmp="$OUT_ABS/raw/_b.bmp"
  to 20 sips -z 16 16 -s format bmp "$1" --out "$tmp" >/dev/null 2>&1 || { echo -1; return; }
  python3 -I - "$tmp" <<'PY' 2>/dev/null || echo -1
import struct, sys
b = open(sys.argv[1], "rb").read()
off = struct.unpack_from("<I", b, 10)[0]; w, h = struct.unpack_from("<ii", b, 18); bpp = struct.unpack_from("<H", b, 28)[0]
step = bpp // 8; row = (w * step + 3) & ~3; tot = n = 0
for y in range(abs(h)):
    for x in range(w):
        p = off + y * row + x * step; tot += b[p] + b[p + 1] + b[p + 2]; n += 3
print(int(tot / n))
PY
  rm -f "$tmp"
}

shoot() {   # shoot <name> <inner|cover>
  local name="$1" want="$2" ib=-1 cb=-1 pick
  [[ -n "$INNER" ]] && to 30 xcrun simctl io "$UDID" screenshot --display="$INNER" "$OUT_ABS/raw/$name-inner.png" >/dev/null 2>>"$RUNLOG" && ib=$(brightness "$OUT_ABS/raw/$name-inner.png")
  [[ -n "$COVER" ]] && to 30 xcrun simctl io "$UDID" screenshot --display="$COVER" "$OUT_ABS/raw/$name-cover.png" >/dev/null 2>>"$RUNLOG" && cb=$(brightness "$OUT_ABS/raw/$name-cover.png")
  if [[ -z "$INNER$COVER" ]]; then to 30 xcrun simctl io "$UDID" screenshot "$OUT_ABS/$name.png" >/dev/null 2>>"$RUNLOG"; return; fi
  if (( ib > 6 && cb <= 6 )); then pick=inner; elif (( cb > 6 && ib <= 6 )); then pick=cover; else pick="$want"; fi
  [[ -f "$OUT_ABS/raw/$name-$pick.png" ]] && cp "$OUT_ABS/raw/$name-$pick.png" "$OUT_ABS/$name.png"
  log "shot $name (inner=$ib cover=$cb -> $pick, hinge ${CUR}°) size=$(sips -g pixelWidth -g pixelHeight "$OUT_ABS/$name.png" 2>/dev/null | awk '/pixel/{printf "%s ", $2}')"
}

launch() {   # launch <name> <demo args>
  local name="$1" args="$2"
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  : > "$OUT_ABS/logs/$name.txt"
  to 60 xcrun simctl launch --terminate-running-process --stdout="$OUT_ABS/logs/$name.txt" --stderr="$OUT_ABS/logs/$name.txt" \
    "$UDID" "$BUNDLE" -swoopDemo "$args" >/dev/null 2>>"$RUNLOG" || log "WARN launch $name failed"
  local t=0
  while (( t < 45 )); do grep -q "SWOOP-T frame 120" "$OUT_ABS/logs/$name.txt" 2>/dev/null && break; sleep 1; t=$((t+1)); done
  log "launched $name after ${t}s; $(grep -c 'SWOOP-H' "$OUT_ABS/logs/$name.txt" 2>/dev/null) hinge lines so far; $(grep -m1 'SWOOP-T canvas' "$OUT_ABS/logs/$name.txt" 2>/dev/null)"
  sleep 1
}

# freeze_wait <launch name> <freeze tag> <limit s>: wait for the app's "SWOOP-T freeze <tag>" line, then 1.5 s.
freeze_wait() {
  local f="$OUT_ABS/logs/$1.txt" t=0
  while (( t < $3 )); do grep -q "SWOOP-T freeze $2" "$f" 2>/dev/null && break; sleep 1; t=$((t+1)); done
  if grep -q "SWOOP-T freeze $2" "$f" 2>/dev/null; then log "$1 froze ($2) after ${t}s"; sleep 1.5
  else log "WARN $1: no 'SWOOP-T freeze $2' after $3 s (capturing anyway)"; fi
}

# ---- pass: real hinge flight ------------------------------------------------------------------------------
if [[ " $PASSES " == *" hinge "* ]]; then
  # Held like a book at 150°: the countdown, then a slow tuck/open rhythm (one swell every ~2 s), like a player.
  hinge_set 150
  launch hinge-flight "mode=flight;seed=7;hints=fresh"
  sleep 1.5; shoot duo-01-countdown inner
  sleep 2.5; shoot duo-02-first-drop inner
  for i in 1 2 3 4 5 6 7 8; do
    hinge_sweep 124 0.7; sleep 0.5
    [[ $i == 3 ]] && shoot duo-03-tucked inner
    hinge_sweep 156 0.6; sleep 0.4
    [[ $i == 4 ]] && shoot duo-04-open inner
  done
  shoot duo-05-midflight inner
  HL="$OUT_ABS/logs/hinge-flight.txt"
  {
    echo "== hinge flight check"
    echo "hinge lines: $(grep -c 'SWOOP-H' "$HL")"
    grep -E "SWOOP-T (canvas|input|calib|event)" "$HL" | head -40
  } >>"$RUNLOG"
  tucks=$(grep -cE "SWOOP-T tuck [0-9.]+ angle" "$HL")
  launches=$(grep -c "SWOOP-T event launched" "$HL")
  touchdowns=$(grep -c "SWOOP-T event touchdown" "$HL")
  if grep -q "SWOOP-T input hinge" "$HL" && (( launches > 0 && touchdowns > 0 )); then
    log "HINGE-FLIGHT PASS (input hinge, launches=$launches touchdowns=$touchdowns tuck-lines=$tucks)"
  else
    log "HINGE-FLIGHT FAIL: input=$(grep -m1 'SWOOP-T input' "$HL") launches=$launches touchdowns=$touchdowns"
  fi

  # Closing pauses (never a crash, never a lost run): close to the cover display, reopen, keep flying.
  hinge_sweep 60 1.0; sleep 1; shoot duo-06-closing inner
  hinge_sweep 10 0.6; hinge_set 0; sleep 3; shoot duo-07-closed cover
  hinge_sweep 150 2.0; sleep 3; shoot duo-08-reopened inner
  if grep -q "SWOOP-T paused closing" "$HL" && grep -q "SWOOP-T resumed" "$HL"; then
    log "CLOSE-PAUSE PASS"
  else
    log "CLOSE-PAUSE FAIL: paused=$(grep -c 'SWOOP-T paused' "$HL") resumed=$(grep -c 'SWOOP-T resumed' "$HL")"
  fi
fi

# ---- pass: autopilot frames on the Duo canvas (store set) --------------------------------------------------
if [[ " $PASSES " == *" store "* ]]; then
  hinge_set 150 || true
  LIST="${STORE_LIST:-ci/duo-scenarios.txt}"
  [[ -f "$LIST" ]] || log "WARN store list $LIST not found"
  [[ -f "$LIST" ]] && while IFS='|' read -r -u 3 name args wait _caption _expect; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    [[ "$name" =~ ${STORE_FILTER:-.} ]] || continue
    launch "store-$name" "$args"
    if [[ "$args" =~ freezeOn=([a-z]+) ]]; then freeze_wait "store-$name" "${BASH_REMATCH[1]}" "$(( ${wait:-20} > 20 ? ${wait:-20} : 20 ))"
    else sleep "${wait:-6}"; fi
    shoot "store-$name" inner
    cp "$OUT_ABS/logs/store-$name.txt" "$OUT_ABS/logs/store-$name.at-capture.txt" 2>/dev/null || true
  done 3< "$LIST"
fi

# ---- pass: UI frames ---------------------------------------------------------------------------------------
if [[ " $PASSES " == *" ui "* ]]; then
  # The title bird mirrors the real hinge: spread at 160°, tucked at 124°.
  hinge_set 160 || true
  launch ui-home "screen=home"; sleep 3; shoot duo-ui-home-open inner
  hinge_sweep 124 1.0; sleep 2; shoot duo-ui-home-tucked inner
  hinge_sweep 160 1.0; sleep 1
  launch ui-results "screen=results;progress=mid"; sleep 4; shoot duo-ui-results inner
  launch ui-goals "screen=goals;progress=mid"; sleep 4; shoot duo-ui-goals inner
  launch ui-birds "screen=birds;progress=late"; sleep 4; shoot duo-ui-birds inner
  launch ui-settings "screen=settings"; sleep 3; shoot duo-ui-settings inner
  hinge_sweep 40 1.5; hinge_set 0; sleep 3; shoot duo-ui-cover cover
  hinge_set 160 || true
fi

ls -la "$OUT_ABS"
exit 0
