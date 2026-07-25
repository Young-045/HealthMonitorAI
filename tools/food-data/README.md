# Food catalog builder

This tool converts pinned USDA FoodData Central Foundation Foods JSON and the
MEXT 2020 food composition workbook into a versioned, read-only catalog.

It uses only the Python standard library. Source files are immutable inputs;
generated SQLite, CSV and NDJSON files are reproducible release artifacts.
The pipeline supports the system Python 3.9 bundled with current Xcode releases
and newer Python versions.

```bash
python3 tools/food-data/cli.py build \
  --usda /path/to/FoodData_Central_foundation_food_json_2026-04-30.zip \
  --mext /path/to/mext.xlsx \
  --output data/releases/local

python3 tools/food-data/cli.py verify data/releases/local/catalog-core.sqlite
python3 -m unittest discover -s tools/food-data/tests
```

Missing nutrients remain missing. In particular, the MEXT main table does not
publish a single total-sugars column, so `sugars_g` is not synthesized.
