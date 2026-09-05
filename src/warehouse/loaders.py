import pandas as pd
from .config import *


def load_erp_products() -> pd.DataFrame:
    df = pd.read_csv(ERP_PRODUCTS, dtype=str)
    df.columns = df.columns.str.strip().str.lower().str.replace(" ", "_")
    return df


def load_erp_branches() -> pd.DataFrame:
    df = pd.read_csv(ERP_BRANCHES, dtype=str)
    df.columns = df.columns.str.strip().str.lower().str.replace(" ", "_")
    return df


def load_pos_sales() -> pd.DataFrame:
    df = pd.read_csv(POS_SALES, dtype=str)
    df.columns = df.columns.str.strip().str.lower().str.replace(" ", "_")
    return df


def load_stock_counts() -> pd.DataFrame:
    df = pd.read_csv(STOCK_COUNTS, dtype=str)
    df.columns = df.columns.str.strip().str.lower().str.replace(" ", "_")
    return df


def load_supplier_deliveries() -> pd.DataFrame:
    df = pd.read_csv(SUPPLIER_DELIVERIES, dtype=str)
    df.columns = df.columns.str.strip().str.lower().str.replace(" ", "_")
    return df


def load_supplier_code_map() -> pd.DataFrame:
    df = pd.read_csv(SUPPLIER_CODE_MAP, dtype=str)
    df.columns = df.columns.str.strip().str.lower().str.replace(" ", "_")
    return df


def load_wastage() -> pd.DataFrame:
    df = pd.read_csv(WASTAGE_LOG, dtype=str)
    df.columns = df.columns.str.strip().str.lower().str.replace(" ", "_")
    return df
