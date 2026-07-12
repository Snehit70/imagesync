/**
 * Switch — raspberry track + white thumb when on; mist track, hairline
 * outline, muted thumb when off (Material 3 metrics).
 */
export interface SwitchProps {
  checked?: boolean;
  onChange?: (checked: boolean) => void;
  style?: React.CSSProperties;
}
