//  001-nfs-server
resource "kubernetes_deployment" "nfs_server" {
  metadata {
    name      = "nfs-server-${var.name}"
    namespace = kubernetes_namespace.namespace1.metadata.0.name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        role = "nfs-server-${var.name}"
      }
    }
    template {
      metadata {
        namespace = kubernetes_namespace.namespace1.metadata.0.name
        labels = {
          role = "nfs-server-${var.name}"
        }
      }
      spec {
        volume {
          name = "mypvc"
          gce_persistent_disk {
            pd_name = "gce-nfs-disk-${var.name}"
            fs_type = "ext4"
          }
        }
        container {
          name  = "nfs-server-${var.name}"
          image = "gcr.io/google_containers/volume-nfs:0.8"
          port {
            name           = "nfs"
            container_port = 2049
          }
          port {
            name           = "mountd"
            container_port = 20048
          }
          port {
            name           = "rpcbind"
            container_port = 111
          }
          volume_mount {
            name       = "mypvc"
            mount_path = "/exports"
          }
          security_context {
            privileged = true
          }
        }
      }
    }
  }
}

//  002-nfs-server-service
resource "kubernetes_service" "nfs_server" {
  metadata {
    name      = "nfs-server-${var.name}"
    namespace = kubernetes_namespace.namespace1.metadata.0.name
  }
  spec {
    port {
      name = "nfs"
      port = 2049
    }
    port {
      name = "mountd"
      port = 20048
    }
    port {
      name = "rpcbind"
      port = 111
    }
    selector = {
      role = "nfs-server-${var.name}"
    }
  }
}

//  003-pv-pvc
resource "kubernetes_persistent_volume" "nfs_pv" {
  metadata {
    name = "nfs-${var.name}"
  }
  spec {
    capacity = {
      storage = "100Gi"
    }
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "standard"
    persistent_volume_source {
      nfs {
        server = resource.kubernetes_service.nfs_server.spec.0.cluster_ip
        path   = "/"
      }
    }
  }
}

//  Persistent volume claim
resource "kubernetes_persistent_volume_claim" "nfs_pvc" {
  metadata {
    name      = "nfs-${var.name}"
    namespace = kubernetes_namespace.namespace1.metadata.0.name
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "standard"
    resources {
      requests = {
        storage = "100Gi"
      }
    }
    volume_name = kubernetes_persistent_volume.nfs_pv.metadata.0.name
  }
}