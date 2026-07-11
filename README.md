# Media Downloader

A CLI tool to download videos/music from YouTube and videos from TikTok, right from your terminal. Supports **Termux (Android)** and **Debian/Ubuntu**.

## Features

- YouTube Video Downloader (MP4)
- YouTube Music Downloader (MP3)
- TikTok Video Downloader
- Auto-saves files into categorized folders
- Interactive, colorized menu UI
- Universal installer (auto-detects Termux vs Debian/Ubuntu)

## Requirements

- Termux (Android) **or** Debian/Ubuntu
- Internet connection
- Python 3 (automatically installed by the installer if missing)

## Installation

Clone this repo and run the installer:

```bash
git clone https://github.com/pembri/media-downloader
cd media-downloader
bash install.sh
```

The installer will automatically:
1. Detect your environment (Termux or Debian/Ubuntu)
2. Install system dependencies (`python`, `ffmpeg`, `pip`)
3. Install Python dependencies (`yt-dlp`, `requests`)
4. Generate all supporting files inside the `media-downloader/` folder
5. Install the `media-downloader` command so it can be run from anywhere

> On Termux, you'll be asked to grant storage permission — tap **Allow** when prompted.

## Usage

Once installed, run it from any terminal session:

```bash
media-downloader
```

You'll see the following menu:

```
+-----------------------------------------------------+
|            MEDIA-DOWNLOADER                          |
|-------------------------------------------------------
|  YouTube Video / Music  -  TikTok                    |
+-----------------------------------------------------+

  Auto-saved to: /sdcard/Media-Downloader

  ------------------------------------------------------
  1) YouTube Video Downloader
  2) YouTube Music Downloader (MP3)
  3) TikTok Video Downloader
  0) Exit
  ------------------------------------------------------
Select menu [0-3]:
```

Steps:
1. Choose a feature (1-3)
2. Paste the video URL
3. Press Enter — the download starts automatically
4. The file is saved to its matching category folder

## Download Location

| Environment | Path |
|---|---|
| Termux | `/sdcard/Media-Downloader/` |
| Debian/Ubuntu | `~/Media-Downloader/` |

Subfolders by category:
```
Media-Downloader/
├── YouTube-Video/
├── YouTube-Musik/
└── TikTok/
```

## Repo Structure

Before installation, the repo only contains:
```
media-downloader/
└── install.sh
```

After running `install.sh`, the following files are generated in the same folder:
```
media-downloader/
├── install.sh
├── uninstall.sh
├── requirements.txt
├── common.py
├── youtube.py
└── tiktok.py
```

## Uninstall

To remove the command and all supporting files:

```bash
bash media-downloader/uninstall.sh
```

This will remove:
- The `media-downloader` command from bin
- All supporting files (`.py`, `requirements.txt`, etc.)

The downloaded media folder (`Media-Downloader/`) is **not** deleted automatically. To remove it manually:

```bash
rm -rf /sdcard/Media-Downloader   # Termux
rm -rf ~/Media-Downloader         # Debian/Ubuntu
```

## Updating

To update to the latest version, simply re-run the installer (safely overwrites old files):

```bash
cd media-downloader
git pull
bash install.sh
```

## Notes

- Private or login-required content cannot be downloaded.
- Some content may be restricted by the source platform (e.g. TikTok "sensitive" content) and will still require authentication.
- This tool uses [yt-dlp](https://github.com/yt-dlp/yt-dlp) as its core download engine.

## License

For personal use. Please respect content owners' copyright when downloading or redistributing media.
