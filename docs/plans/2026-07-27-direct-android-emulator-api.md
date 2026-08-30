# Direct Android Emulator API Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the repository Caddy dependency and make an Android Emulator launched from Android Studio connect to the local API with no run arguments, certificates, or ADB reverse command.

**Architecture:** Publish the Docker API on host loopback port `5050` and use the emulator host alias `10.0.2.2`. Android Debug alone may use cleartext HTTP to that exact host; Profile and Release remain HTTPS-only. Publish the Admin Nginx container on loopback port `3000` and let it proxy `/api` internally so the Web application remains same-origin without Caddy.

**Tech Stack:** Flutter/Dart, Android Network Security Configuration, Docker Compose, Nginx, ASP.NET Core, Bash.

---

### Task 1: Lock the direct-development contract with failing tests

**Files:**
- Modify: `follow/test/core/config/app_config_test.dart`
- Create: `follow/test/platform/android_debug_network_config_test.dart`
- Create: `follow/test/core/config/local_development_source_guard_test.dart`

1. Expect Android Debug to default to `http://10.0.2.2:5050` and desktop Debug to `http://localhost:5050`.
2. Expect HTTP to remain invalid for Release and for any non-local Debug origin.
3. Expect the Debug manifest resources to allow cleartext only for `10.0.2.2`, while main/profile remain HTTPS-only.
4. Expect startup, Compose, and scripts to contain no local CA or ADB reverse dependency.
5. Run focused tests and confirm they fail against the current Caddy-based implementation.

### Task 2: Switch Flutter Android Debug to the direct API

**Files:**
- Modify: `follow/lib/core/config/app_config.dart`
- Modify: `follow/lib/main.dart`
- Modify: `follow/android/app/src/debug/res/xml/network_security_config.xml`
- Modify: `follow/android/app/src/main/res/xml/network_security_config.xml`
- Modify: `follow/android/app/src/profile/res/xml/network_security_config.xml`
- Delete: `follow/lib/core/network/local_tls_trust.dart`
- Delete: `follow/lib/core/network/local_tls_trust_io.dart`
- Delete: `follow/lib/core/network/local_tls_trust_policy.dart`
- Delete: `follow/lib/core/network/local_tls_trust_stub.dart`
- Delete: `follow/test/core/network/local_tls_trust_policy_test.dart`
- Delete: `follow/test/core/network/local_tls_trust_source_guard_test.dart`
- Delete: `scripts/prepare-android-emulator.sh`
- Delete: `docs/plans/2026-07-27-android-emulator-local-tls-fix.md`

1. Permit local HTTP only when `isDebug` and the origin is exactly desktop localhost or Android emulator `10.0.2.2:5050`.
2. Remove startup CA injection.
3. Scope Android Debug cleartext to `10.0.2.2`; trust only system CAs elsewhere.
4. Remove the obsolete local TLS implementation and tests.
5. Re-run focused tests and confirm they pass.

### Task 3: Remove Caddy from the local stack without breaking Admin

**Files:**
- Modify: `docker-compose.yml`
- Modify: `follow-admin/nginx.conf`
- Modify: `scripts/verify-docker-config.sh`
- Modify: `.env.example`
- Delete: `Caddyfile`

1. Delete the gateway service, Caddy volumes, dedicated public/proxy networks, and gateway environment.
2. Bind API to `127.0.0.1:5050` and Admin to `127.0.0.1:3000`.
3. Put API and Admin on the internal web network and proxy Admin `/api` requests to `api:5000`.
4. Update the Docker contract checks to reject a gateway service and verify the two loopback bindings.
5. Run `docker compose config`, the contract script, and HTTP health checks.

### Task 4: Align current documentation

**Files:**
- Modify: `follow/README.md`
- Modify: `follow-admin/README.md`
- Modify: `follow-server/README.md`
- Modify: `follow-server/docs/deployment-guide.md`
- Modify: `follow-server/docs/technical-analysis.md`
- Modify: `reference.md`

1. Document Android Studio Run with no arguments after the API is up.
2. Document local loopback ports and the Debug-only cleartext exception.
3. Replace Caddy-specific production guidance with a generic public HTTPS reverse-proxy boundary.
4. Keep MinIO/PostgreSQL/Redis private and keep Release clients HTTPS-only.

### Task 5: Verify Android Studio-equivalent device behavior

**Files:**
- Verify only.

1. Run all Flutter tests and analysis.
2. Build a Debug APK without any dart defines.
3. Install the ABI-matched APK on `emulator-5554` without clearing App data.
4. Ensure no ADB reverse mapping is required, then trigger a real login request.
5. Accept an HTTP `401` for invalid probe credentials as proof that the direct transport reached the API; reject any handshake, cleartext-policy, or connection error.
