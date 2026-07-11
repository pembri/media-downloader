#!/usr/bin/env bash
# ==========================================================
#  media-downloader :: installer
#  Universal installer (Termux / Debian / Ubuntu)
#  Repo: berisi HANYA file ini. Semua file pendukung
#  di-embed di sini via heredoc dan ditulis saat instalasi.
# ==========================================================
set -e

C_RESET="\033[0m"
C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_BOLD="\033[1m"

info()  { echo -e "${C_CYAN}[INFO]${C_RESET} $1"; }
ok()    { echo -e "${C_GREEN}[ OK ]${C_RESET} $1"; }
warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET} $1"; }
err()   { echo -e "${C_RED}[FAIL]${C_RESET} $1"; }

echo -e "${C_CYAN}${C_BOLD}"
echo "  +-----------------------------------------------------+"
echo "  |            MEDIA-DOWNLOADER  INSTALLER               |"
echo "  |-------------------------------------------------------"
echo "  |  YouTube Video / Musik  -  TikTok                    |"
echo "  +-----------------------------------------------------+"
echo -e "${C_RESET}"

# ---------------------------------------------------------
# 1. Deteksi environment
# ---------------------------------------------------------
if [ -n "$PREFIX" ] && [[ "$PREFIX" == *"com.termux"* ]]; then
    ENV_TYPE="termux"
    PKG_INSTALL="pkg install -y"
    BIN_DIR="$PREFIX/bin"
    APP_DIR="$HOME/media-downloader"
    DOWNLOAD_BASE="/sdcard/Media-Downloader"
    PY_BIN="python"
elif [ -f /etc/debian_version ]; then
    ENV_TYPE="debian"
    PKG_INSTALL="sudo apt-get install -y"
    BIN_DIR="/usr/local/bin"
    APP_DIR="$HOME/media-downloader"
    DOWNLOAD_BASE="$HOME/Media-Downloader"
    PY_BIN="python3"
else
    ENV_TYPE="unknown"
    PKG_INSTALL=""
    BIN_DIR="$HOME/.local/bin"
    APP_DIR="$HOME/media-downloader"
    DOWNLOAD_BASE="$HOME/Media-Downloader"
    PY_BIN="python3"
fi

info "Environment terdeteksi : ${C_BOLD}${ENV_TYPE}${C_RESET}"
info "Folder aplikasi        : $APP_DIR"
info "Folder hasil download  : $DOWNLOAD_BASE"
info "Folder bin (command)   : $BIN_DIR"
echo ""

mkdir -p "$APP_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$DOWNLOAD_BASE"/{YouTube-Video,YouTube-Musik,TikTok}

# ---------------------------------------------------------
# 2. Install dependency system
# ---------------------------------------------------------
info "Menginstall dependency sistem (proses ini bisa beberapa menit)..."
echo ""

if [ "$ENV_TYPE" = "termux" ]; then
    info "Menjalankan: pkg update"
    pkg update -y || true
    info "Menjalankan: pkg install python python-pip ffmpeg"
    $PKG_INSTALL python python-pip ffmpeg || warn "Gagal install sebagian paket termux, lanjut..."

    echo ""
    warn "Termux akan meminta izin akses penyimpanan (storage)."
    warn "Kalau muncul popup, tap 'Allow/Izinkan' di HP kamu."
    termux-setup-storage || true
    sleep 1
elif [ "$ENV_TYPE" = "debian" ]; then
    if ! command -v sudo >/dev/null 2>&1; then
        PKG_INSTALL="apt-get install -y"
        SUDO_UPDATE="apt-get update -y"
    else
        SUDO_UPDATE="sudo apt-get update -y"
    fi
    info "Menjalankan: apt-get update"
    $SUDO_UPDATE || true
    info "Menjalankan: apt-get install python3 python3-pip ffmpeg"
    $PKG_INSTALL python3 python3-pip ffmpeg || warn "Gagal install sebagian paket apt, lanjut..."
else
    warn "OS tidak dikenali otomatis, pastikan python3, pip, dan ffmpeg sudah terpasang manual."
fi
echo ""
ok "Dependency sistem selesai diperiksa."

# ---------------------------------------------------------
# 3. Install dependency python
# ---------------------------------------------------------
info "Menginstall dependency python (yt-dlp, requests)..."

if ! $PY_BIN -m pip --version >/dev/null 2>&1; then
    warn "pip belum terdeteksi, mencoba pasang via ensurepip..."
    $PY_BIN -m ensurepip --upgrade || true
fi

PIP_EXTRA=""
if [ "$ENV_TYPE" = "debian" ]; then
    PIP_EXTRA="--break-system-packages"
fi

if [ "$ENV_TYPE" != "termux" ]; then
    $PY_BIN -m pip install --upgrade pip $PIP_EXTRA || true
fi
$PY_BIN -m pip install --upgrade yt-dlp requests $PIP_EXTRA || {
    err "Gagal install yt-dlp/requests via pip. Cek koneksi / pip lu."
    exit 1
}
echo ""
ok "yt-dlp & requests terpasang."
echo ""

# ---------------------------------------------------------
# 4. Tulis requirements.txt
# ---------------------------------------------------------
cat > "$APP_DIR/requirements.txt" << 'EOF_REQ'
yt-dlp>=2024.1.1
requests>=2.31.0
EOF_REQ

# ---------------------------------------------------------
# 5. Tulis common.py (helper bersama)
# ---------------------------------------------------------
cat > "$APP_DIR/common.py" << 'EOF_COMMON'
import os
import sys

C_RESET = "\033[0m"
C_CYAN = "\033[1;36m"
C_GREEN = "\033[1;32m"
C_YELLOW = "\033[1;33m"
C_RED = "\033[1;31m"
C_BOLD = "\033[1m"


def info(msg):
    print(f"{C_CYAN}[INFO]{C_RESET} {msg}")


def ok(msg):
    print(f"{C_GREEN}[ OK ]{C_RESET} {msg}")


def warn(msg):
    print(f"{C_YELLOW}[WARN]{C_RESET} {msg}")


def err(msg):
    print(f"{C_RED}[FAIL]{C_RESET} {msg}")


def get_download_base():
    return os.environ.get("MD_DOWNLOAD_BASE", os.path.expanduser("~/Media-Downloader"))


def progress_hook(d):
    if d.get("status") == "downloading":
        pct = d.get("_percent_str", "").strip()
        speed = d.get("_speed_str", "").strip()
        sys.stdout.write(f"\r{C_CYAN}Mengunduh...{C_RESET} {pct} @ {speed}   ")
        sys.stdout.flush()
    elif d.get("status") == "finished":
        print(f"\n{C_GREEN}[ OK ]{C_RESET} Selesai memproses, sedang finalisasi (merge/convert)...")
EOF_COMMON

# ---------------------------------------------------------
# 6. Tulis youtube.py
# ---------------------------------------------------------
cat > "$APP_DIR/youtube.py" << 'EOF_YT'
import sys
import os
import yt_dlp
from common import info, ok, err, get_download_base, progress_hook


def download(url, mode, out_dir):
    os.makedirs(out_dir, exist_ok=True)

    common_opts = {
        "progress_hooks": [progress_hook],
        "quiet": True,
        "no_warnings": True,
        "extractor_args": {
            "youtube": {
                "player_client": ["android", "ios", "web"],
            }
        },
        "http_headers": {
            "User-Agent": "com.google.android.youtube/19.09.37 (Linux; U; Android 14) gzip"
        },
    }

    if mode == "audio":
        ydl_opts = {
            **common_opts,
            "format": "bestaudio/best",
            "outtmpl": os.path.join(out_dir, "%(title)s.%(ext)s"),
            "postprocessors": [{
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": "192",
            }],
        }
    else:
        ydl_opts = {
            **common_opts,
            "format": "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
            "outtmpl": os.path.join(out_dir, "%(title)s.%(ext)s"),
            "merge_output_format": "mp4",
        }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
    except Exception:
        # Fallback: coba format paling sederhana kalau format spesifik gagal
        fallback_opts = {**ydl_opts, "format": "best"}
        with yt_dlp.YoutubeDL(fallback_opts) as ydl:
            ydl.download([url])

    ok(f"File tersimpan di: {out_dir}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        err("Penggunaan: youtube.py <url> <video|audio>")
        sys.exit(1)

    url = sys.argv[1]
    mode = sys.argv[2]
    base = get_download_base()
    folder = "YouTube-Musik" if mode == "audio" else "YouTube-Video"
    out_dir = os.path.join(base, folder)

    info(f"Memproses URL YouTube ({'Musik/MP3' if mode == 'audio' else 'Video'})...")
    try:
        download(url, mode, out_dir)
    except Exception as e:
        err(f"Gagal download: {e}")
        sys.exit(1)
EOF_YT

# ---------------------------------------------------------
# 7. Tulis tiktok.py
# ---------------------------------------------------------
cat > "$APP_DIR/tiktok.py" << 'EOF_TT'
import sys
import os
import yt_dlp
from common import info, ok, err, get_download_base, progress_hook


def download(url, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    ydl_opts = {
        "format": "best",
        "outtmpl": os.path.join(out_dir, "%(title).80s_%(id)s.%(ext)s"),
        "progress_hooks": [progress_hook],
        "quiet": True,
        "no_warnings": True,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])
    ok(f"File tersimpan di: {out_dir}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        err("Penggunaan: tiktok.py <url>")
        sys.exit(1)

    url = sys.argv[1]
    base = get_download_base()
    out_dir = os.path.join(base, "TikTok")

    info("Memproses URL TikTok...")
    try:
        download(url, out_dir)
    except Exception as e:
        err(f"Gagal download: {e}")
        sys.exit(1)
EOF_TT

# ---------------------------------------------------------
# 10. Tulis main launcher: media-downloader
# ---------------------------------------------------------
cat > "$BIN_DIR/media-downloader" << EOF_LAUNCHER
#!/usr/bin/env bash
export MD_DOWNLOAD_BASE="$DOWNLOAD_BASE"
export PYTHONPATH="$APP_DIR:\$PYTHONPATH"
APP_DIR="$APP_DIR"
PY_BIN="$PY_BIN"

C_RESET="\033[0m"
C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_BOLD="\033[1m"
C_MAGENTA="\033[1;35m"

show_banner() {
    clear
    printf "%b\n" "\${C_MAGENTA}\${C_BOLD}"
    printf "  +-----------------------------------------------------+\n"
    printf "  |            MEDIA-DOWNLOADER                          |\n"
    printf "  |-------------------------------------------------------\n"
    printf "  |  YouTube Video / Musik  -  TikTok                    |\n"
    printf "  +-----------------------------------------------------+\n"
    printf "%b\n" "\${C_RESET}"
    printf "%b\n" "\${C_CYAN}  Simpan otomatis ke: \${C_BOLD}$DOWNLOAD_BASE\${C_RESET}"
    printf "%b\n" "\${C_CYAN}  ------------------------------------------------------\${C_RESET}"
    printf "%b\n" "  \${C_GREEN}1)\${C_RESET} YouTube Video Downloader"
    printf "%b\n" "  \${C_GREEN}2)\${C_RESET} YouTube Musik Downloader (MP3)"
    printf "%b\n" "  \${C_GREEN}3)\${C_RESET} TikTok Video Downloader"
    printf "%b\n" "  \${C_RED}0)\${C_RESET} Keluar"
    printf "%b\n" "\${C_CYAN}  ------------------------------------------------------\${C_RESET}"
}

while true; do
    show_banner
    printf "%b" "\${C_YELLOW}Pilih menu [0-3]: \${C_RESET}"
    read -r choice

    case "\$choice" in
        1)
            printf "%b" "\${C_CYAN}Masukkan URL YouTube: \${C_RESET}"
            read -r url
            [ -z "\$url" ] && { printf "%b\n" "\${C_RED}URL kosong.\${C_RESET}"; sleep 1; continue; }
            "\$PY_BIN" "\$APP_DIR/youtube.py" "\$url" video
            ;;
        2)
            printf "%b" "\${C_CYAN}Masukkan URL YouTube: \${C_RESET}"
            read -r url
            [ -z "\$url" ] && { printf "%b\n" "\${C_RED}URL kosong.\${C_RESET}"; sleep 1; continue; }
            "\$PY_BIN" "\$APP_DIR/youtube.py" "\$url" audio
            ;;
        3)
            printf "%b" "\${C_CYAN}Masukkan URL TikTok: \${C_RESET}"
            read -r url
            [ -z "\$url" ] && { printf "%b\n" "\${C_RED}URL kosong.\${C_RESET}"; sleep 1; continue; }
            "\$PY_BIN" "\$APP_DIR/tiktok.py" "\$url"
            ;;
        0)
            printf "%b\n" "\${C_GREEN}Sampai jumpa!\${C_RESET}"
            exit 0
            ;;
        *)
            printf "%b\n" "\${C_RED}Pilihan tidak valid.\${C_RESET}"
            sleep 1
            continue
            ;;
    esac

    echo ""
    printf "%b" "\${C_YELLOW}Tekan ENTER untuk kembali ke menu...\${C_RESET}"
    read -r _
done
EOF_LAUNCHER

chmod +x "$BIN_DIR/media-downloader"
ok "Command 'media-downloader' terpasang di $BIN_DIR"

# ---------------------------------------------------------
# 11. Tulis uninstall.sh
# ---------------------------------------------------------
cat > "$APP_DIR/uninstall.sh" << EOF_UNINSTALL
#!/usr/bin/env bash
echo "Menghapus media-downloader..."
rm -f "$BIN_DIR/media-downloader"
rm -rf "$APP_DIR"
echo "Selesai. Folder hasil download di $DOWNLOAD_BASE TIDAK dihapus (aman)."
echo "Hapus manual jika ingin: rm -rf $DOWNLOAD_BASE"
EOF_UNINSTALL
chmod +x "$APP_DIR/uninstall.sh"

# ---------------------------------------------------------
# 12. Cek PATH
# ---------------------------------------------------------
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    warn "$BIN_DIR belum ada di PATH kamu."
    warn "Tambahkan baris ini ke ~/.bashrc atau ~/.zshrc:"
    echo -e "${C_BOLD}    export PATH=\"$BIN_DIR:\$PATH\"${C_RESET}"
fi

echo ""
ok "Instalasi selesai!"
echo -e "${C_GREEN}${C_BOLD}Jalankan dengan mengetik:${C_RESET} ${C_CYAN}${C_BOLD}media-downloader${C_RESET}"
echo -e "${C_YELLOW}Uninstall dengan:${C_RESET} bash $APP_DIR/uninstall.sh"
echo ""
