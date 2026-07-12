/**
 * Staggered screen entrance: rise 30px + fade, 600ms, 100ms apart.
 * Every screen's children enter with sequential indices.
 */
export interface EntranceProps {
  /** Stagger index — delay is index × 100ms. */
  index?: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
}
