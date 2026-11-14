// ============================================================================
// Polyglot Persistence Capstone — E-Commerce Marketplace (SoukTech)
// Component B (Part 2): 6 Meaningful MongoDB Queries & Aggregations
//
// Usage:
//   Get-Content .\mongo\02_queries.js -Raw | docker exec -i advdb-mongo mongosh -u student -p student --authenticationDatabase admin --quiet
// ============================================================================

const dbCatalog = db.getSiblingDB("souktech_catalog");

print("\n=== Q1: Nested Polymorphic Specs — Active Laptops with >= 16GB RAM & NVMe ===");
printjson(
  dbCatalog.catalog_products
    .find(
      {
        is_active: true,
        "category.slug": "laptops",
        "specs.ram_gb": { $gte: 16 },
        "specs.storage.type": "NVMe"
      },
      {
        _id: 0,
        pg_product_id: 1,
        sku: 1,
        title: 1,
        base_price: 1,
        "specs.brand": 1,
        "specs.ram_gb": 1,
        "specs.storage": 1
      }
    )
    .sort({ base_price: 1 })
    .limit(5)
    .toArray()
);

print("\n=== Q2: Embedded Array ($elemMatch) — Available Black Variants (Size L or 42, delta <= 500) ===");
printjson(
  dbCatalog.catalog_products
    .find(
      {
        is_active: true,
        "category.slug": { $in: ["men-clothing", "footwear"] },
        variants: {
          $elemMatch: {
            available: true,
            "attributes.color": "Black",
            "attributes.size": { $in: ["L", "42"] },
            price_delta: { $lte: 500 }
          }
        }
      },
      {
        _id: 0,
        pg_product_id: 1,
        title: 1,
        "category.name": 1,
        base_price: 1,
        variants: 1
      }
    )
    .limit(5)
    .toArray()
);

print("\n=== Q3: Array ($all) + Rating Filter — Top Rated Wireless & Bluetooth Gear ===");
printjson(
  dbCatalog.catalog_products
    .find(
      {
        is_active: true,
        tags: { $all: ["wireless", "bluetooth"] },
        "rating_summary.avg": { $gte: 4.0 }
      },
      {
        _id: 0,
        pg_product_id: 1,
        title: 1,
        base_price: 1,
        tags: 1,
        rating_summary: 1
      }
    )
    .sort({ "rating_summary.avg": -1, "rating_summary.count": -1 })
    .limit(5)
    .toArray()
);

print("\n=== Q4: Aggregation Pipeline — Catalog Pricing & Rating Summary per Category ===");
printjson(
  dbCatalog.catalog_products.aggregate([
    { $match: { is_active: true } },
    {
      $group: {
        _id: "$category.name",
        product_count: { $sum: 1 },
        avg_price: { $avg: "$base_price" },
        min_price: { $min: "$base_price" },
        max_price: { $max: "$base_price" },
        avg_rating: { $avg: "$rating_summary.avg" }
      }
    },
    {
      $project: {
        _id: 0,
        category: "$_id",
        product_count: 1,
        avg_price: { $round: ["$avg_price", 2] },
        min_price: 1,
        max_price: 1,
        avg_rating: { $round: ["$avg_rating", 2] }
      }
    },
    { $sort: { avg_price: -1 } }
  ]).toArray()
);

print("\n=== Q5: Aggregation Pipeline ($unwind) — Top Praised Features in Verified Reviews ===");
printjson(
  dbCatalog.product_reviews.aggregate([
    { $match: { verified_purchase: true, rating: { $gte: 4 } } },
    { $unwind: "$pros" },
    {
      $group: {
        _id: "$pros",
        mentions: { $sum: 1 },
        avg_helpful_votes: { $avg: "$helpful_votes" }
      }
    },
    {
      $project: {
        _id: 0,
        feature: "$_id",
        mentions: 1,
        avg_helpful_votes: { $round: ["$avg_helpful_votes", 1] }
      }
    },
    { $sort: { mentions: -1 } },
    { $limit: 8 }
  ]).toArray()
);

print("\n=== Q6: Aggregation Pipeline ($lookup) — Most-Reviewed Products with Verified Rating Breakdown ===");
printjson(
  dbCatalog.catalog_products.aggregate([
    { $match: { "rating_summary.count": { $gte: 5 } } },
    { $sort: { "rating_summary.count": -1 } },
    { $limit: 5 },
    {
      $lookup: {
        from: "product_reviews",
        let: { pid: "$pg_product_id" },
        pipeline: [
          { $match: { $expr: { $and: [{ $eq: ["$pg_product_id", "$$pid"] }, { $eq: ["$verified_purchase", true] }] } } },
          { $group: { _id: null, verified_count: { $sum: 1 }, verified_avg: { $avg: "$rating" } } }
        ],
        as: "verified_stats"
      }
    },
    {
      $project: {
        _id: 0,
        pg_product_id: 1,
        title: 1,
        category: "$category.name",
        overall_rating: "$rating_summary",
        verified_stats: { $arrayElemAt: ["$verified_stats", 0] }
      }
    }
  ]).toArray()
);

