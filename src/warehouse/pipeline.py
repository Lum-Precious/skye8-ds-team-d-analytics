from .resolvers.branch import build_branch_resolver
from .resolvers.product import build_product_resolver
from .normalize import normalize_deliveries, normalize_stock_counts, summarize_date_resolution
from .loaders import load_supplier_deliveries, load_stock_counts
from .config import REPORTS_DIR
import pandas as pd


def rebuild_warehouse():
    print(" Building Branch Resolver ")
    branch_map, unresolved_branches, branch_master = build_branch_resolver()

    print("\n Building Product Resolver ")
    product_map, escalations, product_master = build_product_resolver()

    deliveries = load_supplier_deliveries()
    deliveries = normalize_deliveries(deliveries)
    summarize_date_resolution(deliveries, "supplier_deliveries")

    stock = load_stock_counts()
    stock = normalize_stock_counts(stock, product_map, product_master)
    summarize_date_resolution(stock, "stock_counts")

    escalations.to_csv(REPORTS_DIR / "escalations.csv", index=False)
    branch_map.to_csv(REPORTS_DIR / "branch_resolver.csv", index=False)
    product_map.to_csv(REPORTS_DIR / "product_resolver.csv", index=False)

    print("\n Done")
    print(f"Branch mappings : {len(branch_map)}")
    print(f"Product mappings: {len(product_map)}")
    print(f"Unresolved branches: {len(unresolved_branches)}")
    print(f"Escalations: {len(escalations)}")


if __name__ == "__main__":
    rebuild_warehouse()
