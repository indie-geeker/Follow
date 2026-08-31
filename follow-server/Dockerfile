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
FROM mcr.microsoft.com/dotnet/aspnet:10.0@sha256:1fa23fc4872d95fd71c2833ebe65d7e84a43b2d51a31d119516852f13d9505a7 AS final
WORKDIR /app

ARG TARGETARCH
ARG CHROMAPRINT_VERSION=1.6.1
ARG CHROMAPRINT_AMD64_SHA256=fc16cd37a70168040bc9ceb45f1d4d1216f5a75bc4c9cf8564bea70ac6a45733
ARG CHROMAPRINT_ARM64_SHA256=7eaf5d655c4aa172ab28e3c870b8bb61dd2c327ac94de145676f88842cf6215a

# curl serves the health check and downloads the checksum-pinned official
# Chromaprint release. FFmpeg is pinned to the Ubuntu package version in this
# digest-pinned runtime image so decoding support cannot silently change.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl=8.5.0-2ubuntu10.13 \
        ffmpeg=7:6.1.1-3ubuntu5 \
    && case "$TARGETARCH" in \
        amd64) fpcalc_arch='x86_64'; fpcalc_sha256="$CHROMAPRINT_AMD64_SHA256" ;; \
        arm64) fpcalc_arch='arm64'; fpcalc_sha256="$CHROMAPRINT_ARM64_SHA256" ;; \
        *) echo "Unsupported fpcalc architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && fpcalc_url="https://github.com/acoustid/chromaprint/releases/download/v${CHROMAPRINT_VERSION}/chromaprint-fpcalc-${CHROMAPRINT_VERSION}-linux-${fpcalc_arch}.tar.gz" \
    && curl --proto '=https' --tlsv1.2 -fsSLo /tmp/fpcalc.tar.gz "$fpcalc_url" \
    && echo "$fpcalc_sha256  /tmp/fpcalc.tar.gz" | sha256sum -c - \
    && mkdir -p /tmp/fpcalc \
    && tar -xzf /tmp/fpcalc.tar.gz -C /tmp/fpcalc \
    && install -m 0755 "$(find /tmp/fpcalc -type f -name fpcalc -print -quit)" /usr/local/bin/fpcalc \
    && fpcalc -version \
    && ffmpeg -version \
    && rm -rf /tmp/fpcalc /tmp/fpcalc.tar.gz \
    && rm -rf /var/lib/apt/lists/*

LABEL org.follow.fpcalc.version="${CHROMAPRINT_VERSION}"

# Copy published app
COPY --from=build /app/publish .

# Set environment variables
ENV ASPNETCORE_URLS=http://+:5000
ENV AudioFingerprint__ExecutablePath=/usr/local/bin/fpcalc
ENV AudioFingerprint__RequiredVersionPrefix=1.6.1

EXPOSE 5000

CMD ["dotnet", "Follow.Api.dll"]
