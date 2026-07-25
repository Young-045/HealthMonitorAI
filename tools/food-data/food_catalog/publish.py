from __future__ import annotations

import csv
import json
import sqlite3
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from .common import normalize_name, sha256_file
from .model import FoodRecord, NUTRIENT_UNITS


SCHEMA_VERSION = 1
PIPELINE_VERSION = "1"


SCHEMA = """
PRAGMA foreign_keys = ON;
CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE dataset_release (
  source_code TEXT PRIMARY KEY,
  source_release TEXT NOT NULL,
  source_url TEXT NOT NULL,
  license_code TEXT NOT NULL,
  license_url TEXT NOT NULL,
  raw_sha256 TEXT NOT NULL
);
CREATE TABLE food (
  id TEXT PRIMARY KEY,
  source_code TEXT NOT NULL REFERENCES dataset_release(source_code),
  source_food_id TEXT NOT NULL,
  source_release TEXT NOT NULL,
  canonical_name TEXT NOT NULL,
  language_code TEXT NOT NULL,
  category TEXT,
  description TEXT,
  food_state TEXT NOT NULL,
  basis TEXT NOT NULL,
  edible_portion_percent REAL,
  publication_date TEXT,
  notes TEXT,
  UNIQUE(source_code, source_food_id)
);
CREATE TABLE food_name (
  food_id TEXT NOT NULL REFERENCES food(id) ON DELETE CASCADE,
  language_code TEXT NOT NULL,
  name TEXT NOT NULL,
  normalized_name TEXT NOT NULL,
  name_type TEXT NOT NULL,
  PRIMARY KEY(food_id, language_code, name, name_type)
);
CREATE INDEX food_name_normalized_idx ON food_name(normalized_name);
CREATE TABLE nutrient_definition (
  key TEXT PRIMARY KEY,
  unit TEXT NOT NULL
);
CREATE TABLE food_nutrient (
  food_id TEXT NOT NULL REFERENCES food(id) ON DELETE CASCADE,
  nutrient_key TEXT NOT NULL REFERENCES nutrient_definition(key),
  amount REAL,
  raw_amount REAL,
  source_nutrient_code TEXT NOT NULL,
  source_unit TEXT NOT NULL,
  qualifier TEXT,
  derivation TEXT,
  PRIMARY KEY(food_id, nutrient_key)
);
CREATE TABLE food_portion (
  food_id TEXT NOT NULL REFERENCES food(id) ON DELETE CASCADE,
  sequence INTEGER NOT NULL,
  description TEXT NOT NULL,
  amount REAL,
  gram_weight REAL NOT NULL,
  PRIMARY KEY(food_id, sequence, description, gram_weight)
);
"""


def _write_database(
    path: Path,
    records: list[FoodRecord],
    source_manifest: dict,
    catalog_version: str,
) -> None:
    if path.exists():
        path.unlink()
    connection = sqlite3.connect(path)
    try:
        connection.executescript(SCHEMA)
        connection.executemany(
            "INSERT INTO metadata(key, value) VALUES (?, ?)",
            [
                ("schemaVersion", str(SCHEMA_VERSION)),
                ("catalogVersion", catalog_version),
                ("pipelineVersion", PIPELINE_VERSION),
            ],
        )
        connection.executemany(
            "INSERT INTO nutrient_definition(key, unit) VALUES (?, ?)",
            sorted(NUTRIENT_UNITS.items()),
        )
        for source in source_manifest["sources"]:
            connection.execute(
                "INSERT INTO dataset_release VALUES (?, ?, ?, ?, ?, ?)",
                (
                    source["code"],
                    source["version"],
                    source["url"],
                    source["license"],
                    source["licenseUrl"],
                    source["sha256"],
                ),
            )
        for record in records:
            connection.execute(
                "INSERT INTO food VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    record.stable_id,
                    record.source_code,
                    record.source_food_id,
                    record.source_release,
                    record.canonical_name,
                    record.language_code,
                    record.category,
                    record.description,
                    record.food_state,
                    record.basis,
                    record.edible_portion_percent,
                    record.publication_date,
                    record.notes,
                ),
            )
            names = [
                (record.canonical_name, "canonical"),
                *[(alias, "alias") for alias in record.aliases],
            ]
            for name, name_type in names:
                normalized = normalize_name(name)
                if normalized:
                    connection.execute(
                        "INSERT OR IGNORE INTO food_name VALUES (?, ?, ?, ?, ?)",
                        (
                            record.stable_id,
                            record.language_code,
                            name,
                            normalized,
                            name_type,
                        ),
                    )
            for nutrient in record.nutrients:
                connection.execute(
                    "INSERT INTO food_nutrient VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    (
                        record.stable_id,
                        nutrient.key,
                        nutrient.amount,
                        nutrient.raw_amount,
                        nutrient.source_code,
                        nutrient.source_unit,
                        nutrient.qualifier,
                        nutrient.derivation,
                    ),
                )
            for index, portion in enumerate(record.portions):
                connection.execute(
                    "INSERT INTO food_portion VALUES (?, ?, ?, ?, ?)",
                    (
                        record.stable_id,
                        portion.sequence or index,
                        portion.description,
                        portion.amount,
                        portion.gram_weight,
                    ),
                )
        result = connection.execute("PRAGMA integrity_check").fetchone()[0]
        if result != "ok":
            raise ValueError(f"SQLite integrity check failed: {result}")
        connection.commit()
        connection.execute("VACUUM")
    finally:
        connection.close()


def _write_csv(output: Path, records: list[FoodRecord]) -> None:
    with (output / "foods.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(
            [
                "id", "source_code", "source_food_id", "source_release",
                "canonical_name", "language_code", "category", "food_state",
                "basis", "edible_portion_percent",
            ]
        )
        for item in records:
            writer.writerow(
                [
                    item.stable_id, item.source_code, item.source_food_id,
                    item.source_release, item.canonical_name, item.language_code,
                    item.category, item.food_state, item.basis,
                    item.edible_portion_percent,
                ]
            )
    with (output / "food-nutrients.csv").open(
        "w", encoding="utf-8", newline=""
    ) as stream:
        writer = csv.writer(stream)
        writer.writerow(
            [
                "food_id", "nutrient_key", "amount", "raw_amount", "unit",
                "source_nutrient_code", "qualifier", "derivation",
            ]
        )
        for item in records:
            for nutrient in item.nutrients:
                writer.writerow(
                    [
                        item.stable_id, nutrient.key, nutrient.amount,
                        nutrient.raw_amount,
                        NUTRIENT_UNITS[nutrient.key], nutrient.source_code,
                        nutrient.qualifier, nutrient.derivation,
                    ]
                )


def _write_ndjson(output: Path, records: list[FoodRecord]) -> None:
    with (output / "catalog.ndjson").open("w", encoding="utf-8") as stream:
        for record in records:
            stream.write(
                json.dumps(record.as_json(), ensure_ascii=False, sort_keys=True)
            )
            stream.write("\n")


def publish(
    output: Path,
    records: list[FoodRecord],
    source_manifest: dict,
    catalog_version: str,
) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    records = sorted(records, key=lambda item: item.stable_id)
    identifiers = [record.stable_id for record in records]
    if len(identifiers) != len(set(identifiers)):
        duplicates = [
            key for key, count in Counter(identifiers).items() if count > 1
        ]
        raise ValueError(f"Duplicate stable food IDs: {duplicates[:10]}")

    for record in records:
        if not record.canonical_name.strip():
            raise ValueError(f"Blank canonical name: {record.stable_id}")
        for nutrient in record.nutrients:
            if nutrient.amount is not None and nutrient.amount < 0:
                raise ValueError(
                    f"Negative nutrient: {record.stable_id}/{nutrient.key}"
                )

    database_path = output / "catalog-core.sqlite"
    _write_database(database_path, records, source_manifest, catalog_version)
    _write_csv(output, records)
    _write_ndjson(output, records)

    source_counts = Counter(record.source_code for record in records)
    nutrient_counts = Counter(
        nutrient.key
        for record in records
        for nutrient in record.nutrients
        if nutrient.amount is not None
    )
    report = {
        "schemaVersion": SCHEMA_VERSION,
        "pipelineVersion": PIPELINE_VERSION,
        "catalogVersion": catalog_version,
        "foodCount": len(records),
        "sourceCounts": dict(sorted(source_counts.items())),
        "nutrientValueCounts": dict(sorted(nutrient_counts.items())),
        "checks": {
            "stableIdsUnique": True,
            "noNegativeNutrients": True,
            "sqliteIntegrityCheck": "ok",
            "missingValuesPreserved": True,
        },
    }
    (output / "validation-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    files = {}
    for name in (
        "catalog-core.sqlite", "foods.csv", "food-nutrients.csv",
        "catalog.ndjson", "validation-report.json",
    ):
        path = output / name
        files[name] = {
            "sha256": sha256_file(path),
            "bytes": path.stat().st_size,
        }
    manifest = {
        **report,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "sources": source_manifest["sources"],
        "files": files,
    }
    (output / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (output / "ATTRIBUTION.md").write_text(
        "# Food catalog attribution\n\n"
        "- U.S. Department of Agriculture, Agricultural Research Service. "
        "FoodData Central. CC0 1.0.\n"
        "- Ministry of Education, Culture, Sports, Science and Technology, Japan. "
        "Standard Tables of Food Composition in Japan 2020 "
        "(Eighth Revised Edition).\n",
        encoding="utf-8",
    )
    return manifest


def verify_database(path: Path) -> dict:
    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
        metadata = dict(connection.execute("SELECT key, value FROM metadata"))
        food_count = connection.execute("SELECT COUNT(*) FROM food").fetchone()[0]
        return {
            "integrity": integrity,
            "metadata": metadata,
            "foodCount": food_count,
        }
    finally:
        connection.close()
