#!/bin/bash -e

# start.sh
# Utilities to help start anoma and ibc-rs processes

STATUS_INFO="\e[0m[\e[1;32m+\e[0m]"
STATUS_FAIL="\e[0m[\e[1;31mx\e[0m]"

usage() {
  cat << EOF >&2

Usage: $0 [-a <chain-a|chain-b|hermes>] [-h]

  -a: Start an app 
  -h: Show this message

  *Hint* - Set environment variable BASE_IBC_PATH to a different build path. Defaults to $(pwd)/build
EOF
  exit 0
}

if [ ! -z $BASE_IBC_PATH ]; then
  BASE_IBC_PATH=$BASE_IBC_PATH
else
  BASE_IBC_PATH=$(pwd)
fi

CONFIG_PATH="${BASE_IBC_PATH}/build/config.toml"

if [ ! -f $CONFIG_PATH ]; then
  printf "$STATUS_FAIL No $CONFIG_PATH found! Run init-ibc-local.sh to set up chains and relayer!\n\n"
  exit 1
fi

CONFIG="$( cat $CONFIG_PATH ) "
CHAIN_A_ID=$( echo "${CONFIG%?}" | grep "chain_a_id" | cut -d \" -f2 )
CHAIN_B_ID=$( echo "${CONFIG%?}" | grep "chain_b_id" | cut -d \" -f2 )

CHAIN_A_BASE_DIR="${BASE_IBC_PATH}/build/anoma/.anoma/${CHAIN_A_ID}/setup/validator-0/.anoma"
CHAIN_B_BASE_DIR="${BASE_IBC_PATH}/build/anoma/.anoma/${CHAIN_B_ID}/setup/validator-0/.anoma"

ANOMAN_PATH="${BASE_IBC_PATH}/build/anoma/target/release/anoman"
HERMES_PATH="${BASE_IBC_PATH}/build/ibc-rs"

if [ -z "$1" ]
then
  echo "No argument supplied!"
  usage
fi

# Get CLI Options
while getopts "ha:" arg; do
  case ${arg} in
    (a)
      APP=${OPTARG}
      ;;
    (h)
      usage ;;
    (*)
      usage ;;
  esac
done
shift $((OPTIND-1))

start_chain_a() {
  printf "$STATUS_INFO Starting Chain A with ID: ${CHAIN_A_ID}\n\n"
  exec $ANOMAN_PATH --base-dir $CHAIN_A_BASE_DIR --mode validator ledger run
}

start_chain_b() {
  printf "$STATUS_INFO Starting Chain B with ID: ${CHAIN_B_ID}\n\n"
  exec $ANOMAN_PATH --base-dir $CHAIN_B_BASE_DIR --mode validator ledger run
}

start_hermes() {
  printf "$STATUS_INFO Starting Hermes\n\n"
  cd $HERMES_PATH && exec cargo run --bin hermes -- -c config.toml start
}

case $APP in
  chain-a)
    start_chain_a
    ;;
  chain-b)
    start_chain_b
    ;;
  hermes)
    start_hermes
    ;;
  *)
    echo "No app by that name found!"
    exit 1 ;;
esac

