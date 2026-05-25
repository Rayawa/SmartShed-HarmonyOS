/**
 * 智慧农业大棚 - 数据模型
 */
export class SmartShedBean {
  zone: number = 0;
  isAuto: boolean = false;

  moistureMin: number = 0;
  moisture: number = 0;
  moistureMax: number = 0;

  intensityMin: number = 0;
  intensity: number = 0;
  intensityMax: number = 0;

  tempMin: number = 0;
  temp: number = 0;
  tempMax: number = 0;

  humMin: number = 0;
  hum: number = 0;
  humMax: number = 0;

  fanLevel: number = 0;
  waterPumpLevel: number = 0;
  ledLevel: number = 0;

  constructor() {}
}

export class ZoneData {
  bean: SmartShedBean = new SmartShedBean();
  fanValue: number = 0;
  waterPumpValue: number = 0;
  ledValue: number = 0;
  autoEnabled: boolean = false;

  autoTempMin: string = '15';
  autoTempMax: string = '30';
  autoHumMin: string = '30';
  autoHumMax: string = '80';
  autoIntensityMin: string = '200';
  autoIntensityMax: string = '1100';
  autoMoistureMin: string = '40';
  autoMoistureMax: string = '75';

  autoManagerThread: number | null = null;
  isExit: boolean = false;

  assignFrom(other: ZoneData): ZoneData {
    this.bean.temp = other.bean.temp;
    this.bean.hum = other.bean.hum;
    this.bean.intensity = other.bean.intensity;
    this.bean.moisture = other.bean.moisture;

    this.fanValue = other.fanValue;
    this.waterPumpValue = other.waterPumpValue;
    this.ledValue = other.ledValue;
    this.autoEnabled = other.autoEnabled;

    this.autoTempMax = other.autoTempMax;
    this.autoTempMin = other.autoTempMin;
    this.autoHumMax = other.autoHumMax;
    this.autoHumMin = other.autoHumMin;
    this.autoMoistureMax = other.autoMoistureMax;
    this.autoMoistureMin = other.autoMoistureMin;
    this.autoIntensityMax = other.autoIntensityMax;
    this.autoIntensityMin = other.autoIntensityMin;

    this.autoManagerThread = other.autoManagerThread;
    this.isExit = other.isExit;

    return this;
  }
}

export interface SensorData {
  intensity?: number;
  moisture?: number;
  temp?: number;
  hum?: number;
}