import { BusinessError } from '@kit.BasicServicesKit';
import { socket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

// MQTT 常量
const MAX_MQTT_CLIENTID_LENGTH = 22;
const MQTT_CLIENT_ID = 'SmartShed_Pad';

// MQTT 主题（已经全面对齐你的 Rayawa/ 前缀暗号！）
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

  // 🌟【修复点 1】：默认改为 true。公网免费测试服务器强制要求 CleanSession，否则会被 EMQX 防火墙秒切断
  private cleanStart: boolean = true;

  private tcpSocket: socket.TCPSocket | null = null;
  private connected: boolean = false;
  private callback: MqttCallback | null = null;
  private reconnectTimer: number | null = null;

  // 🌟【修复点 2】：在这里直接初始化默认要订阅的主题！确保一连上就能自动去“邮局”订阅
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

  /**
   * 使用标准 @kit.NetworkKit.socket 连接至 MQTT Broker
   */
  public connectToBroker(): void {
    if (this.tcpSocket) {
      this.disconnectInternal();
    }

    const socketInstance = socket.constructTCPSocketInstance();
    this.tcpSocket = socketInstance;

    // 匿名对象解构，彻底免除 SDK 导出的 OnMessageInfo / SocketMessageInfo 命名冲突大坑
    socketInstance.on('message', (msgInfo: { message: ArrayBuffer }) => {
      if (msgInfo && msgInfo.message) {
        this.handleMqttMessage(msgInfo.message);
      }
    });

    socketInstance.on('error', (err: BusinessError) => {
      console.error(`[MQTT] Socket error: ${JSON.stringify(err)}`);
      this.connected = false;
      this.scheduleReconnect();
    });

    socketInstance.on('close', () => {
      console.info('[MQTT] Socket closed');
      this.connected = false;
      this.scheduleReconnect();
    });

    const connectOptions: socket.TCPConnectOptions = {
      address: {
        address: this.brokerHost,
        port: this.brokerPort,
        family: 1
      },
      timeout: 5000
    };

    socketInstance.connect(connectOptions).then(() => {
      console.info('[MQTT] TCP connected successfully');
      // 注意：此时还不能设置 this.connected = true，必须等待 MQTT 底层的 CONNACK 报文确认！
      this.sendConnectPacket();
    }).catch((err: BusinessError) => {
      console.error(`[MQTT] Connect failed: ${JSON.stringify(err)}`);
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
    this.sendPacket(packet);
  }

  public subscribeToTopic(topics: string[]): void {
    this.subscribeTopics = topics;
    if (!this.connected || !this.tcpSocket) {
      console.warn('[MQTT] Not connected yet, subscribe configuration saved.');
      return;
    }

    let payload: number[] = [];
    const packetId = [0x00, 0x01]; // 简易实现，固定 Packet ID

    for (const topic of topics) {
      const topicBytes = this.stringToUtf8Bytes(topic);
      const topicLen = this.intToTwoBytes(topicBytes.length);
      payload = [...payload, ...topicLen, ...topicBytes, 0x00]; // QoS 0
    }

    const packet = this.buildMqttPacket(0x82, [...packetId, ...payload]);
    this.sendPacket(packet);
  }

  public publish(topic: string, msg: string): void {
    if (!this.connected || !this.tcpSocket) {
      console.warn('[MQTT] Not connected, cannot publish');
      return;
    }

    const topicBytes = this.stringToUtf8Bytes(topic);
    const topicLen = this.intToTwoBytes(topicBytes.length);
    const msgBytes = this.stringToUtf8Bytes(msg);

    const payload = [...topicLen, ...topicBytes, ...msgBytes];
    const packet = this.buildMqttPacket(0x30, payload); // QoS 0 PUBLISH
    this.sendPacket(packet);
  }

  public unsubscribe(topics: string[]): void {
    if (!this.connected || !this.tcpSocket) {
      return;
    }

    let payload: number[] = [];
    const packetId = [0x00, 0x02];

    for (const topic of topics) {
      const topicBytes = this.stringToUtf8Bytes(topic);
      const topicLen = this.intToTwoBytes(topicBytes.length);
      payload = [...payload, ...topicLen, ...topicBytes];
    }

    const packet = this.buildMqttPacket(0xA2, [...packetId, ...payload]);
    this.sendPacket(packet);
  }

  public disconnect(): void {
    if (this.reconnectTimer !== null) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
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
        console.error(`[MQTT] Error closing socket: ${JSON.stringify(e)}`);
      }
      this.tcpSocket = null;
    }
    this.connected = false;
  }

  private sendDisconnectPacket(): void {
    const packet = this.buildMqttPacket(0xE0, []);
    this.sendPacket(packet);
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimer !== null) {
      return;
    }
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      console.info('[MQTT] Attempting reconnect...');
      this.connectToBroker();
    }, 5000);
  }

  private handleMqttMessage(data: ArrayBuffer): void {
    const bytes = new Uint8Array(data);
    if (bytes.length < 2) return;

    const packetType = bytes[0] & 0xF0;

    let pos = 1;
    let multiplier = 1;
    let remainingLength = 0;
    while (pos < bytes.length) {
      const digit = bytes[pos++];
      remainingLength += (digit & 0x7F) * multiplier;
      multiplier *= 128;
      if ((digit & 0x80) === 0) break;
    }

    if (packetType === 0x30) {
      this.handlePublish(bytes, pos);
    } else if (packetType === 0x20) {
      // 🌟【逻辑完善点】：只有当收到服务端的 0x20 (CONNACK) 响应，且返回状态码为 0 时，才代表 MQTT 真正连接成功
      const connectReturnCode = bytes[pos + 1];
      if (connectReturnCode === 0x00) {
        console.info('[MQTT] Protocol Handshake Connected Successfully.');
        this.connected = true;
        if (this.subscribeTopics.length > 0 && this.callback) {
          // 此时真正触发向服务器发起订阅
          this.subscribeToTopic(this.subscribeTopics);
        }
      } else {
        console.error(`[MQTT] CONNACK rejected with code: ${connectReturnCode}`);
        this.disconnectInternal();
        this.scheduleReconnect();
      }
    } else if (packetType === 0x90) {
      console.info('[MQTT] SUBACK received from server.');
    }
  }

  private handlePublish(bytes: Uint8Array, startPos: number): void {
    let pos = startPos;
    const topicLen = (bytes[pos] << 8) | bytes[pos + 1];
    pos += 2;

    const topic = this.utf8BytesToString(bytes.slice(pos, pos + topicLen));
    pos += topicLen;

    // 完善：精确定位 Payload 字节区间
    const payload = this.utf8BytesToString(bytes.slice(pos));
    console.info(`[MQTT] Received - topic: ${topic}, payload: ${payload}`);

    if (this.callback) {
      this.callback(topic, payload);
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
      if (length > 0) {
        digit |= 0x80;
      }
      bytes.push(digit);
    } while (length > 0);
    return new Uint8Array(bytes);
  }

  private sendPacket(buffer: ArrayBuffer): void {
    if (!this.tcpSocket) return;
    try {
      this.tcpSocket.send({
        data: buffer
      });
    } catch (e) {
      console.error(`[MQTT] Send failed: ${JSON.stringify(e)}`);
    }
  }

  private stringToUtf8Bytes(str: string): number[] {
    const uint8 = this.textEncoder.encodeInto(str);
    return Array.from(uint8);
  }

  private utf8BytesToString(bytes: Uint8Array): string {
    return this.textDecoder.decode(bytes);
  }

  private intToTwoBytes(value: number): number[] {
    return [(value >> 8) & 0xFF, value & 0xFF];
  }
}