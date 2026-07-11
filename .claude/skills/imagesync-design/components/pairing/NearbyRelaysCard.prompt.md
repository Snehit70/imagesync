Nearby relays card — mDNS discovery list shared by home pairing and the onboarding finale.

```jsx
<NearbyRelaysCard
  relays={[{ name: 'imagesync-relay', host: '192.168.1.4', port: 17321 }]}
  selected={selectedRelay}
  discovering={false}
  onRefresh={discover}
  onSelect={setSelectedRelay}
/>
```

Empty + discovering shows "Searching for relays on this network…" with a PulsingDot in the header.
