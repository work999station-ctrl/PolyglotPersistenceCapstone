// ============================================================================
// Polyglot Persistence Capstone — E-Commerce Marketplace (SoukTech)
// Component B (Part 1): MongoDB Native Catalog & Reviews Seed Script
// Engine: MongoDB 8 (database: souktech_catalog)
//
// Usage:
//   Get-Content .\mongo\01_seed_catalog.js -Raw | docker exec -i advdb-mongo mongosh -u student -p student --authenticationDatabase admin --quiet
// ============================================================================

const dbCatalog = db.getSiblingDB("souktech_catalog");

print("Resetting souktech_catalog collections...");
dbCatalog.catalog_products.drop();
dbCatalog.product_reviews.drop();

// Deterministic pseudo-random helper so seeds are reproducible across runs
let seed = 20261114;
function nextRand() {
  seed = (seed * 1664525 + 1013904223) % 4294967296;
  return seed / 4294967296;
}
function randInt(min, max) {
  return Math.floor(nextRand() * (max - min + 1)) + min;
}
function pick(arr) {
  return arr[randInt(0, arr.length - 1)];
}

// ----------------------------------------------------------------------------
// 1. Generate 20,000 Product Reviews (referencing pg_product_id 1..20000
//    and pg_customer_id 1..10000 from PostgreSQL)
// ----------------------------------------------------------------------------
const TOTAL_PRODUCTS = 20000;
const TOTAL_REVIEWS = 20000;

const prosPool = [
  "fast delivery", "great build quality", "value for money",
  "battery lasts long", "authentic product", "quiet operation",
  "comfortable fit", "clear documentation", "accurate description"
];
const consPool = [
  "packaging slightly worn", "pricey", "average battery",
  "limited color options", "heavy weight", "takes time to set up"
];
const firstNames = ["Amine", "Sarah", "Yacine", "Lina", "Karim", "Meriem", "Riad", "Nadia", "Sofiane", "Ines"];
const lastNames = ["Benali", "Khelifi", "Mansouri", "Boudiaf", "Ziani", "Haddad", "Brahimi", "Chikhi", "Saadi", "Belkacem"];

// Track exact rating sums & counts so catalog_products.rating_summary stays 100% consistent
const ratingSums = new Float64Array(TOTAL_PRODUCTS + 1);
const ratingCounts = new Int32Array(TOTAL_PRODUCTS + 1);

const handReviews = [
  {
    pg_product_id: 1,
    pg_customer_id: 1,
    customer_name: "Amine Benali",
    verified_purchase: true,
    rating: 5,
    title: "Solid ultrabook for database labs",
    comment: "Runs Docker with Postgres and MongoDB smoothly with 16GB RAM and fast NVMe SSD.",
    pros: ["fast delivery", "great build quality", "quiet operation"],
    cons: [],
    helpful_votes: 24,
    seller_reply: { text: "Thank you Amine! Glad it works great for your studies.", replied_at: new Date("2026-10-15T10:30:00Z") },
    created_at: new Date("2026-10-14T14:20:00Z")
  },
  {
    pg_product_id: 5,
    pg_customer_id: 1,
    customer_name: "Amine Benali",
    verified_purchase: true,
    rating: 4,
    title: "Great noise cancellation for the price",
    comment: "ANC blocks cafe noise well and battery easily lasts a full week.",
    pros: ["battery lasts long", "value for money"],
    cons: ["packaging slightly worn"],
    helpful_votes: 11,
    created_at: new Date("2026-10-16T09:15:00Z")
  },
  {
    pg_product_id: 10,
    pg_customer_id: 2,
    customer_name: "Sarah Khelifi",
    verified_purchase: true,
    rating: 5,
    title: "Must-read for distributed systems",
    comment: "Crystal clear explanation of transactions, isolation levels, and replication.",
    pros: ["clear documentation", "authentic product"],
    cons: [],
    helpful_votes: 38,
    created_at: new Date("2026-10-20T18:00:00Z")
  },
  {
    pg_product_id: 11,
    pg_customer_id: 2,
    customer_name: "Sarah Khelifi",
    verified_purchase: true,
    rating: 5,
    title: "Deep dive into B-tree and GIN internals",
    comment: "Helped us understand EXPLAIN (ANALYZE, BUFFERS) output immediately.",
    pros: ["clear documentation", "value for money"],
    cons: [],
    helpful_votes: 19,
    created_at: new Date("2026-10-21T11:45:00Z")
  }
];

let reviewBatch = [];
for (const r of handReviews) {
  ratingSums[r.pg_product_id] += r.rating;
  ratingCounts[r.pg_product_id] += 1;
  reviewBatch.push(r);
}

const baseTime = new Date("2025-01-01T00:00:00Z").getTime();
for (let i = handReviews.length + 1; i <= TOTAL_REVIEWS; i++) {
  // Skew slightly toward products 1..500 so popular items have many reviews for $lookup
  const pid = (i <= 2500) ? randInt(1, 500) : randInt(1, TOTAL_PRODUCTS);
  const cid = randInt(1, 10000);
  const rating = pick([3, 4, 4, 5, 5, 5, 2, 1]);
  const verified = nextRand() < 0.78;
  const pros = [pick(prosPool)];
  if (rating >= 4 && nextRand() < 0.65) {
    const second = pick(prosPool);
    if (second !== pros[0]) pros.push(second);
  }
  const cons = rating <= 3 ? [pick(consPool)] : (nextRand() < 0.25 ? [pick(consPool)] : []);

  ratingSums[pid] += rating;
  ratingCounts[pid] += 1;

  const doc = {
    pg_product_id: pid,
    pg_customer_id: cid,
    customer_name: `${pick(firstNames)} ${pick(lastNames)}`,
    verified_purchase: verified,
    rating: rating,
    title: rating >= 4 ? "Satisfied with this item" : "Could be better",
    comment: rating >= 4
      ? "Matches marketplace description and works as expected."
      : "Acceptable overall, though had minor drawbacks.",
    pros: pros,
    cons: cons,
    helpful_votes: randInt(0, 45),
    created_at: new Date(baseTime + randInt(0, 550) * 86400000)
  };
  if (i % 10 === 0) {
    doc.seller_reply = {
      text: "Thank you for your feedback! Feel free to reach out to support anytime.",
      replied_at: new Date(doc.created_at.getTime() + 86400000)
    };
  }
  reviewBatch.push(doc);

  if (reviewBatch.length >= 5000) {
    dbCatalog.product_reviews.insertMany(reviewBatch, { ordered: false });
    reviewBatch = [];
  }
}
if (reviewBatch.length > 0) {
  dbCatalog.product_reviews.insertMany(reviewBatch, { ordered: false });
}
print(`Inserted ${dbCatalog.product_reviews.countDocuments()} product_reviews documents.`);

// ----------------------------------------------------------------------------
// 2. Helper to build rating_summary from computed review totals
// ----------------------------------------------------------------------------
function buildRatingSummary(pid, fallbackAvg) {
  const count = ratingCounts[pid];
  if (count === 0) {
    return { avg: fallbackAvg, count: 0 };
  }
  return {
    avg: Math.round((ratingSums[pid] / count) * 100) / 100,
    count: count
  };
}

// ----------------------------------------------------------------------------
// 3. Hand-Written Reference Products (pg_product_id 1..15 matching Postgres)
// ----------------------------------------------------------------------------
const sellersRef = {
  1: { pg_seller_id: 1, store_name: "Atlas Tech Store", verified: true },
  2: { pg_seller_id: 2, store_name: "Numidia Fashion House", verified: true },
  3: { pg_seller_id: 3, store_name: "Cirta Bookshop", verified: true },
  4: { pg_seller_id: 4, store_name: "Oran Home Essentials", verified: false },
  5: { pg_seller_id: 5, store_name: "Maghreb Gadgets", verified: true }
};

const refProducts = [
  {
    pg_product_id: 1, sku: "SKU-LAP-001", title: "ThinkBook 14 Gen 6 Laptop",
    category: { id: 5, name: "Laptops", slug: "laptops", parent: "electronics" },
    seller: sellersRef[1], base_price: 145000, tags: ["laptop", "ultrabook", "work", "nvme"],
    specs: { brand: "Lenovo", cpu: { model: "Core Ultra 5 125U", cores: 12, base_ghz: 1.3 }, ram_gb: 16, storage: { type: "NVMe", capacity_gb: 512 }, display: { size_in: 14.0, resolution: "1920x1200", refresh_hz: 60 }, ports: ["USB-C", "HDMI 2.1", "USB-A", "RJ45"] },
    variants: [
      { variant_sku: "SKU-LAP-001-16-512", attributes: { color: "Arctic Grey", ram_gb: 16, storage_gb: 512 }, price_delta: 0, available: true },
      { variant_sku: "SKU-LAP-001-32-1T", attributes: { color: "Arctic Grey", ram_gb: 32, storage_gb: 1024 }, price_delta: 28000, available: true }
    ]
  },
  {
    pg_product_id: 2, sku: "SKU-LAP-002", title: "ProBook Nitro 16 Gaming Laptop",
    category: { id: 5, name: "Laptops", slug: "laptops", parent: "electronics" },
    seller: sellersRef[1], base_price: 215000, tags: ["laptop", "gaming", "rtx", "16gb"],
    specs: { brand: "Acer", cpu: { model: "Ryzen 7 7840HS", cores: 8, base_ghz: 3.8 }, gpu: "RTX 4060 8GB", ram_gb: 16, storage: { type: "NVMe", capacity_gb: 1024 }, display: { size_in: 16.0, resolution: "2560x1600", refresh_hz: 165 }, ports: ["USB-C", "HDMI 2.1", "USB-A", "Ethernet"] },
    variants: [
      { variant_sku: "SKU-LAP-002-BLK", attributes: { color: "Obsidian Black", ram_gb: 16, storage_gb: 1024 }, price_delta: 0, available: true }
    ]
  },
  {
    pg_product_id: 3, sku: "SKU-PHN-001", title: "Galaxy A55 5G Smartphone",
    category: { id: 6, name: "Smartphones", slug: "smartphones", parent: "electronics" },
    seller: sellersRef[5], base_price: 68000, tags: ["smartphone", "5g", "amoled", "android"],
    specs: { brand: "Samsung", chipset: "Exynos 1480", ram_gb: 8, storage_gb: 256, battery_mah: 5000, camera: { main_mp: 50, ultrawide_mp: 12 }, supports_5g: true },
    variants: [
      { variant_sku: "SKU-PHN-001-NVY", attributes: { color: "Awesome Navy", storage_gb: 256 }, price_delta: 0, available: true },
      { variant_sku: "SKU-PHN-001-ICE", attributes: { color: "Iceblue", storage_gb: 128 }, price_delta: -6000, available: true }
    ]
  },
  {
    pg_product_id: 4, sku: "SKU-PHN-002", title: "Pixel 8a 128GB",
    category: { id: 6, name: "Smartphones", slug: "smartphones", parent: "electronics" },
    seller: sellersRef[5], base_price: 89000, tags: ["smartphone", "camera", "5g"],
    specs: { brand: "Google", chipset: "Tensor G3", ram_gb: 8, storage_gb: 128, battery_mah: 4492, camera: { main_mp: 64, ultrawide_mp: 13 }, supports_5g: true },
    variants: [
      { variant_sku: "SKU-PHN-002-OBS", attributes: { color: "Obsidian", storage_gb: 128 }, price_delta: 0, available: true }
    ]
  },
  {
    pg_product_id: 5, sku: "SKU-AUD-001", title: "SoundCore ANC Wireless Headphones",
    category: { id: 7, name: "Audio & Wearables", slug: "audio-wearables", parent: "electronics" },
    seller: sellersRef[1], base_price: 14500, tags: ["audio", "wireless", "bluetooth", "anc"],
    specs: { brand: "Anker", connectivity: ["Bluetooth 5.3", "3.5mm AUX"], battery_hours: 40, features: ["Active Noise Cancellation", "Multipoint", "Fast Charge"] },
    variants: [
      { variant_sku: "SKU-AUD-001-BLK", attributes: { color: "Black" }, price_delta: 0, available: true },
      { variant_sku: "SKU-AUD-001-NVY", attributes: { color: "Midnight Blue" }, price_delta: 400, available: true }
    ]
  },
  {
    pg_product_id: 6, sku: "SKU-AUD-002", title: "FitPulse Pro Smartwatch",
    category: { id: 7, name: "Audio & Wearables", slug: "audio-wearables", parent: "electronics" },
    seller: sellersRef[5], base_price: 18900, tags: ["wearable", "smartwatch", "fitness", "bluetooth"],
    specs: { brand: "FitPulse", connectivity: ["Bluetooth 5.2", "GPS"], battery_hours: 240, features: ["Heart Rate", "SpO2", "5ATM Waterproof"] },
    variants: [
      { variant_sku: "SKU-AUD-002-44", attributes: { color: "Black", size: "44mm" }, price_delta: 0, available: true }
    ]
  },
  {
    pg_product_id: 7, sku: "SKU-CLO-001", title: "Organic Cotton Oxford Shirt",
    category: { id: 8, name: "Men Clothing", slug: "men-clothing", parent: "fashion" },
    seller: sellersRef[2], base_price: 4500, tags: ["shirt", "cotton", "formal", "breathable"],
    specs: { brand: "Numidia", material: "100% Organic Cotton", fit: "Regular", season: "All-season", care_instructions: ["Machine wash 30C", "Low iron"] },
    variants: [
      { variant_sku: "SKU-CLO-001-BLK-L", attributes: { color: "Black", size: "L" }, price_delta: 0, available: true },
      { variant_sku: "SKU-CLO-001-WHT-M", attributes: { color: "White", size: "M" }, price_delta: 0, available: true },
      { variant_sku: "SKU-CLO-001-NVY-XL", attributes: { color: "Navy", size: "XL" }, price_delta: 300, available: false }
    ]
  },
  {
    pg_product_id: 8, sku: "SKU-CLO-002", title: "Atlas Heavyweight Hoodie",
    category: { id: 8, name: "Men Clothing", slug: "men-clothing", parent: "fashion" },
    seller: sellersRef[2], base_price: 5800, tags: ["hoodie", "winter", "cotton", "casual"],
    specs: { brand: "Numidia", material: "85% Cotton / 15% Polyester Fleece", fit: "Relaxed", season: "Winter", care_instructions: ["Machine wash cold", "Do not tumble dry"] },
    variants: [
      { variant_sku: "SKU-CLO-002-BLK-L", attributes: { color: "Black", size: "L" }, price_delta: 200, available: true },
      { variant_sku: "SKU-CLO-002-GRY-M", attributes: { color: "Heather Grey", size: "M" }, price_delta: 0, available: true }
    ]
  },
  {
    pg_product_id: 9, sku: "SKU-SHOE-01", title: "Nomad Trail Running Sneakers",
    category: { id: 9, name: "Footwear", slug: "footwear", parent: "fashion" },
    seller: sellersRef[2], base_price: 11200, tags: ["shoes", "running", "trail", "waterproof"],
    specs: { brand: "Nomad", material: "Ripstop Mesh + Vibram Sole", fit: "True to size", season: "All-season", care_instructions: ["Spot clean only", "Air dry"] },
    variants: [
      { variant_sku: "SKU-SHOE-01-BLK-42", attributes: { color: "Black", size: "42" }, price_delta: 0, available: true },
      { variant_sku: "SKU-SHOE-01-BLK-43", attributes: { color: "Black", size: "43" }, price_delta: 0, available: false }
    ]
  },
  {
    pg_product_id: 10, sku: "SKU-BOK-001", title: "Designing Data-Intensive Applications",
    category: { id: 10, name: "Technical Books", slug: "technical-books", parent: "books-media" },
    seller: sellersRef[3], base_price: 6500, tags: ["book", "databases", "distributed", "engineering"],
    specs: { isbn: "978-1449373320", authors: ["Martin Kleppmann"], publisher: "O'Reilly Media", edition: "1st", pages: 616, language: "English", topics: ["Replication", "Partitioning", "Transactions", "Stream Processing"] },
    variants: [
      { variant_sku: "SKU-BOK-001-PB", attributes: { edition: "Paperback" }, price_delta: 0, available: true }
    ]
  },
  {
    pg_product_id: 11, sku: "SKU-BOK-002", title: "PostgreSQL Internals & Tuning",
    category: { id: 10, name: "Technical Books", slug: "technical-books", parent: "books-media" },
    seller: sellersRef[3], base_price: 5200, tags: ["book", "postgresql", "sql", "performance"],
    specs: { isbn: "978-1718502147", authors: ["Egor Rogov"], publisher: "No Starch Press", edition: "1st", pages: 560, language: "English", topics: ["MVCC", "B-Tree", "GIN", "Query Planner"] },
    variants: [
      { variant_sku: "SKU-BOK-002-PB", attributes: { edition: "Paperback" }, price_delta: 0, available: true }
    ]
  },
  {
    pg_product_id: 12, sku: "SKU-BOK-003", title: "MongoDB Modeling Patterns",
    category: { id: 10, name: "Technical Books", slug: "technical-books", parent: "books-media" },
    seller: sellersRef[3], base_price: 4800, tags: ["book", "mongodb", "nosql", "schema"],
    specs: { isbn: "978-1800560000", authors: ["Daniel Coupal"], publisher: "Packt", edition: "2nd", pages: 410, language: "English", topics: ["Polymorphic Pattern", "Bucket Pattern", "Aggregation Pipeline"] },
    variants: [
      { variant_sku: "SKU-BOK-003-PB", attributes: { edition: "Paperback" }, price_delta: 0, available: true }
    ]
  },
  {
    pg_product_id: 13, sku: "SKU-HOM-001", title: "Espresso Barista Machine 15-Bar",
    category: { id: 4, name: "Home & Kitchen", slug: "home-kitchen", parent: null },
    seller: sellersRef[4], base_price: 34000, tags: ["kitchen", "coffee", "espresso"],
    specs: { brand: "OranBrew", power_watts: 1450, capacity_liters: 1.8, energy_rating: "A+", warranty_months: 24 },
    variants: [
      { variant_sku: "SKU-HOM-001-SLV", attributes: { color: "Brushed Steel" }, price_delta: 0, available: true }
    ]
  },
  {
    pg_product_id: 14, sku: "SKU-HOM-002", title: "Smart Air Purifier HEPA-13",
    category: { id: 4, name: "Home & Kitchen", slug: "home-kitchen", parent: null },
    seller: sellersRef[4], base_price: 27500, tags: ["home", "air-purifier", "smart"],
    specs: { brand: "PureAir", power_watts: 45, coverage_m2: 48, energy_rating: "A++", warranty_months: 24 },
    variants: [
      { variant_sku: "SKU-HOM-002-WHT", attributes: { color: "Matte White" }, price_delta: 0, available: true }
    ]
  },
  {
    pg_product_id: 15, sku: "SKU-LAP-003", title: "Limited Edition Workstation (1 left)",
    category: { id: 5, name: "Laptops", slug: "laptops", parent: "electronics" },
    seller: sellersRef[1], base_price: 290000, tags: ["laptop", "workstation", "limited"],
    specs: { brand: "Dell", cpu: { model: "Core i9-14900HX", cores: 24, base_ghz: 2.2 }, gpu: "RTX 4080 12GB", ram_gb: 64, storage: { type: "NVMe", capacity_gb: 2048 }, display: { size_in: 16.0, resolution: "3840x2400", refresh_hz: 120 }, ports: ["Thunderbolt 4", "HDMI 2.1", "SD Reader"] },
    variants: [
      { variant_sku: "SKU-LAP-003-64-2T", attributes: { color: "Titan Grey", ram_gb: 64, storage_gb: 2048 }, price_delta: 0, available: true }
    ]
  }
];

let productBatch = [];
for (const p of refProducts) {
  p.rating_summary = buildRatingSummary(p.pg_product_id, 4.7);
  p.is_active = true;
  p.created_at = new Date("2026-10-01T08:00:00Z");
  productBatch.push(p);
}

// ----------------------------------------------------------------------------
// 4. Generate Remaining 19,985 Products (pg_product_id 16..20000)
//    Each category uses its own authentic nested specs schema!
// ----------------------------------------------------------------------------
const categoriesMeta = [
  { id: 5,  name: "Laptops",           slug: "laptops",         parent: "electronics" },
  { id: 6,  name: "Smartphones",       slug: "smartphones",     parent: "electronics" },
  { id: 7,  name: "Audio & Wearables", slug: "audio-wearables", parent: "electronics" },
  { id: 8,  name: "Men Clothing",      slug: "men-clothing",    parent: "fashion" },
  { id: 9,  name: "Footwear",          slug: "footwear",        parent: "fashion" },
  { id: 10, name: "Technical Books",   slug: "technical-books", parent: "books-media" },
  { id: 4,  name: "Home & Kitchen",    slug: "home-kitchen",    parent: null }
];

const laptopBrands = ["Lenovo", "Dell", "HP", "Asus", "Acer"];
const laptopCPUs = ["Core i5-1340P", "Core i7-1360P", "Core Ultra 5", "Ryzen 5 7535U", "Ryzen 7 7840HS"];
const phoneBrands = ["Samsung", "Google", "Xiaomi", "Realme", "OnePlus"];
const colors = ["Black", "White", "Navy", "Grey", "Olive"];
const sizesClothing = ["S", "M", "L", "XL"];
const sizesShoe = ["40", "41", "42", "43", "44"];

for (let pid = 16; pid <= TOTAL_PRODUCTS; pid++) {
  const cat = categoriesMeta[(pid - 16) % categoriesMeta.length];
  const sellerId = randInt(1, 1000);
  const sellerObj = sellersRef[sellerId] || {
    pg_seller_id: sellerId,
    store_name: `Marketplace Seller #${sellerId}`,
    verified: (sellerId % 4 !== 0)
  };

  let title = "";
  let basePrice = 5000;
  let tags = [];
  let specs = {};
  let variants = [];

  if (cat.slug === "laptops") {
    const brand = pick(laptopBrands);
    const ram = pick([8, 16, 32, 64]);
    const cap = pick([256, 512, 1024, 2048]);
    const stType = pick(["NVMe", "NVMe", "SATA SSD"]);
    title = `${brand} WorkStation Series ${pid}`;
    basePrice = randInt(75000, 320000);
    tags = ["laptop", stType === "NVMe" ? "nvme" : "ssd", ram >= 16 ? "pro" : "student"];
    specs = {
      brand: brand,
      cpu: { model: pick(laptopCPUs), cores: pick([6, 8, 12, 16]), base_ghz: pick([1.8, 2.2, 3.2]) },
      ram_gb: ram,
      storage: { type: stType, capacity_gb: cap },
      display: { size_in: pick([13.3, 14.0, 15.6, 16.0]), resolution: pick(["1920x1080", "2560x1600"]), refresh_hz: pick([60, 120, 144]) },
      ports: ["USB-C", "HDMI 2.1", "USB-A"]
    };
    variants = [
      { variant_sku: `SKU-${pid}-A`, attributes: { color: pick(["Silver", "Black", "Grey"]), ram_gb: ram }, price_delta: 0, available: nextRand() < 0.85 },
      { variant_sku: `SKU-${pid}-B`, attributes: { color: "Black", ram_gb: ram * 2 }, price_delta: 25000, available: nextRand() < 0.7 }
    ];
  } else if (cat.slug === "smartphones") {
    const brand = pick(phoneBrands);
    const storageGb = pick([64, 128, 256, 512]);
    const has5g = nextRand() < 0.75;
    title = `${brand} SmartPhone Model ${pid}`;
    basePrice = randInt(28000, 150000);
    tags = has5g ? ["smartphone", "5g", "android"] : ["smartphone", "4g", "budget"];
    specs = {
      brand: brand,
      chipset: pick(["Snapdragon 7s Gen 2", "Exynos 1480", "Dimensity 8200", "Tensor G3"]),
      ram_gb: pick([6, 8, 12]),
      storage_gb: storageGb,
      battery_mah: pick([4500, 5000, 5500]),
      camera: { main_mp: pick([48, 50, 64, 108]), ultrawide_mp: pick([8, 12]) },
      supports_5g: has5g
    };
    variants = [
      { variant_sku: `SKU-${pid}-A`, attributes: { color: pick(colors), storage_gb: storageGb }, price_delta: 0, available: true },
      { variant_sku: `SKU-${pid}-B`, attributes: { color: pick(colors), storage_gb: storageGb * 2 }, price_delta: 12000, available: nextRand() < 0.6 }
    ];
  } else if (cat.slug === "audio-wearables") {
    const brand = pick(["Anker", "Sony", "JBL", "FitPulse", "Xiaomi"]);
    title = `${brand} Audio Gear ${pid}`;
    basePrice = randInt(4500, 42000);
    tags = ["audio", "wireless", "bluetooth", nextRand() < 0.5 ? "anc" : "sport"];
    specs = {
      brand: brand,
      connectivity: ["Bluetooth 5.3", "USB-C"],
      battery_hours: randInt(12, 60),
      features: pick([["Active Noise Cancellation", "Fast Charge"], ["Waterproof IPX7", "Touch Controls"]])
    };
    variants = [
      { variant_sku: `SKU-${pid}-A`, attributes: { color: pick(["Black", "White", "Navy"]) }, price_delta: 0, available: true }
    ];
  } else if (cat.slug === "men-clothing") {
    const color = pick(colors);
    const size = pick(sizesClothing);
    title = `Numidia Essential Apparel #${pid}`;
    basePrice = randInt(1800, 9500);
    tags = ["clothing", "cotton", "casual"];
    specs = {
      brand: pick(["Numidia", "AtlasWear", "CirtaTextiles"]),
      material: pick(["100% Organic Cotton", "Linen Blend", "Cotton Fleece"]),
      fit: pick(["Slim", "Regular", "Relaxed"]),
      season: pick(["Summer", "Winter", "All-season"]),
      care_instructions: ["Machine wash 30C", "Air dry"]
    };
    variants = [
      { variant_sku: `SKU-${pid}-A`, attributes: { color: color, size: size }, price_delta: randInt(0, 600), available: nextRand() < 0.82 },
      { variant_sku: `SKU-${pid}-B`, attributes: { color: "Black", size: "L" }, price_delta: randInt(0, 800), available: nextRand() < 0.75 }
    ];
  } else if (cat.slug === "footwear") {
    title = `Nomad Active Footwear #${pid}`;
    basePrice = randInt(4500, 19000);
    tags = ["shoes", "sneakers", "comfort"];
    specs = {
      brand: pick(["Nomad", "AtlasRun", "Kinetix"]),
      material: pick(["Breathable Mesh", "Synthetic Leather", "Canvas"]),
      fit: "True to size",
      season: "All-season",
      care_instructions: ["Spot clean only"]
    };
    variants = [
      { variant_sku: `SKU-${pid}-A`, attributes: { color: pick(colors), size: pick(sizesShoe) }, price_delta: 0, available: nextRand() < 0.85 },
      { variant_sku: `SKU-${pid}-B`, attributes: { color: "Black", size: "42" }, price_delta: randInt(0, 700), available: nextRand() < 0.65 }
    ];
  } else if (cat.slug === "technical-books") {
    title = `Systems & Data Engineering Vol. ${pid}`;
    basePrice = randInt(2500, 9000);
    tags = ["book", "engineering", pick(["databases", "algorithms", "cloud", "nosql"])];
    specs = {
      isbn: `978-1-${String(100000 + pid).slice(-6)}-0`,
      authors: [`Author ${pid % 200}`],
      publisher: pick(["O'Reilly Media", "No Starch Press", "MIT Press", "Packt"]),
      edition: pick(["1st", "2nd", "3rd"]),
      pages: randInt(220, 780),
      language: pick(["English", "French"]),
      topics: pick([["Databases", "Indexing"], ["Distributed Systems", "Consensus"], ["Data Modeling", "NoSQL"]])
    };
    variants = [
      { variant_sku: `SKU-${pid}-PB`, attributes: { edition: "Paperback" }, price_delta: 0, available: true }
    ];
  } else {
    title = `Oran Home Appliance #${pid}`;
    basePrice = randInt(6000, 55000);
    tags = ["home", "kitchen", "appliance"];
    specs = {
      brand: pick(["OranBrew", "PureAir", "MaghrebHome"]),
      power_watts: randInt(40, 2200),
      capacity_liters: pick([1.2, 1.8, 3.5, 5.0]),
      energy_rating: pick(["A", "A+", "A++"]),
      warranty_months: pick([12, 24])
    };
    variants = [
      { variant_sku: `SKU-${pid}-A`, attributes: { color: pick(["Brushed Steel", "Matte White", "Black"]) }, price_delta: 0, available: true }
    ];
  }

  productBatch.push({
    pg_product_id: pid,
    sku: `SKU-GEN-${String(pid).padStart(5, "0")}`,
    title: title,
    category: cat,
    seller: sellerObj,
    base_price: basePrice,
    tags: tags,
    specs: specs,
    variants: variants,
    rating_summary: buildRatingSummary(pid, Math.round((3.5 + nextRand() * 1.5) * 100) / 100),
    is_active: nextRand() < 0.96,
    created_at: new Date(baseTime + randInt(0, 500) * 86400000)
  });

  if (productBatch.length >= 5000) {
    dbCatalog.catalog_products.insertMany(productBatch, { ordered: false });
    productBatch = [];
  }
}
if (productBatch.length > 0) {
  dbCatalog.catalog_products.insertMany(productBatch, { ordered: false });
}
print(`Inserted ${dbCatalog.catalog_products.countDocuments()} catalog_products documents.`);

// ----------------------------------------------------------------------------
// 5. Create Native MongoDB Indexes
// ----------------------------------------------------------------------------
dbCatalog.catalog_products.createIndex({ pg_product_id: 1 }, { unique: true });
dbCatalog.catalog_products.createIndex({ sku: 1 }, { unique: true });
dbCatalog.catalog_products.createIndex({ "category.slug": 1, base_price: 1 });
dbCatalog.catalog_products.createIndex({ tags: 1 });
dbCatalog.catalog_products.createIndex({ "specs.ram_gb": 1, "specs.storage.type": 1 });
dbCatalog.catalog_products.createIndex({ "variants.attributes.color": 1, "variants.attributes.size": 1 });

dbCatalog.product_reviews.createIndex({ pg_product_id: 1, verified_purchase: 1 });
dbCatalog.product_reviews.createIndex({ pg_customer_id: 1 });

print("Created indexes on catalog_products and product_reviews.");
print("MongoDB seed complete! Total documents = " +
  (dbCatalog.catalog_products.countDocuments() + dbCatalog.product_reviews.countDocuments()));

