# Making the shared link open the app

A teacher shares one link with the whole class:

```
https://meet.lynindia.in/?lynmeet=DEVTEST
```

The app already claims that domain — `AndroidManifest.xml` has an
`autoVerify` intent-filter and `Runner.entitlements` has the associated
domain. **That half does nothing on its own.** Both platforms verify the claim
by fetching a file from the domain, and until the server serves those two
files the link keeps opening a browser.

## The problem right now

`https://meet.lynindia.in/.well-known/assetlinks.json` currently returns the
web app's `index.html` — the SPA catch-all answers it. Android's verifier
requires real JSON with `Content-Type: application/json`, so it fails, silently,
and every link goes to the browser.

Both files must be served **before** the SPA fallback route.

| Path | File | Content-Type |
| --- | --- | --- |
| `/.well-known/assetlinks.json` | `assetlinks.json` | `application/json` |
| `/.well-known/apple-app-site-association` | `apple-app-site-association` | `application/json` |

Rules that catch people out:

- No redirects. Both verifiers follow none — the URL must answer `200` directly.
- The Apple file has **no `.json` extension**. That is correct; do not add one.
- Valid TLS, which `meet.lynindia.in` already has.

## Before deploying: fill in the two placeholders

**`assetlinks.json`** already lists the debug keystore fingerprint, so a
`flutter run` build verifies on a test device. Add the release one — Play App
Signing re-signs the upload, so take the fingerprint Play shows you, not your
upload keystore's:

```bash
keytool -list -v -keystore /path/to/release.keystore -alias <alias> | grep SHA256
```

Play Console → *Release* → *Setup* → *App signing* shows the fingerprint that
actually matters once the app is on Play. Both can be listed at once; that is
why the array has two slots.

**`apple-app-site-association`** needs the 10-character Team ID from the Apple
Developer account, giving `ABCDE12345.com.el.lynmeet`.

## Serving them

The frontend is behind a Vite server with a proxy. Serve the directory as
static files ahead of the SPA route — in the Express backend that is:

```js
app.use("/.well-known", express.static(path.join(__dirname, "../../deploy"), {
  setHeaders: (res) => res.setHeader("Content-Type", "application/json"),
}));
```

Any reverse proxy in front works equally well, as long as `/.well-known/*`
never reaches the SPA fallback.

## Checking it worked

```bash
curl -i https://meet.lynindia.in/.well-known/assetlinks.json
```

Look for `200` and `application/json`, not HTML. Then Google's own verifier,
which reports exactly what Android will conclude:

```bash
curl "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://meet.lynindia.in&relation=delegate_permission/common.handle_all_urls"
```

On a device with the app installed:

```bash
adb shell pm get-app-links com.el.lynmeet
```

`verified` is the answer you want. `legacy_failure` or `1024` means the fetch
failed — usually the SPA still answering, or a redirect.

Re-verification only happens on install, so uninstall and reinstall after
fixing the server rather than expecting a running app to notice.

## If verification cannot be made to work

The app also registers `lynmeet://`, which needs no domain proof and always
opens it:

```
lynmeet://join/DEVTEST
```

Useful for testing the in-app handling on its own, and as something to fall
back on. It is not a replacement for the https link — nothing outside the app
knows to write it, and a student without the app installed gets an error
instead of the web page.

## What the app does with the link

`lib/services/meeting_link.dart` reads the meeting ID out of whatever form
arrives — `?lynmeet=`, the older `?meeting=` / `?meetingId=` / `?id=`, the
`/join/ID` and `/m/ID` paths, and a bare generated code — then upper-cases it,
because the server keys the room on that exact string. The join screen opens
with the field already filled.
