<h1> Anoma Test Net Tools </h1>
A set of scripts that can automate repetitive tasks when developing anoma.

- [how to run](#how-to-run)
- [Utils](#utils)
  - [Estimate Sync Time](#estimate-sync-time)
  - [Start backing up anoma folder](#start-backing-up-anoma-folder)
  - [Anoma Doctor](#anoma-doctor)
- [Scripts](#scripts)

## how to run

For now you should have node installed on your machine but in the future this can be compiled so it can just be run standalone.

```bash
# if you do not have node, a good way to get and manage the installations is nvm
# https://github.com/nvm-sh/nvm#install--update-script
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

# clone the scripts
git clone https://github.com/anoma/dev-utils.git

cd dev-utils

# get the dependencies
npm install

# build, resulting js files will be in build folder
npx tsc

# run a commands by calling app.js with args
node ./build/app.js estimate-sync-time --remote-node-ip=54.76.21.80
```

The below the utils are quickly listed and explained

## Utils

### Estimate Sync Time

This will give a rough and naive estimation of how long the syncing of the local node should take. For this you need to get one of IPs from your config file. It's here in the below snippet it is that `54.78.173.66`. You should also pass the frequency of copying the folder, it will keep 2 latest copies. Just stop it by terminating the process by `ctr + c`. After stopping a new set of 3 folders will be created so you might like to delete them manually.

```toml
// .anoma/<net_id>/config.toml
[ledger.tendermint]
p2p_persistent_peers = ["tcp://<hash>@54.78.173.66:26656"]
```

So once you have that and your local node is syncing, call the below command in any directory on your machine.

```bash
node ./build/app.js estimate-sync-time --remote-node-ip=54.76.21.80
node ./build/app.js estimate-sync-time --remote-node-ip=54.76.21.80 --start-logging
```

### Start backing up anoma folder

When developing stuff a few times my local database files in `.anoma` got currupted and I had to restart a +24h sync. This script makes sure that you always have a pretty up to date copy of anoma folder that you can just name to `.anoma` and get back to action quicker.

Get the absolute path to the root folder of anoma, it is the one where you have `.anoma`. You have to pass the root folder as below and you can pass a number to indicate

```bash
node ./build/app.js start-backing-up-anoma-folder --path-to-anoma-root=/my/stuff/anoma --frequency-in-minutes=5
```

### Anoma Doctor

This will check out that the system have all the necessary dependencies in place. It is useful if stuff do not seem to work.

## Scripts

This is intended to be a collection of useful Bash scripts. See the [README](https://github.com/anoma/dev-utils/blob/main/scripts/README.md) file for more information.
