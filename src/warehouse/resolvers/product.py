import pandas as pd
import re
from difflib import get_close_matches
from ..loaders import (
    load_erp_products,
    load_supplier_code_map,
    load_pos_sales,
    load_stock_counts
)


def clean_product_text(text: str) -> str:
    if pd.isna(text):
        return ""
    text = str(text).lower().strip()
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    text = re.sub(
        r"\b(mg|ml|mcg|g|tabs?|tablets?|caps?|capsules?|bottles?|"
        r"solutions?|sachets?|inhalers?)\b", "", text
    )
    text = re.sub(r"\s+", " ", text).strip()
    return text


def extract_strength(text: str) -> str:
    match = re.search(r"\d+(\.\d+)?", text)
    return match.group(0) if match else ""


def build_clean_name(row):
    parts = [row["product_name"]]
    if pd.notna(row["generic"]) and str(row["generic"]).strip().lower() != str(row["product_name"]).strip().lower():
        parts.append(row["generic"])
    parts.append(row["strength"])
    parts.append(row["form"])
    return clean_product_text("".join(str(p) for p in parts if pd.notna(p)))


def build_product_resolver():
    products = load_erp_products()
    supplier_map = load_supplier_code_map()
    pos = load_pos_sales()
    stock = load_stock_counts()

    products["clean_name"] = products.apply(build_clean_name, axis=1)

    mapping = {}
    escalations = []
    official_names = products["clean_name"].tolist()
    name_to_code = dict(zip(products["clean_name"], products["product_code"]))

    for _, row in supplier_map.iterrows():
        mapping[str(row["supplier_item_code"])] = row["product_code"]

    for ref in pos["product_ref"].dropna().unique():
        ref = str(ref)

        if ref in products["product_code"].values:
            mapping[ref] = ref

        elif ref in mapping:
            continue
        else:
            cleaned = clean_product_text(ref)
            strength = extract_strength(cleaned)
            candidates = get_close_matches(
                cleaned, official_names, n=5, cutoff=0.80)
            matches = [
                m for m in candidates if extract_strength(m) == strength]
            if matches:
                mapping[ref] = name_to_code[matches[0]]
            else:
                hint = get_close_matches(
                    cleaned, official_names, n=3, cutoff=0.5)
                escalations.append({
                    "source": "pos",
                    "original": ref,
                    "reason": "unresolved",
                    "candidates": ",".join(hint)if hint else ""
                })

    for desc in stock["item_description"].dropna().unique():
        cleaned = clean_product_text(ref)
        strength = extract_strength(cleaned)
        candidates = get_close_matches(
            cleaned, official_names, n=5, cutoff=0.82)
        matches = [
            m for m in candidates if extract_strength(m) == strength]
        if matches:
            mapping[ref] = name_to_code[matches[0]]
        else:
            hint = get_close_matches(
                cleaned, official_names, n=3, cutoff=0.5)
            escalations.append({
                "source": "pos",
                "original": ref,
                "reason": "unresolved",
                "candidates": ",".join(hint)if hint else ""
            })

    resolver_df = pd.DataFrame([
        {"messy_identifier": k, "product_code": v} for k, v in mapping.items()
    ])
    escalations_df = pd.DataFrame(escalations)

    print(f"product mappings created ; {len(resolver_df)}")
    print(f"escalations (need review ; {len(escalations)})")

    return resolver_df, escalations_df, products
