import fetch from "node-fetch";
import { sleep } from "../utils";

const MEASUREMENT_SECONDS = 30;
const LITTLE_TIME_THRESHOLD_SECONDS = 60 * 60 * 1.5;

export class EstimateSyncTime {
  remoteHost: string;
  remoteBlockHeights: number[] = [];
  localBlockHeights: number[] = [];

  constructor(remoteHost: string) {
    this.remoteHost = remoteHost;
  }

  getNamadaStatus = async (fromHost: string): Promise<number> => {
    const response = await fetch(`http://${fromHost}:26657/status`);
    const data = await response.json();
    return Promise.resolve(Number(data.result.sync_info.latest_block_height));
  };

  startPinging = async (host: string, arrayToPush: number[]) => {
    for (let index = 0; index < MEASUREMENT_SECONDS; index++) {
      const data = await this.getNamadaStatus(host);
      arrayToPush.push(data);
      await sleep(1000);
    }
  };

  startPingingRemote = async () => {
    // ping the block heights a bit to figure out how quickly they are being created
    await Promise.all([
      this.startPinging(this.remoteHost, this.remoteBlockHeights),
      this.startPinging("localhost", this.localBlockHeights),
    ]);

    // then naively estimate the time to reach the remote block height
    const localBlockHeights = this.localBlockHeights;
    const remoteBlockHeights = this.remoteBlockHeights;

    const localBlocksPer30Sec =
      localBlockHeights[localBlockHeights.length - 1] - localBlockHeights[0];
    const localBlocksPerSecond = localBlocksPer30Sec / MEASUREMENT_SECONDS;
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

    const currentTime = new Date();
    const currentTimeFormatted = `${currentTime.getFullYear()}_${currentTime.getMonth()}_${currentTime.getDate()} ${currentTime.getHours()}:${currentTime.getMinutes()}`;
    console.log(
      `${currentTimeFormatted} - estimated time to sync local node: ${timeLeftDisplayed}`
    );
  };
}
