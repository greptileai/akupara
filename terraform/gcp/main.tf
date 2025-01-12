# Secret Manager
resource "google_secret_manager_secret" "llm_secrets" {
  secret_id = "llm-secrets"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "llm_secrets" {
  secret = google_secret_manager_secret.llm_secrets.id
  secret_data = jsonencode({
    "openai-key"     = var.openai_api_key
    "anthropic-key"  = var.anthropic_api_key
  })
}

resource "google_secret_manager_secret" "github_secrets" {
  secret_id = "github-secrets"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "github_secrets" {
  secret = google_secret_manager_secret.github_secrets.id
  secret_data = jsonencode({
    "clientId"       = var.github_client_id
    "clientSecret"   = var.github_client_secret
    "webhookSecret"  = var.github_webhook_secret
    "privateKey"     = var.github_private_key
  })
}

resource "google_secret_manager_secret" "app_secrets" {
  secret_id = "app-secrets"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "app_secrets" {
  secret = google_secret_manager_secret.app_secrets.id
  secret_data = jsonencode({
    "jwtSecret"                  = var.jwt_secret
    "jacksonAdminCredentials"    = var.jackson_admin_credentials
    "jacksonApiKeys"             = var.jackson_api_keys
    "jacksonClientSecretVerifier"= var.jackson_client_secret_verifier
    "jacksonDbEncryptionKey"     = var.jackson_db_encryption_key
    "jacksonNextauthSecret"      = var.jackson_nextauth_secret
    "jacksonPrivateKey"          = var.jackson_private_key
    "jacksonPublicKey"           = var.jackson_public_key
    "boxyhqSamlId"              = var.boxyhq_saml_id
    "boxyhqSamlSecret"          = var.boxyhq_saml_secret
    "boxyhqApiKey"              = var.boxyhq_api_key
  })
}

# VPC Configuration
resource "google_compute_network" "main" {
  name                    = "greptile-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private" {
  count         = 2
  name          = "greptile-private-${count.index + 1}"
  ip_cidr_range = "10.0.${count.index + 1}.0/24"
  network       = google_compute_network.main.id
  region        = var.region
  
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "public" {
  count         = 2
  name          = "greptile-public-${count.index + 1}"
  ip_cidr_range = "10.0.${count.index + 10}.0/24"
  network       = google_compute_network.main.id
  region        = var.region
}

# Cloud SQL (PostgreSQL)
resource "google_sql_database_instance" "postgres" {
  name             = "greptile-gke"
  database_version = "POSTGRES_16"
  region           = var.region

  settings {
    tier = "db-f1-micro"
    
    backup_configuration {
      enabled = true
      retention_days = 7
    }

    ip_configuration {
      ipv4_enabled = false
      private_network = google_compute_network.main.id
    }

    disk_size = 200
    disk_type = "PD_SSD"
  }

  deletion_protection = false
}

resource "google_sql_database" "database" {
  name     = "greptile"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "user" {
  name     = var.db_username
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}

# Memorystore (Redis)
resource "google_redis_instance" "redis" {
  name           = "greptile-internal-gke"
  memory_size_gb = 1
  region         = var.region

  authorized_network = google_compute_network.main.id
  connect_mode      = "PRIVATE_SERVICE_ACCESS"

  redis_version     = "REDIS_6_X"
  tier              = "BASIC"
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = "greptile"
  location = var.region

  network    = google_compute_network.main.name
  subnetwork = google_compute_subnetwork.private[0].name

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "greptile-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = false
    machine_type = "e2-medium"

    service_account = google_service_account.gke_sa.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# Service Account for GKE nodes
resource "google_service_account" "gke_sa" {
  account_id   = "greptile-gke-sa"
  display_name = "GKE Service Account"
}

# Grant necessary permissions to the service account
resource "google_project_iam_member" "gke_sa_roles" {
  for_each = toset([
    "roles/secretmanager.secretAccessor",
    "roles/aiplatform.user"  # For Vertex AI access (similar to AWS Bedrock)
  ])
  
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}
