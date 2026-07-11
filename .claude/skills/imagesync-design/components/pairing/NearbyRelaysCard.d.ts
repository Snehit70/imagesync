/**
 * Nearby relays discovery card — mDNS results list with refresh, empty state,
 * and selection check.
 * @startingPoint section="Pairing" subtitle="Relay discovery list" viewport="360x260"
 */
export interface NearbyRelaysCardProps {
  relays?: { name: string; host: string; port: number }[];
  selected?: { host: string; port: number } | null;
  /** Shows the pulsing dot + searching copy, hides refresh. */
  discovering?: boolean;
  onRefresh?: () => void;
  onSelect?: (relay: { name: string; host: string; port: number }) => void;
}
