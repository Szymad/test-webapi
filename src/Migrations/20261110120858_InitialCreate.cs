using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SaveApi.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                IF OBJECT_ID(N'[dbo].[SaveEntries]', N'U') IS NULL
                BEGIN
                    CREATE TABLE [dbo].[SaveEntries](
                        [Id] int NOT NULL IDENTITY(1,1),
                        [Name] nvarchar(200) NOT NULL,
                        [CreatedAtUtc] datetime2 NOT NULL,
                        CONSTRAINT [PK_SaveEntries] PRIMARY KEY ([Id])
                    );
                END;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SaveEntries");
        }
    }
}
