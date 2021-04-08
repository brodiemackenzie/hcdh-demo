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

provider "google-beta" {

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
  force_destroy = true

# Upload sample data to GCS bucket

  provisioner "local-exec" {
    command = "gsutil -m cp -r ~/healthcare-data-harmonization/mapping_configs/* ${google_storage_bucket.sample_bucket.url}/mapping_configs/"
  }
}

# Create Healthcare API Dataset

resource "google_healthcare_dataset" "dataset" {
  provider = google-beta
  name     = "hcdh-dataset"
  location = "us-central1"
}

# Create HL7v2 Store

resource "google_healthcare_hl7_v2_store" "store" {
  provider = google-beta
  name    = "hcdh-hl7-v2-store"
  dataset = google_healthcare_dataset.dataset.id

  parser_config {
    
    allow_null_header  = false
    segment_terminator = "Cg=="
    version            = "V2"
    schema = <<EOF
    {
        "schematizedParsingType": "SOFT_FAIL",
        "ignoreMinOccurs": "true"
    }
    EOF    
    }
}

# Upload sample message to HL7v2 store 
# Create .env variables file