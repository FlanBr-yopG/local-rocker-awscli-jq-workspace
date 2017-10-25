
# # CONSTS
[[ $admin_group ]] || admin_group=admin

_main() {
  ensure_brew
  ensure_make
  ensure_docker
  ensure_rocker
  ensure_jq
  ensure_awscli
}

check_for_admin() {
  local result=0
  local admin_gid=$(get_admin_gid)
  id | cut -d' ' -f 2- | egrep "[=,]$admin_gid" || result=1
  return $result
}
die() {
  [[ true == $ALREADY_SET_X ]] || set +x
  echo $1;
  CHECKS_RETURNS=1
  exit 1;
}
ensure_awscli() {
  local what='AWS CLI'
  if ! which aws > /dev/null 2>&1 ; then
    local msg="$what should be installed"
    if [[ false == $CHANGE ]] ; then
      echo "FAILURE: Check failed: $msg."
      CHECKS_RETURNS=1
    else # If CHANGE=true, make changes to install it.
      echo "NOTE: $msg; installing now."
      local uname_s=$(uname -s)
      if [[ Darwin != $uname_s ]] ; then
        echo "NOTE: Not installing $what on non-Darwin/non-MacOS (uname -s = '$uname_s')." 1>&2;
        CHECKS_RETURNS=1
      else
        # check_for_admin || must_be_admin_error $what
        ALREADY_SET_X=`case "$-" in *x*) echo "true" ;; esac`
        set -x
        brew install awscli \
        || die "ERROR: $what install failed: '$?'."
        [[ true == $ALREADY_SET_X ]] || set +x
      fi ;
    fi ;
  fi ;
}

ensure_brew() {
  local what=Homebrew
  if ! which brew > /dev/null 2>&1 ; then
    local msg="$what should be installed"
    if [[ false == $CHANGE ]] ; then
      echo "FAILURE: Check failed: $msg."
      CHECKS_RETURNS=1
    else # If CHANGE=true, make changes to install it.
      echo "NOTE: $msg; installing now."
      local uname_s=$(uname -s)
      if [[ Darwin != $uname_s ]] ; then
        echo "NOTE: Not installing $what on non-Darwin/non-MacOS (uname -s = '$uname_s')." 1>&2;
        CHECKS_RETURNS=1
      else
        check_for_admin || must_be_admin_error $what
        ALREADY_SET_X=`case "$-" in *x*) echo "true" ;; esac`
        set -x
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" \
        || die "ERROR: $what install failed: '$?'."
        [[ true == $ALREADY_SET_X ]] || set +x
      fi ;
    fi ;
  fi ;
}
ensure_docker() {
  local what=Docker
  if ! which docker > /dev/null 2>&1 ; then
    local msg="$what should be installed"
    if [[ false == $CHANGE ]] ; then
      echo "FAILURE: Check failed: $msg."
      CHECKS_RETURNS=1
    else # If CHANGE=true, make changes to install it.
      die "ERROR: $msg; please install it from https://docs.docker.com/docker-for-mac/install/#install-and-run-docker-for-mac ."
    fi ;
  fi ;
}
ensure_jq() {
  local what="jq"
  if ! which jq > /dev/null 2>&1 ; then
    local msg="$what should be installed"
    if [[ false == $CHANGE ]] ; then
      echo "FAILURE: Check failed: $msg."
      CHECKS_RETURNS=1
    else # If CHANGE=true, make changes to install it.
      echo "NOTE: $msg; installing now."
      local uname_s=$(uname -s)
      if [[ Darwin != $uname_s ]] ; then
        echo "NOTE: Not installing $what on non-Darwin/non-MacOS (uname -s = '$uname_s')." 1>&2;
        # TODO: Consider someday adding support for non-Darwin/non-MacOS.
        CHECKS_RETURNS=1
      else
        # check_for_admin || must_be_admin_error $what
        ALREADY_SET_X=`case "$-" in *x*) echo "true" ;; esac`
        set -x
        brew install jq \
        || die "ERROR: $what install failed: '$?'."
        [[ true == $ALREADY_SET_X ]] || set +x
      fi ;
    fi ;
  fi ;
}
ensure_make() {
  local what="XCode (for make)"
  if ! which make > /dev/null 2>&1 ; then
    local msg="$what should be installed"
    if [[ false == $CHANGE ]] ; then
      echo "FAILURE: Check failed: $msg."
      CHECKS_RETURNS=1
    else # If CHANGE=true, make changes to install it.
      echo "NOTE: $msg; installing now."
      local uname_s=$(uname -s)
      if [[ Darwin != $uname_s ]] ; then
        echo "NOTE: Not installing $what on non-Darwin/non-MacOS (uname -s = '$uname_s')." 1>&2;
        # TODO: Consider someday adding support for non-Darwin/non-MacOS.
        CHECKS_RETURNS=1
      else
        check_for_admin || must_be_admin_error $what
        ALREADY_SET_X=`case "$-" in *x*) echo "true" ;; esac`
        set -x
        xcode-select --install \
        || die "ERROR: $what install failed: '$?'."
        [[ true == $ALREADY_SET_X ]] || set +x
      fi ;
    fi ;
  fi ;
}
ensure_rocker() {
  local what="Rocker"
  if ! which rocker > /dev/null 2>&1 ; then
    local msg="$what should be installed"
    if [[ false == $CHANGE ]] ; then
      echo "FAILURE: Check failed: $msg."
      CHECKS_RETURNS=1
    else # If CHANGE=true, make changes to install it.
      echo "NOTE: $msg; installing now."
      local uname_s=$(uname -s)
      if [[ Darwin != $uname_s ]] ; then
        echo "NOTE: Not installing $what on non-Darwin/non-MacOS (uname -s = '$uname_s')." 1>&2;
        # TODO: Consider someday adding support for non-Darwin/non-MacOS.
        CHECKS_RETURNS=1
      else
        # check_for_admin || must_be_admin_error $what
        ALREADY_SET_X=`case "$-" in *x*) echo "true" ;; esac`
        set -x
        install_rocker \
        || die "ERROR: $what install failed: '$?'."
        [[ true == $ALREADY_SET_X ]] || set +x
      fi ;
    fi ;
  fi ;
}
get_admin_gid() {
  local gid=''
  if which getent > /dev/null 2>&1 ; then
    gid=$(getent group $admin_group | cut -d: -f3)
  else
    if which dscacheutil > /dev/null 2>&1 ; then
      gid=$(
        dscacheutil -q group -a name $admin_group \
        | awk -F\: '$1 ~ /^gid$/ {print $NF}' \
        | tr -d ' '
      )
    else
      gid=$(
        cat /etc/group \
        | awk -F\: "\$1 ~ /^$admin_group\$/ {print \$3}"
      )
    fi ;
  fi ;
  echo $gid
}
install_rocker() {
  local result=0
  brew tap grammarly/tap \
  && brew install grammarly/tap/rocker \
  || result=1
  [[ 0 -eq $result ]] || echo "ERROR: Failed to install rocker: '$?'."
  return $result
}
must_be_admin_error() {
  local what=$1
  local this_user="$(id -u)($(id -un))"
  local admin_g_with_gid="$(get_admin_gid)($admin_group)"
  local msg="$what must be installed by an admin"
  msg="$msg (but this user, $this_user,"
  msg="$msg is not in admin group, $admin_g_with_gid)."
  msg="$msg You may have a Self Service app"
  msg="$msg or an AdminGuard/\"promote to admin\" app"
  msg="$msg or maybe even an App Store."
  die "ERROR: $msg"
}
