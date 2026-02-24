# discord-latest-bin

Discord package for Arch Linux built directly from the official upstream `.deb` release. The community repo tends to lag behind official releases, so this package tracks upstream as closely as possible.

The PKGBUILD extracts the pre-built binaries from Discord's `.deb` without any recompilation, resulting in an identical installation to what Discord ships officially.

## Installing

```bash
yay -S discord-latest-bin
```

Provides and conflicts with `discord`, so it replaces the community repo package cleanly.

## Maintaining

The `discord-update.sh` script handles checking for new releases, updating the PKGBUILD and `.SRCINFO`, and pushing to AUR.

```
./discord-update.sh [OPTIONS]

  -f, --force      Update even if already on the latest version
  -d, --dry-run    Show what would change without writing anything
  -h, --help       Show this help and exit
```

### First-time AUR setup

```bash
git remote add aur ssh://aur@aur.archlinux.org/discord-latest-bin.git
makepkg --printsrcinfo > .SRCINFO
git add PKGBUILD .SRCINFO
git commit -m "initial release"
git push aur main:master
```

After that, `./discord-update.sh` handles everything on its own.

## License

MIT
