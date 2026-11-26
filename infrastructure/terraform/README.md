# Terraform deployment

Terraform is split into two stages:

1. `infrastructure/terraform/stage1` creates the Azure resources, SQL server and database, and the App Service system-assigned managed identity.
2. `infrastructure/terraform/stage2` creates the SQL user for that managed identity. It reads the SQL server, database, and identity values from the stage 1 local state.

The stage 1 configuration automatically loads `infrastructure/terraform/stage1/terraform.tfvars`. Its local state remains at `infrastructure/terraform/terraform.tfstate` to preserve the current deployment.

Run stage 1 first:

```sh
terraform -chdir=infrastructure/terraform/stage1 init
terraform -chdir=infrastructure/terraform/stage1 apply
```

Then run stage 2:

```sh
terraform -chdir=infrastructure/terraform/stage2 init
terraform -chdir=infrastructure/terraform/stage2 apply
```

Each stage has its own local state. Keep both state files safe; stage 2 reads `infrastructure/terraform/terraform.tfstate`.

## Existing state migration

If the current stage 1 state already contains `mssql_azuread_user.saveapi`, detach it before applying the updated stage 1 configuration. This preserves the SQL user while allowing stage 2 to take ownership:

```sh
terraform -chdir=infrastructure/terraform/stage1 state rm mssql_azuread_user.saveapi
terraform -chdir=infrastructure/terraform/stage1 apply
terraform -chdir=infrastructure/terraform/stage2 init
terraform -chdir=infrastructure/terraform/stage2 import \
  mssql_azuread_user.saveapi \
  "sqlserver://sql-tf-learning-20261116.database.windows.net:1433/db-terraform-learning/web-terraform-learning-20261112"
```

After import, use `terraform -chdir=infrastructure/terraform/stage2 plan` to verify the SQL user is managed by stage 2.
