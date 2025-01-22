[[en]](Introduction_to_the_EspBlufi_API_Interface_for_HarmonyOS__en.md)

# EspBlufi for HarmonyOS API 接口说明

------

为了方便用户进行 Blufi 的二次开发，我司针对 EspBlufi for HarmonyOS 提供了一些 API 接口。本文档将对这些接口进行简要介绍。

## 使用 BlufiClient 与 Device 发起通信

- 实例化 BlufiClient

  ```typescript
  const client = newBlufiClient(scanResult);

  // BlufiCallback 为抽象类，回调 Device 通信过程中的数据，实现您自己的需求
  const blufiCallback;
  client.setBlufiCallback(blufiCallback);
  ```

- 设置 Blufi 发送数据时每包数据的最大长度

  ```typescript
  const limit = 260; // 设置长度限制，若数据超出限制将进行分包发送
  client.setPostPackageLengthLimit(limit)
  ```

- 与 Device 建立连接

  ```typescript
  // 若 client 与设备建立连接，client 将主动扫描 Blufi 的服务和特征
  // 用户在收到 BlufiCallback 回调 onGattPrepared 后才可以与设备发起通信
  client.connect();
  ```

- 与 Device 协商数据加密

  ```typescript
  client.negotiateSecurity();
  ```

  ```typescript
  // 协商结果在 BlufiCallback 回调方法内通知
  public onNegotiateSecurityResult(client: BlufiClient, status: number) {
    // status 为 0 表示加密成功，否则为失败
  }
  ```

- 请求获取 Device 版本

  ```typescript
  client.requestDeviceVersion();
  ```

  ```typescript
  // 设备版本在 BlufiCallback 回调方法内通知
  public onDeviceVersionResponse(client: BlufiClient, status: number, response?: BlufiVersionResponse) {
      // status 为 0 表示加密成功，否则为失败
  
      switch (status) {
          case BlufiCode.STATUS_SUCCESS:
              const version = response!.getVersionString(); // 获得版本号
              break;
          default:
              break;
      }
  }
  ```

- 请求获取 Device 当前扫描到的 Wi-Fi 信号

  ```typescript
  client.requestDeviceWifiScan();
  ```

  ```typescript
  // 扫描结果在 BlufiCallback 回调方法内通知
  public onDeviceScanResult(client: BlufiClient, status: number, results?: BlufiScanResult[]) {
      // status 为 0 表示获取数据成功，否则为失败
      
      switch (status) {
          case BlufiCode.STATUS_SUCCESS:
              for (let scanResult : results) {
                  const ssid = scanResult.ssid; // 获得 Wi-Fi SSID
                  const rssi = scanResult.rssi; // 获得 Wi-Fi RSSI
              }
              break;
          default:
              break;
      }
  }
  ```

- 发送自定义数据

  ```typescript
  const data = new Uint8Array([1, 2, 3]);
  client.postCustomData(data);
  ```

  ```typescript
  // 自定义数据发送结果在 BlufiCallback 回调方法内通知
  public onPostCustomDataResult(client: BlufiClient, status: number, data?: Uint8Array) {
      // status 为 0 表示发送成功，否则为发送失败
  
      // data 为需要发送的自定义数据
  }
  
  // 收到 Device 端发送的自定义数据
  public onReceiveCustomData(client: BlufiClient, status: number, data?: Uint8Array) {
      // status 为 0 表示成功接收
      // data 为收到的数据
  }
  ```

- 请求获取 Device 当前状态

  ```typescript
  client.requestDeviceStatus();
  ```

  ```typescript
  // Device 状态在 BlufiCallback 回调方法内通知
  public onDeviceStatusResponse(client: BlufiClient, status: number, response?: BlufiStatusResponse) {
      // status 为 0 表示获取状态成功，否则为失败
  
      switch (status) {
          case BlufiCode.STATUS_SUCCESS:
              const opMode = response!.opMode;
              if (opMode == OpMode.MODE_STA) {
                  // 当前为 Station 模式
                  const conn = response.staConnectionStatus; // 获取 Device 当前连接状态：0 表示有 Wi-Fi 连接，否则没有 Wi-Fi 连接
                  const ssid = response.staSSID; // 获取 Device 当前连接的 Wi-Fi 的 SSID
                  const bssid = response.staBSSID; // 获取 Device 当前连接的 Wi-Fi 的 BSSID
                  const password = response.staPassword; // 获取 Device 当前连接的 Wi-Fi 密码
              } else if (opMode == OpMode.MODE_SOFTAP) {
                  // 当前为 SoftAP 模式
                  const ssid = response.softApSSID; // 获取 Device 的 SSID
                  const channel = response.softApChannel; // 获取 Device 的信道
                  const security = response.softApSecurity; // 获取 Device 的加密方式：0 为不加密，2 为 WPA，3 为 WPA2，4 为 WPA/WPA2
                  const connMaxCount = response.softApMaxConnectionCount; // 最多可连接的 Device 个数
                  const connCount = response.softApConnectionCount; // 当前已连接 的 Device 个数
              } else if (opMode == OpMode.MODE_STASOFTAP) {
                  // 当前为 Station 和 SoftAP 共存模式
                  // 获取状态方法同 Station 模式和 SoftAP 模式
              }
              break;
          default:
              break;
      }
  }
  ```

- 对 Device 进行配网

  ```typescript
  const params = new BlufiConfigureParams();
  const opMode = // 设置需要配置的模式：1 为 Station 模式，2 为 SoftAP 模式，3 为 Station 和 SoftAP 共存模式
  params.setOpMode(deviceMode);
  if (opMode == OpMode.MODE_STA) {
      // 设置 Station 配置信息
      params.staSSID = ssid; // 设置 Wi-Fi SSID
      params.staPassword = password; // 设置 Wi-Fi 密码，若是开放 Wi-Fi 则不设或设空
      // 注意：Device 若是不支持连接 5G Wi-Fi，建议提前检查一下是不是 5G Wi-Fi
  } else if (opMode == OpMode.MODE_SOFTAP) {
      // 设置 SoftAP 配置信息
      params.softAPSSID = ssid; // 设置 Device 的 SSID
      params.softAPSecurity = security; // 设置 Device 的加密方式：0 为不加密，2 为 WPA，3 为 WPA2，4 为 WPA/WPA2
      params.softAPPassword = password; // 若 Security 非 0 则必须设置 
      params.softAPChannel = channel; // 设置 Device 的信道, 可不设
      params.softAPMaxConnection = maxConnection; // 设置可连接 Device 的最大个数
  
  } else if (opMode == OpMode.MODE_STASOFTAP) {
      // 同上两个
  }
  
  client.configure(params);
  ```

  ```typescript
  // 设置信息发送结果在 BlufiCallback 回调方法内通知
  public onPostConfigureParams(client: BlufiClient, status: number) {
      // Status 为 0 表示发送配置信息成功，否则为失败
  }
  
  // 配置后的状态变化回调
  public onDeviceStatusResponse(client: BlufiClient, status: number, response?: BlufiStatusResponse) {
      // 同上方请求获取设备当前状态
  }
  ```

- 请求 Device 断开 BLE 连接

  ```typescript
  // 有时 Device 端无法获知 app 端已主动断开连接, 此时会导致 app 后续无法重新连上设备
  client.requestCloseConnection();
  ```

- 关闭 BlufiClient Close BlufiClient

  ```typescript
  // 释放资源
  client.close();
  ```

## BlufiCallback 说明

```typescript
// 当 Gatt 准备工作完成后调用该方法
public onGattPrepared(client: BlufiClient, status: number) {
}

// 收到 Device 的通知数据
// 返回 false 表示处理尚未结束，交给 BlufiClient 继续后续处理
// 返回 true 表示处理结束，后续将不再解析该数据，也不会调用回调方法
public onCharacteristicChange(characteristic: ble.BLECharacteristic): boolean {
	return false;
}

// 收到 Device 发出的错误代码
public onError(client: BlufiClient, errorCode: number) {
}

// 与 Device 协商加密的结果
public onNegotiateSecurityResult(client: BlufiClient, status: number) {
}

// 发送配置信息的结果
public onPostConfigureParams(client: BlufiClient, status: number) {
}

// 收到 Device 的版本信息
public onDeviceVersionResponse(client: BlufiClient, status: number, response?: BlufiVersionResponse) {
}

// 收到 Device 的状态信息
public onDeviceStatusResponse(client: BlufiClient, status: number, response?: BlufiStatusResponse) {
}

// 收到 Device 扫描到的 Wi-Fi 信息
public onDeviceScanResult(client: BlufiClient, status: number, results?: BlufiScanResult[]) {
}

// 发送自定义数据的结果
public onPostCustomDataResult(client: BlufiClient, status: number, data?: Uint8Array) {
}

// 收到 Device 的自定义信息
public onReceiveCustomData(client: BlufiClient, status: number, data?: Uint8Array) {
}
```
