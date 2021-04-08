terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

provider "google" {

  credentials = file(var.credentials_file)
  project = var.project
  region  = var.region
  zone    = var.zone

}

# Enable services
# Create notebook service account 
# Add roles to notebook service account
# Create GCS sample data bucket

resource "random_string" "bucket" {
  length  = 8
  special = false
  upper   = false
}

resource "google_storage_bucket" "sample_bucket" {
  name     = "hcdh-sample-data-${random_string.bucket.result}"
  location = "US"

  provisioner "local-exec" {
    command = "gsutil -m cp -r ~/healthcare-data-harmonization/mapping_configs/* ${google_storage_bucket.sample_bucket.url}/mapping_configs/"
  }
}

# Upload sample data to GCS bucket
# Create Healthcare API Dataset
# Create HL7v2 Store
# Upload sample message to HL7v2 store 
# Create .env variables file 