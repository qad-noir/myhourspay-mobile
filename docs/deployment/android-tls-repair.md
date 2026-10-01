# Android TLS repair for mhp.glsltd.co.uk

Confirmed 2026-10-01 on the connected Android 13 Samsung SM_N981N:

- The app fails during TLS handshake before sending login credentials.
- Phone UTC time agrees with the computer (within one second).
- Production login, /me, workspace list and weekly-hours reads pass with the app's Dart repositories on Windows.
- The live server sends its leaf certificate plus SSL.com TLS Issuing RSA CA R1 issued by SSL.com TLS RSA Root CA 2022.
- Verification using only the phone's 125 system trust certificates fails: error 20, unable to get local issuer certificate.
- Replacing the supplied intermediate with SSL.com's cross-signed SSL.com TLS Issuing RSA CA R1 (issuer AAA Certificate Services) makes the same leaf pass hostname and TLS-server-purpose verification against that unchanged phone trust store.

## Prepared server configuration

`mhp-android-compatible-ca-bundle.pem` contains the public, cross-signed intermediate from SSL.com's official archive:
https://www.ssl.com/repo/certs/SSL.com-Cross-Certificates.zip
Archive member: SSL.com-TLS-I-RSA-R1_AAA.crt
Validity: 2024-06-21 through 2028-12-31.

In the hosting SSL configuration for mhp.glsltd.co.uk, keep the existing domain certificate and private key. Replace the CA Bundle / CABUNDLE / intermediate-chain field with this PEM file. For a server that requires a fullchain file, concatenate the existing domain certificate followed by this intermediate. Do not replace the private key, install this certificate on the phone, or bundle a custom trust store into the app. Reload the TLS-serving web server if the hosting panel does not do that automatically.

This compatibility chain was cryptographically verified locally; it has NOT been deployed. The hosting provider should confirm its supported chain and renewal configuration. Current certificate expires 2027-03-04; recheck chain compatibility at renewal. The CA also offers newer-root cross-signed bundles as alternative trust paths; use the provider's supported compatible chain rather than reverting to a newer-root-only bundle.

After installation, recheck the live served chain against the phone trust store and retry login on the already-installed APK. No app rebuild is required for the server-side certificate repair.

Provider references:
- https://www.ssl.com/repository/
- https://www.namecheap.com/support/knowledgebase/article.aspx/9393/33/where-do-i-find-ssl-ca-bundle/
