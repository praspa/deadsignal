#!/usr/bin/env bash
# Build Dead Signal for Linux and copy it to a Steam Deck over SSH.
#
#   ./deploy-to-steamdeck.sh                 # deck@steamdeck
#   ./deploy-to-steamdeck.sh 192.168.1.50    # or any host / IP
#   DECK_USER=deck GODOT=/path/to/godot ./deploy-to-steamdeck.sh
#
# Installs to /home/deck/Games/DeadSignal/ and gives you DeadSignal.sh to add in
# Steam as a "Non-Steam Game".
#
# One-time setup on the Deck (Desktop Mode -> Konsole):
#   passwd                              # give the 'deck' user a password
#   sudo systemctl enable --now sshd    # turn on SSH
set -euo pipefail

GAME_NAME="DeadSignal"
DECK_HOST="${1:-steamdeck}"
DECK_USER="${DECK_USER:-deck}"
REMOTE_DIR="/home/${DECK_USER}/Games/${GAME_NAME}"
GODOT="${GODOT:-godot}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/export/steamdeck/${GAME_NAME}"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v "$GODOT" >/dev/null || die "Godot not found. Put it on PATH or set GODOT=/path/to/godot"
command -v rsync >/dev/null    || die "rsync is not installed (sudo apt install rsync)"
command -v ssh >/dev/null      || die "ssh is not installed (sudo apt install openssh-client)"

# --------------------------------------------------------------- build ---
say "Building ${GAME_NAME} in ${BUILD_DIR}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$PROJECT_DIR"

# Make sure the import cache exists (first run on a fresh checkout).
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

GODOT_VER="$("$GODOT" --version | cut -d. -f1-4)"     # e.g. 4.5.1.stable
TEMPLATE="${HOME}/.local/share/godot/export_templates/${GODOT_VER}/linux_release.x86_64"

if [[ -f "$TEMPLATE" ]]; then
    say "Export templates found (${GODOT_VER}): doing a full release export"
    "$GODOT" --headless --path . --export-release "Linux" "${BUILD_DIR}/${GAME_NAME}.x86_64" \
        || die "Export failed"
else
    # No templates: export just the game data (.pck) and ship the Godot
    # runtime you already have next to it. Same engine version, runs the same.
    say "No export templates for ${GODOT_VER}: packing game data + bundling the Godot runtime"
    "$GODOT" --headless --path . --export-pack "Linux" "${BUILD_DIR}/${GAME_NAME}.pck" \
        || die "Pack export failed"
    cp "$(readlink -f "$(command -v "$GODOT")")" "${BUILD_DIR}/godot-runtime.x86_64"
    chmod +x "${BUILD_DIR}/godot-runtime.x86_64"
fi

# Launcher Steam points at: works for either build type.
cat > "${BUILD_DIR}/${GAME_NAME}.sh" <<'EOF'
#!/usr/bin/env bash
# Dead Signal launcher (add this file to Steam as a Non-Steam Game).
cd "$(dirname "$(readlink -f "$0")")"
if [[ -x ./DeadSignal.x86_64 ]]; then
    exec ./DeadSignal.x86_64 "$@"
else
    exec ./godot-runtime.x86_64 --main-pack DeadSignal.pck "$@"
fi
EOF
chmod +x "${BUILD_DIR}/${GAME_NAME}.sh"
[[ -f "${PROJECT_DIR}/icon.svg" ]] && cp "${PROJECT_DIR}/icon.svg" "${BUILD_DIR}/icon.svg"
# Steam library artwork (regenerate with: godot --path . -- --steam-art)
HAS_ART=0
if compgen -G "${PROJECT_DIR}/steam_art/*.png" >/dev/null; then
    HAS_ART=1
    mkdir -p "${BUILD_DIR}/artwork"
    cp "${PROJECT_DIR}"/steam_art/*.png "${BUILD_DIR}/artwork/"
fi

say "Build contents:"
ls -lh "$BUILD_DIR"

# ---------------------------------------------------------- connection ---
# 'steamdeck' may only resolve as 'steamdeck.local' (mDNS) on some networks.
if ! getent hosts "$DECK_HOST" >/dev/null 2>&1 && getent hosts "${DECK_HOST}.local" >/dev/null 2>&1; then
    DECK_HOST="${DECK_HOST}.local"
fi
getent hosts "$DECK_HOST" >/dev/null 2>&1 || say "Warning: can't resolve '${DECK_HOST}' - trying anyway (pass the Deck's IP as an argument if this fails)"

TARGET="${DECK_USER}@${DECK_HOST}"
CTL_DIR="$(mktemp -d)"
CTL="${CTL_DIR}/ctl"
SSH_OPTS=(-o ControlPath="$CTL" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

cleanup() {
    ssh "${SSH_OPTS[@]}" -O exit "$TARGET" >/dev/null 2>&1 || true
    rm -rf "$CTL_DIR"
}
trap cleanup EXIT

say "Connecting to ${TARGET}"
# Use an SSH key silently if one is set up; otherwise ask for the password once
# and reuse the connection for everything below.
if ssh "${SSH_OPTS[@]}" -o BatchMode=yes -o ControlMaster=yes -o ControlPersist=120 -fN "$TARGET" 2>/dev/null; then
    say "Logged in with SSH key"
else
    read -r -s -p "Password for ${TARGET}: " DECK_PASS
    echo
    ASKPASS="${CTL_DIR}/askpass.sh"
    printf '#!/bin/sh\nprintf "%%s\\n" "$DECK_PASS"\n' > "$ASKPASS"
    chmod 700 "$ASKPASS"
    DECK_PASS="$DECK_PASS" SSH_ASKPASS="$ASKPASS" SSH_ASKPASS_REQUIRE=force DISPLAY="${DISPLAY:-:0}" \
        ssh "${SSH_OPTS[@]}" -o ControlMaster=yes -o ControlPersist=120 \
            -o PreferredAuthentications=password,keyboard-interactive -o NumberOfPasswordPrompts=1 \
            -fN "$TARGET" </dev/null \
        || die "Could not log in to ${TARGET}. Check the password, that SSH is enabled on the Deck (sudo systemctl enable --now sshd), and the host name/IP."
    unset DECK_PASS
    rm -f "$ASKPASS"
fi

# ------------------------------------------------------------- copy ---
say "Copying to ${TARGET}:${REMOTE_DIR}/"
ssh "${SSH_OPTS[@]}" "$TARGET" "mkdir -p '${REMOTE_DIR}'"
# --delete only affects this game's folder (saves live in ~/.local/share/godot, untouched)
rsync -az --delete --info=progress2 -e "ssh ${SSH_OPTS[*]}" "${BUILD_DIR}/" "${TARGET}:${REMOTE_DIR}/"
ssh "${SSH_OPTS[@]}" "$TARGET" "chmod +x '${REMOTE_DIR}/${GAME_NAME}.sh' '${REMOTE_DIR}'/*.x86_64"

cat <<EOF

$(say "Done! Installed to ${REMOTE_DIR}")

Add it to Steam (once):
  1. On the Deck, switch to Desktop Mode and open Steam.
  2. Games -> "Add a Non-Steam Game to My Library..." -> Browse...
  3. Set the file type filter to "All Files", pick:
       ${REMOTE_DIR}/${GAME_NAME}.sh
  4. Add Selected Programs. (Optional: right-click it -> Properties to rename
     it "Dead Signal"; Controller settings -> use the "Gamepad" layout.)
  5. Back in Gaming Mode it's under Library -> Non-Steam.
EOF

if [[ "$HAS_ART" == 1 ]]; then
cat <<EOF

Icon & library artwork (Desktop Mode Steam, once) - images are in
  ${REMOTE_DIR}/artwork/
  * Icon:   right-click Dead Signal -> Properties -> click the blank icon square
            -> pick icon.png
  * Art:    in the Library, select Dead Signal, then right-click each empty slot:
            - grid tile (Library home)  -> capsule.png       ("Set custom artwork")
            - game page banner          -> hero.png          ("Set custom background")
            - title over the banner     -> logo.png          ("Set custom logo")
            - wide tile (Recent games)  -> wide_capsule.png
EOF
fi

cat <<EOF

Re-run this script any time to push a new build - the Steam shortcut keeps working.
EOF
