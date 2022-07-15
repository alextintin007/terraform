resource "kubernetes_namespace" "namespace1" {
  metadata {
    name = "argo"
  }
}

// regular argo installation 
data "kubectl_file_documents" "manifests" {
  content = file("${path.module}/argo.yaml")
}
resource "kubectl_manifest" "argo" {
  count              = length(data.kubectl_file_documents.manifests.documents)
  yaml_body          = element(data.kubectl_file_documents.manifests.documents, count.index)
  override_namespace = kubernetes_namespace.namespace1.metadata.0.name
}

// argo modifications  (changed: names, LoadBalancers, namespaces )
resource "kubernetes_service_account" "argo_server" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "argo-server-${var.name}"
  }
}

resource "kubernetes_role" "argo_server_role" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "argo-server-${var.name}-role"
  }
  rule {
    verbs      = ["get", "watch", "list"]
    api_groups = [""]
    resources  = ["configmaps"]
  }
  rule {
    verbs      = ["get", "create"]
    api_groups = [""]
    resources  = ["secrets"]
  }
  rule {
    verbs      = ["get", "list", "watch", "delete"]
    api_groups = [""]
    resources  = ["pods", "pods/exec", "pods/log"]
  }
  rule {
    verbs      = ["watch", "create", "patch"]
    api_groups = [""]
    resources  = ["events"]
  }
  rule {
    verbs      = ["get", "list"]
    api_groups = [""]
    resources  = ["serviceaccounts"]
  }
  rule {
    verbs      = ["create", "get", "list", "watch", "update", "patch", "delete"]
    api_groups = ["argoproj.io"]
    resources  = ["eventsources", "sensors", "workflows", "workfloweventbindings", "workflowtemplates", "cronworkflows", "cronworkflows/finalizers"]
  }
}

resource "kubernetes_cluster_role" "argo_server_clusterworkflowtemplate_role" {
  metadata {
    name = "argo-server-${var.name}-clusterworkflowtemplate-role"
  }
  rule {
    verbs      = ["create", "delete", "watch", "get", "list", "watch"]
    api_groups = ["argoproj.io"]
    resources  = ["clusterworkflowtemplates", "clusterworkflowtemplates/finalizers"]
  }
}

resource "kubernetes_role_binding" "argo_server_binding" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "argo-server-${var.name}-binding"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "argo-server-${var.name}"
    namespace = kubernetes_namespace.namespace1.metadata.0.name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "argo-server-${var.name}-role"
  }
}

resource "kubernetes_cluster_role_binding" "argo_server_clusterworkflowtemplate_role_binding" {
  metadata {
    name = "argo-server-${var.name}-clusterworkflowtemplate-role-binding"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "argo-server-${var.name}"
    namespace = kubernetes_namespace.namespace1.metadata.0.name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "argo-server-${var.name}-clusterworkflowtemplate-role"
  }
}

resource "kubernetes_secret" "argo_server_sso" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "argo-server-${var.name}-sso"
    labels = {
      app = "argo-server-${var.name}"
    }
  }
}

resource "kubernetes_service" "argo_server" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "argo-server-${var.name}"
  }
  spec {
    port {
      name        = "web"
      port        = 2746
      target_port = "2746"
    }
    selector = {
      app = "argo-server-${var.name}"
    }
    type                    = "LoadBalancer"
    session_affinity        = "None"
    external_traffic_policy = "Cluster"
  }
}

resource "kubernetes_deployment" "argo_server" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "argo-server-${var.name}"
  }
  spec {
    selector {
      match_labels = {
        app = "argo-server-${var.name}"
      }
    }
    template {
      metadata {
        namespace = kubernetes_namespace.namespace1.metadata.0.name
        labels = {
          app = "argo-server-${var.name}"
        }
      }
      spec {
        volume {
          name = "tmp"
        }
        container {
          name  = "argo-server-${var.name}"
          image = "argoproj/argocli:v3.0.3"
          args  = ["server", "--namespaced", "--auth-mode", "server", "--auth-mode", "client"]
          port {
            name           = "web"
            container_port = 2746
          }
          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
          readiness_probe {
            http_get {
              path   = "/"
              port   = "2746"
              scheme = "HTTPS"
            }
            initial_delay_seconds = 10
            period_seconds        = 20
          }
          security_context {
            capabilities {
              drop = ["ALL"]
            }
          }
        }
        node_selector = {
          "kubernetes.io/os" = "linux"
        }
        service_account_name = "argo-server-${var.name}"
        security_context {
          run_as_non_root = true
        }
      }
    }
  }
}

resource "kubernetes_config_map" "artifact_repositories" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "artifact-repositories"
    annotations = {
      "workflows.argoproj.io/default-artifact-repository" = "default-v1"
    }
  }
  data = {
    default-v1 = "archiveLogs: true\ns3:\n  bucket: my-bucket\n  endpoint: minio-${var.name}:9000\n  insecure: true\n  accessKeySecret:\n    name: my-minio-${var.name}-cred\n    key: accesskey\n  secretKeySecret:\n    name: my-minio-${var.name}-cred\n    key: secretkey\n"
    my-key = "archiveLogs: true\ns3:\n  bucket: my-bucket\n  endpoint: minio-${var.name}:9000\n  insecure: true\n  accessKeySecret:\n    name: my-minio-${var.name}-cred\n    key: accesskey\n  secretKeySecret:\n    name: my-minio-${var.name}-cred\n    key: secretkey\n"
  }
}

resource "kubernetes_config_map" "workflow_controller_configmap" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "workflow-controller-configmap"
  }

  data = {
    artifactRepository = "archiveLogs: true\ns3:\n  bucket: my-bucket\n  endpoint: minio-${var.name}:9000\n  insecure: true\n  accessKeySecret:\n    name: my-minio-${var.name}-cred\n    key: accesskey\n  secretKeySecret:\n    name: my-minio-${var.name}-cred\n    key: secretkey\n"
    containerRuntimeExecutor = "docker"
    containerRuntimeExecutors = "- name: k8sapi\n  selector:\n    matchLabels:\n      workflows.argoproj.io/container-runtime-executor: k8sapi\n"
    executor = "resources:\n  requests:\n    cpu: 10m\n    memory: 64Mi\n"
    links = "- name: Workflow Link\n  scope: workflow\n  url: http://logging-facility?namespace=$${metadata.namespace}&workflowName=$${metadata.name}&startedAt=$${status.startedAt}&finishedAt=$${status.finishedAt}\n- name: Pod Link\n  scope: pod\n  url: http://logging-facility?namespace=$${metadata.namespace}&podName=$${metadata.name}&startedAt=$${status.startedAt}&finishedAt=$${status.finishedAt}\n- name: Pod Logs Link\n  scope: pod-logs\n  url: http://logging-facility?namespace=$${metadata.namespace}&podName=$${metadata.name}&startedAt=$${status.startedAt}&finishedAt=$${status.finishedAt}\n- name: Event Source Logs Link\n  scope: event-source-logs\n  url: http://logging-facility?namespace=$${metadata.namespace}&podName=$${metadata.name}&startedAt=$${status.startedAt}&finishedAt=$${status.finishedAt}\n- name: Sensor Logs Link\n  scope: sensor-logs\n  url: http://logging-facility?namespace=$${metadata.namespace}&podName=$${metadata.name}&startedAt=$${status.startedAt}&finishedAt=$${status.finishedAt}\n"
    metricsConfig = "disableLegacy: true\nenabled: true\npath: /metrics\nport: 9090\n"
    persistence = "connectionPool:\n  maxIdleConns: 100\n  maxOpenConns: 0\n  connMaxLifetime: 0s\nnodeStatusOffLoad: true\narchive: true\narchiveTTL: 7d\npostgresql:\n  host: postgres\n  port: 5432\n  database: postgres\n  tableName: argo_workflows\n  userNameSecret:\n    name: argo-postgres-config\n    key: username\n  passwordSecret:\n    name: argo-postgres-config\n    key: password\n"
  }
}

resource "kubernetes_secret" "my_minio_cred" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "my-minio-${var.name}-cred"
    labels = {
      app = "minio-${var.name}"
    }
  }
  data = {
    accesskey = "admin"
    secretkey = "password"
  }
  type = "Opaque"
}

resource "kubernetes_service" "minio" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "minio-${var.name}"
    labels = {
      app = "minio-${var.name}"
    }
  }

  spec {
    port {
      protocol    = "TCP"
      port        = 9000
      target_port = "9000"
    }
    selector = {
      app = "minio-${var.name}"
    }
  }
}

resource "kubernetes_deployment" "minio" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "minio-${var.name}"
    labels = {
      app = "minio-${var.name}"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "minio-${var.name}"
      }
    }
    template {
      metadata {
        namespace = kubernetes_namespace.namespace1.metadata.0.name
        labels = {
          app = "minio-${var.name}"
        }
      }
      spec {
        container {
          name    = "main"
          image   = "minio/minio:RELEASE.2019-12-17T23-16-33Z"
          command = ["minio", "server", "/data"]
          port {
            container_port = 9000
          }
          env {
            name  = "MINIO_ACCESS_KEY"
            value = "admin"
          }
          env {
            name  = "MINIO_SECRET_KEY"
            value = "password"
          }
          liveness_probe {
            http_get {
              path = "/minio/health/live"
              port = "9000"
            }

            initial_delay_seconds = 5
            period_seconds        = 10
          }
          readiness_probe {
            http_get {
              path = "/minio/health/ready"
              port = "9000"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
          lifecycle {
            post_start {
              exec {
                command = ["mkdir", "-p", "/data/my-bucket"]
              }
            }
          }
        }
      }
    }
  }
}