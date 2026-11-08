# mavericks-postinstall-revert

Undoes the Snow Leopard-style tweaks and the disabled Gatekeeper left behind by the post-install script from [mavericksforever.com](https://mavericksforever.com/), on OS X 10.9 Mavericks. The security patches stay in place.

Unofficial. This project is not affiliated with mavericksforever.com. It targets the post-install script as published in November 2026. If that script changes, check what it does before relying on this one.

## Run it

Download and start it from Terminal:

```
curl -fsSL https://raw.githubusercontent.com/SubhanRaj/mavericks-postinstall-revert/main/revert-postinstall.command -o ~/Downloads/revert-postinstall.command
chmod +x ~/Downloads/revert-postinstall.command
bash ~/Downloads/revert-postinstall.command
```

Or use **Code > Download ZIP** (or `git clone`), then double-click `revert-postinstall.command` in Finder. If double-clicking gives a permission error, run `chmod +x` on the file once.

Run it as your normal user. It asks for your password itself and exits if started with `sudo`.

## What it asks

At the start it asks where to copy Apple's original Dock layout from. Paste or drag in one of:

- the bootable USB installer volume, for example `/Volumes/OS X Base System`
- `Install OS X Mavericks.app`
- `InstallESD.dmg` or `BaseSystem.dmg`
- a folder you copied off the installer that holds the `*.lproj/default.plist` files (the `Dock.app/Contents/Resources` folder, or `Dock.app` itself)

If the installer's base system has no `Dock.app`, the script unpacks the plists from `System/Installation/Packages/Essentials.pkg` on the same volume. That takes a few minutes and about 3 GB of free disk space. It saves the plists to `~/dockplists-from-installer`; pass that folder on a later run to skip the unpacking.

Return skips the Dock step for now. Type `r` to use a rebuilt copy of the stock layout instead. To do the Dock step later, run the script again with the path:

```
bash ~/Downloads/revert-postinstall.command "/Volumes/OS X Base System"
```

## What it changes

Reverted:

- Finder, Time Machine, Notes, autocorrect, iCloud-save and automatic-termination defaults, for your account and for new users
- Dashboard overlay, visible `~/Library` and `/usr`, `/Applications/Utilities` permissions, the HiDPI flag
- Gatekeeper, turned back on
- the Dock layout; your current Dock preferences are saved to `~/postinstall-revert-backup-<date>` first

Left alone: the security patches, SMB and `.DS_Store` tweaks, media-key patches, the font fix and the classic wallpapers. The post-install script deleted the Dashboard widgets, Maps and Game Center; this script does not restore them.

Optional: `REVERT_SHELL=1 bash revert-postinstall.command` also removes the short Terminal prompt and case-insensitive tab completion. `NO_PAUSE=1` skips the "Press Return" wait at the end.

Restart the Mac when it finishes.

## Check that it worked

Paste into Terminal. Each line prints `ok` when the setting is gone and `STILL SET` when it is not.

```
chk() { v=$(defaults read "$1" "$2" 2>/dev/null) && echo "STILL SET  $1 $2 = $v" || echo "ok         $1 $2"; }
chk NSGlobalDomain NSDisableAutomaticTermination
chk NSGlobalDomain NSDocumentSaveNewDocumentsToCloud
chk NSGlobalDomain NSAutomaticSpellingCorrectionEnabled
chk NSGlobalDomain WebAutomaticSpellingCorrectionEnabled
chk com.apple.finder NewWindowTarget
chk com.apple.finder NewWindowTargetPath
chk com.apple.finder FXDefaultSearchScope
chk com.apple.TimeMachine DoNotOfferNewDisksForBackup
chk com.apple.Notes ShouldUseSmartLinks
chk com.apple.Notes EnableAutomaticListInsertion
```

Gatekeeper, hidden folders, permissions, the HiDPI flag and the LaunchAgent:

```
spctl --status                      # expect: assessments enabled
ls -ldO ~/Library /usr              # expect: "hidden" on both lines
stat -f '%Lp' /Applications/Utilities   # expect: 755
defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled   # expect: ... does not exist
ls ~/Library/LaunchAgents/show-library.plist   # expect: No such file or directory
```

New-user template (a new account would start from these files):

```
T="/System/Library/User Template/Non_localized/Library"
ls "$T/LaunchAgents/show-library.plist"   # expect: No such file or directory
if sudo grep -la -E 'NSDisableAutomaticTermination|NSDocumentSaveNewDocumentsToCloud|AutomaticSpellingCorrection|NewWindowTarget|FXDefaultSearchScope|DoNotOfferNewDisksForBackup|ShouldUseSmartLinks|EnableAutomaticListInsertion' "$T"/Preferences/*.plist "$T"/Preferences/.GlobalPreferences.plist 2>/dev/null; then echo "STILL PRESENT"; else echo "ok: none"; fi
```

A key can show `STILL SET` if you changed that option yourself afterwards in System Preferences or Finder; check whether the value is one you chose.

If you skipped the Dock step, `defaults read com.apple.dock dashboard-in-overlay` still prints `1`. To drop that one key and keep your Dock layout:

```
defaults delete com.apple.dock dashboard-in-overlay && killall Dock
sudo defaults delete "/System/Library/User Template/Non_localized/Library/Preferences/com.apple.dock" dashboard-in-overlay
```

## If an app is blocked afterwards

With Gatekeeper on, some newer apps may be refused on 10.9. Right-click the app and choose Open, or run:

```
sudo xattr -dr com.apple.quarantine /Applications/AppName.app
```

## Optional: install Office 2011

`install-office-2011.command` downloads the Office for Mac 2011 installer from Microsoft's CDN and opens it in the normal macOS Installer. Run it the same way as the revert script (`chmod +x`, then double-click, or `bash install-office-2011.command`).

- It only downloads from `officecdn-microsoft-com.akamaized.net`, the host Microsoft lists for Office for Mac installers in [Network requests in Office for Mac](https://learn.microsoft.com/en-us/microsoft-365/enterprise/network-requests-in-office-2016-for-mac). It stops if a redirect leads anywhere else, if the file is too small, or if `hdiutil verify` finds the image damaged.
- It prints the SHA-256 of the download. To pin it: `EXPECTED_SHA256=<hash> bash install-office-2011.command`.
- The download is resumable and stays in `~/Downloads/Office2011`.
- If Microsoft no longer serves the file, the script says so and downloads nothing.

It does not activate Office. Enter your own product key the first time you open an Office app. Microsoft's Volume License Serializer is for administrators with a volume agreement and covers only Office LTSC 2021 and 2024, so it does not apply to Office 2011.

## Notes

- Tested with stubbed commands on Linux. Read the scripts before running them; each is a single file.
- The post-install script replaces Apple's Dock layout files without a backup, so the originals have to come from the installer.

## License

MIT, see [LICENSE](LICENSE).
