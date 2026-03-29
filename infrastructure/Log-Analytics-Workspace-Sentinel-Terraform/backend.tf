terraform {
  backend "remote" {
    organization = "your-org-name"

    workspaces {
      name = "law-sentinel"
    }
  }
}
