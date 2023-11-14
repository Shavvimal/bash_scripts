#!/bin/sh
set -eu

# *************
# Rerun this install script with --uninstall to uninstall.
# DO NOT EDIT
#
# install.sh was bundled together from
#
# - ./ci/sub/lib/rand.sh
# - ./ci/sub/lib/temp.sh
# - ./ci/sub/lib/log.sh
# - ./ci/sub/lib/flag.sh
# - ./ci/sub/lib/release.sh
# - ./ci/release/_install.sh
#
# The last of which implements the installation logic.
#
# Generated by ./ci/release/gen_install.sh.
# *************

#!/bin/sh
if [ "${LIB_RAND-}" ]; then
  return 0
fi
LIB_RAND=1

pick() {
  seed="$1"
  shift

  seed_file="$(mktempd)/pickseed"

  # We add 32 more bytes to the seed file for sufficient entropy. Otherwise both Cygwin's
  # and MinGW's sort for example complains about the lack of entropy on stderr and writes
  # nothing to stdout. I'm sure there are more platforms that would too.
  #
  # We also limit to a max of 32 bytes as otherwise macOS's sort complains that the random
  # seed is too large. Probably more platforms too.
  (echo "$seed" && echo "================================") | head -c32 >"$seed_file"

  while [ $# -gt 0 ]; do
    echo "$1"
    shift
  done \
    | sort --sort=random --random-source="$seed_file" \
    | head -n1
}
#!/bin/sh
if [ "${LIB_TEMP-}" ]; then
  return 0
fi
LIB_TEMP=1

ensure_tmpdir() {
  if [ -n "${_TMPDIR-}" ]; then
    return
  fi
  _TMPDIR=$(mktemp -d)
  export _TMPDIR
}

if [ -z "${_TMPDIR-}" ]; then
  trap 'rm -Rf "$_TMPDIR"' EXIT
fi
ensure_tmpdir

temppath() {
  while true; do
    temppath=$_TMPDIR/$(</dev/urandom od -N8 -tx -An -v | tr -d '[:space:]')
    if [ ! -e "$temppath" ]; then
      echo "$temppath"
      return
    fi
  done
}

mktempd() {
  tp=$(temppath)
  mkdir -p "$tp"
  echo "$tp"
}
#!/bin/sh
if [ "${LIB_LOG-}" ]; then
  return 0
fi
LIB_LOG=1

if [ -n "${TRACE-}" ]; then
  set -x
fi

tput() {
  if should_color; then
    TERM=${TERM:-xterm-256color} command tput "$@"
  fi
}

should_color() {
  if [ -n "${COLOR-}" ]; then
    if [ "$COLOR" = 1 -o "$COLOR" = true ]; then
      _COLOR=1
      __COLOR=1
      return 0
    elif [ "$COLOR" = 0 -o "$COLOR" = false ]; then
      _COLOR=
      __COLOR=0
      return 1
    else
      printf '$COLOR must be 0, 1, false or true but got %s\n' "$COLOR" >&2
    fi
  fi

  if [ -t 1 -a "${TERM-}" != dumb ]; then
    _COLOR=1
    __COLOR=1
    return 0
  else
    _COLOR=
    __COLOR=0
    return 1
  fi
}

setaf() {
  fg=$1
  shift
  printf '%s\n' "$*" | while IFS= read -r line; do
    tput setaf "$fg"
    printf '%s' "$line"
    tput sgr0
    printf '\n'
  done
}

_echo() {
  printf '%s\n' "$*"
}

get_rand_color() {
  if [ "${TERM_COLORS+x}" != x ]; then
    TERM_COLORS=""
    export TERM_COLORS
    ncolors=$(TERM=${TERM:-xterm-256color} command tput colors)
    if [ "$ncolors" -ge 8 ]; then
      # 1-6 are regular
      TERM_COLORS="$TERM_COLORS 1 2 3 4 5 6"
    elif [ "$ncolors" -ge 16 ]; then
      # 9-14 are bright.
      TERM_COLORS="$TERM_COLORS 9 10 11 12 13 14"
    fi
  fi
  pick "$*" $TERM_COLORS
}

echop() {
  prefix="$1"
  shift

  if [ "$#" -gt 0 ]; then
    printfp "$prefix" "%s\n" "$*"
  else
    printfp "$prefix"
    printf '\n'
  fi
}

printfp() {(
  prefix="$1"
  shift

  _FGCOLOR=${FGCOLOR:-$(get_rand_color "$prefix")}
  should_color || true
  if [ $# -eq 0 ]; then
    printf '%s' "$(COLOR=$__COLOR setaf "$_FGCOLOR" "$prefix")"
  else
    printf '%s: %s\n' "$(COLOR=$__COLOR setaf "$_FGCOLOR" "$prefix")" "$(printf "$@")"
  fi
)}

catp() {
  prefix="$1"
  shift

  should_color || true
  sed "s/^/$(COLOR=$__COLOR printfp "$prefix" '')/"
}

repeat() {
  char="$1"
  times="$2"
  seq -s "$char" "$times" | tr -d '[:digit:]'
}

strlen() {
  printf %s "$1" | wc -c
}

echoerr() {
  FGCOLOR=1 logp err "$*"
}

caterr() {
  FGCOLOR=1 logpcat err "$@"
}

printferr() {
  FGCOLOR=1 logfp err "$@"
}

logp() {
  should_color >&2 || true
  COLOR=$__COLOR echop "$@" | humanpath >&2
}

logfp() {
  should_color >&2 || true
  COLOR=$__COLOR printfp "$@" | humanpath >&2
}

logpcat() {
  should_color >&2 || true
  COLOR=$__COLOR catp "$@" | humanpath >&2
}

log() {
  FGCOLOR=5 logp log "$@"
}

logf() {
  FGCOLOR=5 logfp log "$@"
}

logcat() {
  FGCOLOR=5 logpcat log "$@"
}

warn() {
  FGCOLOR=3 logp warn "$@"
}

warnf() {
  FGCOLOR=3 logfp warn "$@"
}

warncat() {
  FGCOLOR=3 logpcat warn "$@"
}

sh_c() {
  FGCOLOR=3 logp exec "$*"
  if [ -z "${DRY_RUN-}" ]; then
    eval "$@"
  fi
}

sudo_sh_c() {
  if [ "$(id -u)" -eq 0 ]; then
    sh_c "$@"
  elif command -v doas >/dev/null; then
    sh_c "doas $*"
  elif command -v sudo >/dev/null; then
    sh_c "sudo $*"
  elif command -v su >/dev/null; then
    sh_c "su root -c '$*'"
  else
    caterr <<EOF
Unable to run the following command as root:
  $*
Please install doas, sudo, or su.
EOF
    return 1
  fi
}

header() {
  FGCOLOR=${FGCOLOR:-4} logp "/* $1 */"
}

bigheader() {
  set -- "$(echo "$*" | sed "s/^/ * /")"
  FGCOLOR=${FGCOLOR:-6} logp "/****************************************************************
$*
 ****************************************************************/"
}

# humanpath replaces all occurrences of " $HOME" with " ~"
# and all occurrences of '$HOME' with the literal '$HOME'.
humanpath() {
  if [ -z "${HOME-}" ]; then
    cat
  else
    sed -e "s# $HOME# ~#g" -e "s#$HOME#\$HOME#g"
  fi
}

hide() {
  out="$(mktempd)/hideout"
  capcode "$@" >"$out" 2>&1
  if [ "$code" -eq 0 ]; then
    return
  fi
  cat "$out" >&2
  return "$code"
}

hide_stderr() {
  out="$(mktempd)/hideout"
  capcode "$@" 2>"$out"
  if [ "$code" -eq 0 ]; then
    return
  fi
  cat "$out" >&2
  return "$code"
}

echo_dur() {
  local dur=$1
  local h=$((dur/60/60))
  local m=$((dur/60%60))
  local s=$((dur%60))
  printf '%dh%dm%ds' "$h" "$m" "$s"
}

sponge() {
  dst="$1"
  tmp="$(mktempd)/sponge"
  cat > "$tmp"
  cat "$tmp" > "$dst"
}

stripansi() {
  # First regex gets rid of standard xterm escape sequences for controlling
  # visual attributes.
  # The second regex I'm not 100% sure, the reference says it selects the US
  # encoding but I'm not sure why that's necessary or why it always occurs
  # in tput sgr0 before the standard escape sequence.
  # See tput sgr0 | xxd
  sed -e $'s/\x1b\[[0-9;]*m//g' -e $'s/\x1b(.//g'
}

runtty() {
  case "$(uname)" in
    Darwin)
      script -q /dev/null "$@"
      ;;
    Linux)
      script -eqc "$*"
      ;;
    *)
      echoerr "runtty: unsupported OS $(uname)"
      return 1
  esac
}

capcode() {
  set +e
  "$@"
  code=$?
  set -e
}

strjoin() {
  (IFS="$1"; shift; echo "$*")
}
#!/bin/sh
if [ "${LIB_FLAG-}" ]; then
  return 0
fi
LIB_FLAG=1

# flag_parse implements a robust flag parser.
#
# For a full fledge example see ../examples/date.sh
#
# It differs from getopts(1) in that long form options are supported. Currently the only
# deficiency is that short combined options are not supported like -xyzq. That would be
# interpreted as a single -xyzq flag. The other deficiency is lack of support for short
# flag syntax like -carg where the arg is not separated from the flag. This one is
# unfixable I believe unfortunately but for combined short flags I have opened
# https://github.com/terrastruct/ci/issues/6
#
# flag_parse stores state in $FLAG, $FLAGRAW, $FLAGARG and $FLAGSHIFT.
# FLAG contains the name of the flag without hyphens.
# FLAGRAW contains the name of the flag as passed in with hyphens.
# FLAGARG contains the argument for the flag if there was any.
#   If there was none, it will not be set.
# FLAGSHIFT contains the number by which the arguments should be shifted to
#   start at the next flag/argument
#
# flag_parse exits with a non zero code when there are no more flags
# to be parsed. Still, call shift "$FLAGSHIFT" in case there was a --
#
# If the argument for the flag is optional, then use ${FLAGARG-} to access
# the argument if one was passed. Use ${FLAGARG+x} = x to check if it was set.
# You only need to explicitly check if the flag was set if you care whether the user
# explicitly passed the empty string as the argument.
#
# Otherwise, call one of the flag_*arg functions:
#
# If a flag requires an argument, call flag_reqarg
#   - $FLAGARG is guaranteed to be set after.
# If a flag requires a non empty argument, call flag_nonemptyarg
#   - $FLAGARG is guaranteed to be set to a non empty string after.
# If a flag should not be passed an argument, call flag_noarg
#   - $FLAGARG is guaranteed to be unset after.
#
# And then shift "$FLAGSHIFT"
flag_parse() {
  case "${1-}" in
    -*=*)
      # Remove everything after first equal sign.
      FLAG="${1%%=*}"
      # Remove leading hyphens.
      FLAG="${FLAG#-}"; FLAG="${FLAG#-}"
      FLAGRAW="$(flag_fmt)"
      # Remove everything before first equal sign.
      FLAGARG="${1#*=}"
      FLAGSHIFT=1
      return 0
      ;;
    -)
      FLAGSHIFT=0
      return 1
      ;;
    --)
      FLAGSHIFT=1
      return 1
      ;;
    -*)
      # Remove leading hyphens.
      FLAG="${1#-}"; FLAG="${FLAG#-}"
      FLAGRAW=$(flag_fmt)
      unset FLAGARG
      FLAGSHIFT=1
      if [ $# -gt 1 ]; then
        case "$2" in
          -)
            FLAGARG="$2"
            FLAGSHIFT=2
            ;;
          -*)
            ;;
          *)
            FLAGARG="$2"
            FLAGSHIFT=2
            ;;
        esac
      fi
      return 0
      ;;
    *)
      FLAGSHIFT=0
      return 1
      ;;
  esac
}

flag_reqarg() {
  if [ "${FLAGARG+x}" != x ]; then
    flag_errusage "flag $FLAGRAW requires an argument"
  fi
}

flag_nonemptyarg() {
  flag_reqarg
  if [ -z "$FLAGARG" ]; then
    flag_errusage "flag $FLAGRAW requires a non-empty argument"
  fi
}

flag_noarg() {
  if [ "$FLAGSHIFT" -eq 2 ]; then
    unset FLAGARG
    FLAGSHIFT=1
  elif [ "${FLAGARG+x}" = x ]; then
    # Means an argument was passed via equal sign as in -$FLAG=$FLAGARG
    flag_errusage "flag $FLAGRAW does not accept an argument"
  fi
}

flag_errusage() {
  caterr <<EOF
$1
Run with --help for usage.
EOF
  return 1
}

flag_fmt() {
  if [ "$(printf %s "$FLAG" | wc -c)" -eq 1 ]; then
    echo "-$FLAG"
  else
    echo "--$FLAG"
  fi
}
#!/bin/sh
if [ "${LIB_RELEASE-}" ]; then
  return 0
fi
LIB_RELEASE=1

ensure_os() {
  if [ -n "${OS-}" ]; then
    # Windows defines OS=Windows_NT.
    if [ "$OS" = Windows_NT ]; then
      OS=windows
    fi
    return
  fi
  uname=$(uname)
  case $uname in
    Linux) OS=linux;;
    Darwin) OS=macos;;
    FreeBSD) OS=freebsd;;
    *) OS=$uname;;
  esac
}

ensure_arch() {
  if [ -n "${ARCH-}" ]; then
    return
  fi
  uname_m=$(uname -m)
  case $uname_m in
    aarch64) ARCH=arm64;;
    x86_64) ARCH=amd64;;
    *) ARCH=$uname_m;;
  esac
}

ensure_goos() {
  if [ -n "${GOOS-}" ]; then
    return
  fi
  ensure_os
  case "$OS" in
    macos) export GOOS=darwin;;
    *) export GOOS=$OS;;
  esac
}

ensure_goarch() {
  if [ -n "${GOARCH-}" ]; then
    return
  fi
  ensure_arch
  case "$ARCH" in
    *) export GOARCH=$ARCH;;
  esac
}

gh_repo() {
  gh repo view --json nameWithOwner --template '{{ .nameWithOwner }}'
}

manpath() {
  if command -v manpath >/dev/null; then
    command manpath
  elif man -w 2>/dev/null; then
    man -w
  else
    echo "${MANPATH-}"
  fi
}

is_writable_dir() {
  mkdir -p "$1" 2>/dev/null
  # directory must exist otherwise -w returns 1 even for paths that should be writable.
  [ -w "$1" ]
}

ensure_prefix() {
  if [ -n "${PREFIX-}" ]; then
    return
  fi
  # The reason for checking whether lib is writable is that on macOS you have /usr/local
  # owned by root but you don't need root to write to its subdirectories which is all we
  # need to do.
  if ! is_writable_dir "/usr/local/lib"; then
    # This also handles M1 Mac's which do not allow modifications to /usr/local even
    # with sudo.
    PREFIX=$HOME/.local
  else
    PREFIX=/usr/local
  fi
}

ensure_prefix_sh_c() {
  ensure_prefix

  sh_c="sh_c"
  # The reason for checking whether lib is writable is that on macOS you have /usr/local
  # owned by root but you don't need root to write to its subdirectories which is all we
  # need to do.
  if ! is_writable_dir "$PREFIX/lib"; then
    sh_c="sudo_sh_c"
  fi
}
#!/bin/sh
set -eu


help() {
  arg0="$0"
  if [ "$0" = sh ]; then
    arg0="curl -fsSL https://d2lang.com/install.sh | sh -s --"
  fi

  cat <<EOF
usage: $arg0 [-d|--dry-run] [--version vX.X.X] [--edge] [--method detect] [--prefix path]
  [--tala latest] [--force] [--uninstall] [-x|--trace]

install.sh automates the installation of D2 onto your system. It currently only supports
the installation of standalone releases from GitHub and via Homebrew on macOS. See the
docs for --detect below for more information

If you pass --edge, it will clone the source, build a release and install from it.
--edge is incompatible with --tala and currently unimplemented.

\$PREFIX in the docs below refers to the path set by --prefix. See docs on the --prefix
flag below for the default.

Flags:

-d, --dry-run
  Pass to have install.sh show the install method and flags that will be used to install
  without executing them. Very useful to understand what changes it will make to your system.

--version vX.X.X
  Pass to have install.sh install the given version instead of the latest version.
  warn: The version may not be obeyed with package manager installations. Use
        --method=standalone to enforce the version.

--edge
  Pass to build and install D2 from source. This will still use --method if set to detect
  to install the release archive for your OS, whether it's apt, yum, brew or standalone
  if an unsupported package manager is used.

  To install from source like a dev would, use go install oss.terrastruct.com/d2. There's
  also ./ci/release/build.sh --install to build and install a proper standalone release
  including manpages. The proper release will also ensure d2 --version shows the correct
  version by embedding the commit hash into the binary.

  note: currently unimplemented.
  warn: incompatible with --tala as TALA is closed source.

--method [detect | standalone | homebrew ]
  Pass to control the method by which to install. Right now we only support standalone
  releases from GitHub but later we'll add support for brew, rpm, deb and more.

  - detect will use your OS's package manager automatically.
    So far it only detects macOS and automatically uses homebrew.
  - homebrew uses https://brew.sh/ which is a macOS and Linux package manager.
  - standalone installs a standalone release archive into the unix hierarchy path
     specified by --prefix

--prefix path
  Controls the unix hierarchy path into which standalone releases are installed.
  Defaults to /usr/local or ~/.local if /usr/local is not writable by the current user.
  Remember that whatever you use, you must have the bin directory of your prefix path in
  \$PATH to execute the d2 binary. For example, if my prefix directory is /usr/local then
  my \$PATH must contain /usr/local/bin.
  You may also need to include \$PREFIX/share/man into \$MANPATH.
  install.sh will tell you whether \$PATH or \$MANPATH need to be updated after successful
  installation.

--tala [latest]
  Install Terrastruct's closed source TALA for improved layouts.
  See https://github.com/terrastruct/tala
  It optionally takes an argument of the TALA version to install.
  Installation obeys all other flags, just like the installation of d2. For example,
  the d2plugin-tala binary will be installed into \$PREFIX/bin/d2plugin-tala
  warn: The version may not be obeyed with package manager installations. Use
        --method=standalone to enforce the version.

--force:
  Force installation over the existing version even if they match. It will attempt a
  uninstall first before installing the new version. The installed release tree
  will be deleted from \$PREFIX/lib/d2/d2-<VERSION> but the release archive in
  ~/.cache/d2/release will remain.

--uninstall:
  Uninstall the installed version of d2. The --method and --prefix flags must be the same
  as for installation. i.e if you used --method standalone you must again use --method
  standalone for uninstallation. With detect, the install script will try to use the OS
  package manager to uninstall instead.
  note: tala will also be uninstalled if installed.

-x, --trace:
  Run script with set -x.

All downloaded archives are cached into ~/.cache/d2/release. use \$XDG_CACHE_HOME to change
path of the cached assets. Release archives are unarchived into \$PREFIX/lib/d2/d2-<VERSION>

note: Deleting the unarchived releases will cause --uninstall to stop working.

You can rerun install.sh to update your version of D2. install.sh will avoid reinstalling
if the installed version is the latest unless --force is passed.

See https://github.com/terrastruct/d2/blob/master/docs/INSTALL.md#security for
documentation on its security.
EOF
}

main() {
  while flag_parse "$@"; do
    case "$FLAG" in
      h|help)
        help
        return 0
        ;;
      d|dry-run)
        flag_noarg && shift "$FLAGSHIFT"
        DRY_RUN=1
        ;;
      version)
        flag_nonemptyarg && shift "$FLAGSHIFT"
        VERSION=$FLAGARG
        ;;
      tala)
        shift "$FLAGSHIFT"
        TALA=${FLAGARG:-latest}
        ;;
      edge)
        flag_noarg && shift "$FLAGSHIFT"
        EDGE=1
        echoerr "$FLAGRAW is currently unimplemented"
        return 1
        ;;
      method)
        flag_nonemptyarg && shift "$FLAGSHIFT"
        METHOD=$FLAGARG
        ;;
      prefix)
        flag_nonemptyarg && shift "$FLAGSHIFT"
        export PREFIX=$FLAGARG
        ;;
      force)
        flag_noarg && shift "$FLAGSHIFT"
        FORCE=1
        ;;
      uninstall)
        flag_noarg && shift "$FLAGSHIFT"
        UNINSTALL=1
        ;;
      x|trace)
        flag_noarg && shift "$FLAGSHIFT"
        set -x
        export TRACE=1
        ;;
      *)
        flag_errusage "unrecognized flag $FLAGRAW"
        ;;
    esac
  done
  shift "$FLAGSHIFT"

  if [ $# -gt 0 ]; then
    flag_errusage "no arguments are accepted"
  fi

  REPO=${REPO:-terrastruct/d2}
  ensure_os
  ensure_arch
  ensure_prefix
  CACHE_DIR=$(cache_dir)
  mkdir -p "$CACHE_DIR"
  METHOD=${METHOD:-detect}
  INSTALL_DIR=$PREFIX/lib/d2

  case $METHOD in
    detect)
      case "$OS" in
        macos)
          if command -v brew >/dev/null; then
            log "detected macOS with homebrew, using homebrew for installation"
            METHOD=homebrew
          else
            warn "detected macOS without homebrew, falling back to --method=standalone"
            METHOD=standalone
          fi
          ;;
        linux|windows)
          METHOD=standalone
          ;;
        *)
          warn "unrecognized OS $OS, falling back to --method=standalone"
          METHOD=standalone
          ;;
      esac
      ;;
    standalone) ;;
    homebrew) ;;
    *)
      echoerr "unknown installation method $METHOD"
      return 1
      ;;
  esac

  if [ -n "${UNINSTALL-}" ]; then
    uninstall
    if [ -n "${DRY_RUN-}" ]; then
      bigheader "Rerun without --dry-run to execute printed commands and perform install."
    fi
  else
    install
    if [ -n "${DRY_RUN-}" ]; then
      bigheader "Rerun without --dry-run to execute printed commands and perform install."
    fi
  fi
}

install() {
  case $METHOD in
    standalone)
      install_d2_standalone
      if [ -n "${TALA-}" ]; then
        # Run in subshell to avoid overwriting VERSION.
        TALA_VERSION="$( RELEASE_INFO= install_tala_standalone && echo "$VERSION" )"
      fi
      ;;
    homebrew)
      install_d2_brew
      if [ -n "${TALA-}" ]; then install_tala_brew; fi
      ;;
  esac

  FGCOLOR=2 bigheader 'next steps'
  case $METHOD in
    standalone) install_post_standalone ;;
    homebrew) install_post_brew ;;
  esac
  install_post_warn
}

install_post_standalone() {
  log "d2-$VERSION-$OS-$ARCH has been successfully installed into $PREFIX"
  if [ -n "${TALA-}" ]; then
    log "tala-$TALA_VERSION-$OS-$ARCH has been successfully installed into $PREFIX"
  fi
  log "Rerun this install script with --uninstall to uninstall."
  log
  if ! echo "$PATH" | grep -qF "$PREFIX/bin"; then
    logcat >&2 <<EOF
Extend your \$PATH to use d2:
  export PATH=$PREFIX/bin:\$PATH
Then run:
  ${TALA:+D2_LAYOUT=tala }d2 --help
EOF
  else
    log "Run ${TALA:+D2_LAYOUT=tala }d2 --help for usage."
  fi
  if ! manpath 2>/dev/null | grep -qF "$PREFIX/share/man"; then
    logcat >&2 <<EOF
Extend your \$MANPATH to view d2's manpages:
  export MANPATH=$PREFIX/share/man:\$MANPATH
Then run:
  man d2
EOF
  if [ -n "${TALA-}" ]; then
    log "  man d2plugin-tala"
  fi
  else
    log "Run man d2 for detailed docs."
    if [ -n "${TALA-}" ]; then
      log "Run man d2plugin-tala for detailed TALA docs."
    fi
  fi
}

install_post_brew() {
  log "d2 has been successfully installed with homebrew."
  if [ -n "${TALA-}" ]; then
    log "tala has been successfully installed with homebrew."
  fi
  log "Rerun this install script with --uninstall to uninstall."
  log
  log "Run ${TALA:+D2_LAYOUT=tala }d2 --help for usage."
  log "Run man d2 for detailed docs."
  if [ -n "${TALA-}" ]; then
    log "Run man d2plugin-tala for detailed TALA docs."
  fi

  VERSION=$(brew info d2 | head -n1 | cut -d' ' -f4)
  VERSION=${VERSION%,}
  if [ -n "${TALA-}" ]; then
    TALA_VERSION=$(brew info tala | head -n1 | cut -d' ' -f4)
    TALA_VERSION=${TALA_VERSION%,}
  fi
}

install_post_warn() {
  if command -v d2 >/dev/null; then
    INSTALLED_VERSION=$(d2 --version)
    if [ "$INSTALLED_VERSION" != "$VERSION" ]; then
      warn "newly installed d2 $VERSION is shadowed by d2 $INSTALLED_VERSION in \$PATH"
    fi
  fi
  if [ -n "${TALA-}" ] && command -v d2plugin-tala >/dev/null; then
    INSTALLED_TALA_VERSION=$(d2plugin-tala --version)
    if [ "$INSTALLED_TALA_VERSION" != "$TALA_VERSION" ]; then
      warn "newly installed d2plugin-tala $TALA_VERSION is shadowed by d2plugin-tala $INSTALLED_TALA_VERSION in \$PATH"
    fi
  fi
}

install_d2_standalone() {
  VERSION=${VERSION:-latest}
  header "installing d2-$VERSION"

  if [ "$VERSION" = latest ]; then
    fetch_release_info
  fi

  if command -v d2 >/dev/null; then
    INSTALLED_VERSION="$(d2 --version)"
    if [ ! "${FORCE-}" -a "$VERSION" = "$INSTALLED_VERSION" ]; then
      log "skipping installation as d2 $VERSION is already installed."
      return 0
    fi
    log "uninstalling d2 $INSTALLED_VERSION to install $VERSION"
    if ! uninstall_d2_standalone; then
      warn "failed to uninstall d2 $INSTALLED_VERSION"
    fi
  fi

  ARCHIVE="d2-$VERSION-$OS-$ARCH.tar.gz"
  log "installing standalone release $ARCHIVE from github"

  fetch_release_info
  asset_line=$(sh_c 'cat "$RELEASE_INFO" | grep -n "$ARCHIVE" | cut -d: -f1 | head -n1')
  asset_url=$(sh_c 'sed -n $((asset_line-3))p "$RELEASE_INFO" | sed "s/^.*: \"\(.*\)\",$/\1/g"')
  fetch_gh "$asset_url" "$CACHE_DIR/$ARCHIVE" 'application/octet-stream'

  ensure_prefix_sh_c
  "$sh_c" mkdir -p "'$INSTALL_DIR'"
  "$sh_c" tar -C "$INSTALL_DIR" -xzf "$CACHE_DIR/$ARCHIVE"
  "$sh_c" sh -c "'cd \"$INSTALL_DIR/d2-$VERSION\" && make install PREFIX=\"$PREFIX\"'"
}

install_d2_brew() {
  header "installing d2 with homebrew"
  sh_c brew update
  sh_c brew install d2
}

install_tala_standalone() {
  REPO="${REPO_TALA:-terrastruct/tala}"
  VERSION=$TALA

  header "installing tala-$VERSION"

  if [ "$VERSION" = latest ]; then
    fetch_release_info
  fi

  if command -v d2plugin-tala >/dev/null; then
    INSTALLED_VERSION="$(d2plugin-tala --version)"
    if [ ! "${FORCE-}" -a "$VERSION" = "$INSTALLED_VERSION" ]; then
      log "skipping installation as tala $VERSION is already installed."
      return 0
    fi
    log "uninstalling tala $INSTALLED_VERSION to install $VERSION"
    if ! uninstall_tala_standalone; then
      warn "failed to uninstall tala $INSTALLED_VERSION"
    fi
  fi

  ARCHIVE="tala-$VERSION-$OS-$ARCH.tar.gz"
  log "installing standalone release $ARCHIVE from github"

  fetch_release_info
  asset_line=$(sh_c 'cat "$RELEASE_INFO" | grep -n "$ARCHIVE" | cut -d: -f1 | head -n1')
  asset_url=$(sh_c 'sed -n $((asset_line-3))p "$RELEASE_INFO" | sed "s/^.*: \"\(.*\)\",$/\1/g"')

  fetch_gh "$asset_url" "$CACHE_DIR/$ARCHIVE" 'application/octet-stream'

  ensure_prefix_sh_c
  "$sh_c" mkdir -p "'$INSTALL_DIR'"
  "$sh_c" tar -C "$INSTALL_DIR" -xzf "$CACHE_DIR/$ARCHIVE"
  "$sh_c" sh -c "'cd \"$INSTALL_DIR/tala-$VERSION\" && make install PREFIX=\"$PREFIX\"'"
}

install_tala_brew() {
  header "installing tala with homebrew"
  sh_c brew update
  sh_c brew install terrastruct/tap/tala
}

uninstall() {
  # We uninstall tala first as package managers require that it be uninstalled before
  # uninstalling d2 as TALA depends on d2.
  if command -v d2plugin-tala >/dev/null; then
    INSTALLED_VERSION="$(d2plugin-tala --version)"
    header "uninstalling tala-$INSTALLED_VERSION"
    case $METHOD in
      standalone) uninstall_tala_standalone ;;
      homebrew) uninstall_tala_brew ;;
    esac
  elif [ "${TALA-}" ]; then
    warn "no version of tala installed"
  fi

  if ! command -v d2 >/dev/null; then
    warn "no version of d2 installed"
    return 0
  fi

  INSTALLED_VERSION="$(d2 --version)"
  header "uninstalling d2-$INSTALLED_VERSION"
  case $METHOD in
    standalone) uninstall_d2_standalone ;;
    homebrew) uninstall_d2_brew ;;
  esac
}

uninstall_d2_standalone() {
  log "uninstalling standalone release of d2-$INSTALLED_VERSION"

  if [ ! -e "$INSTALL_DIR/d2-$INSTALLED_VERSION" ]; then
    warn "missing standalone install release directory $INSTALL_DIR/d2-$INSTALLED_VERSION"
    warn "d2 must have been installed via some other installation method."
    return 1
  fi

  ensure_prefix_sh_c
  "$sh_c" sh -c "'cd \"$INSTALL_DIR/d2-$INSTALLED_VERSION\" && make uninstall PREFIX=\"$PREFIX\"'"
  "$sh_c" rm -rf "$INSTALL_DIR/d2-$INSTALLED_VERSION"
}

uninstall_d2_brew() {
  sh_c brew remove d2
}

uninstall_tala_standalone() {
  log "uninstalling standalone release tala-$INSTALLED_VERSION"

  if [ ! -e "$INSTALL_DIR/tala-$INSTALLED_VERSION" ]; then
    warn "missing standalone install release directory $INSTALL_DIR/tala-$INSTALLED_VERSION"
    warn "tala must have been installed via some other installation method."
    return 1
  fi

  ensure_prefix_sh_c
  "$sh_c" sh -c "'cd \"$INSTALL_DIR/tala-$INSTALLED_VERSION\" && make uninstall PREFIX=\"$PREFIX\"'"
  "$sh_c" rm -rf "$INSTALL_DIR/tala-$INSTALLED_VERSION"
}

uninstall_tala_brew() {
  sh_c brew remove tala
}

cache_dir() {
  if [ -n "${XDG_CACHE_HOME-}" ]; then
    echo "$XDG_CACHE_HOME/d2/release"
  elif [ -n "${HOME-}" ]; then
    echo "$HOME/.cache/d2/release"
  else
    echo "/tmp/d2-cache/release"
  fi
}

fetch_release_info() {
  if [ -n "${RELEASE_INFO-}" ]; then
    return 0
  fi

  log "fetching info on $VERSION version of $REPO"
  RELEASE_INFO=$(mktempd)/release-info.json
  if [ "$VERSION" = latest ]; then
    release_info_url="https://api.github.com/repos/$REPO/releases/$VERSION"
  else
    release_info_url="https://api.github.com/repos/$REPO/releases/tags/$VERSION"
  fi
  DRY_RUN= fetch_gh "$release_info_url" "$RELEASE_INFO" \
    'application/json'
  VERSION=$(cat "$RELEASE_INFO" | grep -m1 tag_name | sed 's/^.*: "\(.*\)",$/\1/g')
}

curl_gh() {
  sh_c curl -fL ${GITHUB_TOKEN:+"-H \"Authorization: Bearer \$GITHUB_TOKEN\""} "$@"
}

fetch_gh() {
  url=$1
  file=$2
  accept=$3

  if [ -e "$file" ]; then
    log "reusing $file"
    return
  fi

  curl_gh -#o "$file.inprogress" -C- -H "'Accept: $accept'" "$url"
  sh_c mv "$file.inprogress" "$file"
}

# The main function does more than provide organization. It provides robustness in that if
# the install script was to only partial download into sh, sh will not execute it because
# main is not invoked until the very last byte.
main "$@"