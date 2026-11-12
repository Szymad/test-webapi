using Azure.Extensions.AspNetCore.Configuration.Secrets;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
var keyVaultUri = builder.Configuration["KeyVault:Uri"];

if (!string.IsNullOrWhiteSpace(keyVaultUri))
{
	if (!Uri.TryCreate(keyVaultUri, UriKind.Absolute, out var keyVaultEndpoint))
	{
		throw new InvalidOperationException("Konfiguracja KeyVault:Uri musi być poprawnym bezwzględnym URI.");
	}
}

SecretClient? secretClient = null;

if (!string.IsNullOrWhiteSpace(keyVaultUri))
{
	if (!Uri.TryCreate(keyVaultUri, UriKind.Absolute, out var keyVaultEndpoint))
	{
		throw new InvalidOperationException("Konfiguracja KeyVault:Uri musi być poprawnym bezwzględnym URI.");
	}

	secretClient = new SecretClient(keyVaultEndpoint, new DefaultAzureCredential());
}

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
	?? throw new InvalidOperationException("Brak konfiguracji ConnectionStrings:DefaultConnection.");

builder.Services.AddDbContext<SaveDbContext>(options => options.UseSqlServer(connectionString));

var app = builder.Build();

app.MapGet("/", () => Results.Ok(new { status = "ok" }));

app.MapGet("/save", async (string? name, SaveDbContext db, CancellationToken cancellationToken) =>
{
	if (string.IsNullOrWhiteSpace(name))
	{
		return Results.BadRequest(new { error = "Parametr 'name' jest wymagany." });
	}

	var entry = new SaveEntry
	{
		Name = name.Trim(),
		CreatedAtUtc = DateTime.UtcNow
	};

	db.SaveEntries.Add(entry);
	await db.SaveChangesAsync(cancellationToken);

	return Results.Ok(new { id = entry.Id });
});

app.MapGet("/health/db", async (SaveDbContext db, CancellationToken ct) =>
{
    var canConnect = await db.Database.CanConnectAsync(ct);

    return Results.Ok(new
    {
        version = "1.1",
        database = canConnect ? "connected" : "disconnected"
    });
});

app.MapGet("/health/keyvault", async (CancellationToken ct) =>
{
	if (secretClient is null)
	{
		return Results.Problem("Key Vault nie jest skonfigurowany.", statusCode: StatusCodes.Status503ServiceUnavailable);
	}

    var secret = await secretClient.GetSecretAsync(
        "ExternalApiKey",
        cancellationToken: ct
    );

    return Results.Ok(new
    {
        keyVault = "connected",
        secretFound = !string.IsNullOrEmpty(secret.Value.Value)
    });
});

app.Run();

sealed class SaveDbContext(DbContextOptions<SaveDbContext> options) : DbContext(options)
{
	public DbSet<SaveEntry> SaveEntries => Set<SaveEntry>();

	protected override void OnModelCreating(ModelBuilder modelBuilder)
	{
		modelBuilder.Entity<SaveEntry>(entity =>
		{
			entity.HasKey(saveEntry => saveEntry.Id);
			entity.Property(saveEntry => saveEntry.Name).HasMaxLength(200).IsRequired();
			entity.Property(saveEntry => saveEntry.CreatedAtUtc).HasColumnType("datetime2");
		});
	}
}

sealed class SaveEntry
{
	public int Id { get; set; }
	public string Name { get; set; } = string.Empty;
	public DateTime CreatedAtUtc { get; set; }
}
