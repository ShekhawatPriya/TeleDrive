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
