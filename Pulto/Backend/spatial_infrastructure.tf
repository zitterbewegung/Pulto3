# spatial_infrastructure.tf - Local Development Infrastructure

# Import required configurations from other files:
# - provider_configuration.tf: Terraform and provider setup
# - deployment_config.tf: Variable definitions  
# - computed_values.tf: Local computed values
# - service_endpoints.tf: Output definitions

# Docker network for local development
resource "docker_network" "spatial_viz_network" {
  name = local.network_config.name
  
  ipam_config {
    subnet  = local.network_config.subnet
    gateway = local.network_config.gateway
  }
}

# Docker volumes for persistent data
resource "docker_volume" "app_data" {
  name = local.volume_names.app_data
}

resource "docker_volume" "redis_data" {
  name = local.volume_names.redis_data
}

resource "docker_volume" "notebook_storage" {
  name = local.volume_names.notebook_storage
}

resource "docker_volume" "postgres_data" {
  name = local.volume_names.postgres_data
}

# Redis container for caching and session storage
resource "docker_image" "redis" {
  name = "redis:7-alpine"
}

resource "docker_container" "redis" {
  name  = local.container_names.redis
  image = docker_image.redis.image_id
  
  networks_advanced {
    name = docker_network.spatial_viz_network.name
    aliases = ["redis"]
  }
  
  ports {
    internal = local.port_mappings.redis.internal
    external = local.port_mappings.redis.external
  }
  
  volumes {
    volume_name    = docker_volume.redis_data.name
    container_path = "/data"
  }
  
  command = local.redis_config.commands
  
  restart = "unless-stopped"
  
  healthcheck {
    test     = local.health_checks.redis.test
    interval = local.health_checks.redis.interval
    timeout  = local.health_checks.redis.timeout
    retries  = local.health_checks.redis.retries
  }
}

# Build the FastAPI application image
resource "docker_image" "spatial_viz_app" {
  name = "${local.app_name}:${local.build_config.target}"
  
  build {
    context    = local.build_config.context
    dockerfile = local.build_config.dockerfile
    tag        = ["${local.app_name}:latest"]
    
    build_arg = local.build_config.args
  }
  
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "**") : filesha1(f) if !contains(split("/", f), ".terraform")]))
  }
}

# Main FastAPI application container
resource "docker_container" "spatial_viz_app" {
  name  = local.container_names.app
  image = docker_image.spatial_viz_app.image_id
  
  networks_advanced {
    name = docker_network.spatial_viz_network.name
    aliases = ["app", "api"]
  }
  
  ports {
    internal = local.port_mappings.app.internal
    external = local.port_mappings.app.external
  }
  
  # Environment variables from computed values
  env = local.app_environment_vars
  
  # Volume mounts
  volumes {
    volume_name    = docker_volume.app_data.name
    container_path = "/app/data"
  }
  
  volumes {
    volume_name    = docker_volume.notebook_storage.name
    container_path = "/app/notebooks"
  }
  
  # Mount source code for development (hot reload)
  dynamic "volumes" {
    for_each = local.dev_config.mount_source_code ? [1] : []
    content {
      host_path      = abspath("${path.module}")
      container_path = "/app"
    }
  }
  
  restart = "unless-stopped"
  
  # Wait for Redis to be ready
  depends_on = [docker_container.redis]
  
  healthcheck {
    test         = local.health_checks.app.test
    interval     = local.health_checks.app.interval
    timeout      = local.health_checks.app.timeout
    retries      = local.health_checks.app.retries
    start_period = local.health_checks.app.start_period
  }
  
  # Add labels for easier management
  labels {
    label = "project"
    value = var.project_name
  }
  
  labels {
    label = "environment"
    value = var.environment
  }
  
  labels {
    label = "managed_by"
    value = "terraform"
  }
}

# PostgreSQL database for production-like testing
resource "docker_image" "postgres" {
  name = "postgres:15-alpine"
}

resource "docker_container" "postgres" {
  count = var.enable_postgres ? 1 : 0
  
  name  = local.container_names.postgres
  image = docker_image.postgres.image_id
  
  networks_advanced {
    name = docker_network.spatial_viz_network.name
    aliases = ["postgres", "db"]
  }
  
  ports {
    internal = local.port_mappings.postgres.internal
    external = local.port_mappings.postgres.external
  }
  
  env = local.postgres_config.environment
  
  volumes {
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }
  
  restart = "unless-stopped"
  
  healthcheck {
    test     = local.health_checks.postgres.test
    interval = local.health_checks.postgres.interval
    timeout  = local.health_checks.postgres.timeout
    retries  = local.health_checks.postgres.retries
  }
  
  labels {
    label = "project"
    value = var.project_name
  }
  
  labels {
    label = "environment"
    value = var.environment
  }
}