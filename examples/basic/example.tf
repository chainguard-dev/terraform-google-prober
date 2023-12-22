terraform {
  required_providers {
    ko = {
      source = "ko-build/ko"
    }
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "google" {
  project = var.project_id
}

variable "project_id" {
  type        = string
  description = "The project that will host the prober."
}

resource "google_service_account" "prober" {
  project    = var.project_id
  account_id = "basic-example-prober"
}

module "prober" {
  source  = "chainguard-dev/prober/google"
  version = "v0.2.0"

  name            = "basic-example"
  project_id      = var.project_id
  service-account = google_service_account.prober.email

  importpath  = "github.com/chainguard-dev/terraform-google-prober/examples/basic"
  working_dir = path.module

  env = {
    EXAMPLE_ENV = "honk"
  }

  enable_alert = true
}
