#!/bin/bash
#
# install-office-2011.command
#
# Downloads the Office for Mac 2011 installer from Microsoft's CDN and opens it
# in the normal macOS Installer. It does not activate Office: enter your own
# product key (or sign in) the first time you open an Office app.
#
# Usage:      double-click this file (run  chmod +x  on it once first), or
#             bash install-office-2011.command
#
# Safety:     the download only goes to Microsoft's Office CDN hosts. The script
#             checks the host before and after redirects, checks the size, runs
#             hdiutil verify on the disk image, and prints its SHA-256. To also
#             pin the checksum:  EXPECTED_SHA256=<hash> bash install-office-2011.command
#
# Run as your normal user, not with sudo. The macOS Installer asks for your
# password itself.

OFFICE_URL="https://officecdn-microsoft-com.akamaized.net/PR/MacOffice2011/en-us/MicrosoftOffice2011.dmg"
DEST_DIR="$HOME/Downloads/Office2011"
DMG="$DEST_DIR/MicrosoftOffice2011.dmg"
MIN_BYTES="${MIN_BYTES:-200000000}"       # anything smaller is not the installer
MIN_FREE_KB="${MIN_FREE_KB:-5000000}"     # room for the image plus the install
PROMPT_TTY="${PROMPT_TTY:-/dev/tty}"
MP=""

say() { echo "==> $*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

cleanup() {
  if [ -n "$MP" ]; then
    hdiutil detach "$MP" -force >/dev/null 2>&1
    rmdir "$MP" 2>/dev/null
  fi
}
trap cleanup EXIT

[ "$(uname)" = "Darwin" ] || fail "This script is for OS X."
[ "$(id -u)" -ne 0 ] || fail "Run this as your normal user, not with sudo."

# Only Microsoft's Office CDN hosts are accepted.
host_of() { printf '%s' "$1" | sed -E 's#^[A-Za-z]+://([^/:]+).*#\1#'; }
host_ok() {
  case "$1" in
    officecdn-microsoft-com.akamaized.net|officecdn.microsoft.com|officecdn.microsoft.com.edgesuite.net) return 0 ;;
  esac
  return 1
}

clear
echo "Office for Mac 2011: download and install"
echo

host_ok "$(host_of "$OFFICE_URL")" || fail "Download host is not on the Microsoft CDN list."

if [ -d "/Applications/Microsoft Office 2011" ]; then
  echo "Office 2011 already seems to be installed in /Applications/Microsoft Office 2011."
  if { : < "$PROMPT_TTY"; } 2>/dev/null; then
    printf 'Install again anyway? [y/N] '
    IFS= read -r ans < "$PROMPT_TTY"
    case "$ans" in y|Y|yes|YES) ;; *) echo "Nothing changed."; exit 0 ;; esac
  else
    echo "Nothing changed."
    exit 0
  fi
fi

mkdir -p "$DEST_DIR" || fail "Cannot create $DEST_DIR"

FREE_KB=$(df -k "$DEST_DIR" | awk 'NR==2{print $4}')
if [ -n "$FREE_KB" ] && [ "$FREE_KB" -lt "$MIN_FREE_KB" ]; then
  fail "Not enough free disk space (need about $((MIN_FREE_KB / 1000000)) GB, have $((FREE_KB / 1000000)) GB)."
fi

# --- Check what Microsoft's server answers before downloading --- #
say "Checking the download on Microsoft's CDN"
HDRS=$(curl -sIL --proto '=https' --proto-redir '=https' --max-time 30 "$OFFICE_URL" 2>/dev/null | tr -d '\r')
[ -n "$HDRS" ] || fail "Could not reach the Microsoft CDN. Check your internet connection and try again."

STATUS=$(printf '%s\n' "$HDRS" | grep '^HTTP/' | tail -n 1 | awk '{print $2}')
if [ "$STATUS" != "200" ]; then
  fail "The Microsoft CDN answered HTTP $STATUS for this file, so it is no longer served from that address. Nothing was downloaded."
fi

for loc in $(printf '%s\n' "$HDRS" | grep -i '^location:' | sed 's/^[Ll]ocation: *//'); do
  case "$loc" in
    http*) host_ok "$(host_of "$loc")" || fail "The download redirects to $(host_of "$loc"), which is not a Microsoft CDN host. Stopping." ;;
  esac
done

REMOTE_BYTES=$(printf '%s\n' "$HDRS" | awk 'tolower($0) ~ /^http\//{cl=""} tolower($1)=="content-length:"{cl=$2} END{print cl}')
if [ -n "$REMOTE_BYTES" ] && [ "$REMOTE_BYTES" -lt "$MIN_BYTES" ]; then
  fail "The file on the server is only $REMOTE_BYTES bytes, too small to be the installer."
fi
[ -n "$REMOTE_BYTES" ] && say "Size on the server: $((REMOTE_BYTES / 1000000)) MB"

# --- Download (resumes if interrupted) --- #
LOCAL_BYTES=0
[ -f "$DMG" ] && LOCAL_BYTES=$(stat -f %z "$DMG" 2>/dev/null || echo 0)

if [ -n "$REMOTE_BYTES" ] && [ "$LOCAL_BYTES" = "$REMOTE_BYTES" ]; then
  say "Already downloaded: $DMG"
else
  say "Downloading to $DMG"
  EFFECTIVE=$(curl -fL -C - --retry 3 --proto '=https' --proto-redir '=https' --progress-bar \
    -o "$DMG" -w '%{url_effective}' "$OFFICE_URL")
  [ $? -eq 0 ] || fail "Download failed. Run the script again to resume."
  host_ok "$(host_of "$EFFECTIVE")" || { rm -f "$DMG"; fail "The file came from $(host_of "$EFFECTIVE"), not a Microsoft CDN host. Deleted it."; }
fi

# --- Check the file --- #
SIZE=$(stat -f %z "$DMG" 2>/dev/null || echo 0)
[ "$SIZE" -ge "$MIN_BYTES" ] || fail "The downloaded file is only $SIZE bytes, too small to be the installer."

say "Checking the disk image"
hdiutil verify "$DMG" >/dev/null 2>&1 || fail "hdiutil says the disk image is damaged. Delete $DMG and run this again."

SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
say "SHA-256: $SHA"
if [ -n "$EXPECTED_SHA256" ] && [ "$SHA" != "$EXPECTED_SHA256" ]; then
  fail "SHA-256 does not match EXPECTED_SHA256. Not installing."
fi

# --- Open the installer --- #
MP=$(mktemp -d /tmp/office2011.XXXXXX) || fail "Cannot create a mount point."
hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MP" -quiet || fail "Could not open the disk image."

PKG=$(find "$MP" -maxdepth 2 \( -name '*.mpkg' -o -name '*.pkg' \) 2>/dev/null | head -n 1)
[ -n "$PKG" ] || fail "No installer package found inside the disk image."

say "Installer: $(basename "$PKG")"
pkgutil --check-signature "$PKG" 2>&1 | sed 's/^/    /'

say "Opening the Installer. Follow the on-screen steps; it asks for your password."
open -W -a Installer "$PKG"

echo
if [ -d "/Applications/Microsoft Office 2011" ]; then
  echo "Office 2011 is installed in /Applications/Microsoft Office 2011."
else
  echo "The Installer has closed. If you finished it, Office is in /Applications/Microsoft Office 2011."
fi
echo "Office is not activated yet: enter your own product key the first time you open an Office app."
echo "The downloaded disk image is kept at $DMG; delete it when you no longer need it."

if { : < "$PROMPT_TTY"; } 2>/dev/null && [ -z "$NO_PAUSE" ]; then
  printf '\nPress Return to close this window. '
  read -r _ < "$PROMPT_TTY"
fi
