from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "data" / "raw"
REPORTS_DIR = ROOT / "reports"

ERP_PRODUCTS = RAW_DIR / "erp_products.csv"
ERP_BRANCHES = RAW_DIR / "erp_branches.csv"
POS_SALES = RAW_DIR / "pos_sales.csv"
STOCK_COUNTS = RAW_DIR / "stock_counts.csv"
SUPPLIER_DELIVERIES = RAW_DIR / "supplier_deliveries.csv"
SUPPLIER_CODE_MAP = RAW_DIR / "supplier_code_map.csv"
WASTAGE_LOG = RAW_DIR / "wastage_log.csv"
