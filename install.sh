#!/bin/sh
#
# MeshBench, installed the way this machine expects.
#
#   curl -fsSL https://meshbench.github.io/install.sh | sh
#   curl -fsSL https://meshbench.github.io/install.sh | sh -s -- --bundled
#
# It works out the distribution and installs the right way for it:
#
#   Debian, Ubuntu   adds our apt repository and installs through apt, so
#                    updates arrive with the rest of the system.
#   macOS            adds our Homebrew tap and installs the cask.
#   Arch family      no package manager repository yet, so it installs the
#                    release tarball into /opt/meshbench, puts meshbench on
#                    PATH, and adds a launcher entry. Re-running upgrades it in
#                    place; the last section here says how to remove it.
#
# Where a package manager repository exists it is used, rather than instead of
# it, so MeshBench does not acquire a second install path on a machine that has
# a maintained one. The tarball install is only for the distributions that have
# no repository, and it stays a single, self-describing directory precisely so
# it is not a mess nobody can find later.
#
# Two packages, and the difference is only whether the emulators travel with
# the application:
#
#   meshbench           the application. About 26 MB. Emulated boards work once
#                       Configuration > Setup fetches the emulators.
#   meshbench-bundled   the same, with QEMU and Renode in it. About 118 MB, and
#                       an emulated board boots on first run.
#
# The plain name is the smaller one, on every package manager, because a
# package manager re-downloads on every release for a tool you may never point
# at an emulated board. A one-off download is a different question and the
# download page leads with the bundled build there.
#
# POSIX sh, not bash: this is piped into whatever /bin/sh is, and on Debian
# that is dash.
set -eu

VARIANT=compact
PACKAGE=meshbench
DRY=

usage() {
  cat >&2 <<USAGE
MeshBench installer

  --bundled     install meshbench-bundled, which carries the emulators
  --compact     install meshbench, the application alone (the default)
  --dry-run     print what would run, and run none of it
  -h, --help    this

Neither flag is needed for the common case. Read this script first if you would
rather not pipe one into a shell:

  https://github.com/MeshBench/meshbench.github.io/blob/main/install.sh
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --bundled) VARIANT=bundled; PACKAGE=meshbench-bundled ;;
    --compact) VARIANT=compact; PACKAGE=meshbench ;;
    --dry-run) DRY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install.sh: unknown option $1" >&2; usage; exit 2 ;;
  esac
  shift
done

say() { printf '%s\n' "$*" >&2; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

# Every command that changes the machine goes through this, so --dry-run shows
# the whole sequence rather than a description of it.
run() {
  if [ -n "$DRY" ]; then
    printf '  %s\n' "$*" >&2
    return 0
  fi
  # shellcheck disable=SC2068 # deliberate: the words are the command
  $@
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "$2"
}

# sudo only where it is needed and only where it exists. A root shell in a
# container has neither sudo nor a use for it.
SUDO=
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO=sudo
  else
    die "this needs root to install a package, and there is no sudo here. Run it as root."
  fi
fi

install_macos() {
  need brew "Homebrew is not installed. Get it from https://brew.sh, or take the disk image from https://meshbench.github.io/download"
  say "Adding the MeshBench tap..."
  run brew tap MeshBench/meshbench
  say "Installing $PACKAGE..."
  # No sudo: Homebrew refuses to run as root and owns its own prefix.
  run brew install --cask "$PACKAGE"
  say ""
  say "Installed. Run MeshBench from Applications, or 'meshbench workbench'."
}

install_debian() {
  need curl "curl is needed to fetch the signing key"
  KEYRING=/usr/share/keyrings/meshbench.gpg
  LIST=/etc/apt/sources.list.d/meshbench.list

  say "Adding the MeshBench repository..."
  if [ -n "$DRY" ]; then
    printf '  curl -fsSL https://meshbench.github.io/apt/meshbench.gpg | %s tee %s >/dev/null\n' "$SUDO" "$KEYRING" >&2
    printf '  echo "deb [signed-by=%s] https://meshbench.github.io/apt stable main" | %s tee %s\n' "$KEYRING" "$SUDO" "$LIST" >&2
  else
    curl -fsSL https://meshbench.github.io/apt/meshbench.gpg \
      | $SUDO tee "$KEYRING" >/dev/null \
      || die "could not fetch the signing key. Take a .deb from https://meshbench.github.io/download instead."
    echo "deb [signed-by=$KEYRING] https://meshbench.github.io/apt stable main" \
      | $SUDO tee "$LIST" >/dev/null
  fi

  say "Installing $PACKAGE..."
  run $SUDO apt-get update
  run $SUDO apt-get install -y "$PACKAGE"
  say ""
  say "Installed. Run 'meshbench workbench', or find MeshBench in the applications menu."
}

# For a distribution we publish no repository for, but whose glibc is current
# enough to run the Linux build: fetch the release tarball, verify it, and put
# it where an installed application lives. The tarball is a self-contained tree
# - the binary finds its fixtures, fonts and chip model beside itself - so it
# installs flat into one directory and reaches PATH through a single symlink.
# os.Executable resolves that symlink to the real file, so resource discovery
# lands in /opt/meshbench exactly as it would from the unpacked tarball.
PREFIX=/opt/meshbench
BINLINK=/usr/local/bin/meshbench
DESKTOP=/usr/share/applications/io.github.meshbench.meshbench.desktop
ICON=/usr/share/icons/hicolor/256x256/apps/io.github.meshbench.meshbench.png
RELEASE=https://github.com/MeshBench/meshbench/releases/latest/download
RAW=https://raw.githubusercontent.com/MeshBench/meshbench/main/packaging

install_tarball() {
  need curl "curl is needed to download the release"
  need tar "tar is needed to unpack the release"
  need sha256sum "sha256sum is needed to verify the download. Install coreutils."

  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) ;;
    *) die "the Linux build is x86_64 only, and this machine is $arch.
Take a build from https://meshbench.github.io/download." ;;
  esac

  asset="meshbench-linux-x86_64-${VARIANT}.tar.gz"

  if [ -n "$DRY" ]; then
    say "Would install the $VARIANT tarball:"
    printf '  curl -fL %s/%s -o <tmp>/%s\n' "$RELEASE" "$asset" "$asset" >&2
    printf '  curl -fL %s/SHA256SUMS | grep %s | sha256sum -c\n' "$RELEASE" "$asset" >&2
    printf '  %s rm -rf %s && %s tar xzf <tmp>/%s -C /opt (as meshbench/)\n' "$SUDO" "$PREFIX" "$SUDO" "$asset" >&2
    printf '  %s ln -sf %s/meshbench %s\n' "$SUDO" "$PREFIX" "$BINLINK" >&2
    printf '  %s install the launcher entry %s and icon %s\n' "$SUDO" "$DESKTOP" "$ICON" >&2
    return 0
  fi

  tmp=$(mktemp -d)
  # set -e means an early failure still has to clean up after itself.
  trap 'rm -rf "$tmp"' EXIT INT TERM

  say "Downloading ${asset}..."
  curl -fL --proto '=https' "$RELEASE/$asset" -o "$tmp/$asset" \
    || die "could not download $asset. Take a build from https://meshbench.github.io/download instead."

  say "Verifying the download..."
  curl -fsSL "$RELEASE/SHA256SUMS" -o "$tmp/SHA256SUMS" \
    || die "could not fetch SHA256SUMS to verify the download."
  # One line, our asset, checked where the file actually is.
  grep " ${asset}\$" "$tmp/SHA256SUMS" > "$tmp/want.sha256" \
    || die "SHA256SUMS has no entry for $asset; refusing to install an unverified file."
  ( cd "$tmp" && sha256sum -c want.sha256 >/dev/null 2>&1 ) \
    || die "the download did not match its published checksum; refusing to install it."

  say "Installing into ${PREFIX}..."
  # A clean tree every time: an upgrade, or a swap between compact and bundled,
  # must not leave an emulator from the last install behind.
  $SUDO rm -rf "$PREFIX"
  $SUDO mkdir -p /opt
  # The tarball unpacks as meshbench/; move it into place under our own name.
  tar xzf "$tmp/$asset" -C "$tmp"
  $SUDO mv "$tmp/meshbench" "$PREFIX"

  say "Linking ${BINLINK}..."
  $SUDO mkdir -p "$(dirname "$BINLINK")"
  $SUDO ln -sf "$PREFIX/meshbench" "$BINLINK"

  # The launcher entry and its icon are not in the tarball; take them from the
  # source tree, so the entry matches the one the .deb installs. A desktop
  # without them still has meshbench on PATH, so this is a warning, not a death.
  say "Adding the launcher entry..."
  if curl -fsSL "$RAW/meshbench.desktop" -o "$tmp/meshbench.desktop" \
     && curl -fsSL "$RAW/icons/meshbench-256.png" -o "$tmp/icon.png"; then
    $SUDO mkdir -p "$(dirname "$DESKTOP")" "$(dirname "$ICON")"
    $SUDO cp "$tmp/meshbench.desktop" "$DESKTOP"
    $SUDO cp "$tmp/icon.png" "$ICON"
    if command -v update-desktop-database >/dev/null 2>&1; then
      $SUDO update-desktop-database "$(dirname "$DESKTOP")" >/dev/null 2>&1 || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
      $SUDO gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
    fi
  else
    say "  (could not fetch the launcher entry; meshbench is still on your PATH)"
  fi

  rm -rf "$tmp"
  trap - EXIT INT TERM
  say ""
  say "Installed $VARIANT into $PREFIX. Run 'meshbench workbench', or find MeshBench in the applications menu."
  say "There is no package manager entry for it, so it does not update with the"
  say "system: re-run this script for a new release. To remove it:"
  say "  $SUDO rm -rf $PREFIX $BINLINK $DESKTOP $ICON"
}

# What this machine is. Deliberately narrow: a distribution nothing is
# published for, and whose glibc floor we cannot vouch for, gets sent to the
# download page rather than a guess, because a wrong guess here is a
# half-installed machine.
case "${UNAME_S:-$(uname -s)}" in
  Darwin)
    install_macos
    ;;
  Linux)
    # Overridable so the branches below can be exercised without a machine of
    # each kind. Nothing else reads it.
    OS_RELEASE=${OS_RELEASE:-/etc/os-release}
    if [ -r "$OS_RELEASE" ]; then
      # shellcheck disable=SC1090,SC1091 # a file this reads, not one it ships
      . "$OS_RELEASE"
    fi
    case "${ID:-}${ID_LIKE:+ $ID_LIKE}" in
      *debian*|*ubuntu*)
        install_debian
        ;;
      *arch*)
        # Arch and its family (CachyOS, Manjaro, EndeavourOS) roll forward, so
        # their glibc is always above the build's floor.
        install_tarball
        ;;
      *)
        die "no package is published for ${PRETTY_NAME:-this distribution} yet.
Take the AppImage or the tarball from https://meshbench.github.io/download -
both run on any distribution above glibc 2.35."
        ;;
    esac
    ;;
  *)
    die "this script covers macOS and Debian-family Linux.
For Windows, take the installer from https://meshbench.github.io/download."
    ;;
esac

if [ -n "$DRY" ]; then
  say ""
  say "(dry run: nothing above was executed)"
fi
