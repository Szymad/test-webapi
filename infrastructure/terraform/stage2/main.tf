resource "mssql_azuread_user" "saveapi" {
  database_name = data.terraform_remote_state.stage1.outputs.sql_database_name
  name          = data.terraform_remote_state.stage1.outputs.app_service_name
  object_id     = data.terraform_remote_state.stage1.outputs.app_service_principal_id

  default_schema = "dbo"

  roles = [
    "db_datareader",
    "db_datawriter"
  ]
}
