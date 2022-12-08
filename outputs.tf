output "uptime_check" {
  value = local.use_gclb ? google_monitoring_uptime_check_config.global_uptime_check[0].uptime_check_id : google_monitoring_uptime_check_config.regional_uptime_check[0].uptime_check_id
}
