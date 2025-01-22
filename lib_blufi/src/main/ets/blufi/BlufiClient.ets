import { BlufiConfigureParams } from './params/BlufiConfigureParams';
import { ble } from '@kit.ConnectivityKit';
import { BlufiClientImpl } from './utils/BlufiClientImpl';
import { BlufiCallback } from './BlufiCallback';

export const BLUFI_VERSION = "2.4.0"

export function newBlufiClient(scanResult: ble.ScanResult): BlufiClient {
  return new BlufiClientImpl(scanResult)
}

export interface BlufiClient {
  getGattClientDevice(): ble.GattClientDevice | undefined

  setBlufiCallback(callback?: BlufiCallback): void

  setPostPackageLengthLimit(limit: number): number

  connect(): void

  close(): void

  requestCloseConnection(): void

  negotiateSecurity(): void

  requestDeviceVersion(): void

  requestDeviceStatus(): void

  requestDeviceWifiScan(): void

  configure(params: BlufiConfigureParams): void

  postCustomData(data: Uint8Array): void
}