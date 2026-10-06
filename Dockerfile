# syntax=docker/dockerfile:1.6
###############################################################################
# Stage 1 – builder
###############################################################################
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS builder
WORKDIR /build

# Copy solution & project files first so layer cache is reused on code-only changes
COPY eShopOnWeb.sln global.json ./
COPY src/ApplicationCore/ApplicationCore.csproj          src/ApplicationCore/
COPY src/Infrastructure/Infrastructure.csproj            src/Infrastructure/
COPY src/Web/Web.csproj                                  src/Web/
COPY src/PublicApi/PublicApi.csproj                      src/PublicApi/
COPY tests/UnitTests/UnitTests.csproj                    tests/UnitTests/
COPY tests/IntegrationTests/IntegrationTests.csproj      tests/IntegrationTests/
COPY tests/FunctionalTests/FunctionalTests.csproj        tests/FunctionalTests/

# Restore all packages (uses NuGet package cache layer)
RUN dotnet restore eShopOnWeb.sln

# Copy the rest of the source
COPY src/ src/
COPY tests/ tests/

# Publish Web
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
# Stage 2 – runtime (Web)
###############################################################################
FROM mcr.microsoft.com/dotnet/aspnet:8.0-slim AS web-runtime

# Non-root user
RUN groupadd --gid 1001 appgroup && \
    useradd  --uid 1001 --gid appgroup --shell /bin/false --create-home appuser

# Install curl for HEALTHCHECK
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder --chown=appuser:appgroup /app/web ./

# ── Non-secret runtime defaults ──────────────────────────────────────────────
ENV ASPNETCORE_ENVIRONMENT=Production \
    ASPNETCORE_URLS=http://+:8080 \
    LOG_LEVEL=Information \
    PAGE_SIZE=10 \
    JWT_ALGORITHM=HS256 \
    FORWARDED_HEADERS_ENABLED=true \
    # Matches Azure App Service VNet CIDR — override via env in production
    VPC_CIDR=10.0.0.0/8 \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_gcServer=0

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health/live || exit 1

USER appuser

# Run migrations then start the Web app
CMD ["sh", "-c", \
     "dotnet Web.dll --migrate-only || exit 1 ; exec dotnet Web.dll"]

###############################################################################
# Stage 3 – runtime (PublicApi)
###############################################################################
FROM mcr.microsoft.com/dotnet/aspnet:8.0-slim AS api-runtime

RUN groupadd --gid 1001 appgroup && \
    useradd  --uid 1001 --gid appgroup --shell /bin/false --create-home appuser

RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder --chown=appuser:appgroup /app/api ./

ENV ASPNETCORE_ENVIRONMENT=Production \
    ASPNETCORE_URLS=http://+:8081 \
    LOG_LEVEL=Information \
    PAGE_SIZE=10 \
    JWT_ALGORITHM=HS256 \
    FORWARDED_HEADERS_ENABLED=true \
    VPC_CIDR=10.0.0.0/8 \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_gcServer=0

EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8081/health/live || exit 1

USER appuser

CMD ["sh", "-c", \
     "dotnet PublicApi.dll --migrate-only || exit 1 ; exec dotnet PublicApi.dll"]
