/**
 * Flat card — mist fill, 20px radius, no shadow, no border, no margin.
 */
export interface CardProps {
  children: React.ReactNode;
  /** default = mist surface; emphasis = petal (setup banner, status chips). */
  variant?: "default" | "emphasis";
  /** CSS padding. App uses 14px (status cards) to 20px. */
  padding?: number | string;
  onClick?: () => void;
  style?: React.CSSProperties;
}
