#!/usr/bin/env node

import { EstimateSyncTime } from "./estimateSyncTime";
import { BackupAnomaFolder } from "./backupAnomaFolder";

const HELP_TEXT = `
USAGE:
    test-net-tool <OPTIONS>
    test-net-tool [COMMAND] <OPTIONS>

OPTIONS:
    --help                          see this help

COMMANDS:
estimate-sync-time --remote-node-ip=<REMOTE_IP>
    
    OPTIONS:
        --remote-node-ip            IP of a remote node

    EXAMPLES:
        test-net-tool estimate-sync-time --remote-node-ip=54.76.21.80 # you can find this from .anoma/<network_id>/config.toml:[ledger.tendermint].p2p_persistent_peers but they must listen for network calls


start-backing-up-anoma-folder --remote-node-ip=<REMOTE_IP>

    OPTIONS:
        --path-to-anoma-root        root directory of anoma
        --frequency-in-minutes      optional: frequency in minutes, if omitted it is 20min

    EXAMPLES:
        test-net-tool start-backing-up-anoma-folder # this is only useful if you can run this globally from anoma folder
        test-net-tool start-backing-up-anoma-folder --path-to-anoma-root=/my/stuff/anoma # this is the folder containing .anoma
        test-net-tool start-backing-up-anoma-folder --path-to-anoma-root=/my/stuff/anoma --frequency-in-minutes=5

`;

let remoteNodeIp: string;
let pathToAnomaRoot: string;
let frequencyInMinutesMaybe: string;
let command = process.argv[2];
const commands = ["estimate-sync-time", "start-backing-up-anoma-folder"];

if (!commands.includes(command)) {
  console.log(
    `You provided command: ${command}, that is not known. The known ones are ${commands.join(
      ","
    )}`
  );
  console.log(HELP_TEXT);
  process.exit(1);
}

process.argv.forEach((argument) => {
  const [key, value] = argument.split("=");
  switch (key) {
    case "--remote-node-ip": {
      remoteNodeIp = value;
      break;
    }
    case "--path-to-anoma-root": {
      pathToAnomaRoot = value;
      break;
    }
    case "--frequency-in-minutes": {
      frequencyInMinutesMaybe = value;
      break;
    }
    case "--help": {
      console.log(HELP_TEXT);
      process.exit(1);
    }
  }
});

const main = async () => {
  if (command === "estimate-sync-time" && remoteNodeIp) {
    const estimateSyncTime = new EstimateSyncTime(remoteNodeIp);
    await estimateSyncTime.startPingingRemote();
  } else if (command === "start-backing-up-anoma-folder") {
    const backupUtil = new BackupAnomaFolder(pathToAnomaRoot);
    const frequencyInMinutes = Number(frequencyInMinutesMaybe) || 20;
    await backupUtil.startBackingUp(frequencyInMinutes);
  }
};

(async () => {
  await main();
  process.exit(1);
})();
