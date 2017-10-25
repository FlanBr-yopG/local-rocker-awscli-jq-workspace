#!/bin/bash

export CHANGE=false

main() {
  export PATH="$(pwd):$PATH"
  source functions.sh
  CHECKS_RETURNS=0
  _main
  return $CHECKS_RETURNS
}

cd $(dirname $0) && main
