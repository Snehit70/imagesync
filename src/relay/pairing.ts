import qrcode from "qrcode-terminal";

export interface PairingCodeOptions {
  host: string;
  port: number;
  pairingSecret: string;
}

export interface PairingCode {
  raw: string;
  manual: string;
  qr: string;
}

export function createPairingCode(options: PairingCodeOptions): PairingCode {
  const raw = JSON.stringify({
    v: 1,
    service: "vidyut",
    host: options.host,
    port: options.port,
    secret: options.pairingSecret,
  });

  return {
    raw,
    manual: `host=${options.host} port=${options.port} secret=${options.pairingSecret}`,
    qr: renderQr(raw),
  };
}

function renderQr(value: string): string {
  let output = "";
  qrcode.generate(value, { small: true }, (qr) => {
    output = qr;
  });
  return output;
}

