# Authentication lifecycle

The backend login challenge consists of `attempt_id` and `attempt_token` from
`POST /telegram/auth/start`. Flutter keeps the 43-character URL-safe token only
in the mounted login screen and sends it in the JSON body of `verify-code` and
`verify-password`. It is never placed in URLs, secure storage, preferences, or
logs. Returning to the phone step, finishing login, or disposing the screen
clears the challenge and entered code/password. Two-factor authentication keeps
the same challenge until completion.

The matching backend verifies the secret before contacting Telegram or changing
failure counters, serializes verification for each attempt, and consumes the
attempt on success. A used, expired, or pre-migration attempt requires a new
login flow. Account JWTs, TDLib sessions, API paths, storage namespaces, and
installed application IDs remain unchanged.

Release these Flutter changes together with backend migration `20260921_0018`
and the matching auth service. The backend rejects clients that omit the token;
Flutter rejects older backend responses that omit it. Existing signed-in users
keep their saved credentials. A deployment must never restore ID-only login as
a compatibility workaround. Local mocked tests cover the request contract;
actual Telegram OTP/2FA and physical-device sign-in require separate verification.

## Token lifetime and renewal

Backend tokens expire `JWT_EXPIRES_DAYS` (30) after they are issued, and there
is no refresh token. Before renewal existed, a saved account that was not
opened for that long showed as saved but sent its owner back to phone sign-in,
although neither Telegram nor TeleDrive had signed it out.

When saved-account snapshots refresh (after startup restores the active
account), the client exchanges every token that is a third of the way through
its lifetime through `POST /telegram/auth/renew`, one account at a time. The
active account's API token is replaced only if it is still the token that was
renewed; other accounts only change in the vault. Renewal never activates
another account or its TDLib session. A `401` marks that account as needing
sign-in; a server without the endpoint (`404`/`405`) stops renewal and leaves
tokens untouched. Thumbnail and avatar cache keys already exclude the token, so
a renewed token does not invalidate cached media.

An account whose token has already expired still needs one Telegram sign-in.
The Accounts list labels it "Signed out · Tap to sign in again", and sign-in
opens as "Sign In Again" with the account's name and saved number filled in.
Coverage: `test/session_renewal_test.dart` and the backend's
`tests/test_session_renewal.py`.
