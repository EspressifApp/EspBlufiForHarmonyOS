import { bigintToUint8Array } from "../utils/BlufiUtils"

export class BlufiDH {
  public p: bigint
  public g: bigint
  public l: number
  public privateKey: bigint
  public publicKey: bigint
  public secretKey?: Uint8Array

  constructor(p: bigint, g: bigint, length: number) {
    this.p = p
    this.g = g
    this.l = length
    this.privateKey = this.generatePrivateKey(length)
    this.publicKey = this.computePublicKey()
  }

  private generatePrivateKey(length: number): bigint {
    const max = BigInt(2) ** BigInt(length) - BigInt(1)
    const min = BigInt(2) ** BigInt(length - 1)
    return min + BigInt(Math.floor(Math.random() * Number(max - min)))
  }

  private computePublicKey(): bigint {
    return this.modularExponentiation(this.g, this.privateKey, this.p)
  }

  private computeSharedSecret(otherPublicKey: bigint): bigint {
    return this.modularExponentiation(otherPublicKey, this.privateKey, this.p)
  }

  private modularExponentiation(base: bigint, exp: bigint, mod: bigint): bigint {
    let result = BigInt(1)
    base = base % mod
    while (exp > 0) {
      if (exp % BigInt(2) === BigInt(1)) {
        result = (result * base) % mod
      }
      exp = exp >> BigInt(1)
      base = (base * base) % mod
    }
    return result
  }

  public generateSecret(deviceY: bigint): Uint8Array {
    const keyBN = this.computeSharedSecret(deviceY)
    const keyLength = this.l / 8
    const keyData = bigintToUint8Array(keyBN, keyLength)
    let offset = 0
    for (let b of keyData) {
      if (b === 0) {
        offset++
      } else {
        break
      }
    }
    if (offset === 0) {
      this.secretKey = keyData
    } else {
      this.secretKey = keyData.slice(offset)
    }

    return this.secretKey!
  }
}