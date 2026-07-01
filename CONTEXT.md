# ImageSync

A personal utility that keeps a single shared clipboard "pool" in sync across a
user's Linux laptop and Android phone on the same WiFi network, so an image
copied on one device can be pasted on the other. Modeled on Apple's Universal
Clipboard, adapted to Android's clipboard restrictions.

## Language

**Pool**:
The single most-recent clipboard payload shared across all connected devices.
Latest write wins; there is no history.
_Avoid_: queue, history, buffer, stack

**Payload**:
One clipboard item synced through the pool — either an image or a text blob,
plus its metadata (type, size, origin device, timestamp).
_Avoid_: item, entry, message, clip

**Relay**:
The small server that holds the current pool payload and broadcasts new payloads
to every connected device. It runs on the laptop and is reachable only over the
local WiFi network; nothing leaves the LAN.
_Avoid_: server, hub, broker

**Device**:
One participant in the pool — currently the Linux laptop or the Android phone.
Each device both publishes and receives payloads.
_Avoid_: client, node, peer

**Pairing**:
The one-time act of pointing the phone at the laptop's relay on the local
network, so the two devices share a pool. This is the entire setup.
_Avoid_: onboarding, registration

**Share-sheet push**:
The phone-to-relay path. Because Android forbids background clipboard reads,
the phone publishes a payload only when the user explicitly shares content
(e.g. a screenshot) into ImageSync via the Android share sheet.
_Avoid_: upload, send
