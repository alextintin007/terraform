resource "kubernetes_config_map" "nginx_conf" {
  metadata {
    name      = "basic-config"
    namespace = kubernetes_namespace.namespace1.metadata.0.name
  }
  data = {
    "nginx.conf" = "server {\nlocation / {\nroot /usr/share/nginx/html/;\nindex index.html;\nautoindex on;}}"
  }
}

resource "kubernetes_deployment" "http_fileserver" {
  metadata {
    name      = "http-fileserver-${var.name}"
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    labels = {
      service = "http-fileserver-${var.name}"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        service = "http-fileserver-${var.name}"
      }
    }
    template {
      metadata {
        labels = {
          service = "http-fileserver-${var.name}"
        }
      }
      spec {
        volume {
          name = "volume-output"
          persistent_volume_claim {
            claim_name = "nfs-${var.name}"
          }
        }
        volume {
          name = "basic-config"

          config_map {
            name = "basic-config"
          }
        }
        container {
          name  = "file-storage-container"
          image = "nginx"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "volume-output"
            mount_path = "/usr/share/nginx/html"
          }
          volume_mount {
            name       = "basic-config"
            mount_path = "/etc/nginx/conf.d"
          }
          lifecycle {
            post_start {
              exec {
                command = ["rm", "/usr/share/nginx/html/index.html"]
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "http_fileserver" {
  metadata {
    name      = "http-fileserver-${var.name}"
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    labels = {
      service = "http-fileserver-${var.name}"
    }
  }
  spec {
    port {
      protocol    = "TCP"
      port        = 80
      target_port = "80"
      node_port   = 32703
    }
    selector = {
      service = "http-fileserver-${var.name}"
    }
    type                    = "LoadBalancer"
    session_affinity        = "None"
    external_traffic_policy = "Cluster"
  }
}

resource "kubernetes_cluster_role_binding" "rb" {
  metadata {
    name = var.name
  }
  subject {
    kind = "User"
    name = var.email
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
}
