# syntax=docker/dockerfile:1.6
###############################################################################
# STAGE 1 — builder
###############################################################################
FROM mcr.microsoft.com/dotnet/sdk:8.0-bookworm-slim AS builder
WORKDIR /build

# Copy solution and project files first for layer-cache efficiency
COPY eShopOnWeb.sln global.json ./
COPY src/ApplicationCore/ApplicationCore.csproj        src/ApplicationCore/
COPY src/Infrastructure/Infrastructure.csproj          src/Infrastructure/
COPY src/Web/Web.csproj                                src/Web/
COPY src/PublicApi/PublicApi.csproj                    src/PublicApi/
COPY src/BlazorAdmin/BlazorAdmin.csproj                src/BlazorAdmin/

# Restore (separate layer — only re-runs when .csproj files change)
RUN dotnet restore eShopOnWeb.sln --locked-mode

# Copy the rest of the source
COPY src/ src/

# Publish Web (storefront)
RUN dotnet publish src/Web/Web.csproj \
      --configuration Release \
      --no-restore \
      --output /app/web

# Publish PublicApi
RUN dotnet publish src/PublicApi/PublicApi.csproj \
      --configuration Release \
      --no-restore \
      --output /app/api

###############################################################################
# STAGE 2 — runtime (Web storefront)
###############################################################################
FROM mcr.microsoft.com/dotnet/aspnet:8.0-bookworm-slim AS web-runtime

# Non-root user (uid 1001)
RUN addgroup --gid 1001 appgroup && \
    adduser  --uid 1001 --ingroup appgroup --disabled-password --gecos "" appuser

WORKDIR /app

# Copy published output
COPY --from=builder --chown=appuser:appgroup /app/web ./

# ── Runtime environment defaults (non-secret) ────────────────────────────────
ENV ASPNETCORE_ENVIRONMENT=Production \
    ASPNETCORE_URLS=http://+:8080 \
    LOG_LEVEL=Information \
    PAGE_SIZE=10 \
    CATALOG_ITEMS_PER_PAGE=10 \
    FORWARDED_HEADERS_ENABLED=true \
    USE_AZURE_KEY_VAULT=true \
    DATA_PROTECTION_BLOB_CONTAINER=dataprotection \
    REDIS_CHANNEL_PREFIX=eshopweb \
    TZ=UTC

# Health probe
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:8080/health/live || exit 1

USER appuser
EXPOSE 8080

# Apply EF migrations then start Kestrel (ASP.NET Core self-hosts; no separate
# WSGI server needed for .NET — Kestrel is the production server)
CMD ["sh", "-c", \
     "dotnet Web.dll migrate-database && \
      dotnet Web.dll"]

###############################################################################
# STAGE 3 — runtime (PublicApi)
###############################################################################
FROM mcr.microsoft.com/dotnet/aspnet:8.0-bookworm-slim AS api-runtime

RUN addgroup --gid 1001 appgroup && \
    adduser  --uid 1001 --ingroup appgroup --disabled-password --gecos "" appuser

WORKDIR /app

COPY --from=builder --chown=appuser:appgroup /app/api ./

ENV ASPNETCORE_ENVIRONMENT=Production \
    ASPNETCORE_URLS=http://+:8081 \
    LOG_LEVEL=Information \
    JWT_ALGORITHM=HS256 \
    PAGE_SIZE=10 \
    FORWARDED_HEADERS_ENABLED=true \
    USE_AZURE_KEY_VAULT=true \
    TZ=UTC

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:8081/health/live || exit 1

USER appuser
EXPOSE 8081

CMD ["sh", "-c", \
     "dotnet PublicApi.dll migrate-database && \
      dotnet PublicApi.dll"]
