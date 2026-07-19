<img align="left" alt="Velox" src="assets/app.svg" width="128" />

# Velox

A GTK4 media downloader written in Vala.

**Source:** [codeberg.org/el1lovescomputers/velox](https://codeberg.org/el1lovescomputers/velox)

## Features

- **Download** — Paste one or more URLs, choose format and quality, and download with real-time progress
- **Formats** — Video (MP4, MKV, WebM) or audio-only (M4A, MP3, FLAC, Opus), codec selection (H.264, H.265, VP9, AV1), quality presets (2160p down to 240p)
- **Metadata** — Embed metadata, thumbnails, chapters, and subtitles (with auto-generated and language selection)
- **SponsorBlock** — Remove or mark sponsored segments, configurable categories
- **Playlists** — Automatic playlist expansion into individual videos
- **Concurrency** — Configurable parallel downloads with a managed queue
- **Settings** — Persistent preferences for output directory, filename templates, network options, download archive, rate limiting, and custom yt-dlp arguments
- **Visuals** — Follows system light/dark mode via Adwaita, responsive layout

## Dependencies

**Arch Linux:**
```bash
sudo pacman -S vala meson gtk4 libadwaita json-glib
```

**Debian/Ubuntu:**
```bash
sudo apt install vala meson libgtk-4-dev libadwaita-1-dev libjson-glib-dev
```

**Fedora:**
```bash
sudo dnf install vala meson gtk4-devel libadwaita-devel json-glib-devel
```

**OpenSUSE Tumbleweed:**
```bash
sudo zypper install vala meson gtk4-devel libadwaita-devel json-glib-devel
```

**Void Linux:**
```bash
sudo xbps-install vala meson gtk4-devel libadwaita-devel json-glib-devel
```

**Alpine:**
```bash
sudo apk add vala meson gtk4.0-dev libadwaita-dev json-glib-dev
```

**Runtime dependency:** [yt-dlp](https://github.com/yt-dlp/yt-dlp) must be installed and available on `PATH`.

## Installation

### Flatpak

Pre-built flatpak packages are available in [flatpak-downloads](https://codeberg.org/el1lovescomputers/Velox/src/branch/main/flatpak-downloads). May be slightly behind the latest version.

### Recommended: [gitpkg](https://codeberg.org/el1lovescomputers/gitpkg)

```bash
curl -fsSL "https://codeberg.org/el1lovescomputers/gitpkg/raw/branch/main/install.sh" | sh
gitpkg install el1lovescomputers/velox --supplier "codeberg.org"
```

### From Source

```bash
git clone https://codeberg.org/el1lovescomputers/velox
cd velox
meson setup build --buildtype=release --prefix=/usr
sudo ninja -C build install
```

## Reporting Issues

https://codeberg.org/el1lovescomputers/velox/issues
