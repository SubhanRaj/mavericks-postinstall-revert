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
