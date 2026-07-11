/**
 * Text field — mist fill, 16px radius, floating label, raspberry focus ring.
 */
export interface TextFieldProps {
  /** Floating label, e.g. "Relay IP", "Port", "Pairing secret". */
  label: string;
  /** Muted prefix Material icon: router, settings_ethernet, key. */
  icon?: string;
  value?: string;
  onChange?: (value: string) => void;
  /** Input type; "password" for the pairing secret. */
  type?: string;
  placeholder?: string;
  /** Error state: deep-red border. */
  error?: boolean;
  style?: React.CSSProperties;
}
