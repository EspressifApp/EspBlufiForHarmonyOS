import { OpMode, SoftApSecurity } from "./BlufiConstatnts"

export class BlufiConfigureParams {
  public opMode: OpMode = OpMode.MODE_NULL

  public staSSID?: string
  public staPassword?: string

  public softApSecurity: SoftApSecurity = -1
  public softApSSID?: string
  public softApPassword?: string
  public softApChannel: number = -1
  public softApMaxConnection: number = -1
}