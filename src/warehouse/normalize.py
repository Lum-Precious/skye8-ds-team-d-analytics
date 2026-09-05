import re
import pandas as pd
from datetime import date, datetime

def normalize_date(raw):
    if raw is None or (isinstance(raw, float) and pd.isna(raw)):
        return None, "missing"

    s = str(raw).strip()

    for fmt in ("%d-%b-%y", "%d-%b-%Y"):
        try:
            return datetime.strptime(s, fmt).strftime("%Y-%m-%d"), "unambiguous_month_name"
        except ValueError:
            pass

    m = re.match(r"^(\d{1,2})/(\d{1,2})/(\d{4})$", s)
    if m:
        a, b, year = int(m.group(1)), int(m.group(2)), int(m.group(3))

        if a > 12 and b <= 12:
            return date(year, b, a).strftime("%Y-%m-%d"), "resolved_day_gt_12"

        elif b > 12 and a <= 12:
            return date(year, a, b).strftime("%Y-%m-%d"), "resolved_day_gt_12"

        elif a <= 12 and b <= 12:
            return date(year, b, a).strftime("%Y-%m-%d"), "fallback_assumed_DMY"

    return None, "unparsed"


def normalize_deliveries(deliveries):
    df = deliveries.copy()
    df["cartons"] = pd.to_numeric(df["cartons"], errors="coerce")
    df["units_per_carton"] = pd.to_numeric(
        df["units_per_carton"], errors="coerce")
    df["units_total"] = df["cartons"] * df["units_per_carton"]

    parsed = df["delivered_on"].apply(normalize_date)
    df["delivered_date"] = parsed.apply(lambda x: x[0])
    df["date_resolution"] = parsed.apply(lambda x: x[1])

    print(f"Deliveries - total cartons: {df['cartons'].sum()}")
    print(f"Deliveries - total loose units: {df['units_total'].sum()}")
    return df


def normalize_stock_counts(stock, product_map, product_master):
    df = stock.copy()
    df["quantity"] = pd.to_numeric(df["quantity"], errors="coerce")
    code_map = product_map
    pack_size_map = dict(
        zip(product_master["product_code"], product_master["pack_size"]))

    def convert(row):
        code = code_map.get(row["item_description"])
        if code is None:
            return None
        pack_size = pack_size_map.get(code, 1)
        if str(row["quantity_unit"]).strip().lower() == "packs":
            return row["quantity"] * pack_size
        return row["quantity"]

    df["quantity_units"] = df.apply(convert, axis=1)
    matched_count = df["item_description"].isin(code_map.keys()).sum()
    print(
        f"Stock counts - rows with matching product code:{matched_count} of {len(df)}")

    parsed = df["counted_on"].apply(normalize_date)
    df["counted_date"] = parsed.apply(lambda x: x[0])
    df["date_resolution"] = parsed.apply(lambda x: x[1])

    print(f"Stock counts - total (mixed packs/units): {df['quantity'].sum()}")
    print(f"Stock counts - total (loose units): {df['quantity_units'].sum()}")
    print(
        f"Stock counts - unresoled products (could not convert): {df['quantity_units'].isna().sum()}")
    return df


def summarize_date_resolution(df, source_name):
    counts = df["date_resolution"].value_counts().to_dict()
    print(f"\n Date resolution for {source_name}:")
    for k, v in counts.items():
        print(f"{k}:{v}")
    return counts
