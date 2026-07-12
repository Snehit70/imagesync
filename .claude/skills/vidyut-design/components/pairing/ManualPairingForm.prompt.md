Manual pairing form — host/port/secret entry with QR fallback; the pairing surface on home and onboarding.

```jsx
<ManualPairingForm
  host={host} port={port} secret={secret}
  onHostChange={setHost} onPortChange={setPort} onSecretChange={setSecret}
  error={error} onPair={pair} onScanQr={scan}
/>
```

Errors render inside a mist box with a deep-red `error_outline` icon — never a red fill.
