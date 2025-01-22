import { cryptoFramework } from '@kit.CryptoArchitectureKit';

export class BlufiAES {
  private static readonly Transformation = 'AES128|CFB|NoPadding'
  private static readonly Algorithm = 'AES128'
  private key: cryptoFramework.DataBlob
  private iv: cryptoFramework.DataBlob
  private encryptCipher: cryptoFramework.Cipher
  private decryptCipher: cryptoFramework.Cipher

  constructor(key: Uint8Array, iv: Uint8Array) {
    this.key = { data: key }
    this.iv = { data: iv }

    this.encryptCipher = this.generateCipher(this.key, this.iv, cryptoFramework.CryptoMode.ENCRYPT_MODE)
    this.decryptCipher = this.generateCipher(this.key, this.iv, cryptoFramework.CryptoMode.DECRYPT_MODE)
  }

  private generateCipher(
    key: cryptoFramework.DataBlob,
    iv: cryptoFramework.DataBlob,
    mode: cryptoFramework.CryptoMode
  ): cryptoFramework.Cipher {
    let cipher = cryptoFramework.createCipher(BlufiAES.Transformation)
    let generator = cryptoFramework.createSymKeyGenerator(BlufiAES.Algorithm)
    let symKey = generator.convertKeySync(key)
    let ivParamSpec: cryptoFramework.IvParamsSpec = {
      algName: "IvParamsSpec",
      iv: iv
    }
    cipher.initSync(mode, symKey, ivParamSpec)
    return cipher
  }

  public encrypt(content: Uint8Array): Uint8Array {
    let blob = this.encryptCipher.doFinalSync({ data: content })
    return blob.data
  }

  public decrypt(content: Uint8Array): Uint8Array {
    let blob = this.decryptCipher.doFinalSync({ data: content })
    return blob.data
  }
}