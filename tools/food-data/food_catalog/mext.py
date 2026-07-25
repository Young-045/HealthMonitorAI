from __future__ import annotations

import re
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from .common import extract_mext_aliases, infer_food_state
from .model import FoodRecord, NutrientValue


MAIN_SHEET_NAME = "表全体"
MEXT_COLUMNS = {
    "energy_kcal": ("ENERC_KCAL", "kcal"),
    "protein_g": ("PROT-", "g"),
    "fat_g": ("FAT-", "g"),
    "carbohydrate_g": ("CHOCDF-", "g"),
    "fiber_g": ("FIB-", "g"),
    "sodium_mg": ("NA", "mg"),
}


def _column_index(reference: str) -> int:
    letters = re.match(r"[A-Z]+", reference).group(0)
    result = 0
    for character in letters:
        result = result * 26 + ord(character) - ord("A") + 1
    return result - 1


def _shared_strings(archive: zipfile.ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in archive.namelist():
        return []
    root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
    namespace = {"x": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    values = []
    for item in root.findall("x:si", namespace):
        direct = item.find("x:t", namespace)
        if direct is not None:
            values.append(direct.text or "")
            continue
        values.append(
            "".join(
                node.text or ""
                for node in item.findall("x:r/x:t", namespace)
            )
        )
    return values


def _sheet_path(archive: zipfile.ZipFile, sheet_name: str) -> str:
    namespace = {
        "x": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
        "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
        "p": "http://schemas.openxmlformats.org/package/2006/relationships",
    }
    workbook = ET.fromstring(archive.read("xl/workbook.xml"))
    relationship_id = None
    for sheet in workbook.findall("x:sheets/x:sheet", namespace):
        if sheet.attrib.get("name") == sheet_name:
            relationship_id = sheet.attrib[
                "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
            ]
            break
    if relationship_id is None:
        raise ValueError(f"MEXT worksheet {sheet_name!r} is missing")

    relationships = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
    for relation in relationships.findall("p:Relationship", namespace):
        if relation.attrib.get("Id") == relationship_id:
            target = relation.attrib["Target"].lstrip("/")
            return target if target.startswith("xl/") else f"xl/{target}"
    raise ValueError(f"Relationship for MEXT worksheet {sheet_name!r} is missing")


def _rows(path: Path) -> list[list[str | float | None]]:
    namespace = {"x": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    with zipfile.ZipFile(path) as archive:
        shared = _shared_strings(archive)
        root = ET.fromstring(archive.read(_sheet_path(archive, MAIN_SHEET_NAME)))
        output: list[list[str | float | None]] = []
        for row in root.findall(".//x:sheetData/x:row", namespace):
            values: list[str | float | None] = []
            for cell in row.findall("x:c", namespace):
                index = _column_index(cell.attrib["r"])
                while len(values) <= index:
                    values.append(None)
                cell_type = cell.attrib.get("t")
                if cell_type == "inlineStr":
                    value = "".join(
                        node.text or "" for node in cell.findall(".//x:t", namespace)
                    )
                else:
                    node = cell.find("x:v", namespace)
                    if node is None:
                        value = None
                    elif cell_type == "s":
                        value = shared[int(node.text)]
                    elif cell_type == "str":
                        value = node.text
                    else:
                        try:
                            value = float(node.text)
                        except (TypeError, ValueError):
                            value = node.text
                values[index] = value
            output.append(values)
        return output


def _cell(row: list, index: int):
    return row[index] if index < len(row) else None


def _parse_amount(value) -> tuple[float | None, str | None]:
    if value is None:
        return None, None
    if isinstance(value, (int, float)):
        return float(value), None
    normalized = str(value).strip()
    if normalized in {"", "-", "*"}:
        return None, None
    if normalized.casefold() == "tr":
        return None, "trace"
    estimated = normalized.startswith("(") and normalized.endswith(")")
    if estimated:
        normalized = normalized[1:-1]
    try:
        return float(normalized), "estimated" if estimated else None
    except ValueError:
        return None, "unparsed"


def parse_mext(path: Path, release: str) -> list[FoodRecord]:
    rows = _rows(path)
    identifier_row_index = next(
        (
            index
            for index, row in enumerate(rows)
            if any(str(value).strip() == "成分識別子" for value in row if value is not None)
        ),
        None,
    )
    if identifier_row_index is None:
        raise ValueError("MEXT component identifier row is missing")
    identifiers = {
        str(value).strip(): index
        for index, value in enumerate(rows[identifier_row_index])
        if value is not None and str(value).strip()
    }
    required = {"ENERC_KCAL", "PROT-", "FAT-", "CHOCDF-", "FIB-", "NA"}
    missing = sorted(required - identifiers.keys())
    if missing:
        raise ValueError(f"MEXT required components are missing: {missing}")

    records: list[FoodRecord] = []
    for row in rows[identifier_row_index + 1 :]:
        source_food_id = _cell(row, 1)
        name = _cell(row, 3)
        if source_food_id is None or name is None:
            continue
        source_food_id = (
            str(int(source_food_id)).zfill(5)
            if isinstance(source_food_id, float)
            else str(source_food_id).strip()
        )
        name = str(name).strip()
        notes = str(_cell(row, 61)).strip() if _cell(row, 61) is not None else None
        nutrients = []
        for key, (component, unit) in MEXT_COLUMNS.items():
            amount, qualifier = _parse_amount(_cell(row, identifiers[component]))
            if amount is None and qualifier is None:
                continue
            nutrients.append(
                NutrientValue(
                    key=key,
                    amount=amount,
                    source_code=component,
                    source_unit=unit,
                    raw_amount=amount,
                    qualifier=qualifier,
                )
            )

        refuse, _ = _parse_amount(_cell(row, 4))
        category_value = _cell(row, 0)
        category = (
            str(int(category_value)).zfill(2)
            if isinstance(category_value, float)
            else str(category_value).zfill(2)
            if category_value is not None
            else None
        )
        records.append(
            FoodRecord(
                source_code="mext-2020",
                source_food_id=source_food_id,
                source_release=release,
                canonical_name=name,
                language_code="ja",
                category=category,
                description=name,
                food_state=infer_food_state(name),
                edible_portion_percent=100.0 - refuse if refuse is not None else None,
                aliases=extract_mext_aliases(notes),
                nutrients=nutrients,
                notes=notes,
            )
        )
    return records
