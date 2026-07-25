#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOL_ROOT))

from food_catalog.common import sha256_file
from food_catalog.mext import parse_mext
from food_catalog.publish import publish, verify_database
from food_catalog.usda import parse_usda_foundation


def _manifest(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _source(manifest: dict, code: str) -> dict:
    return next(item for item in manifest["sources"] if item["code"] == code)


def _check_hash(path: Path, source: dict) -> None:
    actual = sha256_file(path)
    if actual != source["sha256"]:
        raise ValueError(
            f"SHA-256 mismatch for {source['code']}: "
            f"{actual}, expected {source['sha256']}"
        )


def build(arguments) -> None:
    manifest = _manifest(arguments.manifest)
    usda_source = _source(manifest, "usda-foundation")
    mext_source = _source(manifest, "mext-2020")
    _check_hash(arguments.usda, usda_source)
    _check_hash(arguments.mext, mext_source)

    records = [
        *parse_usda_foundation(arguments.usda, usda_source["version"]),
        *parse_mext(arguments.mext, mext_source["version"]),
    ]
    catalog_version = f"{usda_source['version']}+pipeline.1"
    result = publish(arguments.output, records, manifest, catalog_version)
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))


def verify(arguments) -> None:
    result = verify_database(arguments.database)
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    if result["integrity"] != "ok":
        raise SystemExit(1)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(
        description="Build the offline authority food catalog"
    )
    subcommands = result.add_subparsers(required=True)
    build_parser = subcommands.add_parser("build")
    build_parser.add_argument("--usda", type=Path, required=True)
    build_parser.add_argument("--mext", type=Path, required=True)
    build_parser.add_argument("--output", type=Path, required=True)
    build_parser.add_argument(
        "--manifest",
        type=Path,
        default=TOOL_ROOT.parent.parent
        / "data/manifests/food-sources.json",
    )
    build_parser.set_defaults(function=build)

    verify_parser = subcommands.add_parser("verify")
    verify_parser.add_argument("database", type=Path)
    verify_parser.set_defaults(function=verify)
    return result


if __name__ == "__main__":
    arguments = parser().parse_args()
    arguments.function(arguments)
