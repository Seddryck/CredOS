FROM mcr.microsoft.com/dotnet/sdk:8.0 AS net8
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS net9
FROM mcr.microsoft.com/dotnet/sdk:10.0
COPY --from=net8 /usr/share/dotnet/shared/Microsoft.NETCore.App/ /usr/share/dotnet/shared/Microsoft.NETCore.App/
COPY --from=net9 /usr/share/dotnet/shared/Microsoft.NETCore.App/ /usr/share/dotnet/shared/Microsoft.NETCore.App/
RUN apt-get update && apt-get install -y --no-install-recommends dbus gnome-keyring libsecret-1-0 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
COPY . .
RUN dotnet restore CredOS.slnx && dotnet build CredOS.slnx -c Release --no-restore
CMD ["bash", "build/test-linux.sh"]
