#!/usr/bin/env bash
# Fetch current Step Up purchasing guides, extract text, and report what changed.
# Usage:
#   bash scripts/refresh-guide.sh              # all reimbursement programs
#   bash scripts/refresh-guide.sh FES-UA       # one program
#   bash scripts/refresh-guide.sh <url>        # any guide URL (PDF or web page); saved as "custom"
# Programs: FES-UA, FTC-FES-EO (private school guide), PEP.
# Saves per program in ~/.reimbursaurus/reference/ (override with REIMBURSAURUS_DATA):
#   <PROGRAM>.txt (or .pdf) .sha256 .source .fetched
# No installs needed. Uses only bash, curl, and perl, which ship with macOS, Linux, and Git Bash.
# pdftotext is used if present. Without it, PDF guides are saved as .pdf for Claude to read directly.
set -uo pipefail

REF="${REIMBURSAURUS_DATA:-$HOME/.reimbursaurus}/reference"
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

for tool in curl perl; do
  command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: '$tool' not found. It ships with macOS, Linux, and Git Bash, so this system is unusual." >&2; exit 2; }
done

hash_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else sha256sum "$1" | cut -d' ' -f1; fi
}

html_to_text() { # in out
  perl -CSD -0777 -pe '
    s/<(script|style|noscript)\b.*?<\/\1\s*>//gsi;
    s/<(br|p|div|li|tr|h[1-6])\b[^>]*>/\n/gi;
    s/<[^>]+>//g;
    s/&nbsp;/ /g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&rsquo;|&lsquo;/\x27/g; s/&rdquo;|&ldquo;/"/g;
    s/&ndash;/\x{2013}/g; s/&mdash;/\x{2014}/g;
    s/&#x([0-9a-f]+);/chr(hex $1)/gei; s/&#(\d+);/chr($1)/ge; s/&amp;/&/g;
    s/[ \t]+/ /g; s/\n\s*\n+/\n/g;
  ' "$1" > "$2"
}

# Downloads are untrusted data: fresh empty directory, nothing from it is ever executed.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FETCH_ERR=""
fetch_guide() { # url name -> sets KIND=txt|pdf, output in $WORK/<name>.<KIND>
  local url="$1" name="$2" raw="$WORK/raw.bin"
  rm -f "$WORK/$name.txt" "$WORK/$name.pdf"
  curl -fsSL --max-time 90 -A "Mozilla/5.0 (reimbursaurus)" -o "$raw" "$url" || { FETCH_ERR="download failed"; return 1; }
  if head -c 5 "$raw" | grep -q '%PDF-'; then
    if command -v pdftotext >/dev/null 2>&1 && pdftotext -layout "$raw" "$WORK/$name.txt" 2>/dev/null; then
      KIND=txt
    else
      cp "$raw" "$WORK/$name.pdf"; KIND=pdf; return 0
    fi
  else
    html_to_text "$raw" "$WORK/$name.txt" || { FETCH_ERR="could not extract text from web page"; return 1; }
    KIND=txt
  fi
  [ "$(wc -c < "$WORK/$name.txt")" -gt 2000 ] || { FETCH_ERR="page had too little text"; return 1; }
}

refresh_one() { # name primary [fallback]
  local name="$1" primary="$2" fallback="${3:-}" used="" err1=""
  if fetch_guide "$primary" "$name"; then used="$primary"
  else
    err1="$FETCH_ERR"
    if [ -n "$fallback" ] && fetch_guide "$fallback" "$name"; then used="$fallback"
    else echo "[$name] ERROR: no readable guide. $primary: $err1${fallback:+. $fallback: $FETCH_ERR}" >&2; return 1; fi
  fi

  local file="$WORK/$name.$KIND" new old
  new="$(hash_file "$file")"
  old="$(cat "$REF/$name.sha256" 2>/dev/null || echo none)"
  echo "[$name] source: $used"

  if [ "$KIND" = txt ]; then
    local edition dated
    edition="$(grep -m1 -oE '20[0-9]{2}[-–]20?[0-9]{2}' "$file" || true)"
    dated="$(grep -m1 -oiE '(last (updated|modified)|updated|effective)[: ]+[A-Za-z]+ [0-9]{1,2},? 20[0-9]{2}|(January|February|March|April|May|June|July|August|September|October|November|December) [0-9]{1,2}, 20[0-9]{2}' "$file" || true)"
    echo "[$name] school year: ${edition:-unknown}   date: ${dated:-unknown}"
  fi

  if [ "$new" = "$old" ]; then echo "[$name] UNCHANGED since last refresh."; date +%Y-%m-%d > "$REF/$name.fetched"; return 0; fi

  if [ "$KIND" = pdf ]; then
    echo "[$name] $( [ "$old" = none ] && echo 'FIRST SAVE' || echo 'CHANGED' ). Saved as PDF (pdftotext not installed)."
    echo "[$name] CLAUDE: read $REF/$name.pdf with the Read tool. Do NOT pass the pages parameter (it needs poppler). Reading the whole file works."
    rm -f "$REF/$name.txt"
  elif [ -f "$REF/$name.txt" ]; then
    echo "[$name] CHANGED. Diff vs saved copy (first 120 lines):"
    diff -u "$REF/$name.txt" "$file" | head -120 || true
  else
    echo "[$name] FIRST SAVE. Nothing to compare."
    rm -f "$REF/$name.pdf"
  fi
  cp "$file" "$REF/$name.$KIND"; echo "$new" > "$REF/$name.sha256"
  echo "$used" > "$REF/$name.source"; date +%Y-%m-%d > "$REF/$name.fetched"
  echo "[$name] saved $REF/$name.$KIND"
}

ARG="${1:-all}"
rc=0
case "$ARG" in
  all) for p in FES-UA FTC-FES-EO PEP; do IFS='|' read -r a b <<<"$(guide_urls "$p")"; refresh_one "$p" "$a" "$b" || rc=1; echo; done ;;
  http*) refresh_one custom "$ARG" || rc=1 ;;
  *) if u="$(guide_urls "$ARG")"; then IFS='|' read -r a b <<<"$u"; refresh_one "$ARG" "$a" "$b" || rc=1
     else echo "Unknown program '$ARG'. Use FES-UA, FTC-FES-EO, PEP, all, or a URL." >&2; rc=2; fi ;;
esac
echo "NEXT: update category-map.md from any diff or new PDF, then compare the portal dropdowns."
exit $rc
