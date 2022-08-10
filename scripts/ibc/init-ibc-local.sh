#!/bin/bash -e

# init-ibc-local.sh
# Set up a local instance of ibc-rs (Hermes) with two IBC-enabled Namada chains

usage() {
  cat << EOF >&2

Usage: $0 [-s] [-i <IP Address>] [-h]

  -s: Use SSH for Github repos (defaults to https)
  -i: Specify a non-localhost IP address (IP of machine where network is to be hosted)
  -h: Show this message

  *Hint* - Set environment variable BASE_BUILD_PATH to point build to a different path. Defaults to $(pwd)/build

  Required packages:
    - git
    - cargo (install via rustup: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh)
    - wasm-opt (part of the binaryen package at https://github.com/WebAssembly/binaryen)
EOF
  exit 1
}

STATUS_INFO="\e[0m[\e[1;32m+\e[0m]"
STATUS_WARN="\e[0m[\e[1;33m!\e[0m]"
STATUS_NOTICE="\e[0m[\e[1;34m*\e[0m]"
STATUS_FAIL="\e[0m[\e[1;31mx\e[0m]"

HERMES_CONFIG_TEMPLATE="config_template.toml"
CHAIN_A_TEMPLATE="#{CHAIN_A_ID}"
CHAIN_B_TEMPLATE="#{CHAIN_B_ID}"

check_dependencies() {
  if [ ! command -v git &> /dev/null ]; then
    printf "\n$STATUS_FAIL git could not be found, but is a required dependency!\n"
    exit 1
  fi

  if [ ! command -v rustup &> /dev/null ]; then
    printf "\n$STATUS_FAIL rustup could not be found, but is a required dependency!\n"
    echo "Install rustup: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
  fi

  if [ ! command -v wasm-opt &> /dev/null ]; then
    printf "\n$STATUS_FAIL wasm-opt could not be found, but is a required dependency!\n"
    echo "Install binaryen: https://github.com/WebAssembly/binaryen"
    exit 1
  fi
}

# DEFAULTS

BASE_PATH=$(pwd)

if [ ! -z $BASE_BUILD_PATH ]; then
  BASE_BUILD_PATH=$BASE_BUILD_PATH
else
  BASE_BUILD_PATH=$BASE_PATH
fi

if [ ! -z $NAMADA_BRANCH ]; then
  NAMADA_BRANCH=$NAMADA_BRANCH
else
  #NAMADA_BRANCH="yuji/ibc_test_ibc-rs_v0.14"
  NAMADA_BRANCH="main"
fi

if [ ! -z $HERMES_BRANCH ]; then
  HERMES_BRANCH=$HERMES_BRANCH
else
  HERMES_BRANCH="yuji/v0.14.0_anoma"
fi

if [ ! -z $GAIA_BRANCH ]; then
  GAIA_BRANCH=$GAIA_BRANCH
else
  GAIA_BRANCH="yuji/ics23_smt"
fi

BUILD_DIR="$BASE_BUILD_PATH/build"
NAMADA_DIR="namada"
HERMES_DIR="ibc-rs"
GAIA_DIR="gaia"

USE_GIT_SSH=false

CHAIN_A_ALIAS="Namada - Instance 1"
CHAIN_A_ID=""
CHAIN_A_PORT=27657
CHAIN_A_NET_PORT=27656
CHAIN_A_FAUCET=""

CHAIN_B_ALIAS="Namada - Instance 2"
CHAIN_B_ID=""
CHAIN_B_PORT=28657
CHAIN_B_NET_PORT=28656
CHAIN_B_FAUCET=""

GITHUB_SSH_URL="git@github.com"
GITHUB_HTTPS_URL="https://github.com"

NAMADA_REPO="/anoma/namada.git"
HERMES_REPO="/heliaxdev/ibc-rs.git"
GAIA_REPO="/heliaxdev/gaia.git"

GENESIS_PATH="genesis/e2e-tests-single-node.toml"
WASM_CHECKSUMS_PATH="wasm/checksums.json"

LOCALHOST_URL="127.0.0.1"
NETWORK=""

# Spawn an anoman child process and return the PID
spawn_anoma() {
  CHAIN_ID=$1
  cd $BUILD_DIR/$NAMADA_DIR
  nohup $BUILD_DIR/$NAMADA_DIR/target/release/anoman --base-dir .anoma/$CHAIN_ID/setup/validator-0/.anoma \
    --mode validator ledger run > /dev/null &
  echo $!
}

# Get CLI Options
while getopts "hsi:" arg; do
  case $arg in
    (s)
      USE_GIT_SSH=true ;;
    (h)
      usage ;;
    (i)
      NETWORK=${OPTARG}
      ;;
    (*)
      usage ;;
    # TODO: Add option to force-rebuild everything (no skipping of existing builds)
  esac
done
shift $((OPTIND-1))

if [ -z $NETWORK ]; then
  NETWORK=$LOCALHOST_URL
fi

NAMADA_GIT_URL="${GITHUB_HTTPS_URL}${NAMADA_REPO}"
HERMES_GIT_URL="${GITHUB_HTTPS_URL}${HERMES_REPO}"
GAIA_GIT_URL="${GITHUB_HTTPS_URL}${GAIA_REPO}"

[[ $USE_GIT_SSH == true ]] && NAMADA_GIT_URL="${GITHUB_SSH_URL}:${NAMADA_REPO}"
[[ $USE_GIT_SSH == true ]] && HERMES_GIT_URL="${GITHUB_SSH_URL}:${HERMES_REPO}"
[[ $USE_GIT_SSH == true ]] && GAIA_GIT_URL="${GIHUB_SSH_URL}:${GAIA_REPO}"

check_dependencies

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR" && printf "\n$STATUS_WARN Set working directory to $(pwd)\n"

# Clone anoma and ibc-rs repositories

# Check for Anoma, git clone if none
printf "\n$STATUS_INFO Cloning $NAMADA_GIT_URL\n"
[ ! -d $BUILD_DIR/$NAMADA_DIR ] &&  git clone  $NAMADA_GIT_URL || \
  printf "$STATUS_NOTICE Directory anoma exists, skipping git clone...\n\n"

# Check for Hermes (ibc-rs), git clone if none
printf "$STATUS_INFO Cloning $HERMES_GIT_URL\n"
[ ! -d $BUILD_DIR/$HERMES_DIR ] && git clone $HERMES_GIT_URL || \
  printf "$STATUS_NOTICE Directory ibc-rs exists, skipping git clone...\n\n"

# Check for Gaia, git clone if none
printf "$STATUS_INFO Cloning $GAIA_GIT_URL\n"
[ ! -d $BUILD_DIR/$GAIA_DIR ] && git clone $GAIA_GIT_URL || \
  printf "$STATUS_NOTICE Directory gaia exists, skipping git clone...\n\n"

# Install Anoma
printf "\n$STATUS_INFO Installing Anoma\n"
cd $BUILD_DIR/$NAMADA_DIR && printf "\n$STATUS_WARN Changed directory to $(pwd)\n\n"

git checkout $NAMADA_BRANCH
printf "$STATUS_INFO checked out $NAMADA_BRANCH\n"

if [ ! -f $BUILD_DIR/$NAMADA_DIR/target/release/anomac  ] || [ ! -f $BUILD_DIR/$NAMADA_DIR/target/release/anoman ]; then
  printf "\n$STATUS_WARN Anoma not installed. Installing now...\n\n"
  git checkout main && git pull && git checkout $NAMADA_BRANCH && make install

  rustup target add wasm32-unknown-unknown
  printf "\n$STATUS_INFO added rustup target wasm32-unknown-unknown\n"

  printf "\n$STATUS_INFO Building wasm scripts...\n\n"
  make build-wasm-scripts
else
  printf "$STATUS_NOTICE Anoma release targets already present, skipping build...\n"

  if [ -d $BUILD_DIR/$NAMADA_DIR/.anoma ]; then
    printf "$STATUS_NOTICE Clearing existing Anoma configuration...\n"
    rm -rf $BUILD_DIR/$NAMADA_DIR/.anoma
  fi
fi

# Install Gaia

if [ ! -f $BUILD_DIR/$GAIA_DIR/build/gaiad ]; then
  printf "\n$STATUS_INFO Building Gaia"
  cd $BUILD_DIR/$GAIA_DIR  && printf "\n$STATUS_WARN Changed directory to $(pwd)\n\n"
  git checkout $GAIA_BRANCH && make build
  export PATH=$PATH:${pwd}/build
  cd - && printf "\n$STATUS_WARN Changed directory to $(pwd)\n\n"
fi

# Initialize Namada Chains

# Check to ensure vp_token hash is correct, update if not
VP_TOKEN_OLD_HASH=$( cat $BUILD_DIR/$NAMADA_DIR/$GENESIS_PATH | grep -A 3 "wasm.vp_token" | grep sha256 | cut -d \" -f2 )
VP_TOKEN_HASH=$( cat $BUILD_DIR/$NAMADA_DIR/$WASM_CHECKSUMS_PATH | grep "\"vp_token.wasm\"" | cut -d \" -f4 | cut -d \. -f2 )

if [ $VP_TOKEN_OLD_HASH != $VP_TOKEN_HASH ]; then
  printf "$STATUS_NOTICE $VP_TOKEN_OLD_HASH != $VP_TOKEN_HASH\n"
  printf "$STATUS_NOTICE vp_token hash mismatch, updating...\n"
  sed -i "s/$VP_TOKEN_OLD_HASH/$VP_TOKEN_HASH/g" $BUILD_DIR/$NAMADA_DIR/$GENESIS_PATH
  printf "$STATUS_INFO Successfuly updated $BUILD_DIR/$NAMADA_DIR/$GENESIS_PATH!\n\n"
fi

# CHAIN A
printf "$STATUS_INFO Initializing Chain A\n\n"
# Swap net_address port for Chain A genesis
sed -i "s/${CHAIN_B_NET_PORT}/${CHAIN_A_NET_PORT}/g" $BUILD_DIR/$NAMADA_DIR/$GENESIS_PATH
printf "$STATUS_INFO Using $( grep "net_address" $BUILD_DIR/$NAMADA_DIR/$GENESIS_PATH )\n\n"

CHAIN_A_INIT_STDOUT=$(./target/release/anomac utils init-network \
  --unsafe-dont-encrypt \
  --genesis-path $GENESIS_PATH \
  --chain-prefix anoma-test \
  --localhost \
  --dont-archive \
  --wasm-checksums-path $WASM_CHECKSUMS_PATH)

CHAIN_A_ID=$( echo "${CHAIN_A_INIT_STDOUT%?}" | grep "Derived" | sed 's/Derived chain ID: //g' )
CHAIN_A_PATH="$BUILD_DIR/$NAMADA_DIR/.anoma/$CHAIN_A_ID"

printf "$STATUS_INFO Initialized Chain A: $CHAIN_A_ID\n\n"
CHAIN_A_FAUCET=$( cat $BUILD_DIR/$NAMADA_DIR/.anoma/$CHAIN_A_ID/setup/other/wallet.toml | \
  grep "faucet " |  cut -d \" -f2 )
printf "$STATUS_INFO Setting Chain A faucet to $CHAIN_A_FAUCET\n\n"

# CHAIN B
printf "$STATUS_INFO Initializing Chain B\n\n"
# Swap net_address port for Chain B genesis
sed -i "s/$CHAIN_A_NET_PORT/$CHAIN_B_NET_PORT/g" $BUILD_DIR/$NAMADA_DIR/$GENESIS_PATH
printf "$STATUS_INFO Using $( grep "net_address" $BUILD_DIR/$NAMADA_DIR/$GENESIS_PATH )\n\n"

CHAIN_B_INIT_STDOUT=$(./target/release/anomac utils init-network \
  --unsafe-dont-encrypt \
  --genesis-path $GENESIS_PATH \
  --chain-prefix anoma-test \
  --localhost \
  --dont-archive \
  --wasm-checksums-path $WASM_CHECKSUMS_PATH)

CHAIN_B_ID=$( echo "${CHAIN_B_INIT_STDOUT%?}" | grep "Derived" | sed 's/Derived chain ID: //g' )
CHAIN_B_PATH="$BUILD_DIR/$NAMADA_DIR/.anoma/$CHAIN_B_ID"

printf "$STATUS_INFO Initialized Chain B: $CHAIN_B_ID\n\n"
CHAIN_B_FAUCET=$( cat $BUILD_DIR/$NAMADA_DIR/.anoma/$CHAIN_B_ID/setup/other/wallet.toml | \
  grep "faucet " |  cut -d \" -f2 )
printf "$STATUS_INFO Setting Chain B faucet to $CHAIN_B_FAUCET\n\n"

# Set default chain to Chain A
sed -i "s/$CHAIN_B_ID/$CHAIN_A_ID/" $BUILD_DIR/$NAMADA_DIR/.anoma/global-config.toml
printf "$STATUS_INFO Set default chain to $CHAIN_A_ID\n\n"

# Chain A - Copy wasms and checksums.json to appropriate directories

cp wasm/*.wasm .anoma/$CHAIN_A_ID/wasm/
cp wasm/checksums.json .anoma/$CHAIN_A_ID/wasm/
cp wasm/*.wasm .anoma/$CHAIN_A_ID/setup/validator-0/.anoma/$CHAIN_A_ID/wasm/
cp wasm/checksums.json .anoma/$CHAIN_A_ID/setup/validator-0/.anoma/$CHAIN_A_ID/wasm/

printf "$STATUS_INFO Copied wasms and checksums.json for $CHAIN_A_ID\n\n"

# Chain B - Copy wasms and checksums.json to appropriate directories

cp wasm/*.wasm .anoma/$CHAIN_B_ID/wasm/
cp wasm/checksums.json .anoma/$CHAIN_B_ID/wasm/
cp wasm/*.wasm .anoma/$CHAIN_B_ID/setup/validator-0/.anoma/$CHAIN_B_ID/wasm/
cp wasm/checksums.json .anoma/$CHAIN_B_ID/setup/validator-0/.anoma/$CHAIN_B_ID/wasm/

printf "$STATUS_INFO Copied wasms and checksums.json for $CHAIN_B_ID\n\n"

# Set up Hermes

printf "$STATUS_INFO Configuring Hermes\n\n"
cd $BUILD_DIR/$HERMES_DIR && printf "$STATUS_WARN Changed directory to $(pwd)\n\n" && \
  git checkout $HERMES_BRANCH

mkdir -p anoma_wasm
printf "$STATUS_INFO Created directory $BUILD_DIR/$HERMES_DIR/anoma_wasm\n"
mkdir -p anoma_wallet/$CHAIN_A_ID
printf "$STATUS_INFO Created directory $BUILD_DIR/$HERMES_DIR/anoma_wallet/$CHAIN_A_ID\n"
mkdir -p anoma_wallet/$CHAIN_B_ID
printf "$STATUS_INFO Created directory $BUILD_DIR/$HERMES_DIR/anoma_wallet/$CHAIN_B_ID\n"

# Copy chain files to Hermes

cp $BUILD_DIR/$NAMADA_DIR/.anoma/$CHAIN_A_ID/setup/other/wallet.toml $BUILD_DIR/$HERMES_DIR/anoma_wallet/$CHAIN_A_ID
printf "$STATUS_INFO Copied $BUILD_DIR/$NAMADA_DIR/.anoma/$CHAIN_A_ID/setup/other/wallet.toml -->\
 $BUILD_DIR/$HERMES_DIR/anoma_wallet/$CHAIN_A_ID\n"

cp $BUILD_DIR/$NAMADA_DIR/.anoma/$CHAIN_B_ID/setup/other/wallet.toml $BUILD_DIR/$HERMES_DIR/anoma_wallet/$CHAIN_B_ID
printf "$STATUS_INFO Copied $BUILD_DIR/$NAMADA_DIR/.anoma/$CHAIN_B_ID/setup/other/wallet.toml -->\
 $BUILD_DIR/$HERMES_DIR/anoma_wallet/$CHAIN_B_ID\n"

cp $BUILD_DIR/$NAMADA_DIR/$WASM_CHECKSUMS_PATH $BUILD_DIR/$HERMES_DIR/anoma_wasm
printf "$STATUS_INFO Copied $BUILD_DIR/$NAMADA_DIR/$WASM_CHECKSUMS_PATH -->\
 $BUILD_DIR/$HERMES_DIR/anoma_wasm/\n"

cp $BUILD_DIR/$NAMADA_DIR/wasm/tx_ibc*.wasm $BUILD_DIR/$HERMES_DIR/anoma_wasm
printf "$STATUS_INFO Copied $BUILD_DIR/$NAMADA_DIR/wasm/tx_ibc*.wasm -->\
 $BUILD_DIR/$HERMES_DIR/anoma_wasm/\n"

# Copy configuration template to Hermes and add Namada Chain IDs
cp $BASE_PATH/$HERMES_CONFIG_TEMPLATE $BUILD_DIR/$HERMES_DIR/config.toml
printf "$STATUS_INFO Copied $BASE_PATH/$HERMES_CONFIG_TEMPLATE -->\
 $BUILD_DIR/$HERMES_DIR/config.toml\n"

sed -i "s/$CHAIN_A_TEMPLATE/$CHAIN_A_ID/" $BUILD_DIR/$HERMES_DIR/config.toml
printf "$STATUS_INFO Added $CHAIN_A_ID to $BUILD_DIR/$HERMES_DIR/config.toml\n"
sed -i "s/$CHAIN_B_TEMPLATE/$CHAIN_B_ID/" $BUILD_DIR/$HERMES_DIR/config.toml
printf "$STATUS_INFO Added $CHAIN_B_ID to $BUILD_DIR/$HERMES_DIR/config.toml\n"

# Initialize Gaia

printf "$STATUS_INFO Initializing Gaia\n"
cd $BUILD_DIR/$HERMES_DIR && printf "\n$STATUS_WARN Changed directory to $(pwd)\n\n"
./scripts/one-chain gaiad gaia ./data 26657 26656 26660 9092 100

# Launch Namada chains

# Spawn Chain A
printf "$STATUS_INFO Spawning Chain A anoman process\n"
CHAIN_A_PID=$( spawn_anoma $CHAIN_A_ID )
printf "$STATUS_INFO Spawned anoman process for $CHAIN_A_ID with PID: $CHAIN_A_PID\n\n"

# Spawn Chain B
printf "$STATUS_INFO Spawning Chain B anoman process\n"
CHAIN_B_PID=$( spawn_anoma $CHAIN_B_ID )
printf "$STATUS_INFO Spawned anoman process for $CHAIN_B_ID with PID: $CHAIN_B_PID\n\n"

ANOMAN_PROCESSES="$( ps -e | grep anoman ) "
cat <<EOF >&2

-----------------------------------
anoman processes
-----------------------------------
$( echo "${ANOMAN_PROCESSES%?}")

EOF

# Wait for block height to be > 0
sleep 3

if [ $NETWORK != $LOCALHOST_URL ]; then
  printf "$STATUS_NOTICE Updating for remote host configuration...\n"

  # Update configs for Chain A
  sed -i 's/127.0.0.1/0.0.0.0/g' $CHAIN_A_PATH/config.toml
  sed -i 's/127.0.0.1/0.0.0.0/g' $CHAIN_A_PATH/setup/validator-0/.anoma/$CHAIN_A_ID/config.toml
  sed -i 's/127.0.0.1/0.0.0.0/g' \
    $CHAIN_A_PATH/setup/validator-0/.anoma/$CHAIN_A_ID/tendermint/config/config.toml
  sed -i 's/^\(cors_allowed_origins =\).*/\1 ["*"]/' \
    $CHAIN_A_PATH/setup/validator-0/.anoma/$CHAIN_A_ID/tendermint/config/config.toml

  # Update configs for Chain B
  sed -i 's/127.0.0.1/0.0.0.0/g' $CHAIN_B_PATH/config.toml
  sed -i 's/127.0.0.1/0.0.0.0/g' $CHAIN_B_PATH/setup/validator-0/.anoma/$CHAIN_B_ID/config.toml
  sed -i 's/127.0.0.1/0.0.0.0/g' \
    $CHAIN_B_PATH/setup/validator-0/.anoma/$CHAIN_B_ID/tendermint/config/config.toml
  sed -i 's/^\(cors_allowed_origins =\).*/\1 ["*"]/' \
    $CHAIN_B_PATH/setup/validator-0/.anoma/$CHAIN_B_ID/tendermint/config/config.toml

  printf "$STATUS_INFO Successfully updated configuration!\n\n"
fi

# Create IBC connection and channel

printf "$STATUS_INFO Creating connection between $CHAIN_A_ID and $CHAIN_B_ID\n"

CONNECTION_STDOUT="$( cargo run --bin hermes -- -c config.toml \
  create connection $CHAIN_A_ID $CHAIN_B_ID ) "

CONNECTION_1_ID=$( echo "${CONNECTION_STDOUT%?}" | grep -A 3 connection_id | grep -m1 "connection-" |  tr -d " " | cut -d \" -f2 )

printf "$STATUS_INFO Established connection with ID: $CONNECTION_1_ID\n"

printf "$STATUS_INFO Create channel on $CONNECTION_1_ID\n"

CHANNEL_STDOUT="$( cargo run --bin hermes -- -c config.toml \
  create channel \
  --port-a transfer --port-b transfer \
   $CHAIN_A_ID $CONNECTION_1_ID ) "

# We can likely just assume channel-0 for src and dst, as the chains will always be new.
# This is mainly for debugging and seeing in the output that Hermes completed the channel creation process.
CHANNEL_1_ID="channel-$( echo "${CHANNEL_STDOUT%?}" | grep -A 3 "channel_id: Some" | tr -d " " | grep -E -o -m1 "[0-9]+" )"
echo "${CHANNEL_STDOUT%?}"
printf "$STATUS_INFO Established channel with ID: $CHANNEL_1_ID\n"

# Add Gaia keys to Hermes
printf "$STATUS_INFO Add user key Hermes\n"
cargo run  --bin hermes -- -c config.toml keys add gaia -f data/gaia/user_seed.json
printf "$STATUS_INFO Add user2 key to Hermes\n"
cargo run  --bin hermes -- -c config.toml keys add gaia -f data/gaia/user2_seed.json

# Create connection and channel between Gaia and Chain A
printf "$STATUS_INFO Creating connection between gaia and $CHAIN_A_ID\n"
CONNECTION_STDOUT="$( cargo run --bin hermes -- -c config.toml \
  create connection gaia $CHAIN_A_ID ) "
CONNECTION_2_ID=$( echo "${CONNECTION_STDOUT%?}" | grep -A 3 connection_id | grep -m1 "connection-" |  tr -d " " | cut -d \" -f2 )
CHANNEL_STDOUT="$( cargo run --bin hermes -- -c config.toml \
  create channel \
  --port-a transfer --port-b transfer \
   gaia $CONNECTION_2_ID ) "
CHANNEL_2_ID="channel-$( echo "${CHANNEL_STDOUT%?}" | grep -A 3 "channel_id: Some" | tr -d " " | grep -E -o -m1 "[0-9]+" )"

# Create connection and channel between Gaia and Chain B
printf "$STATUS_INFO Creating connection between gaia and $CHAIN_B_ID\n"
CONNECTION_STDOUT="$( cargo run --bin hermes -- -c config.toml \
  create connection gaia $CHAIN_B_ID ) "
CONNECTION_3_ID=$( echo "${CONNECTION_STDOUT%?}" | grep -A 3 connection_id | grep -m1 "connection-" |  tr -d " " | cut -d \" -f2 )
CHANNEL_STDOUT="$( cargo run --bin hermes -- -c config.toml \
  create channel \
  --port-a transfer --port-b transfer \
   gaia $CONNECTION_3_ID ) "
CHANNEL_3_ID="channel-$( echo "${CHANNEL_STDOUT%?}" | grep -A 3 "channel_id: Some" | tr -d " " | grep -E -o -m1 "[0-9]+" )"

# Kill existing anoman and gaiad processes:
if [ ! command -v pkill &> /dev/null ]; then
  kill -9 $CHAIN_A_PID && printf "$STATUS_WARN Killed process with PID = $CHAIN_A_PID\n"
  kill -9 $CHAIN_B_PID && printf "$STATUS_WARN Killed process with PID = $CHAIN_B_PID\n"
  # TODO: Get PID of gaiad to kill here, to be invoked manually later
else
  pkill anoman
  pkill gaiad
fi

cd $BUILD_DIR && printf "\n$STATUS_WARN Changed directory to $(pwd)\n" 

# Generate a runtime config for CLI:
CONFIG_PATH=$BUILD_DIR/config.toml

write_config() {
  cat <<EOF > $CONFIG_PATH
[[chain]]
chain_id = "$CHAIN_A_ID"

[[chain]]
chain_id = "$CHAIN_B_ID"

[[chain]]
chain_id = "gaia"

[[connection]]
chain_a_id = "$CHAIN_A_ID"
chain_b_id = "$CHAIN_B_ID"
CONNECTION_1_ID = "$CONNECTION_1_ID"
CHANNEL_1_ID = "$CHANNEL_1_ID"

[[connection]]
chain_a_id = "gaia"
chain_b_id = "$CHAIN_A_ID"
CONNECTION_1_ID = "$CONNECTION_2_ID"
CHANNEL_1_ID = "$CHANNEL_2_ID"

[[connection]]
chain_a_id = "gaia"
chain_b_id = "$CHAIN_B_ID"
CONNECTION_1_ID = "$CONNECTION_3_ID"
CHANNEL_1_ID = "$CHANNEL_3_ID"
EOF
}

# Generate a .env file for the Wallet UI:
ENV_PATH=$BUILD_DIR/.env

write_env() {
  cat <<EOF > $ENV_PATH
GENERATE_SOURCEMAP=false

# Chain A
REACT_APP_CHAIN_A_ALIAS=${CHAIN_A_ALIAS}
REACT_APP_CHAIN_A_ID=${CHAIN_A_ID}
REACT_APP_CHAIN_A_URL=http://${NETWORK}
REACT_APP_CHAIN_A_PORT=${CHAIN_A_PORT}
REACT_APP_CHAIN_A_FAUCET=${CHAIN_A_FAUCET}

# Chain B
REACT_APP_CHAIN_B_ALIAS=${CHAIN_B_ALIAS}
REACT_APP_CHAIN_B_ID=${CHAIN_B_ID}
REACT_APP_CHAIN_B_URL=http://${NETWORK}
REACT_APP_CHAIN_B_PORT=${CHAIN_B_PORT}
REACT_APP_CHAIN_B_FAUCET=${CHAIN_B_FAUCET}
EOF
}

printf "\n$STATUS_INFO Writing CLI runtime config to $CONFIG_PATH\n"
write_config

printf "\n$STATUS_INFO Writing Wallet UI config to $ENV_PATH\n"
write_env

echo "Finished!"
exit 0
