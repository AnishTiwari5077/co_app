FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY ["src/SahakariMS.Api/SahakariMS.Api.csproj",            "src/SahakariMS.Api/"]
COPY ["src/SahakariMS.Application/SahakariMS.Application.csproj", "src/SahakariMS.Application/"]
COPY ["src/SahakariMS.Domain/SahakariMS.Domain.csproj",      "src/SahakariMS.Domain/"]
COPY ["src/SahakariMS.Infrastructure/SahakariMS.Infrastructure.csproj", "src/SahakariMS.Infrastructure/"]
COPY ["src/SahakariMS.Shared/SahakariMS.Shared.csproj",      "src/SahakariMS.Shared/"]

RUN dotnet restore "src/SahakariMS.Api/SahakariMS.Api.csproj"
COPY . .

RUN dotnet build "src/SahakariMS.Api/SahakariMS.Api.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "src/SahakariMS.Api/SahakariMS.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "SahakariMS.Api.dll"]
