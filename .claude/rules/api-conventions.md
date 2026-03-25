---
globs: "src/api/**,app/api/**,src/routes/**,src/controllers/**,app/**/route.ts,app/**/route.tsx"
---

# API Layer Conventions

Routes are thin. They validate input, delegate to services, and return responses. Business logic lives in services.

## Structure

- Validate all input at the route boundary (Zod / Pydantic) **before** calling any service function
- Services raise domain exceptions — routes catch them and translate to HTTP responses
- Never import DB clients directly in route handlers — use service functions
- Auth middleware runs before every protected route — never check auth inside services

## Response Shape

Always return consistent JSON:
- **Success**: the resource or `{ "data": ... }` wrapper
- **Error**: `{ "error": "human-readable message" }` or `{ "error": { "field": "message" } }` for validation

## HTTP Status Codes

| Status | When to use |
|--------|-------------|
| `200` | Successful GET / PUT / PATCH |
| `201` | Resource created (POST) |
| `204` | Success with no body (DELETE) |
| `400` | Bad input / validation failure |
| `401` | Not authenticated |
| `403` | Authenticated but not authorized |
| `404` | Resource not found |
| `409` | Conflict (duplicate, slot already taken) |
| `422` | Valid schema but fails business rules |
| `500` | Unexpected server error — never expose details |

## Pagination

For list endpoints returning potentially large sets: use cursor-based pagination. Return `{ data: [], nextCursor: string | null }`.
