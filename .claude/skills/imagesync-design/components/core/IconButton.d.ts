/**
 * Icon chip button — mist square, rounded 14px (12px inline refresh), used in
 * app bars and card headers.
 */
export interface IconButtonProps {
  /** Material icon name (outlined variant is rendered). */
  icon: string;
  /** Icon color: ink in app bars, raspberry inline. */
  color?: string;
  /** Icon size. Default 20. */
  size?: number;
  /** Corner radius: 14 app bar, 12 inline. */
  radius?: number;
  /** Tooltip text. */
  title?: string;
  onClick?: () => void;
  style?: React.CSSProperties;
}
