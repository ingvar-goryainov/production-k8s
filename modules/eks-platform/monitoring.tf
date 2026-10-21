# Grafana admin and Telegram credentials for the ArgoCD-managed monitoring stack (gitops/apps).
resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_secret_v1" "grafana_credentials" {
  metadata {
    name      = "grafana-credentials"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  data = {
    admin-user         = "admin"
    admin-password     = var.grafana_admin_password
    telegram-bot-token = var.telegram_bot_token
    telegram-chat-id   = var.telegram_chat_id
  }
}
