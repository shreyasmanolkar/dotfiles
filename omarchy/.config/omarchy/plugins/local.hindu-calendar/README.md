# Hindu Calendar & Pañcāṅga for Omarchy

A compact, offline-first Omarchy 4.0 Quickshell bar widget for ordinary timekeeping and Hindu calendrical information. It replaces the visible Gregorian clock only after you enable it; a click opens the detail panel.

It is deliberately not a horoscope or prediction tool.

## What the widget shows

The bar stays compact:

```text
12:00 · 22 Aug · VS 2083
```

Clicking it opens two switchable views: **Pañcāṅga** and a familiar **Gregorian Calendar**. The calendar view has previous/next month controls, highlights today, and lets you select a civil date. The Pañcāṅga view contains:

- Gregorian date, local time, IANA time zone, configured place, and Vikrama Saṁvat year;
- Vāra, Tithi, Pakṣa, Nakṣatra, Yoga, Karaṇa, lunar Māsa, and sidereal solar Māsa;
- a live vector cycle diagram showing the schematic annual Pṛthvī position, Candra around Pṛthvī, 27 nakṣatra divisions, and the current illuminated lunar phase;
- sunrise/sunset, moonrise/moonset, illumination estimate, and next Saṅkrānti;
- Rāhu Kāla, Yamaganda, Gulika Kāla, Abhijit Muhūrta, and Brahma Muhūrta;
- optional sunrise-proportional Prahara, Muhūrta, Ghaṭī, Kalā, and Kāṣṭhā.

Left click opens the panel; middle click refreshes the local calculation; `R` refreshes while the panel is open. The clock itself updates once a minute; the astronomy engine runs at startup and every 15 minutes, so it has negligible idle cost.

## Install

This plugin targets the installed **Omarchy 4.x Quickshell** plugin API—not Waybar or Eww. It is user-owned and never writes to `/usr/share/omarchy`.

```bash
cd ~/dotfiles/omarchy/.config/omarchy/plugins/local.hindu-calendar
bash install.sh
```

The installer:

1. links the plugin into `~/.config/omarchy/plugins/local.hindu-calendar`;
2. creates `~/.config/omarchy/hindu-calendar.json` only when it does not already exist;
3. creates an isolated virtual environment under `~/.local/share/omarchy-hindu-calendar/venv` and installs the pinned `pyswisseph` dependency.

Then edit the user configuration with your exact coordinates. Do not leave the sample `null` values in place.

```bash
$EDITOR ~/.config/omarchy/hindu-calendar.json
omarchy-shell shell rescanPlugins
omarchy plugin enable local.hindu-calendar --section center --index 1
omarchy plugin disable omarchy.clock
```

The last command disables, rather than edits, the packaged clock; it survives Omarchy updates. To return to the stock clock:

```bash
omarchy plugin disable local.hindu-calendar
omarchy plugin enable omarchy.clock --section center --index 1
```

If the widget is enabled but your running shell does not discover it, run `omarchy restart shell` after the rescan.

## Configuration

`~/.config/omarchy/hindu-calendar.json` is private user configuration and intentionally not committed to dotfiles. Start with [`config.example.json`](config.example.json).

```json
{
  "location": {
    "name": "Kolkata, India",
    "latitude": 22.5726,
    "longitude": 88.3639,
    "elevation_m": 9
  },
  "timezone": "Asia/Kolkata",
  "calendar": {
    "lunar_month_convention": "amanta",
    "vikram_samvat_convention": "chaitradi",
    "ayanamsha": "lahiri",
    "sunrise_mode": "geometric_center"
  },
  "display": {
    "use_24_hour_time": true,
    "show_devanagari": true,
    "traditional_time": "sunrise_proportional"
  }
}
```

| Setting | Meaning |
| --- | --- |
| `location.latitude`, `location.longitude` | Required WGS-84 coordinates. They determine rising/setting and all day-part windows. |
| `location.elevation_m` | Optional elevation in metres passed to the rising/setting calculation. |
| `timezone` | Required IANA zone (for example `Asia/Kolkata`), not merely a UTC offset. |
| `lunar_month_convention` | `amanta` starts after Amāvasyā; `purnimanta` starts after Pūrṇimā and renames the Kṛṣṇa half accordingly. |
| `vikram_samvat_convention` | `chaitradi` rolls over at the locally calculated Caitra new moon; `kartakadi` at Kārtika new moon. |
| `ayanamsha` | Currently accepts `lahiri`/`chitrapaksha`, the same explicit Lahiri selection. |
| `sunrise_mode` | `geometric_center` uses centre-disc/no-refraction geometry; `observed_upper_limb` uses the Swiss Ephemeris observational default. Pick the convention used by your reference almanac. |
| `traditional_time` | `off` or `sunrise_proportional`. This affects only the explanatory traditional-time section. |

The widget shows **Pañcāṅga unavailable** rather than inventing results when the location, time zone, or ephemeris dependency is missing.

## Calendar Methodology

The design draws its practical scope from Alok Mandavgane’s Hindu Calendar: an offline, location-aware presentation of Pañcāṅga, Amānta/Pūrṇimānta choice, Vikram/Kārtak year choices, rising/setting, and the eight-prahara Hindu clock. It does not copy that product’s UI or call/scrape its service.

Astronomical inputs are calculated locally with the pinned [`pyswisseph`](https://pypi.org/project/pyswisseph/) binding to Swiss Ephemeris. The engine explicitly selects Lahiri/Chitrapakṣa sidereal mode and obtains apparent geocentric Sun and Moon longitudes. Its method is:

- **Tithi:** Moon–Sun sidereal elongation in 12° increments; **Karaṇa:** its 6° half.
- **Nakṣatra:** sidereal lunar longitude in 27 equal 13°20′ arcs.
- **Cycle diagram:** its Sun/Moon markers use calculated ecliptic longitudes. The inner band names the twelve Lahiri Saura Māsa/rāśi sectors from Meṣa through Mīna and accents the current one. The outer band labels all 27 nakṣatra divisions and accents the current one; long Pūrvā/Uttarā names are compacted as `P.`/`U.` on the ring while the full current name remains below it. The displayed annual Pṛthvī marker is the sidereal Sun plus 180° so it shares the labelled ring’s reference frame (the tropical equivalent is also emitted by the engine). This is an explanatory orientation—not a scaled orbit or a three-dimensional sky map. The lunar disc is drawn from Moon–Sun elongation, with approximate illumination `(1 − cos(elongation)) / 2`; its “day” is a phase-angle projection onto the mean 29.530588853-day synodic month.
- **Yoga:** normalized sum of sidereal Sun and Moon longitudes in the same 27 arcs.
- **Māsa:** new-moon-bound lunar month. It detects an **Adhika Māsa** when the Sun stays in one sidereal sign across two successive new moons. The Pūrṇimānta option assigns the Kṛṣṇa half to the following named month.
- **Vikrama Saṁvat:** the engine calculates the selected local Caitra or Kārtika new-moon boundary for that Gregorian year. It does not use a universal `Gregorian year + 57` shortcut.
- **Saṅkrānti:** next crossing of the Sun into a sidereal 30° rāśi.
- **Sun/Moon rises and sets:** Swiss Ephemeris `rise_trans` at the configured longitude, latitude, elevation, and time zone. Different Pañcāṅgas may choose centre-disc/geometric or upper-limb/observational rising; select the one appropriate to your tradition/reference.
- **Rāhu, Yamaganda, and Gulika:** traditional weekday-specific eighths of the calculated daylight. Abhijit is the central fifteenth of daylight. Brahma Muhūrta is the penultimate fifteenth of the calculated night. Regional practice can differ.

`sunrise_proportional` traditional time is a clearly labelled display convention: sunrise→sunset and sunset→next sunrise each contain 30 Ghaṭīs (60 per ahorātra); it renders 15 daytime and 15 nighttime Muhūrtas and eight Praharas. For its optional educational subdivision it uses **1 Ghaṭī = 30 Kalā** and **1 Kalā = 30 Kāṣṭhā**. These are not presented as SI-clock replacements and historical definitions vary.

Pañcāṅga rows describe the value at the present instant and show their next transition. Festival determination and vrata rules often depend on **tithi at sunrise** plus locality- and tradition-specific vyāpti/tie-break rules. The small built-in observance hints (Ekādaśī, Pūrṇimā, Amāvasyā) are not a festival database and must not be treated as a complete regional observance calendar.

## Project layout

```text
local.hindu-calendar/
├── BarWidget.qml                 # fast compact clock + cached subprocess trigger
├── Panel.qml                     # Omarchy-native click popup
├── manifest.json                 # Quickshell bar-widget registration
├── config.example.json           # no private location data
├── requirements.txt
├── install.sh
├── engine/
│   ├── launch.sh
│   └── panchang.py               # astronomy, calendar, samvat, traditional time
└── tests/
    ├── kolkata.json
    └── test_panchang.py
```

The engine’s JSON boundary keeps astronomy/calendar work independent of the QML UI. Future additions can safely add a festival-rule provider, date-range/month summaries, saved locations, regional solar calendars, Shaka/Bengali/Tamil systems, notifications, or ICS without coupling those concerns to the bar.

## Test and validate

Use the same isolated environment the installer creates:

```bash
~/.local/share/omarchy-hindu-calendar/venv/bin/python tests/test_panchang.py
omarchy plugin validate .
```

The regression suite covers a fixed Kolkata Pañcāṅga snapshot, a non-flat Vikrama Saṁvat boundary, Amānta/Pūrṇimānta naming, an Adhika Śrāvaṇa, location-dependent rise/window changes, and missing-coordinate failure behaviour. Before changing ephemeris versions or methodology, cross-check transition instants with the selected regional reference Pañcāṅga; visual agreement alone is not a validation strategy.

## Troubleshooting

- **Only Gregorian time appears / panel says unavailable:** add numeric latitude and longitude to `~/.config/omarchy/hindu-calendar.json`, then press `R` in the panel.
- **“Swiss Ephemeris … not installed”:** rerun `bash install.sh`; it creates the isolated virtual environment.
- **Widget is not listed:** run `omarchy-shell shell rescanPlugins`, then `omarchy plugin enable local.hindu-calendar --section center --index 1`.
- **Times disagree with a preferred calendar:** first compare location, elevation, IANA time zone, Amānta/Pūrṇimānta choice, and sunrise mode. Those are methodological differences, not cosmetic settings.
- **Need the normal clock back:** use the two restore commands in the Installation section. No packaged Omarchy code has been modified.

## License and attribution

Swiss Ephemeris is dual-licensed; review its [licensing terms](https://www.astro.com/swisseph/swephinfo_e.htm) before redistributing this plugin or bundling ephemeris data. This repository declares no additional license yet. Hindu Calendar by Alok Mandavgane is acknowledged as a terminology and feature-scope reference; this implementation is independent local code.
