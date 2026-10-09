# Branding

The app icon (decision D-007, UX_UI_SPEC.md §3.1.1). Everything here, and every icon image in
`ios/` and `android/`, is generated. To change the icon, edit the drawing in
`tool/build_icons.py` and run:

```bash
pip install -r tool/requirements-icons.txt
python3 tool/build_icons.py
```

| File | Use |
|---|---|
| `preview.png` | Every variant at home-screen sizes, on light and dark wallpaper |
| `store/app-store-1024.png` | App Store Connect (opaque, no transparency) |
| `store/google-play-512.png` | Google Play Console → Store listing → App icon |
| `icon.svg` | The store icon as a vector |
| `icon-dark.svg`, `icon-tinted.svg` | iOS dark and tinted appearances |
| `icon-dev.svg`, `icon-staging.svg` | Test-build icons |
| `mark.svg` | The book alone on a transparent background (for the splash screen, the drawer header, the website) |

These files are not bundled into the app.
