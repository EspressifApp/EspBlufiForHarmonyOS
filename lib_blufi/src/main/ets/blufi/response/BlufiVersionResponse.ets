export class BlufiVersionResponse {
  private versionValues: number[] = [0, 0]

  constructor(bigVer: number, smallVer: number) {
    this.versionValues[0] = bigVer
    this.versionValues[1] = smallVer
  }

  getVersionString(): string {
    return `V${this.versionValues[0]}.${this.versionValues[1]}`
  }
}