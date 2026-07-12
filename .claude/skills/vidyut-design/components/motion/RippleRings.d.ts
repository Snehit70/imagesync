/**
 * Ripple rings radiating outward from a central child (success orb).
 */
export interface RippleRingsProps {
  /** Outer diameter in px. Default 160. */
  size?: number;
  /** Ring stroke color. Default var(--petal). */
  color?: string;
  /** Centered content — e.g. a raspberry circle or MorphingBlob. */
  children?: React.ReactNode;
}
