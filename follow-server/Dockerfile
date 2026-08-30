# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0@sha256:ed034a8bf0b24ded0cbbac07e17825d8e9ebfe21e308191d0f7421eaf5ad4664 AS build
WORKDIR /src

# Copy solution and project files
COPY src/Follow.Api/Follow.Api.csproj src/Follow.Api/
COPY src/Follow.Core/Follow.Core.csproj src/Follow.Core/
COPY src/Follow.Infrastructure/Follow.Infrastructure.csproj src/Follow.Infrastructure/
COPY src/Follow.Shared/Follow.Shared.csproj src/Follow.Shared/

# Restore dependencies
RUN dotnet restore src/Follow.Api/Follow.Api.csproj

# Copy remaining source code
COPY src/ src/

# Build and publish
WORKDIR /src/src/Follow.Api
RUN dotnet publish -c Release -o /app/publish --no-restore

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0@sha256:1fa23fc4872d95fd71c2833ebe65d7e84a43b2d51a31d119516852f13d9505a7 AS runtime
WORKDIR /app

# Used by the container health check.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Copy published app
COPY --from=build /app/publish .

# Set environment variables
ENV ASPNETCORE_URLS=http://+:5000

EXPOSE 5000

ENTRYPOINT ["dotnet", "Follow.Api.dll"]
