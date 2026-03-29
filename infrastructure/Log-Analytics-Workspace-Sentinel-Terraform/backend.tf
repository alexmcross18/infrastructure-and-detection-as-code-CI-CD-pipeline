terraform {
  backend "remote" {
    organization = "GitHub-LAW-SENTINEL"

    workspaces {
      name = "LAW-SENTINEL"
    }
  }
}
