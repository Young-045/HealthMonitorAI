from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any


NUTRIENT_UNITS = {
    "energy_kcal": "kcal",
    "protein_g": "g",
    "carbohydrate_g": "g",
    "fat_g": "g",
    "fiber_g": "g",
    "sugars_g": "g",
    "sodium_mg": "mg",
}


@dataclass(frozen=True)
class NutrientValue:
    key: str
    amount: float | None
    source_code: str
    source_unit: str
    raw_amount: float | None = None
    qualifier: str | None = None
    derivation: str | None = None


@dataclass(frozen=True)
class Portion:
    description: str
    gram_weight: float
    amount: float | None = None
    sequence: int = 0


@dataclass
class FoodRecord:
    source_code: str
    source_food_id: str
    source_release: str
    canonical_name: str
    language_code: str
    category: str | None = None
    description: str | None = None
    food_state: str = "unknown"
    basis: str = "edible_100g"
    edible_portion_percent: float | None = None
    publication_date: str | None = None
    aliases: list[str] = field(default_factory=list)
    nutrients: list[NutrientValue] = field(default_factory=list)
    portions: list[Portion] = field(default_factory=list)
    notes: str | None = None

    @property
    def stable_id(self) -> str:
        return f"{self.source_code}:{self.source_food_id}"

    def as_json(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["id"] = self.stable_id
        return payload
