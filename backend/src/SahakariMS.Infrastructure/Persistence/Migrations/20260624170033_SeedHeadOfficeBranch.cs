using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SahakariMS.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SeedHeadOfficeBranch : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_RolePermissions_Permissions_PermissionId1",
                table: "RolePermissions");

            migrationBuilder.DropForeignKey(
                name: "FK_RolePermissions_Roles_RoleId",
                table: "RolePermissions");

            migrationBuilder.DropForeignKey(
                name: "FK_UserRoles_Users_UserId",
                table: "UserRoles");

            migrationBuilder.DropIndex(
                name: "IX_RolePermissions_PermissionId1",
                table: "RolePermissions");

            migrationBuilder.DropColumn(
                name: "PermissionId1",
                table: "RolePermissions");

            migrationBuilder.AddColumn<string>(
                name: "CitizenshipDocUrl",
                table: "Members",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SignatureUrl",
                table: "Members",
                type: "text",
                nullable: true);

            migrationBuilder.UpdateData(
                table: "Branches",
                keyColumn: "Id",
                keyValue: new Guid("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
                columns: new[] { "CreatedAt", "UpdatedAt" },
                values: new object[] { new DateTime(2026, 6, 24, 17, 0, 30, 685, DateTimeKind.Utc).AddTicks(7390), new DateTime(2026, 6, 24, 17, 0, 30, 685, DateTimeKind.Utc).AddTicks(7390) });

            migrationBuilder.UpdateData(
                table: "Roles",
                keyColumn: "Id",
                keyValue: new Guid("11111111-1111-1111-1111-111111111111"),
                columns: new[] { "CreatedAt", "UpdatedAt" },
                values: new object[] { new DateTime(2026, 6, 24, 17, 0, 30, 685, DateTimeKind.Utc).AddTicks(6881), new DateTime(2026, 6, 24, 17, 0, 30, 685, DateTimeKind.Utc).AddTicks(6881) });

            migrationBuilder.UpdateData(
                table: "Roles",
                keyColumn: "Id",
                keyValue: new Guid("22222222-2222-2222-2222-222222222222"),
                columns: new[] { "CreatedAt", "UpdatedAt" },
                values: new object[] { new DateTime(2026, 6, 24, 17, 0, 30, 685, DateTimeKind.Utc).AddTicks(6896), new DateTime(2026, 6, 24, 17, 0, 30, 685, DateTimeKind.Utc).AddTicks(6897) });

            migrationBuilder.UpdateData(
                table: "Roles",
                keyColumn: "Id",
                keyValue: new Guid("33333333-3333-3333-3333-333333333333"),
                columns: new[] { "CreatedAt", "UpdatedAt" },
                values: new object[] { new DateTime(2026, 6, 24, 17, 0, 30, 685, DateTimeKind.Utc).AddTicks(6903), new DateTime(2026, 6, 24, 17, 0, 30, 685, DateTimeKind.Utc).AddTicks(6903) });

            migrationBuilder.UpdateData(
                table: "Roles",
                keyColumn: "Id",
                keyValue: new Guid("44444444-4444-4444-4444-444444444444"),
                columns: new[] { "CreatedAt", "UpdatedAt" },
                values: new object[] { new DateTime(2026, 6, 24, 17, 0, 30, 685, DateTimeKind.Utc).AddTicks(6909), new DateTime(2026, 6, 24, 17, 0, 30, 685, DateTimeKind.Utc).AddTicks(6910) });

            migrationBuilder.UpdateData(
                table: "Roles",
                keyColumn: "Id",
                keyValue: new Guid("55555555-5555-5555-5555-555555555555"),
                columns: new[] { "CreatedAt", "UpdatedAt" },
                values: new object[] { new DateTime(2026, 6, 24, 17, 0, 30, 685, DateTimeKind.Utc).AddTicks(6916), new DateTime(2026, 6, 24, 17, 0, 30, 685, DateTimeKind.Utc).AddTicks(6916) });

            migrationBuilder.AddForeignKey(
                name: "FK_RolePermissions_Roles_RoleId",
                table: "RolePermissions",
                column: "RoleId",
                principalTable: "Roles",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_UserRoles_Users_UserId",
                table: "UserRoles",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_RolePermissions_Roles_RoleId",
                table: "RolePermissions");

            migrationBuilder.DropForeignKey(
                name: "FK_UserRoles_Users_UserId",
                table: "UserRoles");

            migrationBuilder.DropColumn(
                name: "CitizenshipDocUrl",
                table: "Members");

            migrationBuilder.DropColumn(
                name: "SignatureUrl",
                table: "Members");

            migrationBuilder.AddColumn<Guid>(
                name: "PermissionId1",
                table: "RolePermissions",
                type: "uuid",
                nullable: true);

            migrationBuilder.UpdateData(
                table: "Branches",
                keyColumn: "Id",
                keyValue: new Guid("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
                columns: new[] { "CreatedAt", "UpdatedAt" },
                values: new object[] { new DateTime(2026, 6, 22, 15, 14, 41, 404, DateTimeKind.Utc).AddTicks(1411), new DateTime(2026, 6, 22, 15, 14, 41, 404, DateTimeKind.Utc).AddTicks(1412) });

            migrationBuilder.UpdateData(
                table: "Roles",
                keyColumn: "Id",
                keyValue: new Guid("11111111-1111-1111-1111-111111111111"),
                columns: new[] { "CreatedAt", "UpdatedAt" },
                values: new object[] { new DateTime(2026, 6, 22, 15, 14, 41, 404, DateTimeKind.Utc).AddTicks(1069), new DateTime(2026, 6, 22, 15, 14, 41, 404, DateTimeKind.Utc).AddTicks(1070) });

            migrationBuilder.UpdateData(
                table: "Roles",
                keyColumn: "Id",
                keyValue: new Guid("22222222-2222-2222-2222-222222222222"),
                columns: new[] { "CreatedAt", "UpdatedAt" },
                values: new object[] { new DateTime(2026, 6, 22, 15, 14, 41, 404, DateTimeKind.Utc).AddTicks(1075), new DateTime(2026, 6, 22, 15, 14, 41, 404, DateTimeKind.Utc).AddTicks(1076) });

            migrationBuilder.UpdateData(
                table: "Roles",
                keyColumn: "Id",
                keyValue: new Guid("33333333-3333-3333-3333-333333333333"),
                columns: new[] { "CreatedAt", "UpdatedAt" },
                values: new object[] { new DateTime(2026, 6, 22, 15, 14, 41, 404, DateTimeKind.Utc).AddTicks(1078), new DateTime(2026, 6, 22, 15, 14, 41, 404, DateTimeKind.Utc).AddTicks(1079) });

            migrationBuilder.UpdateData(
                table: "Roles",
                keyColumn: "Id",
                keyValue: new Guid("44444444-4444-4444-4444-444444444444"),
                columns: new[] { "CreatedAt", "UpdatedAt" },
                values: new object[] { new DateTime(2026, 6, 22, 15, 14, 41, 404, DateTimeKind.Utc).AddTicks(1091), new DateTime(2026, 6, 22, 15, 14, 41, 404, DateTimeKind.Utc).AddTicks(1091) });

            migrationBuilder.UpdateData(
                table: "Roles",
                keyColumn: "Id",
                keyValue: new Guid("55555555-5555-5555-5555-555555555555"),
                columns: new[] { "CreatedAt", "UpdatedAt" },
                values: new object[] { new DateTime(2026, 6, 22, 15, 14, 41, 404, DateTimeKind.Utc).AddTicks(1094), new DateTime(2026, 6, 22, 15, 14, 41, 404, DateTimeKind.Utc).AddTicks(1094) });

            migrationBuilder.CreateIndex(
                name: "IX_RolePermissions_PermissionId1",
                table: "RolePermissions",
                column: "PermissionId1");

            migrationBuilder.AddForeignKey(
                name: "FK_RolePermissions_Permissions_PermissionId1",
                table: "RolePermissions",
                column: "PermissionId1",
                principalTable: "Permissions",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_RolePermissions_Roles_RoleId",
                table: "RolePermissions",
                column: "RoleId",
                principalTable: "Roles",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserRoles_Users_UserId",
                table: "UserRoles",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
