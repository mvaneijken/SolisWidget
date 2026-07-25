# SolisWidget

[![CI](https://github.com/mvaneijken/SolisWidget/actions/workflows/ci.yml/badge.svg)](https://github.com/mvaneijken/SolisWidget/actions/workflows/ci.yml)

A Garmin Connect IQ widget to monitor the solar output of your Ginlong Solis PV system, powered by the [SolisCloud](https://www.soliscloud.com) platform API.

Get it from the [Garmin Connect IQ store](https://apps.garmin.com/nl-NL/apps/10aaf779-d874-453f-a0cc-6795f5dad76c).

## ⚠️ Breaking change in version 0.1.0

This version switches from the old Solis portal to the **SolisCloud API v2**. The old
username/password configuration **no longer works** — every user (new and existing) must
configure an API Key and API Secret:

1. Log in to the [SolisCloud portal](https://www.soliscloud.com).
2. Request API access: **Basic Settings → API Management** (Solis support has to approve
   API access for your account if the option is not visible).
3. Note the generated **KeyID** (API Key) and **KeySecret** (API Secret).
4. Enter both in the widget settings via the Garmin Connect app (or Garmin Express):
   **your device → Connect IQ apps → SolisWidget → Settings**.

The widget automatically detects your station (plant) on the first request and caches its
ID. If you change API credentials, the cached station ID is reset and detected again.

## Features

- Current power production
- Energy produced today, this month, this year, and in total
- Glance view support (quick look without opening the widget)
- Configurable starting page
- Dutch and English

## Requirements

- A Garmin device with Connect IQ 3.0 or higher (the SolisCloud API requires
  request signing, which uses the on-device `Toybox.Cryptography` module)
- An Android or iOS phone with the Garmin Connect app, paired with your device,
  with an active internet connection
- A SolisCloud account with API access enabled (see above)

## Settings

| Setting | Description |
|---|---|
| Starting Page | Which value is shown first (Current / Today / Month / Year / Total / Overview) |
| API Key | The KeyID from SolisCloud API Management |
| API Secret | The KeySecret from SolisCloud API Management |
| Solis Station Identifier | Auto-detected station ID (read-only) |

## Development

The widget is written in [Monkey C](https://developer.garmin.com/connect-iq/monkey-c/).
To develop locally, install the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/)
and the Monkey C extension for Visual Studio Code.

### Running the tests

Unit tests use Garmin's [Run No Evil](https://developer.garmin.com/connect-iq/core-topics/unit-testing/)
framework and live in `SolisWidget/source/SolisWidgetTests.mc`. They cover the SolisCloud
request-signing logic (HMAC-SHA1, Base64, Content-MD5, RFC 2822 date formatting) and the
display formatting/navigation helpers.

Run them locally with Docker (no SDK installation needed):

```sh
docker run --rm -v "$PWD":/work -w /work --entrypoint bash \
  ghcr.io/matco/connectiq-tester:latest .github/scripts/run-tests.sh fenix7
```

Or from VS Code with the Monkey C extension: **Monkey C: Run Tests**.

### Continuous integration

Every push runs the [CI workflow](.github/workflows/ci.yml):

- **test** — runs the unit tests in the Connect IQ simulator (headless, in the
  [connectiq-tester](https://github.com/matco/connectiq-tester) container).
- **build** — builds the store export package (`.iq`) for **all** devices in the
  manifest, which verifies the app compiles for every supported product.

## Releasing to the Connect IQ store

Garmin offers no API for store uploads, so the release flow automates everything up to
the final manual upload:

1. Bump the `version` attribute of `iq:application` in `SolisWidget/manifest.xml`.
2. Commit, then tag the release: `git tag v0.1.0 && git push origin v0.1.0`.
3. The [release workflow](.github/workflows/release.yml) verifies the tag matches the
   manifest version, runs the tests, builds a signed `.iq`, and attaches it to a GitHub
   Release.
4. Download the `.iq` from the release and upload it manually in the
   [Connect IQ developer dashboard](https://apps.garmin.com/developer/dashboard),
   including the "What's New" text.

### Store screenshots

The store listing needs screenshots per device family. The **demo build**
(`SolisWidget/monkey-demo.jungle`) shows realistic hardcoded values without any
network access or credentials, and advances to the **next page on every app
start** — so capturing all six screens takes a few minutes locally:

```sh
cd SolisWidget
monkeyc -f monkey-demo.jungle -d fr965 -o bin/demo.prg -y <your-key.der> -l 0
# start the simulator (Connect IQ: Simulate Device in VS Code, or `connectiq`)
monkeydo bin/demo.prg fr965   # shows page 1 — capture, then re-run for page 2, etc.
```

Use the simulator's built-in screenshot function (File menu) for clean images.
Repeat with `fr970`, `fenix847mm`, `venu3`, or any other device. The demo code
is excluded from production builds via the `(:demo)`/`(:prod)` annotations.

There is also a manual [Screenshots workflow](.github/workflows/screenshots.yml)
that attempts this in CI, but the Connect IQ simulator is unstable on headless
runners, so local capture is the dependable route.

### Signing key

Store updates must be signed with the **same developer key** as the originally published
app. Add it as the GitHub Actions secret `CONNECTIQ_DEVELOPER_KEY`:

```sh
base64 -w0 developer_key.der   # copy the output into the secret
```

(Settings → Secrets and variables → Actions → New repository secret.)

Without the secret, CI builds sign with a throwaway key — fine for compile checks, but
the resulting package cannot be uploaded to the store.

## Credits

Special thanks to akamming's SolarEdgeWidget, which provided the base for this widget:
[github.com/akamming/SolarEdgeWidget](https://github.com/akamming/SolarEdgeWidget) /
[store listing](https://apps.garmin.com/en-US/apps/cfa414be-82de-40a6-8e24-36a816c6fe98#0).
