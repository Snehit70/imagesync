# Payloads are encrypted at the app layer using the pairing secret

Payloads travel over a plain (non-TLS) WebSocket on the LAN, but every payload is
encrypted with AES-256-GCM (libsodium secretbox) before it hits the wire. The key
is derived from the secret exchanged during QR pairing, so only the user's paired
devices can decrypt.

We rejected transport TLS (WSS + self-signed cert) because making Android trust a
self-signed cert is exactly the setup friction the project exists to avoid. Plain
WebSocket alone was rejected because the clipboard carries passwords and private
screenshots that anything on a shared WiFi could sniff.

Reusing the pairing secret as the encryption key makes end-to-end encryption
essentially free and keeps setup to a single QR scan. The trade-off: the relay
itself never sees plaintext, so it cannot inspect or transform payloads — which is
fine, it only needs to store-and-broadcast the latest one.
