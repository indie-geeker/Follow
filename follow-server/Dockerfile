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

# Copy published app
COPY --from=build /app/publish .

# Set environment variables
ENV ASPNETCORE_URLS=http://+:5000

EXPOSE 5000

ENTRYPOINT ["dotnet", "Follow.Api.dll"]
