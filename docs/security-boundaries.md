# Client security boundaries

## Account lifecycle

Authentication reads capture the current account generation. Switching, removal,
sign-out and credential replacement invalidate older reads. Snapshot refresh may
update only a still-present account with the same token; it cannot recreate a
removed account. Profile refresh also rejects results from a previous identity.

Vault writes and sign-out deletion run in order, including writes that were
already pending when removal started. This prevents a slower secure-storage write
from restoring removed credentials after a newer deletion. The stable backend
storage namespace, TDLib keys and pending-commit scope remain unchanged.

Regression coverage: `test/auth_refresh_isolation_test.dart`,
`test/startup_auth_test.dart`, and `test/auth_connection_lifetime_test.dart`.

## Backend and media destinations

The authenticated API client accepts only HTTP(S) URLs at the selected backend
origin (scheme, hostname and port), without embedded URL credentials. Its active
token remains bound to the origin selected when it was installed. Cross-origin
URLs and API redirects are rejected before credentials can be forwarded.
External media, if added in a future contract, requires an explicit URL policy
and a separate downloader without backend credentials.

Automatic LAN discovery and health responses establish reachability only. They
cannot authorize login, saved-token bootstrap or tokenized media URLs. Choose a
server explicitly in Server Connection settings, or configure `API_BASE_URL`
for the build. Loopback/USB/emulator addresses remain supported when explicitly
configured; location alone does not authenticate a local server. Android's
`10.0.2.2` emulator alias can also identify an ordinary LAN host on a physical
device. Hosted configured
and pinned endpoints retain their existing fail-closed behavior.

Changing to another origin while signed in requires sign-out and a fresh login;
an automatic retry must not transport the old token to the new server. Trusted
configuration changes do not replace `AppConfig.storageNamespace` or delete
account data.

Regression coverage: `test/api_credential_origin_test.dart` and
`test/hosted_backend_config_test.dart`.

## Login and transfers

See [authentication](authentication.md) for the client-held login challenge and
coordinated backend rollout, and [Telegram transfers](telegram-transfer-service.md)
for cancellation and durable completion of already-accepted originals.

Automated fixture checks do not establish real Telegram delivery or native iOS
behavior. Report Android compilation, iOS compilation and physical device checks
separately.
