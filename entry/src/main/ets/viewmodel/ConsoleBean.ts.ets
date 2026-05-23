export enum LogType {
  RECEIVE = 'RECEIVE', // 蓝/绿
  SEND = 'SEND',       // 橙/黄
  ERROR = 'ERROR'      // 红
}

export interface LogMessage {
  id: number;
  time: string;
  type: LogType;
  content: string;
}