import { DataDirection } from '../params/BlufiConstatnts'

export class FrameCtrlData {
  private static POSITION_ENCRYPTED = 0
  private static POSITION_CHECKSUM = 1
  private static POSITION_DATA_DIRECTION = 2
  private static POSITION_REQUIRE_ACK = 3
  private static POSITION_FRAG = 4
  private readonly value: number

  constructor(frameCtrlValue: number) {
    this.value = frameCtrlValue
  }

  private check(position: number): boolean {
    return ((this.value >> position) & 1) == 1;
  }

  public isEncrypted(): boolean {
    return this.check(FrameCtrlData.POSITION_ENCRYPTED);
  }

  public isChecksum(): boolean {
    return this.check(FrameCtrlData.POSITION_CHECKSUM);
  }

  public isAckRequirement(): boolean {
    return this.check(FrameCtrlData.POSITION_REQUIRE_ACK);
  }

  public hasFrag(): boolean {
    return this.check(FrameCtrlData.POSITION_FRAG);
  }

  static getFrameCTRLValue(
    encrypted: boolean,
    checksum: boolean,
    direction: DataDirection,
    requireAck: boolean,
    frag: boolean
  ): number {
    let frame = 0;
    if (encrypted) {
      frame = frame | (1 << FrameCtrlData.POSITION_ENCRYPTED);
    }
    if (checksum) {
      frame = frame | (1 << FrameCtrlData.POSITION_CHECKSUM);
    }
    if (direction == DataDirection.INPUT) {
      frame = frame | (1 << FrameCtrlData.POSITION_DATA_DIRECTION);
    }
    if (requireAck) {
      frame = frame | (1 << FrameCtrlData.POSITION_REQUIRE_ACK);
    }
    if (frag) {
      frame = frame | (1 << FrameCtrlData.POSITION_FRAG);
    }

    return frame;
  }
}