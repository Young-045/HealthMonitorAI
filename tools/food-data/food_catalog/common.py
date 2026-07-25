from __future__ import annotations

import hashlib
import re
import unicodedata
from pathlib import Path


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalize_name(value: str) -> str:
    folded = unicodedata.normalize("NFKC", value).casefold()
    return "".join(character for character in folded if character.isalnum())


def infer_food_state(value: str) -> str:
    lowered = value.casefold()
    rules = (
        ("raw", (" raw", "生")),
        ("boiled", ("boiled", "ゆで", "水煮")),
        ("roasted", ("roasted", "焼き", "焼")),
        ("fried", ("fried", "揚げ")),
        ("dried", ("dried", "乾")),
    )
    for state, tokens in rules:
        if any(token in lowered for token in tokens):
            return state
    return "unknown"


def extract_mext_aliases(notes: str | None) -> list[str]:
    if not notes:
        return []
    match = re.search(r"別名：\s*([^\n]+)", notes)
    if not match:
        return []
    return [
        item.strip()
        for item in re.split(r"[、,，]", match.group(1))
        if item.strip()
    ]
