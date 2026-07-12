/**
 * Manual pairing form — Relay IP / Port / Pairing secret fields, inline error
 * box, "Pair manually" + "Scan QR" pill CTAs.
 * @startingPoint section="Pairing" subtitle="Host/port/secret entry form" viewport="360x480"
 */
export interface ManualPairingFormProps {
  host?: string;
  port?: string;
  secret?: string;
  onHostChange?: (v: string) => void;
  onPortChange?: (v: string) => void;
  onSecretChange?: (v: string) => void;
  /** Error message shown in a mist box with error_outline icon. */
  error?: string | null;
  onScanQr?: () => void;
  onPair?: () => void;
}
