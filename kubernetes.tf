data "google_client_config" "default" {
}

variable "letsencrypt_contact" {
  default     = ""
  description = "Lets encrypt email contact for certs expiry"
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  }
}

resource "kubernetes_namespace" "dev" {
  depends_on = [google_container_cluster.primary]
  metadata {
    name = "dev"
  }
}


resource "kubernetes_namespace" "cert-manager" {
  depends_on = [google_container_cluster.primary]
  metadata {
    name        = "cert-manager"
    annotations = {}
    labels      = {}
  }
}


resource "kubernetes_namespace" "ingress-nginx" {
  depends_on = [google_container_cluster.primary]
  metadata {
    name        = "ingress-nginx"
    annotations = {}
    labels      = {}
  }
}


resource "helm_release" "nginx-ingress" {
  depends_on = [kubernetes_namespace.ingress-nginx]
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  version    = "v4.7.1"
  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }
  set {
    name  = "controller.kind"
    value = "Deployment"
  }

}

resource "time_sleep" "wait_for_ingress_service_ip" {
  depends_on      = [helm_release.nginx-ingress]
  create_duration = "45s"
}


data "kubernetes_service" "nginx-ingress" {
  depends_on = [
    helm_release.nginx-ingress,
    time_sleep.wait_for_ingress_service_ip
  ]
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
}

resource "helm_release" "cert-manager" {
  depends_on = [kubernetes_namespace.cert-manager]
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.12.3"
  namespace  = kubernetes_namespace.cert-manager.metadata[0].name
  namespace = "cert-manager"
  set {
    name  = "installCRDs"
    value = "true"
  }

}

resource "kubernetes_manifest" "clusterissuer_letsencrypt_prod" {
  depends_on = [helm_release.cert-manager]
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind" = "ClusterIssuer"
    "metadata" = {
      "name" = "letsencrypt-prod"
    }
    "spec" = {
      "acme" = {
        "email" = var.letsencrypt_contact
        "preferredChain" = ""
        "privateKeySecretRef" = {
          "name" = "letsencrypt-prod"
        }
        "server" = "https://acme-v02.api.letsencrypt.org/directory"
        "solvers" = [
          {
            "http01" = {
              "ingress" = {
                "class" = "nginx"
              }
            }
          },
        ]
      }
    }
  }
}
