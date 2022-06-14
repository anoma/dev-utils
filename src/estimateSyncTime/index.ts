import { execSync } from "child_process";
import fetch from "node-fetch";
import { sleep } from "../utils";

const MEASUREMENT_SECONDS = 5;
const LITTLE_TIME_THRESHOLD_SECONDS = 60 * 60 * 1.5;
const LOG_FILE_PATH = "./blog_height_logging.csv";
export class EstimateSyncTime {
  remoteHost: string;
  remoteBlockHeights: number[] = [];
  localBlockHeights: number[] = [];

  latestLogEntry: string = "";

  constructor(remoteHost: string) {
    this.remoteHost = remoteHost;
  }

  // gives the block height at host
  getBlockHeightAtHost = async (fromHost: string): Promise<number> => {
    const response = await fetch(`http://${fromHost}:26657/status`);
    const data = await response.json();
    return Promise.resolve(Number(data.result.sync_info.latest_block_height));
  };

  private createLogEntry = (blockHeight: string, host: string) => {
    const currentTime = new Date();
    const currentTimeFormatted = `${currentTime.getFullYear()}, ${currentTime.getMonth()}, ${currentTime.getDate()}, ${currentTime.getHours()}, ${currentTime.getMinutes()}, ${currentTime.getSeconds()}`;
    const dataToAppend = `${currentTimeFormatted}, ${host}, ${blockHeight}`;
    execSync(`echo ${dataToAppend} >> ${LOG_FILE_PATH}`);
  };

  startPinging = async (host: string, arrayToPush: number[]) => {
    for (let index = 0; index < MEASUREMENT_SECONDS; index++) {
      const blockHeight = await this.getBlockHeightAtHost(host);
      arrayToPush.push(blockHeight);
      if (host !== "localhost") {
        console.clear();
        console.log(`querying time to sync${".".repeat(index)}`);
        console.log(this.latestLogEntry);
      }
      this.createLogEntry(`${blockHeight}`, host);
      await sleep(1000);
    }
  };

  // based on the objects state estimates the duration to reach a sync
  private estimateDuration = (): string => {
    const currentTime = new Date();
    // then naively estimate the time to reach the remote block height
    const localBlockHeights = this.localBlockHeights;
    const remoteBlockHeights = this.remoteBlockHeights;

    const localBlocksPerMeasurementSeconds =
      localBlockHeights[localBlockHeights.length - 1] - localBlockHeights[0];
    const localBlocksPerSecond =
      localBlocksPerMeasurementSeconds / MEASUREMENT_SECONDS;
    const blocksDistanceToRemote =
      remoteBlockHeights[remoteBlockHeights.length - 1] -
      localBlockHeights[localBlockHeights.length - 1];
    const secondsToCatchUpRemote =
      blocksDistanceToRemote / localBlocksPerSecond;
    const littleTimeLeft =
      secondsToCatchUpRemote < LITTLE_TIME_THRESHOLD_SECONDS;

    // if we have little time left we show it more detailed
    let timeLeftDisplayed;
    if (littleTimeLeft) {
      const hoursToCatchUpRemote = secondsToCatchUpRemote / 60;
      timeLeftDisplayed = `${Math.round(hoursToCatchUpRemote)}min`;
    } else {
      const hoursToCatchUpRemote = secondsToCatchUpRemote / 60 / 60;
      timeLeftDisplayed = `${Math.round(hoursToCatchUpRemote)}h`;
    }

    const minutesFormatted =
      currentTime.getMinutes() < 10
        ? `0${currentTime.getMinutes()}`
        : currentTime.getMinutes();
    const currentTimeFormatted = `${currentTime.getFullYear()}_${currentTime.getMonth()}_${currentTime.getDate()} ${currentTime.getHours()}:${minutesFormatted} - estimated time to sync local node: ${timeLeftDisplayed}`;
    return currentTimeFormatted;
  };

  startPingingRemote = async (shouldBeLogging: boolean) => {
    if (shouldBeLogging) {
      const dataToAppend =
        "year, month, day, hours, minutes, seconds, host, blockHeight";
      execSync(`rm ${LOG_FILE_PATH}`);
      execSync(`echo ${dataToAppend} >> ${LOG_FILE_PATH}`);
    }
    while (shouldBeLogging) {
      // ping the block heights a bit to figure out how quickly they are being created
      await Promise.all([
        this.startPinging(this.remoteHost, this.remoteBlockHeights),
        this.startPinging("localhost", this.localBlockHeights),
      ]);

      // lets give an update to user
      this.latestLogEntry = this.estimateDuration();
      this.localBlockHeights = [];
      this.remoteBlockHeights = [];
      console.clear();
      console.log(
        `querying time to sync...${".".repeat(MEASUREMENT_SECONDS - 1)}`
      );
      console.log(this.latestLogEntry);
    }

    const formattedOutput = this.estimateDuration();
    console.log(formattedOutput);
  };
}
