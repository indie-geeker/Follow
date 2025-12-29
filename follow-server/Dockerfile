# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0-preview AS build
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
FROM mcr.microsoft.com/dotnet/aspnet:10.0-preview AS runtime
WORKDIR /app

# Create data directories
RUN mkdir -p /app/data/music /app/data/covers /app/data/lyrics

# Copy published app
COPY --from=build /app/publish .

# Set environment variables
ENV ASPNETCORE_URLS=http://+:5000
ENV ConnectionStrings__DefaultConnection="Data Source=/app/data/follow.db"
ENV FileStorage__AudioPath=/app/data/music
ENV FileStorage__CoverPath=/app/data/covers
ENV FileStorage__LyricsPath=/app/data/lyrics

EXPOSE 5000

ENTRYPOINT ["dotnet", "Follow.Api.dll"]
