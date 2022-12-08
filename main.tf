terraform {
  required_providers {
    ko = {
      source = "chainguard-dev/ko"
    }
    google = {
      source = "hashicorp/google"
    }
  }
}

// Create a service account for the prober to run as.
resource "google_service_account" "prober" {
  project = var.project_id
  # Service accounts can be 30 characters long, so truncate var.name to 26 chars.
  account_id = "${substr(var.name, 0, 26)}-prb"
}

// Build the prober into an image we can run on Cloud Run.
resource "ko_image" "image" {
  base_image  = "cgr.dev/chainguard/static"
  importpath  = var.importpath
  working_dir = var.working_dir
}

// Create a shared secret to have the uptime check pass to the
// Cloud Run app as an "Authorization" header to keep ~anyone
// from being able to use our prober endpoints to indirectly
// DoS our SaaS.
resource "random_password" "secret" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

// Spin up a Cloud Run service to perform our custom prober logic.
resource "google_cloud_run_service" "probers" {
  for_each = toset(var.locations)

  project  = var.project_id
  name     = "${var.name}-prb"
  location = each.key

  template {
    spec {
      service_account_name = google_service_account.prober.email
      containers {
        image = ko_image.image.image_ref

        // This is a shared secret with the uptime check, which must be
        // passed in an Authorization header for the probe to do work.
        env {
          name  = "AUTHORIZATION"
          value = random_password.secret.result
        }

        dynamic "env" {
          for_each = var.env
          content {
            name  = env.key
            value = env.value
          }
        }
      }
    }
  }
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauths" {
  for_each = toset(var.locations)

  project  = var.project_id
  location = each.key
  service  = google_cloud_run_service.probers[each.key].name

  policy_data = data.google_iam_policy.noauth.policy_data
}

// This is the uptime check, which will send traffic to the Cloud Run
// application every few minutes (from several locations) to ensure
// things are operating as expected.
resource "google_monitoring_uptime_check_config" "regional_uptime_check" {
  count = local.use_gclb ? 0 : 1

  display_name = "${var.name}-uptime-regional"
  timeout      = "60s"
  period       = "300s"

  http_check {
    path         = "/"
    port         = "443"
    use_ssl      = true
    validate_ssl = true

    // Pass the shared secret as an Authorization header.
    headers = {
      "Authorization" = random_password.secret.result
    }
  }

  monitored_resource {
    labels = {
      // Strip the scheme and path off of the Cloud Run URL.
      host       = split("/", google_cloud_run_service.probers[var.locations[0]].status[0].url)[2]
      project_id = var.project_id
    }

    type = "uptime_url"
  }

  lifecycle {
    # We must create any replacement uptime checks before
    # we tear this check down.
    create_before_destroy = true
  }
}

// This is the uptime check, which will send traffic to the GCLB
// address every few minutes (from several locations) to ensure
// things are operating as expected.
resource "google_monitoring_uptime_check_config" "global_uptime_check" {
  count = local.use_gclb ? 1 : 0

  display_name = "${var.name}-uptime-global"
  timeout      = "60s"
  period       = "300s"

  http_check {
    path         = "/"
    port         = "443"
    use_ssl      = true
    validate_ssl = true

    // Pass the shared secret as an Authorization header.
    headers = {
      "Authorization" = random_password.secret.result
    }
  }

  monitored_resource {
    labels = {
      host       = "${var.name}-prober.${var.domain}."
      project_id = var.project_id
    }

    type = "uptime_url"
  }

  lifecycle {
    # We must create any replacement uptime checks before
    # we tear this check down.
    create_before_destroy = true
  }
}

// Create an alert policy based on the uptime check above.
resource "google_monitoring_alert_policy" "prober_uptime" {
  project = var.project_id
  # In the absence of data, incident will auto-close in 7 days
  alert_strategy {
    auto_close = "604800s"
  }
  combiner = "OR"

  conditions {
    condition_threshold {
      aggregations {
        alignment_period     = "300s"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.*"]
        per_series_aligner   = "ALIGN_NEXT_OLDER"
      }

      comparison = "COMPARISON_GT"
      duration   = "60s"
      filter = format("metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" resource.type=\"uptime_url\" metric.label.\"check_id\"=\"%s\"",
      local.use_gclb ? google_monitoring_uptime_check_config.regional_uptime_check[0].uptime_check_id : google_monitoring_uptime_check_config.regional_uptime_check[0].uptime_check_id)

      threshold_value = "1"

      trigger {
        count   = "1"
        percent = "0"
      }
    }

    display_name = "${var.name} probe failure"
  }

  display_name = "${var.name} prober failed alert"
  enabled      = "true"

  documentation {
    content = var.alert_documentation
  }

  notification_channels = var.notification_channels
}
