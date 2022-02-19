terraform {
  cloud {
    organization = "kb-terransible"

    workspaces {
      name = "terransible"
    }
  }
} 