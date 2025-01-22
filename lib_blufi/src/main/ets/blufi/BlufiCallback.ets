import { BlufiClient } from "./BlufiClient";
import { BlufiScanResult } from "./response/BlufiScanResult";
import { BlufiStatusResponse } from "./response/BlufiStatusResponse";
import { BlufiVersionResponse } from "./response/BlufiVersionResponse";
import { ble } from "@kit.ConnectivityKit";

export abstract class BlufiCallback {
  /**
   * Callback will be invoked when received error from the device
   *
   * @param client
   * @param errorCode
   */
  public onError(client: BlufiClient, errorCode: number) {
  }

  /**
   * The system ble connection state changed callback
   *
   * @param state
   */
  public onConnectionStateChange(state: ble.BLEConnectionChangeState) {
  }

  /**
   * The system ble characteristic changed callback
   * If the function returns true, the notification will not be handled by lib_blufi.
   *
   * @param characteristic
   * @returns true if the callback consumed the notification, false otherwise
   */
  public onCharacteristicChange(characteristic: ble.BLECharacteristic): boolean {
    return false
  }

  /**
   * Callback will be invoked after all blufi preparations have been completed
   *
   * @param client
   * @param status
   */
  public onGattPrepared(client: BlufiClient, status: number) {
  }

  /**
   * Callback will be invoked when negotiates security over with the device
   *
   * @param client
   * @param status
   */
  public onNegotiateSecurityResult(client: BlufiClient, status: number) {
  }

  /**
   * Callback will be invoked when posts configure data over
   *
   * @param client
   * @param status
   */
  public onPostConfigureParams(client: BlufiClient, status: number) {
  }

  /**
   * Callback will be invoked when receives device version
   *
   * @param client
   * @param status
   * @param response
   */
  public onDeviceVersionResponse(client: BlufiClient, status: number, response?: BlufiVersionResponse) {
  }

  /**
   * Callback will be invoked when receives device status
   *
   * @param client
   * @param status
   * @param response
   */
  public onDeviceStatusResponse(client: BlufiClient, status: number, response?: BlufiStatusResponse) {
  }

  /**
   * Callback will be invoked when receives device scan results
   *
   * @param client
   * @param status
   * @param results
   */
  public onDeviceScanResult(client: BlufiClient, status: number, results?: BlufiScanResult[]) {
  }

  /**
   * Callback will be invoked when posts custom data over
   *
   * @param client
   * @param status
   * @param data
   */
  public onPostCustomDataResult(client: BlufiClient, status: number, data?: Uint8Array) {
  }

  /**
   * Callback will be invoked when receives custom data from the device
   *
   * @param client
   * @param status
   * @param data
   */
  public onReceiveCustomData(client: BlufiClient, status: number, data?: Uint8Array) {
  }
}