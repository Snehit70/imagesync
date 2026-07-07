declare module "qrcode-terminal" {
  interface GenerateOptions {
    small?: boolean;
  }

  interface QRCodeTerminal {
    generate(value: string, options: GenerateOptions, callback: (qr: string) => void): void;
  }

  const qrcode: QRCodeTerminal;
  export default qrcode;
}

