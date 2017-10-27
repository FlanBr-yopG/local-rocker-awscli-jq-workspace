
# # CONSTS

use_docker_for_binaries="gcloud jq packer terraform"
# # Why not garland/aws-cli-docker ?
# #  Well, I prefer "aws --version" 
# #   to say      "aws-cli/1.11.170 Python/2.7.10 Darwin/16.7.0 botocore/1.7.28"
# #   rather than "aws-cli/1.11.131 Python/2.7.13 Linux/4.9.49-moby botocore/1.5.94".
# #  But it also seems healthier to trust our the Homebrew formulas list more than some unofficial Docker Hub image.

# # DEFAULTS
[[ $admin_group ]] || admin_group=admin

_main() {
  ensure_bin
  ensure_brew
  ensure_make
  ensure_docker
  ensure_rocker
  # ensure_jq # Comes in from ensure_bin and $use_docker_for_binaries as a container.
  ensure_awscli
  ensure_virtualbox
  ensure_vagrant
  ensure_kubectl
}

_ensure_it() {
  local what=$1
  local whatcode=$2
  local must_be_admin=$3
  [[ $whatcode ]] || whatcode=$what
  [[ $must_be_admin ]] || must_be_admin=false
  if ! which $whatcode > /dev/null 2>&1 ; then
    local msg="$what should be installed"
    if [[ false == $CHANGE ]] ; then
      fail_check "FAILURE: Check failed: $msg."
    else # If CHANGE=true, make changes to install it.
      echo "NOTE: $msg; installing now."
      local uname_s=$(uname -s)
      if [[ Darwin != $uname_s ]] ; then
        fail_check "NOTE: Not installing $what on non-Darwin/non-MacOS (uname -s = '$uname_s')." 1>&2;
      else
        [[ false == $must_be_admin ]] || check_for_admin || must_be_admin_error $what
        ALREADY_SET_X=`case "$-" in *x*) echo "true" ;; esac`
        set -x
        eval "install_$whatcode" \
        || die "ERROR: $what install failed: '$?'."
        [[ true == $ALREADY_SET_X ]] || set +x
      fi ;
    fi ;
  fi ;
}
_ensure_manual() {
  local what=$1
  local whatcode=$2
  if ! which $whatcode > /dev/null 2>&1 ; then
    local msg="$what should be installed"
    if [[ false == $CHANGE ]] ; then
      fail_check "FAILURE: Check failed: $msg."
    else # If CHANGE=true, make changes to install it.
      local manual_url=$(eval "oops_manual_url_$whatcode")
      die "ERROR: $msg; please install it from $manual_url ."
    fi ;
  fi ;
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
  _ensure_it 'AWS CLI' aws
}
ensure_bin() {
  mk_bash_every_time;
  if [[ false == $CHANGE ]] ; then
    [[ -d ~/bin ]] || fail_check "ERROR: ~/bin should exist."
    [[ -e ~/.bash_every_time ]] || "ERROR: ~/.bash_every_time should exist."
    if [[ -e ~/.bash_every_time ]] ; then
      diff ~/.bash_every_time.gold ~/.bash_every_time 1>&2 || fail_check "ERROR: ~/.bash_every_time has the wrong content (see diff, above)."
    fi ;
  else
    ALREADY_SET_X=`case "$-" in *x*) echo "true" ;; esac`
    set -x
    [[ -d ~/bin ]] || mkdir ~/bin
    mk_bash_every_time;
    if [[ ! -e ~/.bash_every_time ]] ; then
      mv ~/.bash_every_time.gold ~/.bash_every_time
    else
      diff ~/.bash_every_time.gold ~/.bash_every_time || {
        echo "NOTE: Fixing ~/.bash_every_time." ;
        cat ~/.bash_every_time.gold > ~/.bash_every_time
      }
    fi ;
    [[ true == $ALREADY_SET_X ]] || set +x
  fi ;
  local f=''
  for f in .bashrc .bash_profile ; do
    if [[ false == $CHANGE ]] ; then
      [[ -e ~/$f ]] || fail_check "ERROR: ~/$f should exist."
      egrep bash_every_time ~/$f > /dev/null || fail_check "ERROR: ~/$f should invoke ~/.bash_every_time ."
    else
      ALREADY_SET_X=`case "$-" in *x*) echo "true" ;; esac`
      set -x
      [[ -e ~/$f ]] || touch ~/$f
      egrep bash_every_time ~/$f || echo -e '\nsource ~/.bash_every_time' >> ~/$f
      [[ true == $ALREADY_SET_X ]] || set +x
    fi ;
  done ;
  export PATH=$PATH:~/bin
  for x in $use_docker_for_binaries; do
    which $x > /dev/null || {
      if [[ false == $CHANGE ]] ; then
        fail_check "ERROR: Should have $x on your PATH."
      else
        ALREADY_SET_X=`case "$-" in *x*) echo "true" ;; esac`
        set -x
        touch ~/bin/$x
        chmod ug+rx ~/bin/$x
        eval "mk_bin_$x" || echo "ERROR: Found no such function as mk_bin_$x()."
        [[ true == $ALREADY_SET_X ]] || set +x
      fi ;
    }
  done ;
}
ensure_brew() {
  _ensure_it Homebrew brew true
}
ensure_docker() {
  _ensure_manual Docker docker
}
ensure_jq() {
  _ensure_it jq
}
ensure_kubectl() {
  _ensure_it jq
}
ensure_make() {
  _ensure_it "XCode (for make, etc.)" make
}
ensure_rocker() {
  _ensure_it Rocker rocker
}
ensure_virtualbox() {
  # # NOTE: I do not assume a user would want this automatically installed via Homebrew.
  _ensure_manual VirtualBox
}
ensure_vagrant() {
  # # NOTE: I do not assume a user would want this automatically installed via Homebrew.
  _ensure_manual Vagrant vagrant
}
fail_check() {
  echo "$1" 1>&2
  CHECKS_RETURNS=1
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
install_aws() {
  brew install awscli
}
install_brew() {
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}
install_jq() {
  brew install jq
}
install_kubectl() {
  brew install kubectl
}
install_make() {
  xcode-select --install
}
install_rocker() {
  local result=0
  brew tap grammarly/tap \
  && brew install grammarly/tap/rocker \
  || result=1
  [[ 0 -eq $result ]] || fail_check "ERROR: Failed to install rocker: '$?'."
  return $result
}
mk_bash_every_time() {
  cat > ~/.bash_every_time.gold <<'EOFbetg'
#!/bin/bash

main() {
  path_add ~/bin
}

path_add() { # cf. RHEL's pathmunge command
  local path_to_add=$1
  [[ ":$PATH:" != *":$path_to_add:"* ]] && export PATH="$PATH:$path_to_add"
}

main
EOFbetg
}
mk_bin_gcloud() {
  cat > ~/bin/gcloud <<'EOFbg'
#!/bin/bash

image='google/cloud-sdk:alpine'
container='gcloud-config'

main() {
  local already_ran=$(docker ps -a -f "name=$container" --format '{{.ID}}')
  if [[ $already_ran ]]; then
    docker run --rm -it \
      --volumes-from $container \
      "$image" \
      gcloud "$@"
    #
  else
    docker run -ti --name $container "$image" gcloud "$@"
  fi ;
}

main "$@"
EOFbg
}
mk_bin_jq() {
  cat > ~/bin/jq <<'EOFbg'
#!/bin/bash

image='stedolan/jq'

main() {
    docker run --rm -it \
      "$image" \
      "$@"
    #
}

main "$@"
EOFbg
}
mk_bin_kubectl() {
  # # NOTE: Running kubectl as a Docker-contained binary is dumb. Just run it locally.
  # Alternate = brew install kubectl
  cat > ~/bin/kubectl <<'EOFbg'
#!/bin/bash

image='lachlanevenson/k8s-kubectl:latest'

main() {
    docker run --rm -it \
      -v $HOME/.kube:/root/.kube -w /root/.kube/ \
      "$image" \
      "$@"
    #
}

main "$@"
EOFbg
}
mk_bin_packer() {
  cat > ~/bin/packer <<'EOFbg'
#!/bin/bash

image='hashicorp/packer:light'

main() {
    docker run --rm -it \
      "$image" \
      "$@"
    #
}

main "$@"
EOFbg
}
mk_bin_terraform() {
  # Alternate = brew install terraform
  cat > ~/bin/terraform <<'EOFbg'
#!/bin/bash

image='hashicorp/terraform:light'

main() {
    docker run --rm -it \
      -v $(pwd):/app/ -w /app/ \
      "$image" \
      "$@"
    #
}

main "$@"
EOFbg
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
oops_manual_url_docker() {
  echo 'https://docs.docker.com/docker-for-mac/install/#install-and-run-docker-for-mac'
}
oops_manual_url_vagrant() {
  echo 'https://www.vagrantup.com/downloads.html (or just {brew cask install vagrant})'
}
oops_manual_url_VirtualBox() {
  echo 'https://www.virtualbox.org/wiki/Downloads (or just {brew cask install virtualbox})'
}
