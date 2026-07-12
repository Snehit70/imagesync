/**
 * Small dot with a soft expanding halo; pulses while searching.
 */
export interface PulsingDotProps {
  /** CSS color. Default var(--raspberry). */
  color?: string;
  /** Dot diameter in px (halo is 2.6×). Default 10; 8 in the relays header. */
  size?: number;
}
