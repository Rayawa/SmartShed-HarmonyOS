// service/MqttReceiverClient.ts
import { BusinessError } from '@kit.BasicServicesKit';
import { socket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

export enum LogType { RECEIVE, SEND, ERROR }

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

  private subscribeTopics: string[] = TOPICS_ALL;
  private textEncoder = new util.TextEncoder();
  private textDecoder = util.TextDecoder.create('utf-8');

  constructor(callback: MqttCallback) {
    this.callback = callback;
    this.mqttClientId = this.generateClientId();
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
      console.error(`[MQTT] Socket 错误: ${JSON.stringify(err)}`);
      this.updateConnectionState(false);
      this.scheduleReconnect();
    });

    socketInstance.on('close', () => {
      console.info('[MQTT] Socket 连接关闭');
      this.updateConnectionState(false);
      this.scheduleReconnect();
    });

    const connectOptions: socket.TCPConnectOptions = {
      address: { address: this.brokerHost, port: this.brokerPort },
      timeout: 5000
    };

    socketInstance.connect(connectOptions).then(() => {
      console.info('[MQTT] TCP 物理链路成功，发送握手报文...');
      this.sendConnectPacket();
    }).catch((err: BusinessError) => {
      console.error(`[MQTT] TCP 连接失败: ${JSON.stringify(err)}`);
      this.updateConnectionState(false);
      this.scheduleReconnect();
    });
  }

  private sendConnectPacket(): void {
    const protocolName = [0x00, 0x04, 0x4D, 0x51, 0x54, 0x54];
    const protocolLevel = 0x04;
    const connectFlags = this.cleanStart ? 0x02 : 0x00;
    const keepAlive = this.intToTwoBytes(this.keepAliveSeconds);

    const clientIdBytes = this.stringToUtf8Bytes(this.mqttClientId);
    const clientIdLen = this.intToTwoBytes(clientIdBytes.length);

    const variableHeader = [...protocolName, protocolLevel, connectFlags, ...keepAlive];
    const payload = [...clientIdLen, ...clientIdBytes];

    const packet = this.buildMqttPacket(0x10, [...variableHeader, ...payload]);
    this.sendPacket(packet);
  }

  public subscribeToTopic(topics: string[]): void {
    this.subscribeTopics = topics;
    if (!this.connected || !this.tcpSocket) return;

    let payload: number[] = [];
    const packetId = [0x00, 0x01];

    for (const topic of topics) {
      const topicBytes = this.stringToUtf8Bytes(topic);
      const topicLen = this.intToTwoBytes(topicBytes.length);
      payload = [...payload, ...topicLen, ...topicBytes, 0x00]; // QoS 0
    }

    const packet = this.buildMqttPacket(0x82, [...packetId, ...payload]);
    this.sendPacket(packet);
    console.info(`[MQTT] 订阅下发: ${JSON.stringify(topics)}`);
  }

  private logCallback: ((type: LogType, content: string) => void) | null = null;

  public setLogCallback(cb: (type: LogType, content: string) => void) {
    this.logCallback = cb;
  }

  public publish(topic: string, msg: string): void {
    if (!this.connected || !this.tcpSocket) {
      this.logCallback?.(LogType.ERROR, `拒绝发送 -> ${topic}:${msg}`); // 记录错误
      return;
    }

    const topicBytes = this.stringToUtf8Bytes(topic);
    const topicLen = this.intToTwoBytes(topicBytes.length);
    const msgBytes = this.stringToUtf8Bytes(msg);

    const payload = [...topicLen, ...topicBytes, ...msgBytes];
    const packet = this.buildMqttPacket(0x30, payload);
    this.sendPacket(packet);
    this.logCallback?.(LogType.SEND, `${topic}: ${msg}`); // 记录发送
  }

  private startHeartbeat(): void {
    if (this.heartbeatTimer !== null) clearInterval(this.heartbeatTimer);
    this.heartbeatTimer = setInterval(() => {
      if (this.connected) {
        const pingPacket = this.buildMqttPacket(0xC0, []);
        this.sendPacket(pingPacket);
      }
    }, this.keepAliveSeconds * 1000 * 0.75);
  }

  public disconnect(): void {
    if (this.reconnectTimer !== null) { clearTimeout(this.reconnectTimer); this.reconnectTimer = null; }
    if (this.heartbeatTimer !== null) { clearInterval(this.heartbeatTimer); this.heartbeatTimer = null; }
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
        console.error(`[MQTT] 关闭异常: ${JSON.stringify(e)}`);
      }
      this.tcpSocket = null;
    }
    this.updateConnectionState(false);
  }

  private sendDisconnectPacket(): void {
    const packet = this.buildMqttPacket(0xE0, []);
    this.sendPacket(packet);
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimer !== null) return;
    if (this.heartbeatTimer !== null) { clearInterval(this.heartbeatTimer); this.heartbeatTimer = null; }

    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      console.info('[MQTT] 触发自动重连...');
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
          console.info('[MQTT] 应用层连接成功！');
          this.updateConnectionState(true);
          this.startHeartbeat();
          if (this.subscribeTopics.length > 0 && this.callback) {
            this.subscribeToTopic(this.subscribeTopics);
          }
        } else {
          this.updateConnectionState(false);
          this.disconnectInternal();
          this.scheduleReconnect();
          return;
        }
      } else if (packetType === 0xD0) {
        console.info('[MQTT] 收到心跳响应 PINGRESP');
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

    this.logCallback?.(LogType.RECEIVE, `${topic}: ${payload}`); // 记录接收

    if (this.callback) this.callback(topic, payload);
  }

  // 同步通知到全局 AppStorage，驱动 UI 改变
  private updateConnectionState(state: boolean): void {
    this.connected = state;
    AppStorage.setOrCreate('isBoardConnected', state);
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
    try { this.tcpSocket.send({ data: buffer }); } catch (e) { }
  }

  private stringToUtf8Bytes(str: string): number[] { return Array.from(this.textEncoder.encodeInto(str)); }
  private utf8BytesToString(bytes: Uint8Array): string { return this.textDecoder.decode(bytes); }
  private intToTwoBytes(value: number): number[] { return [(value >> 8) & 0xFF, value & 0xFF]; }
}