# Marketplace Architecture: SQL & GraphQL

> **Note:** This is a planned backend architecture, not the current implementation. The app currently uses Firebase (Firestore + Auth + Storage) exclusively. This document describes the target design as Cove migrates to a custom backend — see [Backend Infrastructure](BACKEND_INFRASTRUCTURE.md) for the migration phases. Firestore is retired in Phase 3.

## Overview

This architecture is for a local marketplace discovery app where users browse vendors and products, track places they want to visit, and share social content. Purchases happen in person — there is no order management or payment processing in v1. It uses:
- **SQL backend (PostgreSQL)** for all data — products, vendors, users, visit lists, reviews, and social content.
- **GraphQL API layer** for unifying data queries and flexible client consumption.

> **Out of scope for v1:** Orders, payments, and fulfillment. Purchases happen in person — the app tracks visit intent and outcomes, not transactions.

---

## Data Model

All entities live in PostgreSQL. The data is relational, consistency matters, and volume is well within what Postgres handles comfortably.

| Entity                        | Notes                                                              |
|-------------------------------|--------------------------------------------------------------------|
| User accounts/profiles        | Structured, relational, supports ACID transactions.                |
| Product listings              | Structured, supports relationships (vendor, category, etc).        |
| Vendor management             | Relational data, strong consistency.                               |
| Visit List                    | Per-user rows with status tracking (pending → visited).            |
| Reviews/comments              | Relational to product and user; queryable by product or author.    |
| Social posts/feeds            | Structured content with user and optional product references.      |
| Likes/follows/notifications   | Event rows keyed to user; aggregates computed via SQL.             |

---

## Example: Merging Data for a Product Page

### API Design

All data for a product page comes from SQL via a single GraphQL query:

- **SQL**: Fetch product details
- **SQL**: Fetch reviews for that product

### Example REST API Pseudocode

```python
def get_product_page(product_id):
    product = sql_query("SELECT * FROM products WHERE id = ?", [product_id])
    reviews = sql_query("SELECT * FROM reviews WHERE product_id = ?", [product_id])
    return {
        "product": product,
        "reviews": reviews
    }
```

---

## GraphQL Integration

GraphQL acts as a unified data facade, letting clients request exactly what they need from the SQL backend:

### Why Use GraphQL?

- One endpoint for all resources
- Precise and flexible data requests (avoid over- or under-fetching)
- Cleanly compose relational data in a single query

### Example GraphQL Query

```graphql
query GetProductAndReviews($id: ID!) {
  product(id: $id) {
    id
    name
    price
    vendor
    reviews(limit: 5) {
      user
      rating
      comment
    }
  }
}
```

#### Resolvers

- `product`: Queries the `products` table.
- `reviews`: Queries the `reviews` table filtered by `product.id`.

#### Example Response (GraphQL API)

```json
{
  "product": {
    "id": "p123",
    "name": "Local Honey",
    "price": 12.00,
    "vendor": "Sunrise Apiaries",
    "reviews": [
      { "user": "jane", "rating": 5, "comment": "Great quality!" },
      { "user": "sam", "rating": 4, "comment": "Loved the taste." }
    ]
  }
}
```

---

## Client Implementation Examples

### iOS Client (Swift)

```swift
import Foundation

struct Product: Codable {
    let id: String
    let name: String
    let price: Double
    let vendor: String
}

struct Review: Codable {
    let user: String
    let rating: Int
    let comment: String
}

struct ProductResponse: Codable {
    let product: Product
    let reviews: [Review]
}

class ProductService {
    func fetchProductPage(productId: String, completion: @escaping (ProductResponse?) -> Void) {
        guard let url = URL(string: "https://api.cove.app/graphql") else { return }

        let query = """
        query GetProductAndReviews($id: ID!) {
          product(id: $id) {
            id
            name
            price
            vendor
            reviews(limit: 5) {
              user
              rating
              comment
            }
          }
        }
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["query": query, "variables": ["id": productId]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else { return }
            let decoded = try? JSONDecoder().decode(ProductResponse.self, from: data)
            completion(decoded)
        }.resume()
    }
}
```

---

## Database Schema (PostgreSQL)

```sql
-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Vendors table
CREATE TABLE vendors (
    id SERIAL PRIMARY KEY,
    user_id INT UNIQUE NOT NULL,
    business_name VARCHAR(255),
    description TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Products table
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    vendor_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2),
    inventory INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (vendor_id) REFERENCES vendors(id)
);

-- Orders and payments are out of scope for v1.
-- Purchases happen in person; the visit_list table tracks intent and outcomes.

-- Visit list table
CREATE TABLE visit_list (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    type VARCHAR(10) NOT NULL CHECK (type IN ('vendor', 'product')),
    vendor_id INT,
    product_id INT,
    status VARCHAR(10) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'visited')),
    purchased BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    visited_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (vendor_id) REFERENCES vendors(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- Reviews table
CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL,
    user_id INT NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Social posts table
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    content TEXT,
    image_url TEXT,
    product_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- Notifications table
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    type VARCHAR(50) NOT NULL,
    message TEXT,
    related_product_id INT,
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (related_product_id) REFERENCES products(id)
);
```

---

## Deployment on Google Cloud Platform (GCP)

### Architecture Overview

1. **API Layer**: Host GraphQL or REST API on Cloud Run or App Engine
2. **SQL Database**: Cloud SQL (PostgreSQL)
3. **Authentication**: Firebase Auth (kept through migration — see [Backend Infrastructure](BACKEND_INFRASTRUCTURE.md))
4. **Storage**: Cloud Storage for images/files
5. **CDN**: Cloud CDN for static assets

### Deployment Steps

1. **Create GCP Project**
   ```bash
   gcloud projects create marketplace-app
   ```

2. **Set up Cloud SQL**
   ```bash
   gcloud sql instances create marketplace-db \
     --database-version POSTGRES_13 \
     --region us-central1 \
     --tier db-f1-micro
   ```

3. **Deploy GraphQL API on Cloud Run**
   ```bash
   gcloud run deploy marketplace-api \
     --source . \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated
   ```

### Environment Variables

```bash
DATABASE_URL=postgresql://user:password@ip:5432/marketplace
JWT_SECRET=your_jwt_secret_key
```

---

## Best Practices

### Data Consistency
- All data lives in SQL — use transactions for multi-step writes (e.g., updating visit status + recording outcome).
- Add database indexes on frequently queried fields (`product_id`, `user_id`, `vendor_id`, `status`).

### Security
- Implement authentication in the API layer.
- Use role-based access control (RBAC) for vendor/admin operations.
- Validate and sanitize all user inputs.
- Encrypt sensitive data (passwords, personal info) in transit and at rest.

### Performance
- Cache frequently accessed data (product listings, popular reviews).
- Use pagination for large result sets (reviews, posts, notifications).
- Monitor query performance and optimize slow queries.

### Scalability
- Use database read replicas for read-heavy operations.
- Implement caching layer (Redis) for hot data.
- Use message queues (Pub/Sub) for asynchronous operations.
- Horizontally scale API servers behind a load balancer.

### Monitoring & Logging
- Log all API requests and errors.
- Set up alerts for database performance issues.
- Monitor API latency and response times.
- Track business metrics (visits, active users, popular vendors, conversion to purchase).

---

## Example: Building a Reviews Feature

### Backend Resolver (Node.js/Apollo GraphQL)

```javascript
const resolvers = {
  Product: {
    reviews: async (product, args) => {
      const pool = getPostgresPool();
      const result = await pool.query(
        'SELECT * FROM reviews WHERE product_id = $1 LIMIT $2',
        [product.id, args.limit || 10]
      );
      return result.rows;
    }
  },
  Query: {
    product: async (_, { id }) => {
      const pool = getPostgresPool();
      const result = await pool.query('SELECT * FROM products WHERE id = $1', [id]);
      return result.rows[0];
    }
  }
};
```

### Adding a Review (Mutation)

```graphql
mutation AddReview($productId: ID!, $userId: ID!, $rating: Int!, $comment: String!) {
  addReview(productId: $productId, userId: $userId, rating: $rating, comment: $comment) {
    id
    rating
    comment
    createdAt
  }
}
```

### Resolver Implementation

```javascript
const Mutation = {
  addReview: async (_, { productId, userId, rating, comment }) => {
    const pool = getPostgresPool();
    const result = await pool.query(
      'INSERT INTO reviews (product_id, user_id, rating, comment) VALUES ($1, $2, $3, $4) RETURNING *',
      [productId, userId, rating, comment]
    );
    return result.rows[0];
  }
};
```

---

## References & Further Reading

- PostgreSQL Documentation
- GraphQL Best Practices and Architecture
- Google Cloud Platform Database Patterns
- Marketplace Database Design Patterns
- API Design for Mobile and Web Applications

---

## Revision History

- **Version 1.0** - Initial architecture document (November 2025)
  - Defined hybrid SQL + NoSQL split for marketplace app
  - Added GraphQL integration examples
  - Included GCP deployment guidance
  - Added client implementation examples for iOS and Web
  - Provided database schema examples and best practices
- **Version 2.0** - Pivoted to SQL-only backend (May 2026)
  - All data (products, vendors, users, visit lists, reviews, posts, notifications) moved to PostgreSQL
  - Removed NoSQL (Firestore) from target architecture — aligns with Phase 3 of [Backend Infrastructure](BACKEND_INFRASTRUCTURE.md)
  - Added `visit_list`, `reviews`, `posts`, and `notifications` SQL table schemas
  - Updated GraphQL resolvers to use PostgreSQL throughout
  - Removed orders/payments (out of scope for v1 — purchases happen in person)
