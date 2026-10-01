# Provider artwork

Google mark (unchanged): https://developers.google.com/identity/images/g-logo.png
Apple black logo PNG (unchanged): https://developer.apple.com/design/resources/
Official package: https://devimages-cdn.apple.com/design/resources/download/Logo-Sign-in-with-Apple.dmg

The Apple asset is the original 117x132 PNG including its padding. It was recovered
from the official UDIF image's zlib-compressed HFS payload; every PNG chunk CRC
was verified before inclusion. No redrawing or recolouring was applied.

Both marks are bundled; no runtime asset download. They appear in test fixtures.
Live buttons also require server availability and configured native integrations.
Provider setup and Apple handoff remain pending; no callback URL is invented.
