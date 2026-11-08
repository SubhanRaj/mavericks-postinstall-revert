#!/bin/bash
#
# revert-postinstall.command
#
# Undoes the Snow Leopard-style changes made by
# https://mavericksforever.com/postinstall.sh on OS X 10.9 and turns
# Gatekeeper back on.
#
# Usage:      double-click this file, or run:  bash revert-postinstall.command [installer]
#             (double-clicking needs  chmod +x revert-postinstall.command  once)
#
#   installer (optional) is where Apple's original Dock layout is copied from.
#   It can be the bootable USB volume (for example "/Volumes/OS X Base System"),
#   "Install OS X Mavericks.app", an InstallESD.dmg / BaseSystem.dmg file, or a
#   folder you copied off the installer that holds the *.lproj/default.plist
#   files (the Dock.app/Contents/Resources folder, or Dock.app itself).
#
#   Without an argument the script looks through /Volumes, then asks you at the
#   start. At that prompt you can paste or drag in the path, press Return to
#   skip the Dock step (run the script again later with the path), or type r
#   to use a rebuilt copy of the stock layout. With no terminal to ask on, it
#   uses the rebuilt layout.
#
# Reverted:   Finder, Time Machine, Notes, autocorrect, iCloud-save and
#             automatic-termination defaults (current user and the new-user
#             template), Dashboard overlay, visible ~/Library and /usr,
#             /Applications/Utilities permissions, HiDPI flag, Gatekeeper,
#             and the Dock layout.
# Left alone: the security patches, SMB and .DS_Store tweaks, media-key
#             patches, font fix, classic wallpapers. Widgets, Maps and Game
#             Center were deleted by the original script and cannot be
#             restored from here.
#
# Optional:   REVERT_SHELL=1 bash revert-postinstall.command
#             also removes the short Terminal prompt and case-insensitive tab
#             completion the original script set up.
#
# Run as your normal user, not with sudo. The Dock goes back to the stock
# layout and your current Dock preferences are copied to the backup folder
# first.

REVERT_SHELL=${REVERT_SHELL:-0}

if [ "$(uname)" != "Darwin" ]; then
  echo "This script is for OS X."
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user, not with sudo. It asks for your password itself."
  exit 1
fi

TEMPLATE="/System/Library/User Template/Non_localized"
DOCK_RES="/System/Library/CoreServices/Dock.app/Contents/Resources"
BACKUP="$HOME/postinstall-revert-backup-$(date +%Y%m%d-%H%M%S)"
WORK=$(mktemp -d /tmp/revert-postinstall.XXXXXX)
MOUNTS=()
SRC_RES=""
LAST_MP=""

cleanup() {
  local m
  for m in "${MOUNTS[@]}"; do
    hdiutil detach "$m" -force >/dev/null 2>&1
  done
  rm -rf "$WORK"
}
trap cleanup EXIT

say() { echo "==> $*"; }
# Delete a key for the current user.
udel() { defaults delete "$1" "$2" >/dev/null 2>&1; }
# Delete a key in the new-user template. $1 is the plist name without .plist.
tdel() { sudo defaults delete "$TEMPLATE/Library/Preferences/$1" "$2" >/dev/null 2>&1; }
# Remove a file only if it still holds exactly what the original script wrote.
rm_if_exact() {
  if [ -f "$1" ] && [ "$(cat "$1")" = "$2" ]; then rm -f "$1"; fi
}
sudo_rm_if_exact() {
  if sudo test -f "$1" && [ "$(sudo cat "$1")" = "$2" ]; then sudo rm -f "$1"; fi
}

# --- Finding Apple's original Dock plists --- #

# Mount a disk image read-only; the mount point ends up in $LAST_MP.
attach_dmg() {
  LAST_MP="$WORK/mnt-${#MOUNTS[@]}"
  mkdir -p "$LAST_MP"
  if hdiutil attach "$1" -readonly -noverify -nobrowse -mountpoint "$LAST_MP" >/dev/null 2>&1; then
    MOUNTS+=("$LAST_MP")
    return 0
  fi
  return 1
}

# $1 is the root of a 10.9 system image. Sets SRC_RES if it holds Dock plists.
try_root() {
  local r="$1/System/Library/CoreServices/Dock.app/Contents/Resources"
  grep -q '<string>10\.9' "$1/System/Library/CoreServices/SystemVersion.plist" 2>/dev/null || return 1
  ls "$r"/*.lproj/default.plist >/dev/null 2>&1 || return 1
  SRC_RES="$r"
}

# $1 is a mounted installer volume, an InstallESD volume, or a plain folder
# holding the plists (a copied Dock.app, its Resources folder, or the
# *.lproj folders themselves).
find_from_dir() {
  local d="$1" r
  try_root "$d" && return 0
  if [ -f "$d/BaseSystem.dmg" ] && attach_dmg "$d/BaseSystem.dmg"; then
    try_root "$LAST_MP" && return 0
  fi
  for r in "$d" "$d/Resources" "$d/Contents/Resources" "$d/Dock.app/Contents/Resources"; do
    if ls "$r"/*.lproj/default.plist >/dev/null 2>&1; then
      SRC_RES="$r"
      return 0
    fi
  done
  return 1
}

src_from_path() {
  local p="${1%/}"
  case "$p" in
    *.app)
      if [ -f "$p/Contents/SharedSupport/InstallESD.dmg" ]; then
        attach_dmg "$p/Contents/SharedSupport/InstallESD.dmg" && find_from_dir "$LAST_MP"
      else
        # Not an installer: maybe a Dock.app copied off one.
        [ -d "$p" ] && find_from_dir "$p"
      fi
      ;;
    *.dmg)
      [ -f "$p" ] || return 1
      attach_dmg "$p" && find_from_dir "$LAST_MP"
      ;;
    *)
      [ -d "$p" ] && find_from_dir "$p"
      ;;
  esac
}

# Tidy a pasted or dragged-in path: trim spaces, drop quotes, undo the
# backslash escapes Terminal adds when you drag a file in, expand ~.
clean_path() {
  local p="$1"
  p="${p#"${p%%[![:space:]]*}"}"
  p="${p%"${p##*[![:space:]]}"}"
  case "$p" in
    \"*\") p="${p#\"}"; p="${p%\"}" ;;
    \'*\') p="${p#\'}"; p="${p%\'}" ;;
  esac
  p=$(printf '%s' "$p" | sed 's/\\\(.\)/\1/g')
  case "$p" in
    "~"|"~/"*) p="$HOME${p#\~}" ;;
  esac
  printf '%s' "$p"
}

# Decide where the Dock plists come from. Sets DOCK_MODE to installer,
# rebuilt or skip, and SRC_RES when it is installer.
PROMPT_TTY="${PROMPT_TTY:-/dev/tty}"
DOCK_MODE="installer"

choose_dock_source() {
  local ans prev

  INSTALLER="${1:-$INSTALLER}"
  if [ -n "$INSTALLER" ]; then
    src_from_path "$(clean_path "$INSTALLER")"
  else
    for v in /Volumes/*; do
      [ -d "$v" ] || continue
      [ "$v" -ef / ] && continue
      find_from_dir "$v" && break
    done
  fi

  # A path was given on the command line and it worked: nothing to ask.
  if [ -n "$INSTALLER" ] && [ -n "$SRC_RES" ]; then
    return 0
  fi

  # Nobody to ask: use what was found, otherwise the rebuilt layout.
  if ! { : < "$PROMPT_TTY"; } 2>/dev/null; then
    [ -n "$SRC_RES" ] || DOCK_MODE="rebuilt"
    return 0
  fi

  # Keep one handle on the terminal so every answer is read from the same place.
  exec 3< "$PROMPT_TTY"

  while true; do
    echo
    if [ -n "$SRC_RES" ]; then
      echo "Apple's original Dock plists found in:"
      echo "  $SRC_RES"
      echo "Press Return to use them, or paste a different path."
    else
      echo "Apple's original Dock plists were not found yet."
      echo "Paste the path to the installer: the bootable USB volume,"
      echo "Install OS X Mavericks.app, InstallESD.dmg / BaseSystem.dmg, or a"
      echo "folder you copied the Dock plists into. Dragging it into this"
      echo "window works too."
      echo "  Return = skip the Dock step for now    r = use the rebuilt layout"
    fi
    printf '> '
    IFS= read -r ans <&3 || { [ -n "$SRC_RES" ] || DOCK_MODE="skip"; return 0; }
    ans=$(clean_path "$ans")
    case "$ans" in
      "")
        [ -n "$SRC_RES" ] || DOCK_MODE="skip"
        return 0
        ;;
      r|R)
        DOCK_MODE="rebuilt"
        SRC_RES=""
        return 0
        ;;
    esac
    prev="$SRC_RES"
    SRC_RES=""
    if src_from_path "$ans"; then
      return 0
    fi
    SRC_RES="$prev"
    echo "No Dock plists found at: $ans"
  done
}

clear
choose_dock_source "$@"

echo
echo "Please type in your password. No letters will appear as you type."
echo "Press return when done."
sudo -v || exit 1

mkdir -p "$BACKUP"

# --- Defaults set in the "Mimic Snow Leopard" section --- #
say "Resetting Finder, Time Machine, Notes, autocorrect and related defaults"

udel NSGlobalDomain NSDisableAutomaticTermination
tdel .GlobalPreferences NSDisableAutomaticTermination

udel com.apple.finder NewWindowTarget
udel com.apple.finder NewWindowTargetPath
tdel com.apple.finder NewWindowTarget
tdel com.apple.finder NewWindowTargetPath

udel com.apple.finder FXDefaultSearchScope
tdel com.apple.finder FXDefaultSearchScope

udel NSGlobalDomain NSDocumentSaveNewDocumentsToCloud
tdel .GlobalPreferences NSDocumentSaveNewDocumentsToCloud

udel com.apple.TimeMachine DoNotOfferNewDisksForBackup
tdel com.apple.TimeMachine DoNotOfferNewDisksForBackup

udel NSGlobalDomain NSAutomaticSpellingCorrectionEnabled
udel NSGlobalDomain WebAutomaticSpellingCorrectionEnabled
tdel .GlobalPreferences NSAutomaticSpellingCorrectionEnabled
tdel .GlobalPreferences WebAutomaticSpellingCorrectionEnabled

udel com.apple.Notes ShouldUseSmartLinks
udel com.apple.Notes EnableAutomaticListInsertion
tdel com.apple.Notes ShouldUseSmartLinks
tdel com.apple.Notes EnableAutomaticListInsertion

# --- ~/Library, /usr, Utilities, HiDPI --- #
say "Hiding ~/Library and /usr again, restoring Utilities permissions"

launchctl unload "$HOME/Library/LaunchAgents/show-library.plist" >/dev/null 2>&1
rm -f "$HOME/Library/LaunchAgents/show-library.plist"
sudo rm -f "$TEMPLATE/Library/LaunchAgents/show-library.plist"
chflags hidden "$HOME/Library"
sudo chflags hidden /usr

# The original script set 775 here; the stock mode is 755.
sudo chmod 755 /Applications/Utilities

sudo defaults delete /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled >/dev/null 2>&1

# --- Gatekeeper --- #
say "Turning Gatekeeper back on"
sudo spctl --master-enable

# --- Dock --- #
restore_dock() {
  say "Restoring the Dock layout (backup: $BACKUP)"

  # Apple's original files come from $SRC_RES (chosen at the start);
  # any language folder they don't cover gets the rebuilt layout below.
  if [ -n "$SRC_RES" ]; then
    say "Using Apple's original Dock plists from: $SRC_RES"
  else
    say "Using the rebuilt stock Dock layout"
  fi

  # Rebuilt stock layout, used for any language folder the installer lacks.
  NEWPLIST="$BACKUP/default.plist"
  DOCK_APPS=(
    "Launchpad" "Safari" "Mail" "Contacts" "Calendar" "Reminders" "Notes"
    "Maps" "Messages" "FaceTime" "Photo Booth" "iTunes" "iBooks"
    "App Store" "System Preferences"
  )

  {
    printf '%s\n' \
      '<?xml version="1.0" encoding="UTF-8"?>' \
      '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
      '<plist version="1.0">' \
      '<dict>' \
      '<key>persistent-apps</key>' \
      '<array>'
    for app in "${DOCK_APPS[@]}"; do
      # Skip anything not installed (Maps was removed by the original script).
      if [ -d "/Applications/$app.app" ]; then
        printf '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/%s.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>\n' "$app"
      fi
    done
    printf '%s\n' \
      '</array>' \
      '<key>persistent-others</key>' \
      '<array>' \
      '<dict><key>tile-data</key><dict><key>arrangement</key><integer>2</integer><key>home directory relative</key><string>~/Downloads</string><key>showas</key><integer>1</integer></dict><key>tile-type</key><string>directory-tile</string></dict>' \
      '</array>' \
      '<key>version</key><integer>1</integer>' \
      '</dict>' \
      '</plist>'
  } > "$NEWPLIST"

  REBUILT_OK=0
  plutil -lint "$NEWPLIST" >/dev/null 2>&1 && REBUILT_OK=1

  N_ORIG=0
  N_REBUILT=0
  N_SKIPPED=0

  cp "$HOME/Library/Preferences/com.apple.dock.plist" "$BACKUP/" 2>/dev/null

  # The original script overwrote default.plist in every language folder.
  for f in "$DOCK_RES"/*.lproj/default.plist; do
    [ -f "$f" ] || continue
    rel="${f#"$DOCK_RES"/}"
    src=""
    if [ -n "$SRC_RES" ] && [ -f "$SRC_RES/$rel" ] \
       && grep -q 'persistent-apps' "$SRC_RES/$rel" \
       && plutil -lint "$SRC_RES/$rel" >/dev/null 2>&1; then
      src="$SRC_RES/$rel"
      N_ORIG=$((N_ORIG + 1))
    elif [ "$REBUILT_OK" = "1" ]; then
      src="$NEWPLIST"
      N_REBUILT=$((N_REBUILT + 1))
    else
      N_SKIPPED=$((N_SKIPPED + 1))
      continue
    fi
    sudo cp "$src" "$f"
    sudo chown root:wheel "$f"
    sudo chmod 644 "$f"
  done

  say "Dock plists: $N_ORIG from the installer, $N_REBUILT rebuilt, $N_SKIPPED left unchanged"

  if [ $((N_ORIG + N_REBUILT)) -gt 0 ]; then
    tdel com.apple.dock dashboard-in-overlay
    # Clearing the user's Dock prefs makes the Dock rebuild from default.plist
    # and also drops dashboard-in-overlay.
    defaults delete com.apple.dock >/dev/null 2>&1
  fi
}

if [ "$DOCK_MODE" = "skip" ]; then
  say "Skipping the Dock step. To do it later, run this script again with the path:"
  say "  bash revert-postinstall.command /path/to/installer"
else
  restore_dock
fi

# --- Optional: shell tweaks --- #
if [ "$REVERT_SHELL" = "1" ]; then
  say "Removing the short Terminal prompt and tab-completion setting"
  rm_if_exact "$HOME/.bash_profile" 'export PS1="\W$ "'
  rm_if_exact "$HOME/.inputrc" 'set completion-ignore-case On'
  sudo_rm_if_exact "$TEMPLATE/.bash_profile" 'export PS1="\W$ "'
  sudo_rm_if_exact "$TEMPLATE/.inputrc" 'set completion-ignore-case On'
fi

# --- Restart what needs it --- #
killall cfprefsd >/dev/null 2>&1
sleep 1
killall Dock Finder >/dev/null 2>&1

echo
spctl --status
echo
echo "Done. Restart your Mac (or at least log out and back in) so every change takes effect."
echo "Backup of the previous Dock preferences: $BACKUP"

# Keep the Terminal window readable when the file was double-clicked.
if [ -z "$NO_PAUSE" ] && { : < "$PROMPT_TTY"; } 2>/dev/null; then
  printf '\nPress Return to close this window. '
  read -r _ < "$PROMPT_TTY"
fi
