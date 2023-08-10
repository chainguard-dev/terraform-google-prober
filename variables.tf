/*
Copyright 2022 Chainguard, Inc.
SPDX-License-Identifier: Apache-2.0
*/

variable "name" {
  description = "Name to prefix to created resources."
}

variable "project_id" {
  type        = string
  description = "The project that will host the prober."
}

variable "repository" {
  type        = string
  default     = ""
  description = "Container repository to publish images to."
}

variable "service_account" {
  type        = string
  description = "The email address of the service account to run the service as."
}

variable "importpath" {
  type        = string
  description = "The import path that contains the prober application."
}

variable "working_dir" {
  type        = string
  description = "The working directory that contains the importpath."
}

variable "locations" {
  type        = list(string)
  default     = ["us-central1"]
  description = "Where to run the Cloud Run services."
}

variable "dns_zone" {
  type        = string
  default     = ""
  description = "The managed DNS zone in which to create prober record sets (required for multiple locations)."
}

variable "domain" {
  type        = string
  default     = ""
  description = "The domain of the environment to probe (required for multiple locations)."
}

variable "env" {
  default     = {}
  description = "A map of custom environment variables (e.g. key=value)"
}

variable "timeout" {
  type        = string
  default     = "60s"
  description = "The timeout for the prober in seconds."
}

variable "period" {
  type        = string
  default     = "300s"
  description = "The period for the prober in seconds."
}

variable "cpu" {
  type        = string
  default     = "1000m"
  description = "The CPU limit for the prober."
}

variable "memory" {
  type        = string
  default     = "512Mi"
  description = "The memory limit for the prober."
}
