# Utility Scripts

This folder houses multiple utility scripts to make life easier while working with Anoma chains.

## Table of Contents

- [IBC Setup](#ibc-setup-with-two-namada-chains)
  - [Usage](#ibc-setup---usage)
  - [Start Chains and Relayer](#ibc-setup---startsh)
  - [Start the Wallet UI](#starting-the-wallet-ui)

## IBC Setup with two Namada Chains

Initialize two IBC-enabled Namada chains and the `ibc-rs` (Hermes) relayer.

### IBC Setup - Usage

Show help:

```bash
cd src
./init-ibc-local.sh -h
```

_NOTE_ You can specify the following environment variables to override defaults used by the script:

```bash
# Set an alternative build path:
BASE_BUILD_PATH="/opt/ibc"

# Specify alternative branches
ANOMA_BRANCH="justin/anoma-alternative-branch"
HERMES_BRANCH="justin/ibc-rs-test"
```

Install and configure 2 Namada chains with the Hermes relayer:

```bash
./init-ibc-local.sh

# Alternatively, specify that you want git to work over SSH:
./init-ibc-local.sh -s

# If you want to run this on a remote host (e.g., in a VM), you can specify
# an IP address for the wallet app to connect to. This will configure Tendermint RPC to
# correctly listen on both the source and destination chain:
./init-ibc-local.sh -i 10.9.8.101
```

**NOTE**: If this process hangs during the IBC `create connection` phase, it's safe to hit `Ctrl-C` and exit, then
re-issue the command. It will skip most completed steps, re-initialize two Namada chains, and create an IBC
connection and channel.

Upon completion, this will generate two files in the `build/` folder:

```bash
build/
  .env
  config.toml
```

The `config.toml` is simply the stored, generated information needed to run the chains and relayer from the helper CLI (`.start.sh`).

[ [Table of Contents](#table-of-contents) ]

## IBC Setup - start.sh

_NOTE_ You can specify a `BASE_IBC_PATH` environment variable to choose the `build` directory where the required
`config.toml` is located.

The source chain (e.g., Chain A) and the destination chain (e.g. Chain B), along with Hermes, can be started with the
following commands issued in separate terminals:

```bash
# Show usage
./start.sh -h

# Start Chain A
./start.sh -a chain-a

# Start Chain B
./start.sh -a chain-b

# Start Hermes
./start.sh -a hermes
```

[ [Table of Contents](#table-of-contents) ]

## Starting the Wallet UI

The `.env` file from can be copied to the Wallet UI application (in `anoma-apps/packages/anoma-wallet` - see
<https://github.com/anoma/anoma-apps>) to configure it to work with this set-up:

```bash
# Clone the anoma-apps repo to set up Wallet UI
git clone https://github.com/anoma/anoma-apps.git
cd anoma-apps
git checkout feat/39-ibc-setup
yarn

# Copy the generated .env configuration from "scripts"
cd packages/anoma-wallet
cp /path/to/scripts/src/build/.env .

# Start the wallet with this configuration
yarn dev:local
```

[ [Table of Contents](#table-of-contents) ]
