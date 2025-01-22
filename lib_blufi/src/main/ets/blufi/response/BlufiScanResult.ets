export class BlufiScanResult {
  public static readonly TYPE_WIFI = 1

  public type: number
  public ssid: string
  public rssi: number

  constructor(type: number, ssid: string, rssi: number) {
    this.type = type
    this.ssid = ssid
    this.rssi = rssi
  }
}