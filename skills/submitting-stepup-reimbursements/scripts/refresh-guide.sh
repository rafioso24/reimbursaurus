#!/usr/bin/env bash
# Fetch current Step Up purchasing guides, extract text, and report what changed.
# Usage:
#   bash scripts/refresh-guide.sh              # all reimbursement programs
#   bash scripts/refresh-guide.sh FES-UA       # one program
#   bash scripts/refresh-guide.sh <url>        # any guide URL (PDF or web page); saved as "custom"
# Programs: FES-UA, FTC-FES-EO (private school guide), PEP.
# Saves per program in reference/: <PROGRAM>.txt .sha256 .source .fetched
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
REF="$HERE/reference"
mkdir -p "$REF"

# program -> "primary URL|fallback URL". Primary is the newest known edition. If a new school year starts, find the new link on
# https://fcsua.org/FESUA/ (FES-UA) or https://www.stepupforstudents.org/purchasing-guides/ (others) and edit the URL here.
guide_urls() {
  case "$1" in
    FES-UA)      echo "https://fcsua.org/docs/fesua/2026-27-purchasing-english.pdf|https://go.stepupforstudents.org/hubfs/GUIDES/FES-UA-Purchasing-Guide.pdf" ;;
    FTC-FES-EO)  echo "https://www.stepupforstudents.org/handbook-web/private-school-purchasing-guide/|https://go.stepupforstudents.org/hubfs/GUIDES/Private-School-Purchasing-Guide.pdf" ;;
    PEP)         echo "https://www.stepupforstudents.org/handbook-web/pep-purchasing-guide/|https://go.stepupforstudents.org/hubfs/GUIDES/PEP-Purchasing-Guide.pdf" ;;
    *) return 1 ;;
  esac
}

# Downloads are untrusted data: fresh empty directory, nothing from it is ever executed.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fetch_text() { # url outfile -> 0 on success
  local url="$1" out="$2" raw="$WORK/raw.bin"
  curl -fsSL --max-time 90 -A "Mozilla/5.0 (stepup-skill)" -o "$raw" "$url" || return 1
  if head -c 5 "$raw" | grep -q '%PDF-'; then
    pdftotext -layout "$raw" "$out" 2>/dev/null || return 1
  else
    python3 -I - "$raw" "$out" <<'PY' || return 1
import sys, re, html
from html.parser import HTMLParser
class T(HTMLParser):
    def __init__(s): super().__init__(); s.o=[]; s.skip=0
    def handle_starttag(s,t,a):
        if t in("script","style","noscript"): s.skip+=1
        if t in("p","div","li","br","tr","h1","h2","h3","h4","h5","h6"): s.o.append("\n")
    def handle_endtag(s,t):
        if t in("script","style","noscript") and s.skip: s.skip-=1
    def handle_data(s,d):
        if not s.skip: s.o.append(d)
p=T(); p.feed(open(sys.argv[1],encoding="utf-8",errors="replace").read())
txt=html.unescape("".join(p.o)); txt=re.sub(r"[ \t]+"," ",txt); txt=re.sub(r"\n\s*\n+","\n",txt)
open(sys.argv[2],"w").write(txt)
PY
  fi
  [ "$(wc -c < "$out")" -gt 2000 ]
}

refresh_one() { # name primary [fallback]
  local name="$1" primary="$2" fallback="${3:-}" txt="$WORK/$1.txt" used=""
  rm -f "$txt"
  if fetch_text "$primary" "$txt"; then used="$primary"
  elif [ -n "$fallback" ] && fetch_text "$fallback" "$txt"; then used="$fallback"
  else echo "[$name] ERROR: could not fetch a readable guide (tried: $primary ${fallback:+$fallback})" >&2; return 1; fi

  local new old edition dated
  new="$(shasum -a 256 "$txt" | cut -d' ' -f1)"
  old="$(cat "$REF/$name.sha256" 2>/dev/null || echo none)"
  edition="$(grep -m1 -oE '20[0-9]{2}[-–]20?[0-9]{2}' "$txt" || true)"
  dated="$(grep -m1 -oiE '(last (updated|modified)|updated|effective)[: ]+[A-Za-z]+ [0-9]{1,2},? 20[0-9]{2}|(January|February|March|April|May|June|July|August|September|October|November|December) [0-9]{1,2}, 20[0-9]{2}' "$txt" || true)"
  echo "[$name] source: $used"
  echo "[$name] school year: ${edition:-unknown}   date: ${dated:-unknown}"
  if [ "$new" = "$old" ]; then echo "[$name] UNCHANGED since last refresh."; return 0; fi
  if [ -f "$REF/$name.txt" ]; then
    echo "[$name] CHANGED. Diff vs saved copy (first 120 lines):"
    diff -u "$REF/$name.txt" "$txt" | head -120 || true
  else
    echo "[$name] FIRST SAVE. Nothing to compare."
  fi
  cp "$txt" "$REF/$name.txt"; echo "$new" > "$REF/$name.sha256"
  echo "$used" > "$REF/$name.source"; date +%Y-%m-%d > "$REF/$name.fetched"
  echo "[$name] saved reference/$name.txt"
}

ARG="${1:-all}"
rc=0
case "$ARG" in
  all) for p in FES-UA FTC-FES-EO PEP; do IFS='|' read -r a b <<<"$(guide_urls "$p")"; refresh_one "$p" "$a" "$b" || rc=1; echo; done ;;
  http*) refresh_one custom "$ARG" || rc=1 ;;
  *) if u="$(guide_urls "$ARG")"; then IFS='|' read -r a b <<<"$u"; refresh_one "$ARG" "$a" "$b" || rc=1
     else echo "Unknown program '$ARG'. Use FES-UA, FTC-FES-EO, PEP, all, or a URL." >&2; rc=2; fi ;;
esac
echo "NEXT: update category-map.md from any diff, then compare the portal dropdowns."
exit $rc
