FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY SaveApi.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet tool restore
RUN dotnet publish -c Release -o /app/publish --no-restore

FROM build AS migrations
ENTRYPOINT ["dotnet", "ef"]

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish ./
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
USER $APP_UID
ENTRYPOINT ["dotnet", "SaveApi.dll"]