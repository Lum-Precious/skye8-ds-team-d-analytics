Product
A product is uniquely identified by product_code in the ERP master
(erp_products). All other identifiers — ERP legacy codes, supplier
item codes, POS product refs, and free-text descriptions from stock
counts — are resolved to this code via the product resolver
(src/warehouse/resolvers/product.py).

Resolution precedence:
1. Exact match against product_code
2. Manual/known mapping (supplier code map)
3. Fuzzy match against clean_name, constrained to require an
exact numeric strength match (to avoid conflating different
dosages of the same generic)
4. Unresolved → escalated to reports/escalations.csv with
candidate suggestions, never guessed

Branch
A branch is uniquely identified by branch_id in the ERP branch
master. Free-text branch names are resolved via manual override map,
then exact match, then fuzzy match against official branch names
(src/warehouse/resolvers/branch.py).

Unit
All quantities are normalized to loose units before any analysis:
• Stock counts: quantity * pack_size when quantity_unit == "packs",
using each product's pack_size from the ERP master
• Supplier deliveries: cartons * units_per_carton (varies per
delivery row, not a fixed constant)
• Before/after totals are printed at normalization time for
verification (see pipeline output)

Date convention
Four raw formats appear: month-name (1-Jan-25), and numeric
D/M/Y or M/D/Y slash formats which cannot be distinguished from
each other when both components are ≤ 12.

Rule applied:
1. If a numeric component is > 12, it must be the day (no month
exceeds 12) — resolved with certainty, tagged
resolved_day_gt_12
2. If both components are ≤ 12, day/month/year is assumed (stated
fallback, not proof) — tagged fallback_assumed_DMY
3. Every row is tagged with its resolution method; counts appear in
reports/reconciliation.md