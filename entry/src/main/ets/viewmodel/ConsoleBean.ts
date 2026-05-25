export enum LogType {
  RECEIVE = 'RECEIVE',
  SEND = 'SEND',
  INFO = 'INFO',
  ERROR = 'ERROR'
}

export interface LogMessage {
  id: number;
  time: string;
  type: LogType;
  content: string;
}