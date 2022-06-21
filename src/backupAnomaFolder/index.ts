import { execSync } from "child_process";
import { sleep } from "../utils";

export class BackupAnomaFolder {
  latestBackups: string[] = [];
  pathToAnomaRoot: string;

  constructor(pathToAnomaRoot: string | undefined) {
    this.pathToAnomaRoot = pathToAnomaRoot || "";
  }

  startBackingUp = async (frequencyInMinutes: number) => {
    while (true) {
      const currentTime = new Date();
      const currentTimeFormatted = `${currentTime.getFullYear()}_${
        currentTime.getMonth() + 1
      }_${currentTime.getDate()}_${currentTime.getHours()}_${currentTime.getMinutes()}`;
      const directoryName = `${this.pathToAnomaRoot}/.anoma_${currentTimeFormatted}`;
      try {
        execSync(`cp -r ${this.pathToAnomaRoot}/.anoma ${directoryName}`);
        this.latestBackups.push(directoryName);

        if (this.latestBackups.length > 4) {
          execSync(`rm -r ${this.latestBackups[0]}`);
          const _ = this.latestBackups.shift();
        }
      } catch (error) {
        console.log(error);
        process.exit(1);
      }
      console.log(this.latestBackups);
      await sleep(1000 * 60 * frequencyInMinutes);
    }
  };
}
