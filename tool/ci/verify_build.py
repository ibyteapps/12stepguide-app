#!/usr/bin/env python3
"""Check the identifiers and versions inside built apps (IMPLEMENTATION_PLAN.md, P0).

test/fixed_identifiers_test.dart checks the project files; this checks what the build tools
actually produced, which is what the stores and users' devices see.

    verify_build.py android-apk  <app.apk> <flavor>   # needs aapt2 (Android SDK build-tools)
    verify_build.py android-aab  <app.aab> <flavor>   # needs bundletool (BUNDLETOOL_JAR)
    verify_build.py ios-app      <Runner.app> <flavor>

Expected values come from FLUTTER_ARCHITECTURE.md §0 and pubspec.yaml. Exits non-zero on any
mismatch.
"""
from __future__ import annotations

import glob
import os
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP_ID = "com.ibyteapps.aa12stepguide"
LAUNCHER = f"{APP_ID}.First"
# Streaming, downloads and background playback need these in every build.
REQUIRED_PERMISSIONS = [
    "android.permission.INTERNET",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
    "android.permission.WAKE_LOCK",
]
ANDROID_MIN_SDK = "24"
ANDROID_TARGET_SDK = "36"
IOS_MIN_OS = "15.0"

# prod: today's Play name until the owner decides A-02 (DECISIONS.md D-009).
ANDROID_LABEL = {"dev": "12SG Dev", "staging": "12SG Staging", "prod": "12 Step Guide - AA"}
ADMOB_APP_ID = {
    "android": {"dev": "ca-app-pub-3940256099942544~3347511713",
                "staging": "ca-app-pub-3935706727993760~6070100472",
                "prod": "ca-app-pub-3935706727993760~6070100472"},
    "ios": {"dev": "ca-app-pub-3940256099942544~1458002511",
            "staging": "ca-app-pub-3935706727993760~5296879139",
            "prod": "ca-app-pub-3935706727993760~5296879139"},
}
IOS_NAME = {"dev": "12SG Dev", "staging": "12SG Staging", "prod": "12 Step Guide"}
IOS_ICON = {"dev": "AppIcon-dev", "staging": "AppIcon-staging", "prod": "AppIcon"}
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"


def pubspec_version() -> tuple[str, str]:
    text = (ROOT / "pubspec.yaml").read_text()
    m = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", text, re.M)
    if not m:
        sys.exit("pubspec.yaml has no version like 2.0.0+100")
    return m.group(1), m.group(2)


def expected_id(flavor: str) -> str:
    return f"{APP_ID}.dev" if flavor == "dev" else APP_ID


class Checker:
    def __init__(self, what: str):
        self.what = what
        self.failures = 0
        self.lines: list[str] = []

    def eq(self, label: str, actual, expected) -> None:
        ok = actual == expected
        self.failures += 0 if ok else 1
        line = f"{'✓' if ok else '✗'} {label}: {actual!r}" + ("" if ok else f" (expected {expected!r})")
        self.lines.append(line)
        print("  " + line)

    def note(self, label: str, value: str) -> None:
        """A measured value for the record (P7 size budget), not a check."""
        line = f"· {label}: {value}"
        self.lines.append(line)
        print("  " + line)

    def done(self) -> int:
        verdict = "OK" if not self.failures else f"{self.failures} problem(s)"
        print(f"{self.what}: {verdict}")
        if os.environ.get("GITHUB_ACTIONS") == "true":
            # A notice annotation puts the checked values on the run's summary page.
            level = "notice" if not self.failures else "error"
            body = "%0A".join(line.replace("%", "%25") for line in self.lines)
            title = f"{self.what} {verdict}".replace("%", "%25").replace(":", "%3A").replace(",", "%2C")
            print(f"::{level} title={title}::{body}")
        return 1 if self.failures else 0


def find_aapt2() -> str:
    home = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT") or ""
    found = sorted(glob.glob(os.path.join(home, "build-tools", "*", "aapt2")))
    if not found:
        sys.exit("aapt2 not found; set ANDROID_HOME")
    return found[-1]


def android_apk(path: str, flavor: str) -> int:
    name, code = pubspec_version()
    out = subprocess.run(
        [find_aapt2(), "dump", "badging", path], check=True, capture_output=True, text=True
    ).stdout

    def field(pattern: str) -> str | None:
        m = re.search(pattern, out, re.M)
        return m.group(1) if m else None

    c = Checker(f"Android APK ({flavor})")
    c.eq("package", field(r"^package: name='([^']+)'"), expected_id(flavor))
    c.eq("versionCode", field(r"versionCode='(\d+)'"), code)
    c.eq("versionName", field(r"versionName='([^']+)'"), name)
    c.eq("minSdk", field(r"^(?:minSdkVersion|sdkVersion):'(\d+)'"), ANDROID_MIN_SDK)
    c.eq("targetSdk", field(r"^targetSdkVersion:'(\d+)'"), ANDROID_TARGET_SDK)
    c.eq("compileSdk", field(r"compileSdkVersion='(\d+)'"), ANDROID_TARGET_SDK)
    c.eq("launcher activity", field(r"^launchable-activity: name='([^']+)'"), LAUNCHER)
    c.eq("label", field(r"^application-label:'([^']*)'"), ANDROID_LABEL[flavor])
    c.eq("adaptive icon", field(r"^application-icon-65534:'([^']*)'"),
         "res/mipmap-anydpi-v26/ic_launcher.xml")
    perms = set(re.findall(r"^uses-permission: name='([^']+)'", out, re.M))
    for perm in REQUIRED_PERMISSIONS:
        c.eq(f"permission {perm.rsplit('.', 1)[-1]}", perm in perms, True)
    return c.done()


def android_aab(path: str, flavor: str) -> int:
    name, code = pubspec_version()
    jar = os.environ.get("BUNDLETOOL_JAR")
    if not jar:
        sys.exit("set BUNDLETOOL_JAR to bundletool-all.jar")
    xml = subprocess.run(
        ["java", "-jar", jar, "dump", "manifest", f"--bundle={path}"],
        check=True, capture_output=True, text=True,
    ).stdout
    root = ET.fromstring(xml)
    sdk = root.find("uses-sdk")
    app = root.find("application")
    launcher = None
    for act in app.findall("activity") if app is not None else []:
        for f in act.findall("intent-filter"):
            actions = {a.get(ANDROID_NS + "name") for a in f.findall("action")}
            cats = {a.get(ANDROID_NS + "name") for a in f.findall("category")}
            if "android.intent.action.MAIN" in actions and "android.intent.category.LAUNCHER" in cats:
                launcher = act.get(ANDROID_NS + "name")

    c = Checker(f"Android App Bundle ({flavor})")
    c.eq("package", root.get("package"), expected_id(flavor))
    c.eq("versionCode", root.get(ANDROID_NS + "versionCode"), code)
    c.eq("versionName", root.get(ANDROID_NS + "versionName"), name)
    c.eq("compileSdk", root.get(ANDROID_NS + "compileSdkVersion"), ANDROID_TARGET_SDK)
    c.eq("minSdk", sdk.get(ANDROID_NS + "minSdkVersion") if sdk is not None else None, ANDROID_MIN_SDK)
    c.eq("targetSdk", sdk.get(ANDROID_NS + "targetSdkVersion") if sdk is not None else None, ANDROID_TARGET_SDK)
    c.eq("launcher activity", launcher, LAUNCHER)
    c.eq("label", app.get(ANDROID_NS + "label") if app is not None else None, ANDROID_LABEL[flavor])
    c.eq("debuggable", app.get(ANDROID_NS + "debuggable", "false") if app is not None else None, "false")
    c.eq("icon set", bool(app is not None and app.get(ANDROID_NS + "icon")), True)
    c.eq("round icon set", bool(app is not None and app.get(ANDROID_NS + "roundIcon")), True)
    c.eq(
        "backup rules (recordings left out, F-113)",
        bool(app is not None and app.get(ANDROID_NS + "fullBackupContent")
             and app.get(ANDROID_NS + "dataExtractionRules")),
        True,
    )
    perms = {e.get(ANDROID_NS + "name") for e in root.findall("uses-permission")}
    for perm in REQUIRED_PERMISSIONS:
        c.eq(f"permission {perm.rsplit('.', 1)[-1]}", perm in perms, True)
    services = {
        e.get(ANDROID_NS + "name"): e.get(ANDROID_NS + "foregroundServiceType")
        for e in (app.findall("service") if app is not None else [])
    }
    # bundletool prints the flag value: mediaPlayback is 0x00000002.
    media_type = services.get("com.ryanheise.audioservice.AudioService")
    c.eq("media service", media_type in {"mediaPlayback", "0x00000002", "2"}, True)
    receivers = {e.get(ANDROID_NS + "name") for e in (app.findall("receiver") if app is not None else [])}
    c.eq("media button receiver", "com.ryanheise.audioservice.MediaButtonReceiver" in receivers, True)
    meta = {
        e.get(ANDROID_NS + "name"): e.get(ANDROID_NS + "value")
        for e in (app.findall("meta-data") if app is not None else [])
    }
    c.eq("AdMob app id", meta.get("com.google.android.gms.ads.APPLICATION_ID"),
         ADMOB_APP_ID["android"][flavor])
    c.note("bundle size (all ABIs; Play delivers less)", f"{os.path.getsize(path) / 1e6:.1f} MB")
    return c.done()


def ios_app(path: str, flavor: str) -> int:
    name, code = pubspec_version()
    with open(Path(path) / "Info.plist", "rb") as fh:
        info = plistlib.load(fh)
    c = Checker(f"iOS app ({flavor})")
    c.eq("CFBundleIdentifier", info.get("CFBundleIdentifier"), expected_id(flavor))
    c.eq("CFBundleShortVersionString", info.get("CFBundleShortVersionString"), name)
    c.eq("CFBundleVersion", info.get("CFBundleVersion"), code)
    c.eq("MinimumOSVersion", info.get("MinimumOSVersion"), IOS_MIN_OS)
    c.eq("CFBundleDisplayName", info.get("CFBundleDisplayName"), IOS_NAME[flavor])
    c.eq("ITSAppUsesNonExemptEncryption", info.get("ITSAppUsesNonExemptEncryption"), False)
    c.eq("privacy manifest", (Path(path) / "PrivacyInfo.xcprivacy").exists(), True)
    icon = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {}).get("CFBundleIconName")
    c.eq("app icon set", icon, IOS_ICON[flavor])
    c.eq("compiled asset catalog", (Path(path) / "Assets.car").exists(), True)
    c.eq("background audio", "audio" in info.get("UIBackgroundModes", []), True)
    c.eq("AdMob app id", info.get("GADApplicationIdentifier"), ADMOB_APP_ID["ios"][flavor])
    c.eq("SKAdNetwork ids", len(info.get("SKAdNetworkItems", [])) > 0, True)
    c.eq("no tracking prompt (A-11)", "NSUserTrackingUsageDescription" in info, False)
    app_bytes = sum(f.stat().st_size for f in Path(path).rglob("*") if f.is_file())
    c.note("app size on disk", f"{app_bytes / 1e6:.1f} MB")
    return c.done()


def main() -> int:
    if len(sys.argv) != 4 or sys.argv[1] not in {"android-apk", "android-aab", "ios-app"}:
        print(__doc__)
        return 2
    kind, path, flavor = sys.argv[1:]
    if flavor not in ANDROID_LABEL:
        sys.exit(f"unknown flavour {flavor}")
    return {"android-apk": android_apk, "android-aab": android_aab, "ios-app": ios_app}[kind](path, flavor)


if __name__ == "__main__":
    sys.exit(main())
