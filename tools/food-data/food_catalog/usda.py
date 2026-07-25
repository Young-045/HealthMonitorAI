from __future__ import annotations

import json
import zipfile
from pathlib import Path

from .common import infer_food_state
from .model import FoodRecord, NutrientValue, Portion


USDA_NUTRIENTS = {
    1003: ("protein_g", "g"),
    1004: ("fat_g", "g"),
    1005: ("carbohydrate_g", "g"),
    1079: ("fiber_g", "g"),
    1093: ("sodium_mg", "mg"),
}


def _energy(nutrients: list[dict]) -> dict | None:
    by_id = {
        item.get("nutrient", {}).get("id"): item
        for item in nutrients
        if item.get("amount") is not None
    }
    for nutrient_id in (2048, 2047, 1008):
        if nutrient_id in by_id:
            return by_id[nutrient_id]
    return None


def _nutrient_value(item: dict, key: str, expected_unit: str) -> NutrientValue:
    nutrient = item["nutrient"]
    unit = nutrient.get("unitName", "")
    if unit.casefold() != expected_unit.casefold():
        raise ValueError(
            f"Unexpected USDA unit for {key}: {unit!r}, expected {expected_unit!r}"
        )
    derivation = item.get("foodNutrientDerivation") or {}
    amount = float(item["amount"])
    raw_amount = amount
    qualifier = None
    if key == "carbohydrate_g" and amount < 0:
        amount = 0.0
        qualifier = "clamped-negative"
    return NutrientValue(
        key=key,
        amount=amount,
        source_code=str(nutrient.get("id", "")),
        source_unit=unit,
        raw_amount=raw_amount,
        qualifier=qualifier,
        derivation=derivation.get("code"),
    )


def parse_usda_foundation(path: Path, release: str) -> list[FoodRecord]:
    if path.suffix.casefold() == ".zip":
        with zipfile.ZipFile(path) as archive:
            names = [name for name in archive.namelist() if name.endswith(".json")]
            if len(names) != 1:
                raise ValueError("USDA archive must contain exactly one JSON file")
            payload = json.loads(archive.read(names[0]))
    else:
        payload = json.loads(path.read_text(encoding="utf-8"))

    foods = payload.get("FoundationFoods")
    if not isinstance(foods, list):
        raise ValueError("USDA FoundationFoods array is missing")

    records: list[FoodRecord] = []
    for source in foods:
        if not isinstance(source, dict):
            continue
        source_nutrients = source.get("foodNutrients") or []
        nutrients: list[NutrientValue] = []
        for item in source_nutrients:
            nutrient_id = item.get("nutrient", {}).get("id")
            mapping = USDA_NUTRIENTS.get(nutrient_id)
            if mapping and item.get("amount") is not None:
                nutrients.append(_nutrient_value(item, *mapping))

        energy = _energy(source_nutrients)
        if energy is not None:
            nutrients.append(_nutrient_value(energy, "energy_kcal", "kcal"))
        sugar_by_id = {
            item.get("nutrient", {}).get("id"): item
            for item in source_nutrients
            if item.get("amount") is not None
        }
        sugar = sugar_by_id.get(2000) or sugar_by_id.get(1063)
        if sugar is not None:
            nutrients.append(_nutrient_value(sugar, "sugars_g", "g"))

        portions = []
        for item in source.get("foodPortions") or []:
            gram_weight = item.get("gramWeight")
            if gram_weight is None or float(gram_weight) <= 0:
                continue
            unit = item.get("measureUnit") or {}
            modifier = (item.get("modifier") or "").strip()
            description = modifier or unit.get("name") or unit.get("abbreviation") or "serving"
            portions.append(
                Portion(
                    description=description,
                    gram_weight=float(gram_weight),
                    amount=float(item["amount"]) if item.get("amount") is not None else None,
                    sequence=int(item.get("sequenceNumber") or 0),
                )
            )

        description = str(source["description"]).strip()
        category = (source.get("foodCategory") or {}).get("description")
        records.append(
            FoodRecord(
                source_code="usda-foundation",
                source_food_id=str(source["fdcId"]),
                source_release=release,
                canonical_name=description,
                language_code="en",
                category=category,
                description=description,
                food_state=infer_food_state(description),
                publication_date=source.get("publicationDate"),
                nutrients=nutrients,
                portions=portions,
            )
        )
    return records
