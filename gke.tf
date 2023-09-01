variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 2
  description = "number of gke nodes"
}

variable "gke_max_num_nodes" {
  default     = 2
  description = "number of max gke nodes"
}

variable "gke_node_type" {
  default     = "e2-highcpu-4"
  description = "gke node type"
}

variable "cluster_name" {
  default     = "gke"
  description = "kubernetes cluster name"
}

# GKE cluster
data "google_container_engine_versions" "gke_version" {
  location       = var.region
  version_prefix = "1.27."
}

resource "google_container_cluster" "primary" {
  name     = "${var.cluster_name}-${var.project_id}"
  location = var.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  release_channel {
    channel = "STABLE"
  }

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name     = google_container_cluster.primary.name
  location = var.region
  cluster  = google_container_cluster.primary.name

  version            = data.google_container_engine_versions.gke_version.release_channel_latest_version["STABLE"]
  initial_node_count = var.gke_num_nodes

  autoscaling {
    min_node_count = var.gke_num_nodes
    max_node_count = var.gke_max_num_nodes
  }
  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.project_id
    }


    # preemptible  = true
    machine_type = var.gke_node_type
    tags         = ["gke-node", "${var.project_id}-gke"]
    disk_size_gb = 80
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

