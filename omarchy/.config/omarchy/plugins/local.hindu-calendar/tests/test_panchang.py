#!/usr/bin/env python3
"""Regression tests for the local calendar engine.

The fixed Kolkata fixture deliberately includes an adhika māsa and a Vikrama
Saṁvat boundary.  Exact instants are generated with the pinned Swiss Ephemeris
binding; a release should be cross-checked against the selected reference
Pañcāṅga before changing these fixture values.
"""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "engine"))
import panchang  # noqa: E402


FIXTURE = Path(__file__).with_name("kolkata.json")


def build(at: str, config: Path = FIXTURE) -> dict:
    settings = panchang.load_settings(config)
    return panchang.PanchangEngine(settings).build(datetime.fromisoformat(at))


def field(report: dict, label: str) -> str:
    return next(item["value"] for item in report["panchang"] if item["label"] == label)


class PanchangTests(unittest.TestCase):
    def test_known_kolkata_fixture(self) -> None:
        report = build("2026-08-22T12:00:00+05:30")
        self.assertEqual(report["status"], "ok")
        self.assertEqual(report["header"]["vikram_samvat"]["year"], 2083)
        self.assertEqual(field(report, "Vāra"), "Śanivāra")
        self.assertEqual(field(report, "Tithi"), "Śukla Daśamī")
        self.assertEqual(field(report, "Nakṣatra"), "Jyeṣṭhā")
        self.assertEqual(field(report, "Yoga"), "Viṣkambha")
        self.assertEqual(field(report, "Karaṇa"), "Taitila")
        self.assertEqual(field(report, "Māsa"), "Śrāvaṇa")
        self.assertEqual(report["solar_lunar"]["sunrise"], "2026-08-22T05:19+05:30")
        self.assertEqual(report["solar_lunar"]["sunset"], "2026-08-22T17:59+05:30")

    def test_vikram_samvat_does_not_use_a_flat_year_offset(self) -> None:
        before = build("2026-03-19T06:52:00+05:30")
        after = build("2026-03-19T06:54:00+05:30")
        self.assertEqual(before["header"]["vikram_samvat"]["year"], 2082)
        self.assertEqual(after["header"]["vikram_samvat"]["year"], 2083)
        self.assertEqual(field(after, "Tithi"), "Śukla Pratipadā")
        self.assertEqual(field(after, "Māsa"), "Caitra")

    def test_adhika_masa_is_detected_from_successive_new_moons(self) -> None:
        report = build("2023-07-25T12:00:00+05:30")
        self.assertEqual(field(report, "Māsa"), "Adhika Śrāvaṇa")

    def test_purnimanta_names_krishna_half_as_following_lunar_month(self) -> None:
        raw = json.loads(FIXTURE.read_text(encoding="utf-8"))
        raw["calendar"]["lunar_month_convention"] = "purnimanta"
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "purnimanta.json"
            config.write_text(json.dumps(raw), encoding="utf-8")
            report = build("2026-08-30T12:00:00+05:30", config)
        self.assertEqual(field(report, "Tithi"), "Kṛṣṇa Tṛtīyā")
        self.assertEqual(field(report, "Māsa"), "Bhādrapada")

    def test_location_changes_sunrise_and_muhurta_windows(self) -> None:
        kolkata = build("2026-08-22T12:00:00+05:30")
        raw = json.loads(FIXTURE.read_text(encoding="utf-8"))
        raw["location"] = {"name": "London", "latitude": 51.5072, "longitude": -0.1276, "elevation_m": 11}
        raw["timezone"] = "Europe/London"
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "london.json"
            config.write_text(json.dumps(raw), encoding="utf-8")
            london = build("2026-08-22T12:00:00+01:00", config)
        self.assertNotEqual(kolkata["solar_lunar"]["sunrise"], london["solar_lunar"]["sunrise"])
        self.assertNotEqual(kolkata["muhurta"]["rahu_kalam"], london["muhurta"]["rahu_kalam"])

    def test_missing_coordinates_are_rejected_without_fabricated_data(self) -> None:
        raw = json.loads(FIXTURE.read_text(encoding="utf-8"))
        raw["location"]["latitude"] = None
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "empty.json"
            config.write_text(json.dumps(raw), encoding="utf-8")
            with self.assertRaises(panchang.ConfigError):
                panchang.load_settings(config)


if __name__ == "__main__":
    unittest.main(verbosity=2)
