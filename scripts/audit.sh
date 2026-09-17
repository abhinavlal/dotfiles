#!/usr/bin/env bash
# scripts/audit.sh — read-only report of how this Mac lines up with the Brewfiles.
# Run via ./install.sh --audit. Installs nothing, taps nothing, changes nothing.
#
# For each Brewfile cask it predicts what `brew bundle` will do:
#   brew       already managed by Homebrew
#   new        not on this Mac; will be installed
#   adopt      app already exists (installed by hand); Homebrew takes it over as-is
#   mismatch   app exists but its version differs; install fails, app left alone
#   app-store  an App Store copy exists; adopting it would give it two updaters
#   installer  installed by hand via a vendor .pkg/installer; brew re-runs it
#   untrusted  from a third-party tap Homebrew hasn't been told to trust; it gets ignored
# Anything marked "password" asks for an admin password, so it can't run
# unattended (e.g. from an agent without a terminal).
#
# Written for macOS's stock bash 3.2 — no bash 4 features.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREWFILES=("$DOTFILES/Brewfile" "$DOTFILES/Brewfile.extras")
APPDIR="/Applications"
export HOMEBREW_NO_AUTO_UPDATE=1

die() { echo "audit: $*" >&2; exit 1; }
command -v brew &>/dev/null || die "Homebrew not found — install it from https://brew.sh first"
command -v jq &>/dev/null || die "jq not found (ships with macOS 15+; otherwise: brew install jq)"

row() { printf '  %-10s %-30s %s\n' "$1" "$2" "${3:-}"; }
section() { printf '\n%s\n' "$1"; }
# Here-strings, not pipes: with pipefail, `printf | grep -q` fails with SIGPIPE
# when grep matches early and exits before printf finishes writing.
contains_line() { grep -Fxq -- "$2" <<< "$1"; }

# Brewfile entries, one per line. Entries are matched textually, so keep one
# entry per line in the Brewfiles.
entries() { sed -nE "s/^[[:space:]]*$1 \"([^\"]+)\".*/\\1/p" "${BREWFILES[@]}"; }

plist_value() { plutil -extract "$2" raw -o - "$1/Contents/Info.plist" 2>/dev/null || true; }

# Emits one "|"-separated line per cask: full_token|installed|auto_updates|
# version|kind|sudo|app paths|pkgutil ids|deleted .app paths  (lists ";"-joined)
cask_rows() {
  (( $# )) || return 0
  brew info --cask --json=v2 "$@" 2>/dev/null | jq -r '
    def list(f): [.artifacts[] | select(has("uninstall")) | .uninstall[] | f // empty
                  | if type == "array" then .[] else . end | select(type == "string")];
    .casks[]
    | [.artifacts[] | select(has("app")) | (.target // ("/Applications/" + .app[0]))] as $apps
    | (if any(.artifacts[]; has("pkg")) then "pkg"
       elif any(.artifacts[]; has("installer")) then "installer"
       elif ($apps | length) > 0 then "app" else "other" end) as $kind
    | (($kind == "pkg") or (tostring | test("\"sudo\":true"))) as $sudo
    | [.full_token, (.installed // ""), (.auto_updates // false | tostring), .version, $kind,
       ($sudo | tostring), ($apps | join(";")), (list(.pkgutil?) | join(";")),
       (list(.delete?) | map(select(test("^/.*\\.app$"))) | join(";"))]
    | join("|")'
}

# Apps that a cask's pkg receipts put in /Applications (pkg casks don't list them as artifacts).
pkg_apps() {
  local id
  for id in $(printf '%s' "$1" | tr ';' ' '); do
    # The receipt's install location is either the app itself or a root the files hang off.
    pkgutil --pkg-info "$id" 2>/dev/null | sed -nE 's#^location: /?(Applications/[^/]+\.app)/?$#/\1#p'
    pkgutil --files "$id" 2>/dev/null | sed -nE 's#^Applications/([^/]+\.app)$#/Applications/\1#p'
  done
}

# Homebrew ignores casks from third-party taps until they're trusted, either via
# `trusted: true` on the Brewfile line (brew bundle trusts it on install) or `brew trust`.
trust_json="$(brew trust --json=v1 2>/dev/null || echo '{}')"
tap_cask_trusted() {
  local cask="$1"
  grep -Eq "^[[:space:]]*cask \"$cask\".*trusted:[[:space:]]*true" "${BREWFILES[@]}" && return 0
  jq -e --arg cask "$cask" --arg tap "${cask%/*}" \
    'any((.taps // [])[]; . == $tap) or any((.casks // [])[]; . == $cask)' <<< "$trust_json" >/dev/null
}

# Third-party tap casks can run sudo in postflight blocks the JSON doesn't show,
# so read the cask source: from the local tap if added, else from GitHub.
tap_cask_uses_sudo() {
  local tap="$1" name="$2" repo file
  repo="$(brew --repository "$tap")"
  for file in "$repo/Casks/$name.rb" "$repo/Casks/${name:0:1}/$name.rb"; do
    [[ -f "$file" ]] && { grep -Eq 'sudo:[[:space:]]*true' "$file"; return; }
  done
  local url="https://raw.githubusercontent.com/${tap%%/*}/homebrew-${tap#*/}/HEAD/Casks" body
  for file in "$url/$name.rb" "$url/${name:0:1}/$name.rb"; do
    body="$(curl -fsSL --max-time 10 "$file" 2>/dev/null)" || continue
    grep -Eq 'sudo:[[:space:]]*true' <<< "$body"
    return
  done
  return 1
}

echo "Audit: $(scutil --get ComputerName 2>/dev/null || hostname) vs Brewfile + Brewfile.extras (read-only)"

tapped="$(brew tap)"
installed_casks="$(brew list --cask -1 2>/dev/null)"
covered_apps=""        # every .app path accounted for by some Brewfile or Homebrew entry
n_new=0 n_adopt=0 n_brew=0 n_problem=0 n_password=0
password_casks=""

# ── Casks ─────────────────────────────────────────────────────────────────────
section "Casks"
queryable=()
untapped=()
while IFS= read -r cask; do
  [[ -n "$cask" ]] || continue
  if [[ "$cask" == */*/* ]] && ! contains_line "$tapped" "${cask%/*}"; then
    untapped+=("$cask")       # brew info would add the tap; report these without it
  else
    queryable+=("$cask")
  fi
done < <(entries cask)

while IFS='|' read -r token installed auto_updates version kind sudo apps pkgs deletes; do
  [[ -n "$token" ]] || continue
  name="${token##*/}"
  if [[ "$token" == */*/* ]] && tap_cask_uses_sudo "${token%/*}" "$name"; then sudo=true; fi
  pw=""
  [[ "$sudo" == true ]] && pw=" [password]"

  candidates="$(printf '%s' "$apps;$deletes" | tr ';' '\n' | sed '/^$/d')"
  [[ -n "$pkgs" ]] && candidates="$(printf '%s\n%s' "$candidates" "$(pkg_apps "$pkgs")" | sed '/^$/d')"
  covered_apps="$(printf '%s\n%s' "$covered_apps" "$candidates")"

  if [[ -n "$installed" ]]; then
    row "brew" "$name"; n_brew=$((n_brew + 1)); continue
  fi

  present=""
  while IFS= read -r path; do
    [[ -n "$path" && -d "$path" ]] && { present="$path"; break; }
  done <<< "$candidates"
  if [[ -z "$present" && "$kind" != app && -n "$pkgs" ]]; then
    for id in $(printf '%s' "$pkgs" | tr ';' ' '); do
      pkgutil --pkg-info "$id" &>/dev/null && { present="pkg $id"; break; }
    done
  fi

  # Adopting runs chmod on the existing app, with sudo when the bundle isn't
  # writable — which macOS enforces for apps installed by other means even
  # when you own the files. Same check Homebrew makes (File#writable?).
  if [[ -n "$present" && -d "$present" && ! -w "$present" && "$kind" == app ]]; then
    pw=" [password]"
  fi

  if [[ -z "$present" && "$token" == */*/* ]] && ! tap_cask_trusted "$token"; then
    row "untrusted" "$name" "tap ${token%/*} isn't trusted, so Homebrew ignores it — add trusted: true to its Brewfile line$pw"
    n_problem=$((n_problem + 1))
  elif [[ -z "$present" ]]; then
    row "new" "$name" "${pw# }"
    n_new=$((n_new + 1))
  elif [[ "$kind" == pkg || "$kind" == installer ]]; then
    row "installer" "$name" "installed by hand (${present##*/}); brew re-runs the vendor installer over it$pw"
    n_adopt=$((n_adopt + 1))
  elif [[ -d "$present/Contents/_MASReceipt" ]]; then
    row "app-store" "$name" "${present##*/} is the App Store copy — use a mas entry, or delete the app first"
    n_problem=$((n_problem + 1))
  elif [[ "$auto_updates" == true ]]; then
    row "adopt" "$name" "${present##*/} installed by hand; updates itself, so it is adopted as-is$pw"
    n_adopt=$((n_adopt + 1))
  else
    have="$(plist_value "$present" CFBundleShortVersionString)"
    if [[ "$have" == "${version%%,*}" ]]; then
      row "adopt" "$name" "${present##*/} $have matches the cask, so it is adopted$pw"
      n_adopt=$((n_adopt + 1))
    else
      row "mismatch" "$name" "${present##*/} is ${have:-unknown}, cask is ${version%%,*} — update the app or delete it first"
      n_problem=$((n_problem + 1))
    fi
  fi
  [[ -n "$pw" ]] && { n_password=$((n_password + 1)); password_casks="$password_casks $name"; }
done < <(cask_rows ${queryable[@]+"${queryable[@]}"})

for cask in ${untapped[@]+"${untapped[@]}"}; do
  name="${cask##*/}"
  pw=""
  if tap_cask_uses_sudo "${cask%/*}" "$name"; then
    pw=" [password]"
    n_password=$((n_password + 1)); password_casks="$password_casks $name"
  fi
  if tap_cask_trusted "$cask"; then
    row "new" "$name" "from tap ${cask%/*}$pw"
    n_new=$((n_new + 1))
  else
    row "untrusted" "$name" "tap ${cask%/*} isn't trusted, so Homebrew ignores it — add trusted: true to its Brewfile line$pw"
    n_problem=$((n_problem + 1))
  fi
done

# ── Mac App Store ─────────────────────────────────────────────────────────────
section "Mac App Store (mas)"
mas_ids=""
command -v mas &>/dev/null && mas_ids="$(mas list 2>/dev/null | awk '{print $1}')"
while IFS='|' read -r name id; do
  [[ -n "$name" ]] || continue
  app="$APPDIR/$name.app"
  covered_apps="$(printf '%s\n%s' "$covered_apps" "$app")"
  if { [[ -n "$mas_ids" ]] && contains_line "$mas_ids" "$id"; } || [[ -d "$app/Contents/_MASReceipt" ]]; then
    row "installed" "$name"
  elif [[ -d "$app" ]]; then
    row "mismatch" "$name" "$name.app was not installed from the App Store — mas can't take it over"
    n_problem=$((n_problem + 1))
  else
    row "new" "$name" "needs you signed in to the App Store"
    n_new=$((n_new + 1))
  fi
done < <(sed -nE 's/^[[:space:]]*mas "([^"]+)",[[:space:]]*id:[[:space:]]*([0-9]+).*/\1|\2/p' "${BREWFILES[@]}")

# ── Formulae ──────────────────────────────────────────────────────────────────
section "Formulae"
installed_formulae="$(brew list --formula -1 2>/dev/null)"
missing=""
count=0
while IFS= read -r formula; do
  [[ -n "$formula" ]] || continue
  count=$((count + 1))
  contains_line "$installed_formulae" "${formula##*/}" || missing="$missing ${formula##*/}"
done < <(entries brew)
if [[ -n "$missing" ]]; then
  row "new" "${missing# }"
  n_new=$((n_new + $(printf '%s' "$missing" | wc -w)))
else
  row "brew" "all $count installed"
fi

# ── Not in any Brewfile ───────────────────────────────────────────────────────
section "On this Mac but not in any Brewfile"
untracked=0
brewfile_casks="$(entries cask | sed 's#.*/##')"
brewfile_formulae="$(entries brew | sed 's#.*/##')"

extra_casks=()
while IFS= read -r cask; do
  [[ -n "$cask" ]] || continue
  contains_line "$brewfile_casks" "$cask" && continue
  extra_casks+=("$cask")
  row "cask" "$cask" "installed via Homebrew — add it to a Brewfile or uninstall it"
  untracked=$((untracked + 1))
done <<< "$installed_casks"
while IFS='|' read -r _ _ _ _ _ _ apps pkgs deletes; do
  covered_apps="$(printf '%s\n%s\n%s' "$covered_apps" "$(printf '%s' "$apps;$deletes" | tr ';' '\n')" "$(pkg_apps "$pkgs")")"
done < <(cask_rows ${extra_casks[@]+"${extra_casks[@]}"})

while IFS= read -r formula; do
  [[ -n "$formula" ]] || continue
  contains_line "$brewfile_formulae" "$formula" && continue
  row "formula" "$formula" "installed on request — add it to a Brewfile or uninstall it"
  untracked=$((untracked + 1))
done < <(brew leaves --installed-on-request 2>/dev/null)

# app name -> cask token, from Homebrew's API cache; suggestions are skipped if unavailable.
cask_index=""
index_loaded=0
suggest_cask() {
  if (( ! index_loaded )); then
    index_loaded=1
    local f
    while IFS= read -r f; do
      cask_index="$(jq -r '
        (.payload | fromjson) as $p | ($p.casks // $p)
        | (if type == "object" then to_entries | map(.value + {token: .key}) else . end)
        | .[] | .token as $t
        | (.raw_artifacts // .artifacts // [])[]
        | if type == "array" then (select(.[0] == ":app") | .[1][]) else (.app? // empty | .[]) end
        | select(type == "string") | "\(.)|\($t)"' "$f" 2>/dev/null || true)"
      [[ -n "$cask_index" ]] && break
    done < <(find "$(brew --cache)/api" -name '*.jws.json' 2>/dev/null)
  fi
  awk -F'|' -v app="$1" '$1 == app { print $2; exit }' <<< "$cask_index"
}

for app in "$APPDIR"/*.app; do
  [[ -d "$app" ]] || continue
  contains_line "$covered_apps" "$app" && continue
  bundle_id="$(plist_value "$app" CFBundleIdentifier)"
  name="${app##*/}"
  # Apple's own apps are skipped, except Xcode, which people install themselves.
  [[ "$bundle_id" == com.apple.* && "$bundle_id" != com.apple.dt.Xcode ]] && continue
  if [[ -d "$app/Contents/_MASReceipt" ]]; then
    adam="$(mdls -raw -name kMDItemAppStoreAdamID "$app" 2>/dev/null || true)"
    [[ "$adam" =~ ^[0-9]+$ ]] || adam="<id>"
    row "app-store" "$name" "add: mas \"${name%.app}\", id: $adam"
  elif [[ "$bundle_id" == com.apple.dt.Xcode ]]; then
    row "xcodes" "$name" "Xcode build outside the App Store (xcodes) — fine to leave"
  else
    token="$(suggest_cask "$name")"
    if [[ -n "$token" ]]; then
      row "manual" "$name" "installed by hand — add: cask \"$token\""
    else
      row "manual" "$name" "installed by hand — no cask found"
    fi
  fi
  untracked=$((untracked + 1))
done
(( untracked )) || row "none"

# ── Summary ───────────────────────────────────────────────────────────────────
section "Summary"
echo "  $n_brew already in Homebrew, $n_adopt to adopt, $n_new to install, $n_problem to fix first, $untracked not in any Brewfile."
if (( n_problem )); then
  echo "  Fix the mismatch/app-store/untrusted rows before running ./install.sh --extras; those installs would fail."
fi
if (( n_password )); then
  echo "  Asks for an admin password:$password_casks"
  echo "  Without a terminal (e.g. an agent), skip them and run them yourself afterwards:"
  echo "    HOMEBREW_BUNDLE_CASK_SKIP=\"${password_casks# }\" ./install.sh --extras"
fi
exit 0
