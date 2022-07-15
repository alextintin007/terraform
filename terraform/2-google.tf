data "google_client_config" "default" {}

resource "google_container_cluster" "cluster1" {
  name            = "cluster-${var.name}"
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_ipv4_cidr_block = "/18"
  }
  initial_node_count       = 1
  remove_default_node_pool = true

}

resource "google_container_node_pool" "npool1" {
  cluster = google_container_cluster.cluster1.id
  node_config {
    preemptible  = true
    machine_type = var.machine_type
    image_type   = "COS"
  }
  node_count = 1
  autoscaling {
    min_node_count = 1
    max_node_count = 4
  }
}

resource "google_compute_disk" "default" {
  name = "gce-nfs-disk-${var.name}"
  type = "pd-standard"
  size = 100
}