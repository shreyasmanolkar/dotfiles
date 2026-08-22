#!/usr/bin/env python3
"""Local, location-aware Hindu calendar and Pañcāṅga calculations.

The engine deliberately has a small boundary: it receives a JSON configuration
and returns one JSON document.  QML never performs astronomy itself.  Swiss
Ephemeris provides apparent geocentric Sun/Moon longitudes; Pañcāṅga elements
use their sidereal (nirāyaṇa) Lahiri/Chitrapakṣa positions.

This is a calendrical/timekeeping component.  It has no horoscope, prediction,
or network provider.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Callable, Iterable, Mapping, Sequence
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

try:
    import swisseph as swe
except ModuleNotFoundError:  # handled by main so the widget keeps its clock
    swe = None


ENGINE_VERSION = "0.1.0"
DEGREE = 360.0
TITHI_SPAN = 12.0
NAKSHATRA_SPAN = DEGREE / 27.0
EPSILON_DEG = 1e-8

VARA = [
    ("Ravivāra", "रविवार"), ("Somavāra", "सोमवार"), ("Maṅgalavāra", "मङ्गलवार"),
    ("Budhavāra", "बुधवार"), ("Guruvāra", "गुरुवार"), ("Śukravāra", "शुक्रवार"),
    ("Śanivāra", "शनिवार"),
]

TITHIS = [
    "Pratipadā", "Dvitīyā", "Tṛtīyā", "Caturthī", "Pañcamī", "Ṣaṣṭhī", "Saptamī", "Aṣṭamī",
    "Navamī", "Daśamī", "Ekādaśī", "Dvādaśī", "Trayodaśī", "Caturdaśī", "Pūrṇimā",
    "Pratipadā", "Dvitīyā", "Tṛtīyā", "Caturthī", "Pañcamī", "Ṣaṣṭhī", "Saptamī", "Aṣṭamī",
    "Navamī", "Daśamī", "Ekādaśī", "Dvādaśī", "Trayodaśī", "Caturdaśī", "Amāvasyā",
]
TITHI_DEVANAGARI = [
    "प्रतिपदा", "द्वितीया", "तृतीया", "चतुर्थी", "पञ्चमी", "षष्ठी", "सप्तमी", "अष्टमी",
    "नवमी", "दशमी", "एकादशी", "द्वादशी", "त्रयोदशी", "चतुर्दशी", "पूर्णिमा",
    "प्रतिपदा", "द्वितीया", "तृतीया", "चतुर्थी", "पञ्चमी", "षष्ठी", "सप्तमी", "अष्टमी",
    "नवमी", "दशमी", "एकादशी", "द्वादशी", "त्रयोदशी", "चतुर्दशी", "अमावस्या",
]
NAKSHATRAS = [
    "Aśvinī", "Bharaṇī", "Kṛttikā", "Rohiṇī", "Mṛgaśīrṣa", "Ārdrā", "Punarvasu", "Puṣya", "Āśleṣā",
    "Maghā", "Pūrvaphalgunī", "Uttaraphalgunī", "Hastā", "Citrā", "Svātī", "Viśākhā", "Anurādhā",
    "Jyeṣṭhā", "Mūlā", "Pūrvāṣāḍhā", "Uttarāṣāḍhā", "Śravaṇā", "Dhaniṣṭhā", "Śatabhiṣaj",
    "Pūrvabhādrapadā", "Uttarabhādrapadā", "Revatī",
]
YOGAS = [
    "Viṣkambha", "Prīti", "Āyuṣmān", "Saubhāgya", "Śobhana", "Atigaṇḍa", "Sukarmā", "Dhṛti", "Śūla",
    "Gaṇḍa", "Vṛddhi", "Dhruva", "Vyāghāta", "Harṣaṇa", "Vajra", "Siddhi", "Vyatīpāta", "Varīyān",
    "Parigha", "Śiva", "Siddha", "Sādhya", "Śubha", "Śukla", "Brahmā", "Aindra", "Vaidhṛti",
]
KARANA_CYCLE = ["Bava", "Bālava", "Kaulava", "Taitila", "Gara", "Vāṇija", "Viṣṭi"]
SOLAR_RASIS = [
    "Meṣa", "Vṛṣabha", "Mithuna", "Karka", "Siṁha", "Kanyā", "Tulā", "Vṛścika", "Dhanuṣ",
    "Makara", "Kumbha", "Mīna",
]
# The lunar month between two new moons is named for the sidereal solar sign
# at its new moon.  Mīna at the new moon gives Caitra, Meṣa gives Vaiśākha.
LUNAR_MONTH_FOR_SUN_RASI = [
    "Vaiśākha", "Jyeṣṭha", "Āṣāḍha", "Śrāvaṇa", "Bhādrapada", "Āśvina", "Kārtika", "Mārgaśīrṣa",
    "Pauṣa", "Māgha", "Phālguna", "Caitra",
]


class ConfigError(ValueError):
    """A user-readable configuration error; no calendar data is emitted."""


def normalize(value: float) -> float:
    return value % DEGREE


def fmt_num(value: float, precision: int = 2) -> float:
    return round(float(value), precision)


def lunar_phase_name(phase: float) -> str:
    """Return the familiar eight-part phase name for an elongation angle."""
    angle = normalize(phase)
    if angle < 22.5 or angle >= 337.5:
        return "New Moon"
    if angle < 67.5:
        return "Waxing Crescent"
    if angle < 112.5:
        return "First Quarter"
    if angle < 157.5:
        return "Waxing Gibbous"
    if angle < 202.5:
        return "Full Moon"
    if angle < 247.5:
        return "Waning Gibbous"
    if angle < 292.5:
        return "Last Quarter"
    return "Waning Crescent"


def local_iso(moment: datetime) -> str:
    return moment.isoformat(timespec="minutes")


def utc_julian(moment: datetime) -> float:
    utc = moment.astimezone(timezone.utc)
    hour = utc.hour + utc.minute / 60 + utc.second / 3600 + utc.microsecond / 3.6e9
    return swe.julday(utc.year, utc.month, utc.day, hour, swe.GREG_CAL)


def julian_to_local(jd: float, tz: ZoneInfo) -> datetime:
    year, month, day, hour_float = swe.revjul(jd, swe.GREG_CAL)
    hour = int(hour_float)
    minute_float = (hour_float - hour) * 60
    minute = int(minute_float)
    second = int(round((minute_float - minute) * 60))
    base = datetime(year, month, day, hour, minute, 0, tzinfo=timezone.utc)
    return (base + timedelta(seconds=second)).astimezone(tz)


def row(label: str, value: str, devanagari: str = "", ends: str = "", tooltip: str = "") -> dict:
    return {"label": label, "value": value, "devanagari": devanagari, "ends": ends, "tooltip": tooltip}


@dataclass(frozen=True)
class Settings:
    name: str
    latitude: float
    longitude: float
    elevation_m: float
    tz: ZoneInfo
    lunar_month_convention: str
    samvat_convention: str
    ayanamsha: str
    sunrise_mode: str
    use_24_hour_time: bool
    show_devanagari: bool
    traditional_time: str


def load_settings(path: Path) -> Settings:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ConfigError(f"Configuration file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ConfigError(f"Configuration is not valid JSON: {exc.msg}") from exc

    location = raw.get("location") if isinstance(raw, Mapping) else None
    if not isinstance(location, Mapping):
        raise ConfigError("location must contain name, latitude, and longitude")
    try:
        latitude = float(location.get("latitude"))
        longitude = float(location.get("longitude"))
        elevation = float(location.get("elevation_m", 0))
    except (TypeError, ValueError) as exc:
        raise ConfigError("Set a numeric latitude and longitude before calculating Pañcāṅga") from exc
    if not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
        raise ConfigError("latitude must be −90…90 and longitude must be −180…180")
    name = str(location.get("name") or "Custom location").strip()

    timezone_name = str(raw.get("timezone") or "").strip()
    try:
        tz = ZoneInfo(timezone_name)
    except ZoneInfoNotFoundError as exc:
        raise ConfigError("timezone must be a valid IANA name such as Asia/Kolkata") from exc

    calendar = raw.get("calendar") or {}
    display = raw.get("display") or {}
    lunar = str(calendar.get("lunar_month_convention", "amanta")).lower()
    if lunar not in {"amanta", "purnimanta"}:
        raise ConfigError("calendar.lunar_month_convention must be amanta or purnimanta")
    samvat = str(calendar.get("vikram_samvat_convention", "chaitradi")).lower()
    if samvat not in {"chaitradi", "kartakadi"}:
        raise ConfigError("calendar.vikram_samvat_convention must be chaitradi or kartakadi")
    ayanamsha = str(calendar.get("ayanamsha", "lahiri")).lower()
    if ayanamsha not in {"lahiri", "chitrapaksha"}:
        raise ConfigError("calendar.ayanamsha must be lahiri or chitrapaksha")
    sunrise_mode = str(calendar.get("sunrise_mode", "geometric_center")).lower()
    if sunrise_mode not in {"geometric_center", "observed_upper_limb"}:
        raise ConfigError("calendar.sunrise_mode must be geometric_center or observed_upper_limb")
    traditional_time = str(display.get("traditional_time", "sunrise_proportional")).lower()
    if traditional_time not in {"off", "sunrise_proportional"}:
        raise ConfigError("display.traditional_time must be off or sunrise_proportional")

    return Settings(
        name=name, latitude=latitude, longitude=longitude, elevation_m=elevation, tz=tz,
        lunar_month_convention=lunar, samvat_convention=samvat, ayanamsha=ayanamsha,
        sunrise_mode=sunrise_mode, use_24_hour_time=bool(display.get("use_24_hour_time", True)),
        show_devanagari=bool(display.get("show_devanagari", True)), traditional_time=traditional_time,
    )


class PanchangEngine:
    def __init__(self, settings: Settings):
        self.settings = settings
        # Lahiri is explicitly selected, rather than silently relying on the
        # Swiss Ephemeris process default.  "Chitrapaksha" is a common name
        # for the same selection in calendar UIs.
        swe.set_sid_mode(swe.SIDM_LAHIRI, 0.0, 0.0)
        self.flags = swe.FLG_SWIEPH | swe.FLG_SIDEREAL | swe.FLG_SPEED

    def longitude(self, jd: float, body: int) -> float:
        return normalize(swe.calc_ut(jd, body, self.flags)[0][0])

    def tropical_longitude(self, jd: float, body: int) -> float:
        """Geocentric tropical ecliptic longitude used by the cycle diagram."""
        flags = swe.FLG_SWIEPH | swe.FLG_SPEED
        return normalize(swe.calc_ut(jd, body, flags)[0][0])

    def positions(self, jd: float) -> tuple[float, float]:
        return self.longitude(jd, swe.SUN), self.longitude(jd, swe.MOON)

    def phase(self, jd: float) -> float:
        sun, moon = self.positions(jd)
        return normalize(moon - sun)

    @staticmethod
    def _forward_distance(start: float, end: float) -> float:
        return normalize(end - start)

    def _progress_since(self, jd: float, candidate: float, signal: Callable[[float], float]) -> float:
        """Unwrap a forward angle from jd to candidate.

        A 35-day new-moon search can cross 0° once.  Comparing only its
        endpoints would turn (say) 113° → 474° into 1°; sampling every six
        hours retains the completed revolution while keeping this rare search
        inexpensive.
        """
        span_days = max(0.0, candidate - jd)
        steps = max(1, int(math.ceil(span_days * 4)))
        previous = signal(jd)
        total = 0.0
        for index in range(1, steps + 1):
            current = signal(jd + span_days * index / steps)
            total += self._forward_distance(previous, current)
            previous = current
        return total

    def _next_progress_boundary(
        self,
        jd: float,
        span: float,
        signal: Callable[[float], float],
        max_hours: float,
    ) -> float:
        """Return the next multiple of span reached by a locally increasing angle.

        The Sun/Moon phase, lunar longitude, and Sun+Moon yoga angle all move
        monotonically forward over the modest searches used here.  The binary
        search avoids arbitrary "average tithi duration" assumptions.
        """
        base = signal(jd)
        remainder = base % span
        needed = span - remainder if remainder > EPSILON_DEG else span
        low, high = jd, jd + max_hours / 24
        target = needed
        if self._progress_since(jd, high, signal) < target:
            raise RuntimeError("could not bracket the next astronomical transition")
        for _ in range(45):
            mid = (low + high) / 2
            if self._progress_since(jd, mid, signal) >= target:
                high = mid
            else:
                low = mid
        return high

    def next_tithi(self, jd: float) -> float:
        return self._next_progress_boundary(jd, TITHI_SPAN, self.phase, 40)

    def next_nakshatra(self, jd: float) -> float:
        return self._next_progress_boundary(jd, NAKSHATRA_SPAN, lambda x: self.longitude(x, swe.MOON), 36)

    def next_yoga(self, jd: float) -> float:
        return self._next_progress_boundary(
            jd, NAKSHATRA_SPAN,
            lambda x: normalize(self.longitude(x, swe.SUN) + self.longitude(x, swe.MOON)), 36,
        )

    def next_karana(self, jd: float) -> float:
        return self._next_progress_boundary(jd, 6.0, self.phase, 24)

    def next_new_moon(self, jd: float) -> float:
        base = self.phase(jd)
        needed = DEGREE - base if base > EPSILON_DEG else DEGREE
        low, high = jd, jd + 35
        if self._progress_since(jd, high, self.phase) < needed:
            raise RuntimeError("could not bracket the next new moon")
        for _ in range(50):
            mid = (low + high) / 2
            if self._progress_since(jd, mid, self.phase) >= needed:
                high = mid
            else:
                low = mid
        return high

    def previous_new_moon(self, jd: float) -> float:
        # Start a little more than one lunation back, then walk conjunctions
        # forward.  A single "now − 31 days" lookup is wrong during a long
        # lunation: it can land on the new moon *before* the immediate one.
        candidate = self.next_new_moon(jd - 32)
        for _ in range(3):
            following = self.next_new_moon(candidate + 0.01)
            if following > jd + 1e-7:
                return candidate
            candidate = following
        raise RuntimeError("could not locate the preceding new moon")

    def next_sankranti(self, jd: float) -> float:
        return self._next_progress_boundary(jd, 30.0, lambda x: self.longitude(x, swe.SUN), 36 * 24)

    def rise_set(self, civil_day: date, body: int, rise: bool) -> datetime | None:
        start = datetime(civil_day.year, civil_day.month, civil_day.day, tzinfo=self.settings.tz)
        rsmi = swe.CALC_RISE if rise else swe.CALC_SET
        if self.settings.sunrise_mode == "geometric_center":
            rsmi |= swe.BIT_DISC_CENTER | swe.BIT_NO_REFRACTION
        # Swiss Ephemeris consumes longitude, latitude, elevation in metres.
        result, times = swe.rise_trans(
            utc_julian(start), body, rsmi,
            (self.settings.longitude, self.settings.latitude, self.settings.elevation_m),
            0.0, 0.0, swe.FLG_SWIEPH,
        )
        if result < 0:
            return None
        return julian_to_local(times[0], self.settings.tz)

    def sun_windows(self, civil_day: date) -> tuple[datetime, datetime, datetime]:
        sunrise = self.rise_set(civil_day, swe.SUN, True)
        sunset = self.rise_set(civil_day, swe.SUN, False)
        next_sunrise = self.rise_set(civil_day + timedelta(days=1), swe.SUN, True)
        if not sunrise or not sunset or not next_sunrise:
            raise RuntimeError("Sunrise/sunset is unavailable at this location/date")
        return sunrise, sunset, next_sunrise

    def lunar_month(self, jd: float, paksha: str) -> dict:
        previous = self.previous_new_moon(jd)
        following = self.next_new_moon(previous + 0.01)
        sign_previous = int(self.longitude(previous + 0.001, swe.SUN) // 30)
        sign_following = int(self.longitude(following + 0.001, swe.SUN) // 30)
        adhika = sign_previous == sign_following
        kshaya = (sign_following - sign_previous) % 12 > 1
        name_index = sign_previous
        if self.settings.lunar_month_convention == "purnimanta" and paksha == "Kṛṣṇa":
            name_index = (name_index + 1) % 12
        return {
            "name": LUNAR_MONTH_FOR_SUN_RASI[name_index],
            "adhika": adhika,
            "kshaya": kshaya,
            "convention": self.settings.lunar_month_convention,
            "new_moon": local_iso(julian_to_local(previous, self.settings.tz)),
            "next_new_moon": local_iso(julian_to_local(following, self.settings.tz)),
        }

    def samvat_year_start(self, gregorian_year: int, month_name: str) -> datetime:
        start = datetime(gregorian_year, 1, 1, tzinfo=self.settings.tz)
        cursor = self.next_new_moon(utc_julian(start) - 0.01)
        for _ in range(15):
            sign = int(self.longitude(cursor + 0.001, swe.SUN) // 30)
            if LUNAR_MONTH_FOR_SUN_RASI[sign] == month_name:
                return julian_to_local(cursor, self.settings.tz)
            cursor = self.next_new_moon(cursor + 0.05)
        raise RuntimeError("could not locate the Vikrama Saṁvat year boundary")

    def vikram_samvat(self, local_now: datetime) -> dict:
        boundary_month = "Caitra" if self.settings.samvat_convention == "chaitradi" else "Kārtika"
        boundary = self.samvat_year_start(local_now.year, boundary_month)
        year = local_now.year + (57 if local_now >= boundary else 56)
        return {
            "year": year,
            "convention": "Caitrādi" if self.settings.samvat_convention == "chaitradi" else "Kārtakādi",
            "boundary": local_iso(boundary),
        }

    def traditional_time(self, now: datetime, sunrise: datetime, sunset: datetime, next_sunrise: datetime) -> dict | None:
        if self.settings.traditional_time == "off":
            return None
        if now < sunrise:
            # Fetch prior-day data only in the short interval after midnight.
            prior_sunrise, prior_sunset, _ = self.sun_windows(now.date() - timedelta(days=1))
            sunrise, sunset, next_sunrise = prior_sunrise, prior_sunset, sunrise
        if now < sunset:
            span = (sunset - sunrise).total_seconds()
            ghaṭī = max(0.0, min(30.0, (now - sunrise).total_seconds() / span * 30))
            segment = "day"
        else:
            span = (next_sunrise - sunset).total_seconds()
            ghaṭī = 30.0 + max(0.0, min(30.0, (now - sunset).total_seconds() / span * 30))
            segment = "night"
        muhurta = min(30, int(ghaṭī // 2) + 1)
        prahara = min(8, int(ghaṭī // 7.5) + 1)
        kala = min(29, int((ghaṭī % 1) * 30))
        kashtha = min(29, int((((ghaṭī % 1) * 30) % 1) * 30))
        return {
            "mode": "Sunrise-proportional 60-ghaṭī day",
            "segment": segment,
            "prahara": prahara,
            "muhurta": muhurta,
            "ghati": int(ghaṭī),
            "kala": kala,
            "kashtha": kashtha,
            "tooltip": "A location-dependent display: sunrise→sunset and sunset→next sunrise are each divided into 30 ghaṭīs. Kalā and kāṣṭhā use this plugin’s configured 30:30 educational subdivision.",
        }

    def build(self, now: datetime) -> dict:
        local_now = now.astimezone(self.settings.tz)
        jd = utc_julian(local_now)
        sun, moon = self.positions(jd)
        phase = normalize(moon - sun)
        tropical_sun = self.tropical_longitude(jd, swe.SUN)
        tropical_moon = self.tropical_longitude(jd, swe.MOON)
        tithi_index = int(phase // TITHI_SPAN)
        paksha = "Śukla" if tithi_index < 15 else "Kṛṣṇa"
        nak_index = int(moon // NAKSHATRA_SPAN)
        yoga_index = int(normalize(sun + moon) // NAKSHATRA_SPAN)
        karana_index = int(phase // 6)
        if karana_index == 0:
            karana = "Kiṁstughna"
        elif karana_index <= 56:
            karana = KARANA_CYCLE[(karana_index - 1) % len(KARANA_CYCLE)]
        else:
            karana = ["Śakuni", "Catuṣpāda", "Nāga"][karana_index - 57]

        sunrise, sunset, next_sunrise = self.sun_windows(local_now.date())
        moonrise = self.rise_set(local_now.date(), swe.MOON, True)
        moonset = self.rise_set(local_now.date(), swe.MOON, False)
        tithi_end = julian_to_local(self.next_tithi(jd), self.settings.tz)
        nak_end = julian_to_local(self.next_nakshatra(jd), self.settings.tz)
        yoga_end = julian_to_local(self.next_yoga(jd), self.settings.tz)
        karana_end = julian_to_local(self.next_karana(jd), self.settings.tz)
        masa = self.lunar_month(jd, paksha)
        samvat = self.vikram_samvat(local_now)
        next_sankranti = julian_to_local(self.next_sankranti(jd), self.settings.tz)
        next_sign = int(self.longitude(utc_julian(next_sankranti) + 0.001, swe.SUN) // 30)
        solar_sign = int(sun // 30)

        weekday = (local_now.weekday() + 1) % 7  # datetime: Monday=0; Vara: Sunday=0
        day_seconds = (sunset - sunrise).total_seconds()
        eighth = day_seconds / 8
        rahu_slot = [7, 1, 6, 4, 5, 3, 2][weekday]
        yama_slot = [4, 3, 2, 1, 0, 6, 5][weekday]
        gulika_slot = [6, 5, 4, 3, 2, 1, 0][weekday]
        interval = lambda slot: (sunrise + timedelta(seconds=eighth * slot), sunrise + timedelta(seconds=eighth * (slot + 1)))
        rahu, yama, gulika = interval(rahu_slot), interval(yama_slot), interval(gulika_slot)
        abhijit = (sunrise + timedelta(seconds=day_seconds * 7 / 15), sunrise + timedelta(seconds=day_seconds * 8 / 15))
        brahma = (next_sunrise - (next_sunrise - sunset) / 15 * 2, next_sunrise - (next_sunrise - sunset) / 15)

        observances: list[str] = []
        if tithi_index in {10, 25}:
            observances.append("Ekādaśī — verify local sunrise observance rules before fasting")
        elif tithi_index == 14:
            observances.append("Pūrṇimā")
        elif tithi_index == 29:
            observances.append("Amāvasyā")

        time_format = "%H:%M" if self.settings.use_24_hour_time else "%I:%M %p"
        clock = local_now.strftime(time_format)
        if not self.settings.use_24_hour_time:
            clock = clock.lstrip("0")
        compact = f"{clock} · {local_now.strftime('%d %b')} · VS {samvat['year']}"
        masa_text = ("Adhika " if masa["adhika"] else "") + masa["name"]
        panchang_rows = [
            row("Vāra", VARA[weekday][0], VARA[weekday][1], tooltip="Weekday at the configured location."),
            row("Tithi", f"{paksha} {TITHIS[tithi_index]}", TITHI_DEVANAGARI[tithi_index], local_iso(tithi_end), "12° of elongation between the Moon and Sun."),
            row("Pakṣa", paksha, "शुक्ल पक्ष" if paksha == "Śukla" else "कृष्ण पक्ष"),
            row("Nakṣatra", NAKSHATRAS[nak_index], "", local_iso(nak_end), "Moon’s sidereal longitude divided into 27 equal parts."),
            row("Yoga", YOGAS[yoga_index], "", local_iso(yoga_end), "Sum of sidereal Sun and Moon longitudes divided into 27 equal parts."),
            row("Karaṇa", karana, "", local_iso(karana_end), "Half of a tithi; the sequence is calculated at this instant."),
            row("Māsa", masa_text, "", tooltip=f"{masa['convention'].title()} lunar-month convention."),
            row("Saura māsa", SOLAR_RASIS[solar_sign], "", tooltip="Sidereal solar sign; the solar-calendar layer."),
        ]
        if not self.settings.show_devanagari:
            for item in panchang_rows:
                item["devanagari"] = ""

        return {
            "status": "ok",
            "engine": {"name": "Swiss Ephemeris", "version": swe.version, "calendar_engine_version": ENGINE_VERSION, "ayanamsha": "Lahiri / Chitrapakṣa", "offline": True},
            "generated_at": local_iso(local_now),
            "compact": compact,
            "display": {"use_24_hour_time": self.settings.use_24_hour_time, "show_devanagari": self.settings.show_devanagari},
            "header": {
                "gregorian": local_now.strftime("%A, %-d %B %Y"),
                "time": clock,
                "timezone": str(self.settings.tz),
                "location": self.settings.name,
                "vikram_samvat": samvat,
            },
            "panchang": panchang_rows,
            "solar_lunar": {
                "sunrise": local_iso(sunrise), "sunset": local_iso(sunset), "next_sunrise": local_iso(next_sunrise),
                "moonrise": local_iso(moonrise) if moonrise else None, "moonset": local_iso(moonset) if moonset else None,
                "phase_degrees": fmt_num(phase),
                "phase_name": lunar_phase_name(phase),
                "phase_age_approx_days": fmt_num(phase / DEGREE * 29.530588853, 1),
                "waxing": phase < 180.0,
                "illumination_approx": fmt_num((1 - math.cos(math.radians(phase))) / 2 * 100, 1),
                "positions": {
                    "sun_sidereal_degrees": fmt_num(sun),
                    "moon_sidereal_degrees": fmt_num(moon),
                    "sun_tropical_degrees": fmt_num(tropical_sun),
                    "moon_tropical_degrees": fmt_num(tropical_moon),
                    # The displayed annual ring is labelled with Lahiri sidereal
                    # solar months, so its Earth marker uses the same reference.
                    # The tropical equivalent remains available to consumers.
                    "earth_orbit_degrees": fmt_num(normalize(sun + 180.0)),
                    "earth_orbit_tropical_degrees": fmt_num(normalize(tropical_sun + 180.0)),
                    "reference": "Geocentric ecliptic longitudes; annual Earth markers are schematic",
                },
                "sankranti": {"name": f"{SOLAR_RASIS[next_sign]} Saṅkrānti", "at": local_iso(next_sankranti)},
            },
            "muhurta": {
                "rahu_kalam": [local_iso(rahu[0]), local_iso(rahu[1])],
                "yamaganda": [local_iso(yama[0]), local_iso(yama[1])],
                "gulika_kalam": [local_iso(gulika[0]), local_iso(gulika[1])],
                "abhijit_muhurta": [local_iso(abhijit[0]), local_iso(abhijit[1])],
                "brahma_muhurta": [local_iso(brahma[0]), local_iso(brahma[1])],
            },
            "traditional_time": self.traditional_time(local_now, sunrise, sunset, next_sunrise),
            "observances": observances,
            "methodology": {
                "lunar_month_convention": masa["convention"],
                "vikram_samvat_convention": samvat["convention"],
                "sunrise_mode": self.settings.sunrise_mode,
                "location_dependent": True,
            },
        }


def unavailable(message: str) -> dict:
    return {
        "status": "unavailable",
        "error": message,
        "engine": {"name": "Swiss Ephemeris", "calendar_engine_version": ENGINE_VERSION, "offline": True},
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--at", help="ISO-8601 timestamp; intended for tests and debugging")
    args = parser.parse_args(argv)
    if swe is None:
        print(json.dumps(unavailable("Swiss Ephemeris Python binding is not installed; run install.sh.")))
        return 0
    try:
        settings = load_settings(args.config)
        if args.at:
            moment = datetime.fromisoformat(args.at.replace("Z", "+00:00"))
            if moment.tzinfo is None:
                raise ConfigError("--at must include a timezone offset")
        else:
            moment = datetime.now(timezone.utc)
        print(json.dumps(PanchangEngine(settings).build(moment), ensure_ascii=False, separators=(",", ":")))
    except (ConfigError, RuntimeError, ValueError) as exc:
        print(json.dumps(unavailable(str(exc)), ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
