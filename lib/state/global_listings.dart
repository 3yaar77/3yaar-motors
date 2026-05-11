library global_listings;

/// Very simple in-memory listings store for MVP
/// Each item shape:
/// {
///   "type": "car" | "plate" | "reel",
///   "title": String,          // e.g., "Mercedes G63" or "A 12345"
///   "price": String,          // raw input, e.g., "38000"
///   "image": String?,         // data:image/... or http(s); for reels can be preview/video url
///   "location": String,       // city or emirate
///   "time": DateTime          // creation time
/// }
List<Map<String, dynamic>> listings = [];

void addListingMap(Map<String, dynamic> item) {
  // Insert newest at top
  listings.insert(0, item);
}
