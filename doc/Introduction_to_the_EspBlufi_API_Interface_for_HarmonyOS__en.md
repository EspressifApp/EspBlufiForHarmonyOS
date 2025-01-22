[[cn]](Introduction_to_the_EspBlufi_API_Interface_for_HarmonyOS__cn.md)

# Introduction to the EspBlufi API Interface for HarmonyOS
------
This guide is a basic introduction to the APIs provided by Espressif to facilitate the customers' secondary development of BluFi.

## Communicate with the device using BlufiClient

- Create a BlufiClient instance

    ```typescript
    const client = newBlufiClient(scanResult);

    // BlufiCallback is declared as an abstract class, which can be used to notify the app of the data sent by the device.
    const blufiCallback;
    client.setBlufiCallback(blufiCallback);
    ```

- Configure the maximum length of each data packet

    ```typescript
    const limit = 260; // Configure the maximum length of each post packet. If the length of a post packet exceeds the maximum packet length, the post packet will be split into fragments.
    client.setPostPackageLengthLimit(limit);
    ```

- Establish a BLE connection

  ```typescript
  // If establish connection successfully，client will discover service and characteristic for Blufi
  // client can communicate with Device after receive callback function 'onGattPrepared' in BlufiCallback
  client.connect();
  ```

- Negotiate data security with the device

    ```typescript
    client.negotiateSecurity();
    ```

    ```typescript
    // The result of negotiation will be sent back by the BlufiCallback function
    public onNegotiateSecurityResult(client: BlufiClient, status: number) {
        // status is the result of negotiation: "0" - successful, otherwise - failed.
    }
    ```

- Request Device Version

    ```typescript
    client.requestDeviceVersion();
    ```
    ```typescript
    // The device version is notified in the BlufiCallback function
    public onDeviceVersionResponse(client: BlufiClient, status: number, response?: BlufiVersionResponse) {
        // status is the result of encryption: "0" - successful, otherwise - failed.

        switch (status) {
          case BlufiCode.STATUS_SUCCESS:
              const version = response!.getVersionString(); // Get the version number
              break;
          default:
              break;
        }
    }
    ```

- Request the device's current Wi-Fi scan result

    ```typescript
    client.requestDeviceWifiScan();
    ```

    ```typescript
    // The scan result is notified in the BlufiCallback function
    public onDeviceScanResult(client: BlufiClient, status: number, results?: BlufiScanResult[]) {
        // status is the result: "0" - successful, otherwise - failed.
        
        switch (status) {
          case BlufiCode.STATUS_SUCCESS:
              for (let scanResult : results) {
                  const ssid = scanResult.ssid; // Obtain Wi-Fi SSID
                  const rssi = scanResult.rssi; // Obtain Wi-Fi RSSI
              }
              break;
          default:
              break;
        }
    }
    ```

- Send custom data

    ```typescript
    const data = new Uint8Array([1, 2, 3]);
    client.postCustomData(data);
    ```

    ```typescript
    // The result of sending customer data is notified in the BlufiCallback function
    public onPostCustomDataResult(client: BlufiClient, status: number, data?: Uint8Array) {
        // status is the result: "0" - successful, otherwise - failed.

        // data is the custom data to be sent
    }

    // Receive customer data sent by the device
    public onReceiveCustomData(client: BlufiClient, status: number, data?: Uint8Array) {
        // status is the result: "0" - successful, otherwise - failed.
        // data is the custom data received
    }
    ```

- Request the current status of the device

    ```typescript
    client.requestDeviceStatus();
    ```

    ```typescript
    // The device status is notified in the BlufiCallback function.
    public onDeviceStatusResponse(client: BlufiClient, status: number, response?: BlufiStatusResponse) {
        // status is the result: "0" - successful, otherwise - failed.

        switch (status) {
            case BlufiCode.STATUS_SUCCESS:
                const opMode = response!.opMode;
                if (opMode == OpMode.MODE_STA) {
                    // Station mode is currently enabled.
                    const conn = response.staConnectionStatus; // Obtain the current status of the device: "0" - Wi-Fi connection established, otherwise - no Wi-Fi connection.
                    const ssid = response.staSSID; // Obtain the SSID of the current Wi-Fi connection
                    const bssid = response.staBSSID; // Obtain the BSSID of the current Wi-Fi connection
                    const password = response.staPassword; // Obtain the password of the current Wi-Fi connection
                } else if (opMode == OpMode.MODE_SOFTAP) {
                    // SoftAP mode is currently enabled
                    const ssid = response.softAPSSID; // Obtain the device SSID
                    const channel = response.softAPChannel; // Obtain the device channel
                    const security = response.softAPSecurity; // Obtain the security option of the device: "0" - no security, "2" - WPA, "3" - WPA2, "4" - WPA/WPA2.
                    const connMaxCount = response.softAPMaxConnectionCount; // The number of maximum connections
                    const connCount = response.softAPConnectionCount; // The number of existing connections
                } else if (opMode == OpMode.MODE_STASOFTAP) {
                    // Station/SoftAP mode is currently enabled
                    // Similar to Station and SoftAP modes
                }
                break;
            default:
                break;
        }
    }
    ```

- Configure the device

    ```typescript
    const params = new BlufiConfigureParams();
    const opMode = // Configure the device mode: "1" - Station, "2" - SoftAP, "3" - Station/SoftAP.
    params.setOpMode(deviceMode);
    if (opMode == OpMode.MODE_STA) {
        // Configure the device in Station mode
        params.staSSID = ssid; // Configure the Wi-Fi SSID
        params.staPassword = password; // Configure the Wi-Fi password. For public Wi-Fi networks, this option can be ignored or configured to return void.
        // Note: 5G Wi-Fi is not supported by the device. Please have a look.
    } else if (opMode == OpMode.MODE_SOFTAP) {
        // Configure Device in SoftAP
        params.softAPSSID = ssid; // Configure the device SSID
        params.softAPSecurity = security; // Configure the security option of the device: "0" - no security, "2" - WPA, "3" - WPA2, "4" - WPA/WPA2.
        params.softAPPassword = password; // This option is mandatory, if the security option value is not "0".
        params.softAPChannel = channel; // Configure the device channel
        params.softAPMaxConnection = maxConnection; // Configure the number of maximum connections for the device

    } else if (opMode == OpMode.MODE_STASOFTAP) {
        // Similar to Station and SoftAP modes
    }

    client.configure(params);
    ```

    ```typescript
    // The result of data sending obtained with the BlufiCallback function
    public onPostConfigureParams(client: BlufiClient, status: number) {
        // status is the result: "0" - successful, otherwise - failed.
    }

    // Indicate the change of status after the configuration
    public onDeviceStatusResponse(client: BlufiClient, status: number, response?: BlufiStatusResponse) {
        // Request the current status of the device
    }
    ```

- Request the device to break BLE connection
    ```typescript
    // If the app breaks a connection with the device and the device has not detected this fact, the app has no means to re-establish the connection.
    client.requestCloseConnection();
    ```

- Close BlufiClient
    ```typescript
    // Release resources
    client.close();
    ```

## Notes on BlufiCallback

```typescript
// Gatt preparations have been completed
public onGattPrepared(client: BlufiClient, status: number) {
}

// Receive the notification of the device
// false indicates that the processing has not been completed yet and that the procewssing will be transferred to BlufiClient.
// true indicates that the processing has been completed and there will be no data processing or function calling afterwards.
public onCharacteristicChange(characteristic: ble.BLECharacteristic): boolean {
    return false;
}

// Error code sent by the device
public onError(client: BlufiClient, errorCode: number) {
}

// The result of the security negotiation with the device
public onNegotiateSecurityResult(client: BlufiClient, status: number) {
}

// The result of sending configure data
public onPostConfigureParams(client: BlufiClient, status: number) {
}

// Information on the received device version
public onDeviceVersionResponse(client: BlufiClient, status: number, response?: BlufiVersionResponse) {
}

// Information on the received device status
public onDeviceStatusResponse(client: BlufiClient, status: number, response?: BlufiStatusResponse) {
}

// Information on the received device Wi-Fi scan
public onDeviceScanResult(client: BlufiClient, status: number, results?: BlufiScanResult[]) {
}

// The result of sending custom data
public onPostCustomDataResult(client: BlufiClient, status: number, data?: Uint8Array) {
}

// The received custom data from the device
public onReceiveCustomData(client: BlufiClient, status: number, data?: Uint8Array) {
}
```
