# mavericks-postinstall-revert

Undoes the Snow Leopard-style tweaks and the disabled Gatekeeper left behind by the post-install script from [mavericksforever.com](https://mavericksforever.com/), on OS X 10.9 Mavericks. The security patches stay in place.

Unofficial. This project is not affiliated with mavericksforever.com. It was written against the post-install script as it stood in November 2026; if that script changes, check what it does before relying on this one.

## Run it

Download and start it from Terminal:

```
curl -fsSL https://raw.githubusercontent.com/SubhanRaj/mavericks-postinstall-revert/main/revert-postinstall.command -o ~/Downloads/revert-postinstall.command
chmod +x ~/Downloads/revert-postinstall.command
bash ~/Downloads/revert-postinstall.command
```

Or use **Code → Download ZIP** (or `git clone`), then double-click `revert-postinstall.command` in Finder. If double-clicking gives a permission error, run `chmod +x` on the file once.

Run it as your normal user, not with `sudo`. It asks for your password itself.

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

Left alone: the security patches, SMB and `.DS_Store` tweaks, media-key patches, the font fix and the classic wallpapers. Widgets, Maps and Game Center were deleted by the original script and are not restored.

Optional: `REVERT_SHELL=1 bash revert-postinstall.command` also removes the short Terminal prompt and case-insensitive tab completion. `NO_PAUSE=1` skips the "Press Return" wait at the end.

Restart the Mac when it finishes.

## If an app is blocked afterwards

With Gatekeeper on, some newer apps may be refused on 10.9. Right-click the app and choose Open, or run:

```
sudo xattr -dr com.apple.quarantine /Applications/AppName.app
```

## Notes

- Tested with stubbed commands on Linux, not on every Mavericks setup. Read the script before running it; it is a single file.
- The original script overwrote Apple's Dock layout files without a backup, which is why this one asks for the installer.

## License

MIT, see [LICENSE](LICENSE).
