import pandas as pd
import re
from difflib import get_close_matches
from ..loaders import load_erp_branches, load_stock_counts


def clean_branch_name(name: str) -> str:
    if pd.isna(name):
        return ""
    name = str(name).lower().strip()
    name = re.sub(r"[^a-z0-9\s]", " ", name)
    name = re.sub(r"\b(pharmacy|branch|pharm| store)\b", "", name)
    name = re.sub(r"\s+", " ", name).strip()
    return name


def build_branch_resolver():

    branches = load_erp_branches()
    stock = load_stock_counts()

    branches["clean_name"] = branches["branch_name"].apply(clean_branch_name)

    manual_map = {
        "Nkwen": "PH-03",
        "Bonapriso": "PH-07",
        "Ndokoti": "PH-08",
        "Bastos": "PH-09",
        "Molyko": "PH-12",
        "Akwa": "PH-06",
        "Etoudi": "PH-11",
        "Mvan": "PH-10"
    }

    messy_names = stock["branch"].dropna().unique()

    mapping = []
    unresolved = []

    official_names = branches["clean_name"].tolist()
    official_ids = dict(zip(branches["clean_name"], branches["branch_id"]))
    id_to_official_name = dict(
        zip(branches["branch_id"], branches["branch_name"]))

    for original in messy_names:
        cleaned = clean_branch_name(original)

        if cleaned in manual_map:
            branch_id = manual_map[cleaned]

        elif cleaned in official_ids:
            branch_id = official_ids[cleaned]

        else:
            matches = get_close_matches(
                cleaned, official_names, n=1, cutoff=0.75)
            if matches:
                branch_id = official_ids[matches[0]]

        if branch_id:
            mapping.append({
                           "messy_name": original,
                           "branch_id": branch_id,
                           "official_name": id_to_official_name[branch_id]
                           })

        else:
            unresolved.append(original)

    resolver_df = pd.DataFrame(mapping)

    print(f"Total messy branch names : {len(messy_names)}")
    print(f"Resolved : {len(mapping)}")
    print(f"Unresolved : {len(unresolved)}")
    if unresolved:
        print("Unresolved example:", unresolved[:5])

    return resolver_df, unresolved, branches
