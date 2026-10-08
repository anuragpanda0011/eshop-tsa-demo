# API Endpoints

This folder demonstrates how to configure API endpoints as individual classes.
You can compare it to the traditional controller-based approach found in
`/Web/Controllers/Api`.

## Modernization Notes

- All routes are now prefixed with `/api/v1/`.
- JWT secret is read from the `JWT_SECRET_KEY` environment variable at startup
  (populated from Azure Key Vault via the app's Managed Identity in production).
- Redis distributed cache (Azure Cache for Redis) is used for read-heavy
  endpoints; the connection string is read from `REDIS_CONNECTION_STRING`.
- Rate limiting is applied to auth endpoints via the built-in ASP.NET Core 8
  rate limiter.
- Structured JSON logs are emitted to stdout; every log line includes the Azure
  trace ID for correlation with Application Insights.
- Image uploads are stored in Azure Blob Storage (server-side encryption,
  MIME + extension validation, 5 MB size limit).
- State-changing operations publish structured JSON events to Azure Service Bus.
- `POST` endpoints that mutate money or inventory accept an
  `X-Idempotency-Key` header; the response is cached in Redis for 24 h.
