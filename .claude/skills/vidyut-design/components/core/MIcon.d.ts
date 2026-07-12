/**
 * Material Icons glyph — the app's icon set (Flutter Icons.*).
 */
export interface MIconProps {
  /** Material icon name, e.g. "link", "qr_code_scanner", "check_circle". */
  name: string;
  /** Font size in px. Default 24; app uses 18–32. */
  size?: number;
  /** CSS color. Default currentColor. */
  color?: string;
  /** Use the outlined variant font. */
  outlined?: boolean;
  style?: React.CSSProperties;
}
