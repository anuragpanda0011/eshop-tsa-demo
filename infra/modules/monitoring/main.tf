# ---------------------------------------------------------------------------
# Notification Channel — Email
# ---------------------------------------------------------------------------
resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "Email Alert — Ops Team"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }

  force_delete = false
}

# ---------------------------------------------------------------------------
# Log-based Metric — Django ERROR/CRITICAL log lines
# ---------------------------------------------------------------------------
resource "google_logging_metric" "django_error_count" {
  project     = var.project_id
  name        = "django_error_critical_count"
  description = "Count of Django ERROR or CRITICAL log entries from Cloud Run"
  filter      = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${var.cloudrun_service_name}"
    severity>=ERROR
  EOT

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    unit         = "1"
    display_name = "Django ERROR/CRITICAL Log Count"

    labels {
      key         = "severity"
      value_type  = "STRING"
      description = "Log severity level"
    }
  }

  label_extractors = {
    "severity" = "EXTRACT(severity)"
  }
}

# ---------------------------------------------------------------------------
# Log-based Metric — Cloud SQL slow queries (scoped to reporting instance)
# ---------------------------------------------------------------------------
resource "google_logging_metric" "cloudsql_slow_queries" {
  project     = var.project_id
  name        = "cloudsql_slow_query_count"
  description = "Count of Cloud SQL slow query log entries (>500ms) for the reporting instance"
  filter      = <<-EOT
    resource.type="cloudsql_database"
    resource.labels.database_id="${var.project_id}:${var.db_instance_name}"
    textPayload:"duration:"
    textPayload:"LOG"
  EOT

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    unit         = "1"
    display_name = "Cloud SQL Slow Query Count"
  }
}

# ---------------------------------------------------------------------------
# Monitoring Dashboard
# ---------------------------------------------------------------------------
resource "google_monitoring_dashboard" "reporting_overview" {
  project        = var.project_id
  dashboard_json = jsonencode({
    displayName = "Django Reporting App — Overview"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Cloud Run — Request Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.labels.service_name=\"${var.cloudrun_service_name}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.labels.response_code_class"]
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              }]
              yAxis = { label = "Requests/s", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Cloud Run — Request Latency (p50/p95/p99)"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\" resource.labels.service_name=\"${var.cloudrun_service_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_DELTA"
                        crossSeriesReducer = "REDUCE_PERCENTILE_50"
                      }
                    }
                  }
                  plotType       = "LINE"
                  targetAxis     = "Y1"
                  legendTemplate = "p50"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\" resource.labels.service_name=\"${var.cloudrun_service_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_DELTA"
                        crossSeriesReducer = "REDUCE_PERCENTILE_95"
                      }
                    }
                  }
                  plotType       = "LINE"
                  targetAxis     = "Y1"
                  legendTemplate = "p95"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\" resource.labels.service_name=\"${var.cloudrun_service_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_DELTA"
                        crossSeriesReducer = "REDUCE_PERCENTILE_99"
                      }
                    }
                  }
                  plotType       = "LINE"
                  targetAxis     = "Y1"
                  legendTemplate = "p99"
                }
              ]
              yAxis = { label = "Latency (ms)", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 0
          yPos   = 4
          width  = 4
          height = 4
          widget = {
            title = "Cloud Run — Active Instances"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/container/instance_count\" resource.type=\"cloud_run_revision\" resource.labels.service_name=\"${var.cloudrun_service_name}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              }]
              yAxis = { label = "Instances", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 4
          yPos   = 4
          width  = 4
          height = 4
          widget = {
            title = "Cloud SQL — CPU Utilisation"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\" resource.type=\"cloudsql_database\" resource.labels.database_id=\"${var.project_id}:${var.db_instance_name}\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              }]
              yAxis = { label = "CPU Fraction", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 8
          yPos   = 4
          width  = 4
          height = 4
          widget = {
            title = "Cloud SQL — Disk Utilisation"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"cloudsql.googleapis.com/database/disk/utilization\" resource.type=\"cloudsql_database\" resource.labels.database_id=\"${var.project_id}:${var.db_instance_name}\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              }]
              yAxis = { label = "Disk Fraction", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 0
          yPos   = 8
          width  = 6
          height = 4
          widget = {
            title = "Cloud SQL — Active Connections"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"cloudsql.googleapis.com/database/postgresql/num_backends\" resource.type=\"cloudsql_database\" resource.labels.database_id=\"${var.project_id}:${var.db_instance_name}\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              }]
              yAxis = { label = "Connections", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 8
          width  = 6
          height = 4
          widget = {
            title = "Django ERROR/CRITICAL Log Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"logging.googleapis.com/user/django_error_critical_count\" resource.type=\"cloud_run_revision\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              }]
              yAxis = { label = "Error Count", scale = "LINEAR" }
            }
          }
        },
      ]
    }
  })
}

# ---------------------------------------------------------------------------
# Alert Policy 1 — Cloud Run High 5xx Error Rate
# ---------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "cloudrun_high_error_rate" {
  project      = var.project_id
  display_name = "Cloud Run — High 5xx Error Rate"
  combiner     = "OR"

  conditions {
    display_name = "5xx error rate > ${var.alert_high_error_rate_threshold * 100}% for 5 minutes"

    condition_threshold {
      filter = <<-EOT
        metric.type="run.googleapis.com/request_count"
        resource.type="cloud_run_revision"
        resource.labels.service_name="${var.cloudrun_service_name}"
        metric.labels.response_code_class="5xx"
      EOT

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = var.alert_high_error_rate_threshold
      duration        = "300s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "Cloud Run service **${var.cloudrun_service_name}** is returning 5xx errors above ${var.alert_high_error_rate_threshold * 100}%.\n\n**Runbook**: https://console.cloud.google.com/run/detail/${var.region}/${var.cloudrun_service_name}/logs"
    mime_type = "text/markdown"
  }

  user_labels = var.labels
}

# ---------------------------------------------------------------------------
# Alert Policy 2 — Cloud Run p95 Latency
# ---------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "cloudrun_high_latency" {
  project      = var.project_id
  display_name = "Cloud Run — High p95 Latency"
  combiner     = "OR"

  conditions {
    display_name = "p95 latency > ${var.alert_latency_p95_threshold_ms}ms for 5 minutes"

    condition_threshold {
      filter = <<-EOT
        metric.type="run.googleapis.com/request_latencies"
        resource.type="cloud_run_revision"
        resource.labels.service_name="${var.cloudrun_service_name}"
      EOT

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = var.alert_latency_p95_threshold_ms
      duration        = "300s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "Cloud Run **${var.cloudrun_service_name}** p95 latency exceeded ${var.alert_latency_p95_threshold_ms}ms.\n\n**Action**: Check Cloud SQL slow query logs and Cloud Run CPU metrics."
    mime_type = "text/markdown"
  }

  user_labels = var.labels
}

# ---------------------------------------------------------------------------
# Alert Policy 3 — Cloud SQL High Disk Utilisation
# ---------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "cloudsql_disk_high" {
  project      = var.project_id
  display_name = "Cloud SQL — High Disk Utilisation"
  combiner     = "OR"

  conditions {
    display_name = "Cloud SQL disk utilisation > ${var.alert_sql_disk_threshold * 100}%"

    condition_threshold {
      filter = <<-EOT
        metric.type="cloudsql.googleapis.com/database/disk/utilization"
        resource.type="cloudsql_database"
        resource.labels.database_id="${var.project_id}:${var.db_instance_name}"
      EOT

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = var.alert_sql_disk_threshold
      duration        = "300s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "86400s"
  }

  documentation {
    content   = "Cloud SQL disk at or above ${var.alert_sql_disk_threshold * 100}% utilisation.\n\n**Action**: Review data retention, run VACUUM FULL if needed, verify autoresize."
    mime_type = "text/markdown"
  }

  user_labels = var.labels
}

# ---------------------------------------------------------------------------
# Alert Policy 4 — Cloud SQL High CPU
# ---------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "cloudsql_cpu_high" {
  project      = var.project_id
  display_name = "Cloud SQL — High CPU Utilisation"
  combiner     = "OR"

  conditions {
    display_name = "Cloud SQL CPU > ${var.alert_sql_cpu_threshold * 100}% for 10 minutes"

    condition_threshold {
      filter = <<-EOT
        metric.type="cloudsql.googleapis.com/database/cpu/utilization"
        resource.type="cloudsql_database"
        resource.labels.database_id="${var.project_id}:${var.db_instance_name}"
      EOT

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = var.alert_sql_cpu_threshold
      duration        = "600s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    content   = "Cloud SQL CPU above ${var.alert_sql_cpu_threshold * 100}% for 10 minutes.\n\n**Action**: Check pg_stat_activity for long-running queries. Consider upgrading the instance tier."
    mime_type = "text/markdown"
  }

  user_labels = var.labels
}

# ---------------------------------------------------------------------------
# Alert Policy 5 — Cloud Run Instance Count at Maximum
# ---------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "cloudrun_at_max_instances" {
  project      = var.project_id
  display_name = "Cloud Run — Instance Count at Maximum"
  combiner     = "OR"

  conditions {
    display_name = "Active instances = ${var.cloudrun_max_instances} (max) for 5 minutes"

    condition_threshold {
      filter = <<-EOT
        metric.type="run.googleapis.com/container/instance_count"
        resource.type="cloud_run_revision"
        resource.labels.service_name="${var.cloudrun_service_name}"
        metric.labels.state="active"
      EOT

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_SUM"
      }

      comparison      = "COMPARISON_GE"
      threshold_value = var.cloudrun_max_instances
      duration        = "300s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    content   = "Cloud Run **${var.cloudrun_service_name}** reached max instances (${var.cloudrun_max_instances}). Consider increasing `cloudrun_max_instances`."
    mime_type = "text/markdown"
  }

  user_labels = var.labels
}

# ---------------------------------------------------------------------------
# Alert Policy 6 — Django Application Error Spike
# ---------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "django_error_spike" {
  project      = var.project_id
  display_name = "Django — Application Error/Critical Log Spike"
  combiner     = "OR"

  conditions {
    display_name = "Django ERROR/CRITICAL log count > 10 in 5 minutes"

    condition_threshold {
      filter = <<-EOT
        metric.type="logging.googleapis.com/user/django_error_critical_count"
        resource.type="cloud_run_revision"
        resource.labels.service_name="${var.cloudrun_service_name}"
      EOT

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "0s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "Django application producing >10 ERROR/CRITICAL log entries in 5 minutes.\n\n**Action**: Filter Cloud Logging for severity>=ERROR on **${var.cloudrun_service_name}**."
    mime_type = "text/markdown"
  }

  user_labels = var.labels
}

# ---------------------------------------------------------------------------
# Log bucket — Cloud Run logs (regional, CMEK-encrypted)
# CMEK: log_bucket_kms_key_name must be in the same region as the bucket.
# Grant the logging service account CryptoKeyEncrypterDecrypter on the key
# before applying (see README Prerequisites).
# ---------------------------------------------------------------------------
resource "google_logging_project_bucket_config" "cloudrun_logs" {
  project        = var.project_id
  location       = var.region
  bucket_id      = "cloudrun-reporting-logs"
  retention_days = 30
  description    = "Log bucket for Django reporting Cloud Run service logs"

  # CMEK encryption — consistent with production-grade at-rest encryption posture
  cmek_settings {
    kms_key_name = var.log_bucket_kms_key_name
  }
}

# Grant the sink writer identity permission to write to this bucket
resource "google_project_iam_member" "cloudrun_sink_writer" {
  project = var.project_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_project_sink.cloudrun_sink.writer_identity
}

resource "google_logging_project_sink" "cloudrun_sink" {
  project                = var.project_id
  name                   = "sink-cloudrun-reporting"
  destination            = "logging.googleapis.com/projects/${var.project_id}/locations/${var.region}/buckets/cloudrun-reporting-logs"
  unique_writer_identity = true

  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${var.cloudrun_service_name}"
  EOT

  depends_on = [google_logging_project_bucket_config.cloudrun_logs]
}

# ---------------------------------------------------------------------------
# Log bucket — Cloud SQL logs (regional, CMEK-encrypted)
# ---------------------------------------------------------------------------
resource "google_logging_project_bucket_config" "cloudsql_logs" {
  project        = var.project_id
  location       = var.region
  bucket_id      = "cloudsql-reporting-logs"
  retention_days = 30
  description    = "Log bucket for Cloud SQL slow query and audit logs (reporting instance only)"

  # CMEK encryption — consistent with production-grade at-rest encryption posture
  cmek_settings {
    kms_key_name = var.log_bucket_kms_key_name
  }
}

# Grant the sink writer identity permission to write to this bucket
resource "google_project_iam_member" "cloudsql_sink_writer" {
  project = var.project_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_project_sink.cloudsql_sink.writer_identity
}

resource "google_logging_project_sink" "cloudsql_sink" {
  project                = var.project_id
  name                   = "sink-cloudsql-reporting"
  destination            = "logging.googleapis.com/projects/${var.project_id}/locations/${var.region}/buckets/cloudsql-reporting-logs"
  unique_writer_identity = true

  filter = <<-EOT
    resource.type="cloudsql_database"
    resource.labels.database_id="${var.project_id}:${var.db_instance_name}"
  EOT

  depends_on = [google_logging_project_bucket_config.cloudsql_logs]
}
