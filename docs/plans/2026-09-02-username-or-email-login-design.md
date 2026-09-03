# Username or Email Login Design

## Goal

Allow users to sign in with either their normalized username or normalized email address and password from both the web administration client and the Flutter client.

## Contract

`POST /api/auth/login` accepts `identifier`, `password`, `tokenTransport`, and optional `deviceName`. The old `email` login field is intentionally unsupported. Registration remains unchanged and continues to require a distinct username, email, and password.

The service normalizes the identifier with Unicode NFKC normalization, trimming, and invariant lowercase conversion. It performs one lookup matching either `User.Username` or `User.Email`, then verifies the password exactly as before. Unknown accounts and incorrect passwords return the same generic authentication failure: `用户名/邮箱或密码错误`.

## Server

- Replace `LoginRequest.Email` with `LoginRequest.Identifier`.
- Add a login-identifier normalization operation that does not require email syntax.
- Query the existing unique username and email columns without changing the schema.
- Preserve rate limiting, session creation, Cookie/body token transport, JWT claims, refresh-token rotation, and logout behavior.
- Reject legacy JSON bodies that provide only `email` because the required `identifier` value is absent.

## Web Administration Client

- Rename the form and store parameter from `email` to `identifier`.
- Label and placeholder the field as `用户名或邮箱`.
- Validate that the identifier is non-empty and no longer require email syntax.
- Send `{ identifier, password, tokenTransport: 'cookie' }`.
- Remember the exact trimmed identifier when requested, while continuing to remove any legacy plaintext password data.
- Migrate an existing remembered `{ email }` value to `{ identifier }` without losing the account hint.

The existing admin-role check remains unchanged: a valid non-admin session is revoked and the user sees `仅管理员可访问`.

## Flutter Client

- Rename login-only controller, provider, repository, API model, and remembered-account concepts from email to identifier.
- Keep registration username and email fields and validation unchanged.
- Label the login field `用户名或邮箱`, use a general text keyboard, and require a non-empty identifier.
- Send `{ identifier, password, tokenTransport: 'body', deviceName }`.
- Store only the trimmed remembered identifier in SharedPreferences; migrate the existing remembered email keys and remove legacy password/token preferences as before.
- Change authentication failures to `用户名/邮箱或密码错误`.

## Error Handling and Security

- Do not reveal whether a username or email exists.
- Do not persist passwords or bearer tokens in browser or SharedPreferences storage.
- Do not invalidate active sessions or alter password hashes.
- Keep normalized matching case-insensitive under the current canonical credential policy.
- Require a non-empty identifier without imposing email-only validation.

## Testing

- Server service tests cover username login, email login, normalization, wrong password, unknown identifier, and separate device sessions.
- Endpoint contract tests prove the new JSON property is `identifier` and an email-only legacy request is rejected.
- Web tests cover request payload, login validation source contract, remembered identifier persistence, and legacy remembered-email migration.
- Flutter tests cover request JSON, repository/provider forwarding, remembered identifier migration, login-page labels/validation, and secure token behavior remaining unchanged.
- Final verification runs focused tests first, then relevant full .NET, web, and Flutter test/build/analyze commands plus `git diff --check`.

## Non-goals

- Database migrations or username/email schema changes.
- Password reset, account recovery, account aliasing, or username changes.
- Backward compatibility for clients that still send the login field as `email`.
- Commit, push, deployment, or production verification.
