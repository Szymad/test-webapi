terraform {
  required_version = ">= 1.5.0"

  required_providers {
    mssql = {
      source  = "muecahit94/mssql"
      version = "~> 1.8.2"
    }
  }
}

data "terraform_remote_state" "stage1" {
  backend = "local"

  config = {
    path = "${path.module}/../terraform.tfstate"
  }
}

provider "mssql" {
  hostname = "${data.terraform_remote_state.stage1.outputs.sql_server_name}.database.windows.net"
  port     = 1433

  azure_auth {}
}
