from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT))

from food_catalog.mext import _parse_amount
from food_catalog.publish import publish, verify_database
from food_catalog.usda import parse_usda_foundation


class FoodCatalogPipelineTests(unittest.TestCase):
    def test_mext_qualifiers_preserve_missing_trace_and_estimated(self):
        self.assertEqual(_parse_amount("-"), (None, None))
        self.assertEqual(_parse_amount("Tr"), (None, "trace"))
        self.assertEqual(_parse_amount("(12.3)"), (12.3, "estimated"))
        self.assertEqual(_parse_amount(0), (0.0, None))

    def test_usda_uses_explicit_energy_priority_and_preserves_missing_sugar(self):
        payload = {
            "FoundationFoods": [
                {
                    "fdcId": 42,
                    "description": "Test food, raw",
                    "foodNutrients": [
                        {
                            "nutrient": {"id": 1003, "unitName": "g"},
                            "amount": 2,
                        },
                        {
                            "nutrient": {"id": 2047, "unitName": "kcal"},
                            "amount": 80,
                        },
                        {
                            "nutrient": {"id": 2048, "unitName": "kcal"},
                            "amount": 75,
                        },
                    ],
                    "foodPortions": [],
                }
            ]
        }
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "source.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            records = parse_usda_foundation(path, "test")
        values = {item.key: item.amount for item in records[0].nutrients}
        self.assertEqual(values["energy_kcal"], 75)
        self.assertEqual(values["protein_g"], 2)
        self.assertNotIn("sugars_g", values)

    def test_usda_preserves_and_clamps_negative_carbohydrate_by_difference(self):
        payload = {
            "FoundationFoods": [
                {
                    "fdcId": 43,
                    "description": "Test meat",
                    "foodNutrients": [
                        {
                            "nutrient": {"id": 1005, "unitName": "g"},
                            "amount": -0.25,
                        }
                    ],
                    "foodPortions": [],
                }
            ]
        }
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "source.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            nutrient = parse_usda_foundation(path, "test")[0].nutrients[0]
        self.assertEqual(nutrient.amount, 0)
        self.assertEqual(nutrient.raw_amount, -0.25)
        self.assertEqual(nutrient.qualifier, "clamped-negative")

    def test_publish_creates_valid_read_only_database(self):
        payload = {
            "FoundationFoods": [
                {
                    "fdcId": 42,
                    "description": "Test food",
                    "foodNutrients": [
                        {
                            "nutrient": {"id": 1008, "unitName": "kcal"},
                            "amount": 10,
                        }
                    ],
                    "foodPortions": [],
                }
            ]
        }
        manifest = {
            "sources": [
                {
                    "code": "usda-foundation",
                    "version": "test",
                    "url": "https://example.invalid/usda",
                    "license": "CC0-1.0",
                    "licenseUrl": "https://example.invalid/license",
                    "sha256": "0" * 64,
                }
            ]
        }
        with tempfile.TemporaryDirectory() as temporary:
            temporary = Path(temporary)
            source = temporary / "source.json"
            source.write_text(json.dumps(payload), encoding="utf-8")
            records = parse_usda_foundation(source, "test")
            publish(
                temporary / "release",
                records,
                manifest,
                "test+pipeline.1",
            )
            result = verify_database(
                temporary / "release/catalog-core.sqlite"
            )
        self.assertEqual(result["integrity"], "ok")
        self.assertEqual(result["foodCount"], 1)


if __name__ == "__main__":
    unittest.main()
