#!/bin/sh
#
# MeshBench, installed through your package manager.
#
#   curl -fsSL https://meshbench.github.io/install.sh | sh
#   curl -fsSL https://meshbench.github.io/install.sh | sh -s -- --bundled
#
# It works out the distribution, adds our repository or tap, and then runs apt
# or brew. It installs *through* the package manager rather than instead of it,
# so updates keep arriving with the rest of the system and MeshBench does not
# acquire a third install path nobody maintains.
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

# What this machine is. Deliberately narrow: a distribution nothing is
# published for gets sent to the download page rather than a guess, because a
# wrong guess here is a half-installed machine.
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
