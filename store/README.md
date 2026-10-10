# Store assets for 2.0

Everything the App Store and Google Play listings need, made from the app itself.

| Folder / file | What | Store slot |
|---|---|---|
| `screenshots/app-store/iphone-6.9/` | 8 screenshots, 1320 × 2868 | App Store Connect → iPhone 6.9" display (smaller iPhones use these, scaled) |
| `screenshots/app-store/ipad-13/` | 8 screenshots, 2064 × 2752 | App Store Connect → iPad 13" display (required: the app runs on iPad) |
| `screenshots/google-play/phone/` | 8 screenshots, 1080 × 1920 (9:16) | Play Console → Phone screenshots |
| `screenshots/google-play/tablet-7/` | 8 screenshots, 1080 × 1920 (9:16) | Play Console → 7-inch tablet screenshots |
| `screenshots/google-play/tablet-10/` | 8 screenshots, 1440 × 2560 (9:16) | Play Console → 10-inch tablet screenshots |
| `graphics/google-play-feature-graphic-1024x500.png` | Feature graphic, 1024 × 500 | Play Console → Feature graphic (required) |
| `../assets/branding/store/app-store-1024.png` | App icon, 1024 × 1024, no transparency | App Store Connect → App icon (comes from the build) |
| `../assets/branding/store/google-play-512.png` | App icon, 512 × 512 | Play Console → App icon |
| `previews/*.jpg` | One strip per device, for a quick look | — not for upload |
| `LISTING.md` | Names, subtitle, descriptions, keywords, what's new | Both stores |
| `PRIVACY.md` | App Store privacy label and Play Data safety answers | Both stores |

All images are PNG without transparency, which both stores accept. Upload them in the order of
their file names; the first three are the ones people see without scrolling.

## The eight screenshots

| # | Screen | Caption |
|---|---|---|
| 1 | Steps (iPad: with Step 4 beside the list) | Work the Twelve Steps |
| 2 | Step 4 guide (iPad: Readings with Just for Today) | Practical guidance for each step / Prayers and readings |
| 3 | The Big Book (iPad: with Chapter 5) | The Big Book |
| 4 | Audio, playing (iPad: with the Joe & Charlie album) | Over 90 hours of recovery audio |
| 5 | Player with transcript, dark | Listen and read along |
| 6 | Recovery card on Readings (iPad: the recovery date) | Count your days |
| 7 | Quote of the hour | A gentle reminder each hour |
| 8 | Chapter 5, dark (iPad: a story beside the 2nd-edition list) | Easy on the eyes, day or night |

The screens are the real app, rendered by Flutter at each device's size with its safe areas
(text in Inter on iOS standing in for San Francisco, which can't be bundled, and Roboto on
Android). The status bar, device frame and caption are added afterwards. Content shown is
the app's own: a sample recovery date of 14 March 2019 and a Premium user on the audio shots.

## Making them again

After a design change, from the repository folder:

```bash
flutter test test_screenshots/store_test.dart     # renders the raw screens into build/store_raw/
pip install -r tool/requirements-icons.txt
python3 tool/store_screenshots.py                 # writes screenshots/, graphics/ and previews/
```

Captions live in `CAPTIONS` at the top of `tool/store_screenshots.py`; the screens and their
order in `shotsFor` in `test_screenshots/store_test.dart`.
