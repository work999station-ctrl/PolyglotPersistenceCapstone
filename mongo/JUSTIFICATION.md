# Component B — MongoDB Justification (Product Catalog & Reviews)

## 1. The Access Pattern
In an e-commerce marketplace (**SoukTech**), product browsing and filtering follow a **read-heavy, polymorphic document-retrieval** pattern:
- A shopper opens a category page and filters on **category-specific nested attributes** (e.g., Laptops by `specs.ram_gb >= 16` and `specs.storage.type = "NVMe"`; Clothing by `variants` with `color = "Black"` and `size = "L"` in stock; Books by `authors` or `topics`).
- Displaying a product page requires reading the product's title, seller badge, nested technical specifications, all available variants, tags, and pre-aggregated `rating_summary` in a **single low-latency read**, while occasionally paginating or aggregating detailed customer reviews (`pros`, `cons`, `verified_purchase`, `seller_reply`).
- Meanwhile, onboarding a new category (e.g., *Home Appliances* or *Drones*) introduces brand-new attributes without touching existing products.

## 2. Why MongoDB Fits This Workload
MongoDB's **document model** matches the **Polymorphic Pattern** natively:
- Each document in `catalog_products` stores its own nested `specs` subdocument tailored to its category, alongside embedded `variants` arrays and `rating_summary`, keyed by `pg_product_id` to stay linked to PostgreSQL's transactional core.
- Nested dot-notation queries (`"specs.ram_gb"`), array-element matching (`$elemMatch` on `variants`), and multi-stage aggregation pipelines (`$unwind` on review `pros`, `$lookup` across `catalog_products` and `product_reviews`) execute without multi-table joins.
- Multikey and compound indexes index fields inside nested subdocuments and arrays directly.
- Placing full reviews in `product_reviews` while embedding `rating_summary` on `catalog_products` keeps product documents bounded (well below MongoDB's 16 MB BSON limit) even for viral items with thousands of reviews.

## 3. What You Would Lose by Keeping It in PostgreSQL
1. **Rigid Schema vs. Sparse Tables or EAV Anti-Pattern:** Modeling dozens of category-specific attributes in normalized 3NF tables forces either (a) a single wide table filled mostly with `NULL`s, (b) dozens of category subtype tables requiring complex joins and `ALTER TABLE` migrations for every new product type, or (c) an **Entity-Attribute-Value (EAV)** table that destroys type constraints and turns simple multi-attribute filters into slow multi-way self-joins.
2. **Object-Relational Reassembly Cost:** Even with PostgreSQL `JSONB`, retrieving a full product view alongside variants and category/seller metadata still mixes relational joins with semi-structured JSON paths, and updating one nested field or pushing a seller reply rewrites the whole `JSONB` value in MVCC.
3. **Separation of Concerns:** Keeping rich catalog browsing and review analytics in MongoDB isolates heavy search/filter read traffic from PostgreSQL's strict ACID checkout transactions (`orders`, `payments`, `stock_qty`).

