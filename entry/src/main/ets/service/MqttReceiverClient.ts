// service/MqttReceiverClient.ts
import { BusinessError } from '@kit.BasicServicesKit';
import { socket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

import { LogType } from '../viewmodel/ConsoleBean';

const MAX_MQTT_CLIENTID_LENGTH = 22;
const MQTT_CLIENT_ID = 'SmartShed_Pad';

export const TOPICS_ALL: string[] = ['Rayawa/light_intensity_1', 'Rayawa/soil_moisture_1', 'Rayawa/temp_and_hum_1'];
export const TOPIC_FAN = 'Rayawa/fan_1';
export const TOPIC_LED = 'Rayawa/led_1';
export const TOPIC_WATER_PUMP = 'Rayawa/water_pump_1';

type MqttCallback = (topic: string, payload: string) => void;

export class MqttReceiverClient {
  private mqttClientId: string = '';
  private brokerHost: string = 'broker.emqx.io';
  private brokerPort: number = 1883;
  private keepAliveSeconds: number = 20;
  private cleanStart: boolean = true;

  private tcpSocket: socket.TCPSocket | null = null;
  private connected: boolean = false;
  private callback: MqttCallback | null = null;

  private reconnectTimer: number | null = null;
  private heartbeatTimer: number | null = null;
  private boardOfflineCheckTimer: number | null = null;

  private pingOutstanding: boolean = false;
  private lastDataReceivedTime: number = 0;
  private readonly BOARD_TIMEOUT_MS = 5000;

  private subscribeTopics: string[] = TOPICS_ALL;
  private textEncoder = new util.TextEncoder();
  private textDecoder = util.TextDecoder.create('utf-8');
  private logCallback: ((type: LogType, content: string) => void) | null = null;

  constructor(callback: MqttCallback) {
    this.callback = callback;
    this.mqttClientId = this.generateClientId();
  }

  public setLogCallback(cb: (type: LogType, content: string) => void) {
    this.logCallback = cb;
  }

  private printLog(type: LogType, message: string): void {
    const now = new Date();
    const timeStr = `${now.toLocaleTimeString()}.${String(now.getMilliseconds()).padStart(3, '0')}`;
    const logHeader = `[${timeStr}] [MQTT_${type}]`;

    this.logCallback?.(type, message);

    if (type === LogType.ERROR) {
      console.error(`${logHeader} ${message}`);
    } else {
      console.info(`${logHeader} ${message}`);
    }
  }

  private generateClientId(): string {
    const timestamp = '' + Date.now();
    let clientId = MQTT_CLIENT_ID + timestamp;
    if (clientId.length > MAX_MQTT_CLIENTID_LENGTH) {
      clientId = clientId.substring(0, MAX_MQTT_CLIENTID_LENGTH);
    }
    return clientId;
  }

  public onStart(): void {
    this.printLog(LogType.INFO, `发起连接流程 -> 目标服务器: ${this.brokerHost}:${this.brokerPort}`);
    this.connectToBroker();
  }

  public connectToBroker(): void {
    if (this.tcpSocket) {
      this.disconnectInternal();
    }

    const socketInstance = socket.constructTCPSocketInstance();
    this.tcpSocket = socketInstance;

    socketInstance.on('message', (msgInfo: { message: ArrayBuffer }) => {
      if (msgInfo && msgInfo.message) {
        this.handleMqttMessage(msgInfo.message);
      }
    });

    socketInstance.on('error', (err: BusinessError) => {
      this.printLog(LogType.ERROR, `Socket 异常报错: ${err.message || JSON.stringify(err)}`);
      this.updateConnectionState(false);
      this.scheduleReconnect();
    });

    socketInstance.on('close', () => {
      this.printLog(LogType.INFO, `TCP 物理链路层断开引发 Socket 关闭通知`);
      this.updateConnectionState(false);
      this.scheduleReconnect();
    });

    const connectOptions: socket.TCPConnectOptions = {
      address: { address: this.brokerHost, port: this.brokerPort },
      timeout: 5000
    };

    socketInstance.connect(connectOptions).then(() => {
      this.printLog(LogType.INFO, `TCP 物理通道握手成功，开始构建并投递 MQTT CONNECT 报文...`);
      this.sendConnectPacket();
    }).catch((err: BusinessError) => {
      this.printLog(LogType.ERROR, `TCP 物理层连接失败: ${err.message || JSON.stringify(err)}`);
      this.updateConnectionState(false);
      this.scheduleReconnect();
    });
  }

  private sendConnectPacket(): void {
    const protocolName = [0x00, 0x04, 0x4D, 0x51, 0x54, 0x54]; // "MQTT"
    const protocolLevel = 0x04; // MQTT 3.1.1
    const connectFlags = this.cleanStart ? 0x02 : 0x00;
    const keepAlive = this.intToTwoBytes(this.keepAliveSeconds);

    const clientIdBytes = this.stringToUtf8Bytes(this.mqttClientId);
    const clientIdLen = this.intToTwoBytes(clientIdBytes.length);

    const variableHeader = [...protocolName, protocolLevel, connectFlags, ...keepAlive];
    const payload = [...clientIdLen, ...clientIdBytes];

    const packet = this.buildMqttPacket(0x10, [...variableHeader, ...payload]);
    this.printLog(LogType.INFO, `投递 CONNECT 握手包，ClientId 长度: ${this.mqttClientId.length}`);
    this.sendPacket(packet);
  }

  public subscribeToTopic(topics: string[]): void {
    this.subscribeTopics = topics;
    if (!this.connected || !this.tcpSocket) return;

    let payload: number[] = [];
    const packetId = [0x00, 0x01]; // 简易 Packet ID

    for (const topic of topics) {
      const topicBytes = this.stringToUtf8Bytes(topic);
      const topicLen = this.intToTwoBytes(topicBytes.length);
      payload = [...payload, ...topicLen, ...topicBytes, 0x00]; // QoS 0
    }

    const packet = this.buildMqttPacket(0x82, [...packetId, ...payload]);
    this.sendPacket(packet);
    this.printLog(LogType.INFO, `发送批量订阅请求 -> Topics: [${topics.join(', ')}]`);
  }

  public publish(topic: string, msg: string): void {
    if (!this.connected || !this.tcpSocket) {
      this.printLog(LogType.ERROR, `拒绝发送(Pad未连接到MQTT服务器) -> ${topic}: ${msg}`);
      return;
    }

    const topicBytes = this.stringToUtf8Bytes(topic);
    const topicLen = this.intToTwoBytes(topicBytes.length);
    const msgBytes = this.stringToUtf8Bytes(msg);

    const payload = [...topicLen, ...topicBytes, ...msgBytes];
    const packet = this.buildMqttPacket(0x30, payload);
    this.sendPacket(packet);
    this.printLog(LogType.SEND, `${topic}: ${msg}`);
  }

  private startHeartbeat(): void {
    if (this.heartbeatTimer !== null) clearInterval(this.heartbeatTimer);

    this.pingOutstanding = false;

    this.heartbeatTimer = setInterval(() => {
      if (!this.connected) return;

      if (this.pingOutstanding) {
        this.printLog(LogType.ERROR, `心跳超时检测异常：连续 ${this.keepAliveSeconds}s 没收到服务器 PINGRESP 响应，强制断开重连`);
        this.disconnectInternal();
        this.scheduleReconnect();
        return;
      }

      const pingPacket = this.buildMqttPacket(0xC0, []);
      this.pingOutstanding = true; // 挂起等待回包
      this.sendPacket(pingPacket);
      this.printLog(LogType.INFO, `发送心跳探测包 PINGREQ`);
    }, this.keepAliveSeconds * 1000 * 0.75); // 15秒发送一次
  }

  private startBoardOfflineWatcher(): void {
    if (this.boardOfflineCheckTimer !== null) {
      clearInterval(this.boardOfflineCheckTimer);
    }

    this.boardOfflineCheckTimer = setInterval(() => {
      if (!this.connected) return;

      const currentTime = Date.now();
      if (currentTime - this.lastDataReceivedTime > this.BOARD_TIMEOUT_MS) {
        const isCurrentlyOnline = AppStorage.get<boolean>('isBoardConnected');
        if (isCurrentlyOnline === true) {
          this.printLog(LogType.ERROR, `开发板连接断开！已连续 ${this.BOARD_TIMEOUT_MS / 1000} 秒未收到数据！`);
          AppStorage.setOrCreate('isBoardConnected', false);
        }
      }
    }, 2000);
  }

  public disconnect(): void {
    this.printLog(LogType.INFO, `接收到用户手动断开指令，正在执行清理销毁...`);
    if (this.reconnectTimer !== null) { clearTimeout(this.reconnectTimer); this.reconnectTimer = null; }
    if (this.heartbeatTimer !== null) { clearInterval(this.heartbeatTimer); this.heartbeatTimer = null; }
    if (this.boardOfflineCheckTimer !== null) { clearInterval(this.boardOfflineCheckTimer); this.boardOfflineCheckTimer = null; }

    this.sendDisconnectPacket();
    this.disconnectInternal();
  }

  private disconnectInternal(): void {
    if (this.tcpSocket) {
      try {
        this.tcpSocket.off('message');
        this.tcpSocket.off('error');
        this.tcpSocket.off('close');
        this.tcpSocket.close();
      } catch (e) {
        this.printLog(LogType.ERROR, `关闭底层 Socket 遭遇异常: ${JSON.stringify(e)}`);
      }
      this.tcpSocket = null;
    }
    this.updateConnectionState(false);
  }

  private sendDisconnectPacket(): void {
    const packet = this.buildMqttPacket(0xE0, []);
    this.sendPacket(packet);
    this.printLog(LogType.INFO, `已安全外发标准 MQTT DISCONNECT 断开控制报文`);
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimer !== null) return;
    if (this.heartbeatTimer !== null) { clearInterval(this.heartbeatTimer); this.heartbeatTimer = null; }
    if (this.boardOfflineCheckTimer !== null) { clearInterval(this.boardOfflineCheckTimer); this.boardOfflineCheckTimer = null; }

    this.printLog(LogType.INFO, `重连调度器已就绪：将在 5 秒后尝试自动重建网络会话通道...`);
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.printLog(LogType.INFO, `重连定时器触发，正在尝试连接...`);
      this.connectToBroker();
    }, 5000);
  }

  private handleMqttMessage(data: ArrayBuffer): void {
    const bytes = new Uint8Array(data);
    let cursor = 0;

    while (cursor + 1 < bytes.length) {
      const controlByte = bytes[cursor];
      const packetType = controlByte & 0xF0;
      let pos = cursor + 1;
      let multiplier = 1;
      let remainingLength = 0;

      while (pos < bytes.length) {
        const digit = bytes[pos++];
        remainingLength += (digit & 0x7F) * multiplier;
        multiplier *= 128;
        if ((digit & 0x80) === 0) break;
      }

      const packetEnd = pos + remainingLength;
      if (packetEnd <= cursor || packetEnd > bytes.length) {
        cursor++;
        continue;
      }

      if (packetType === 0x30) {
        this.handlePublish(bytes, pos, packetEnd);
      } else if (packetType === 0x20) {
        const connectReturnCode = bytes[pos + 1];
        if (connectReturnCode === 0x00) {
          this.printLog(LogType.INFO, `应用层握手大成功！已成功握手 MQTT 代理服务器。分配 ClientId: ${this.mqttClientId}`);

          this.updateConnectionState(true);
          this.startHeartbeat();

          this.lastDataReceivedTime = Date.now();
          this.startBoardOfflineWatcher();

          if (this.subscribeTopics.length > 0 && this.callback) {
            this.subscribeToTopic(this.subscribeTopics);
          }
        } else {
          this.printLog(LogType.ERROR, `MQTT 应用层拒绝连接，服务器返回码: ${connectReturnCode}`);
          this.updateConnectionState(false);
          this.disconnectInternal();
          this.scheduleReconnect();
          return;
        }
      } else if (packetType === 0xD0) {
        this.printLog(LogType.INFO, `成功接收服务器心跳响应 PINGRESP`);
        this.pingOutstanding = false;
      } else if (packetType === 0x90) {
        this.printLog(LogType.INFO, `收到服务器订阅确认通知 SUBACK`);
      }

      cursor = packetEnd;
    }
  }

  private handlePublish(bytes: Uint8Array, startPos: number, endPos: number): void {
    let pos = startPos;
    if (pos + 2 > endPos) return;

    const topicLen = (bytes[pos] << 8) | bytes[pos + 1];
    pos += 2;

    if (pos + topicLen > endPos) return;
    const topic = this.utf8BytesToString(bytes.slice(pos, pos + topicLen));
    const payload = this.utf8BytesToString(bytes.slice(pos + topicLen, endPos));

    this.printLog(LogType.RECEIVE, `${topic}: ${payload}`);

    if (topic.startsWith('Rayawa/')) {
      this.lastDataReceivedTime = Date.now();

      const isCurrentlyOnline = AppStorage.get<boolean>('isBoardConnected');
      if (isCurrentlyOnline === false && this.connected) {
        AppStorage.setOrCreate('isBoardConnected', true);
        this.printLog(LogType.INFO, `===开发板已连接！==============`);
      }
    }

    if (this.callback) this.callback(topic, payload);
  }

  private updateConnectionState(state: boolean): void {
    this.connected = state;
    if (!state) {
      AppStorage.setOrCreate('isBoardConnected', false);
    }
  }

  private buildMqttPacket(controlByte: number, remaining: number[]): ArrayBuffer {
    const length = this.encodeRemainingLength(remaining.length);
    const buffer = new Uint8Array(1 + length.length + remaining.length);
    buffer[0] = controlByte;
    buffer.set(length, 1);
    buffer.set(remaining, 1 + length.length);
    return buffer.buffer;
  }

  private encodeRemainingLength(length: number): Uint8Array {
    const bytes: number[] = [];
    do {
      let digit = length % 128;
      length = Math.floor(length / 128);
      if (length > 0) digit |= 0x80;
      bytes.push(digit);
    } while (length > 0);
    return new Uint8Array(bytes);
  }

  private sendPacket(buffer: ArrayBuffer): void {
    if (!this.tcpSocket) return;
    try {
      this.tcpSocket.send({ data: buffer });
    } catch (e) {
      this.printLog(LogType.ERROR, `底层物理 Socket 发包出现异常中断: ${JSON.stringify(e)}`);
    }
  }

  private stringToUtf8Bytes(str: string): number[] { return Array.from(this.textEncoder.encodeInto(str)); }
  private utf8BytesToString(bytes: Uint8Array): string { return this.textDecoder.decode(bytes); }
  private intToTwoBytes(value: number): number[] { return [(value >> 8) & 0xFF, value & 0xFF]; }
}

export { LogType };