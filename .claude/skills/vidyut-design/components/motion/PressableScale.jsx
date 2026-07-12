// Squash-on-press wrapper: scale 0.93 down (120ms easeOutCubic),
// spring overshoot back up (300ms). Recreation of PressableScale.
export function PressableScale({ children, style }) {
  const [pressed, setPressed] = React.useState(false);
  return (
    <div
      style={{
        transform: pressed ? "scale(0.93)" : "scale(1)",
        transition: pressed
          ? "transform var(--dur-press-down, 120ms) var(--ease-out-cubic, ease-out)"
          : "transform var(--dur-press-up, 300ms) var(--ease-spring, ease-out)",
        ...style,
      }}
      onPointerDown={() => setPressed(true)}
      onPointerUp={() => setPressed(false)}
      onPointerLeave={() => setPressed(false)}
    >
      {children}
    </div>
  );
}
