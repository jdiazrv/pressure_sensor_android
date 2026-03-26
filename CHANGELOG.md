# Changelog

## 2026-03-26

- Added Android multicast lock handling so UDP broadcast reception is more reliable while the app is active.
- Reduced HTTP fallback polling interval from 5 seconds to 1 second when UDP telemetry stops arriving.
- Tightened the UDP fallback threshold check to switch back to HTTP as soon as the UDP timeout is reached.
- Avoided dropping the ESP32 connection on a single failed HTTP poll by requiring repeated failures before marking the device offline and triggering rediscovery.