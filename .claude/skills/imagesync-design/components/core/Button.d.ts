/**
 * Pill button — filled / outlined / text, exactly as theme.dart styles them.
 * Wrap in PressableScale for the press squash.
 * @startingPoint section="Core" subtitle="Pill buttons: filled, outlined, text" viewport="360x220"
 */
export interface ButtonProps {
  /** filled = raspberry CTA; outlined = petal-bordered secondary; text = link-style. */
  variant?: "filled" | "outlined" | "text";
  children: React.ReactNode;
  /** Optional leading Material icon name (e.g. "link", "qr_code_scanner"). */
  icon?: string;
  /** Text variant only: muted color, used for Skip. */
  muted?: boolean;
  /** Filled/outlined stretch full width by default (app CTAs do). */
  fullWidth?: boolean;
  onClick?: () => void;
  disabled?: boolean;
  style?: React.CSSProperties;
}
