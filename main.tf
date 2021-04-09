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

provider "local" {}

# Enable services - TDB
# Create notebook service account 

resource "google_service_account" "notebook_service_account" {
  account_id   = "sa-nb-hcdh"
  display_name = "sa-nb-hcdh"
}

# Add roles to notebook service account

resource "google_project_iam_member" "member_binding_storage_admin" {
  project = var.project
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.notebook_service_account.email}"
}

resource "google_project_iam_member" "member_binding_hl7v2_editor" {
  project = var.project
  role    = "roles/healthcare.hl7V2Editor"
  member  = "serviceAccount:${google_service_account.notebook_service_account.email}"
}

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

# Create HL7v2 Store with default schematized parsing

resource "google_healthcare_hl7_v2_store" "store" {
  provider = google-beta
  name    = "hcdh-hl7-v2-store"
  dataset = google_healthcare_dataset.dataset.id

  parser_config {
    
    allow_null_header  = false
    segment_terminator = "Cg=="
    schema = <<EOF
    {
        "schematizedParsingType": "SOFT_FAIL",
        "ignoreMinOccurs": "true"
    }
    EOF    
    }

# Upload sample message to HL7v2 store 

    provisioner "local-exec" {
        command = <<EOF
        curl -X POST \
        -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
        -H "Content-Type: application/json; charset=utf-8" \
        --data-binary @adt_a01.hl7.base64encoded.json \
        https://healthcare.googleapis.com/v1/projects/hdc-demo-307717/locations/us-central1/datasets/hcdh-dataset/hl7V2Stores/hcdh-hl7-v2-store/messages
        EOF
    }

}

# Create sample base64encoded HL7v2 message json file

resource "local_file" "sample_hl7v2_message" {
    content  = ""
    filename = "./adt_a01.hl7.base64encoded.json"

        provisioner "local-exec" {
        command = <<EOF
        echo -e "{\n \"message\": {\n\t \"data\":\n \"$(base64 -w 0 ~/healthcare-data-harmonization/mapping_configs/hl7v2_fhir_stu3/adt_a01.hl7)\"\n }\n}" >> adt_a01.hl7.base64encoded.json
        EOF
    }

}

# Create .env variables file