/**
 * Organic blob that slowly morphs between two silhouettes (10s loop).
 * The hero motif: put a white circle with a raspberry Material icon inside.
 * @startingPoint section="Motion" subtitle="Morphing blob hero motif" viewport="220x220"
 */
export interface MorphingBlobProps {
  /** Diameter in px. Home hero: 180; onboarding step: 150; success orb: 104. */
  size?: number;
  /** CSS color. Default var(--raspberry); petal for soft/attention states. */
  color?: string;
  /** Centered content — typically a white circle containing an icon. */
  children?: React.ReactNode;
}
