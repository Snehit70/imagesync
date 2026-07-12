/**
 * Squash-on-press wrapper: 0.93 down, spring overshoot back up (~300ms).
 * Wrap every primary button and tappable banner in this.
 */
export interface PressableScaleProps {
  children: React.ReactNode;
  /** Extra styles on the wrapper. */
  style?: React.CSSProperties;
}
