# =============================================================================
# docker-infra-stack — Unified Operations Makefile
# =============================================================================

# Variables
INFRA_COMPOSE = infra_stack_application/docker-compose.yml
SVC_DIR = service_stack_application
ALL_SERVICES = clickhouse langfuse presidio infisical

# -----------------------------------------------------------------------------
# HELP
# -----------------------------------------------------------------------------
help:
	@echo "docker-infra-stack — Unified Operations"
	@echo ""
	@echo "Infrastructure:"
	@echo "  make infra-up        Start infra stack"
	@echo "  make infra-down      Stop infra stack"
	@echo "  make infra-ps        Show infra status"
	@echo "  make infra-logs      Follow infra logs"
	@echo ""
	@echo "Services (SVC=clickhouse|langfuse|presidio|infisical):"
	@echo "  make svc-up SVC=langfuse      Start a service"
	@echo "  make svc-down SVC=langfuse    Stop a service"
	@echo "  make svc-ps SVC=langfuse      Show service status"
	@echo "  make svc-logs SVC=langfuse    Follow service logs"
	@echo ""
	@echo "Shortcuts:"
	@echo "  make clickhouse"
	@echo "  make langfuse"
	@echo "  make presidio"
	@echo "  make infisical"
	@echo ""
	@echo "Combined:"
	@echo "  make all-up"
	@echo "  make all-down"
	@echo "  make all-ps"
	@echo ""
	@echo "Utilities:"
	@echo "  make env-example"
	@echo "  make db-provision"
	@echo "  make health"
	@echo "  make clean"

# -----------------------------------------------------------------------------
# INFRASTRUCTURE (empty bodies - will fill next)
# -----------------------------------------------------------------------------
infra-up:
infra-down:
infra-ps:
infra-logs:

# -----------------------------------------------------------------------------
# SERVICES (empty bodies - will fill next)
# -----------------------------------------------------------------------------
svc-up:
svc-down:
svc-ps:
svc-logs:

# Service shortcuts
clickhouse:
langfuse:
presidio:
infisical:

# -----------------------------------------------------------------------------
# COMBINED (empty bodies - will fill next)
# -----------------------------------------------------------------------------
all-up:
all-down:
all-ps:

# -----------------------------------------------------------------------------
# UTILITIES (empty bodies - will fill next)
# -----------------------------------------------------------------------------
env-example:
db-provision:
health:
clean:

# -----------------------------------------------------------------------------
# INFRASTRUCTURE IMPLEMENTATION
# -----------------------------------------------------------------------------
infra-up:
	docker compose -f $(INFRA_COMPOSE) up -d

infra-down:
	docker compose -f $(INFRA_COMPOSE) down

infra-ps:
	docker compose -f $(INFRA_COMPOSE) ps

infra-logs:
	docker compose -f $(INFRA_COMPOSE) logs -f

# -----------------------------------------------------------------------------
# SERVICES IMPLEMENTATION
# -----------------------------------------------------------------------------
svc-up:
	@[ -n "$(SVC)" ] || (echo "Usage: make svc-up SVC=<service>" && exit 1)
	docker compose -f $(SVC_DIR)/$(SVC)/docker-compose.yml up -d

svc-down:
	@[ -n "$(SVC)" ] || (echo "Usage: make svc-down SVC=<service>" && exit 1)
	docker compose -f $(SVC_DIR)/$(SVC)/docker-compose.yml down

svc-ps:
	@[ -n "$(SVC)" ] || (echo "Usage: make svc-ps SVC=<service>" && exit 1)
	docker compose -f $(SVC_DIR)/$(SVC)/docker-compose.yml ps

svc-logs:
	@[ -n "$(SVC)" ] || (echo "Usage: make svc-logs SVC=<service>" && exit 1)
	docker compose -f $(SVC_DIR)/$(SVC)/docker-compose.yml logs -f

clickhouse:
	$(MAKE) svc-up SVC=clickhouse

langfuse:
	$(MAKE) svc-up SVC=langfuse

presidio:
	$(MAKE) svc-up SVC=presidio

infisical:
	$(MAKE) svc-up SVC=infisical

# -----------------------------------------------------------------------------
# COMBINED OPERATIONS
# -----------------------------------------------------------------------------
all-up: infra-up
	@for svc in $(ALL_SERVICES); do \
		echo "Starting $$svc..."; \
		$(MAKE) svc-up SVC=$$svc; \
	done

all-down:
	@for svc in $(ALL_SERVICES); do \
		echo "Stopping $$svc..."; \
		$(MAKE) svc-down SVC=$$svc; \
	done
	$(MAKE) infra-down

all-ps:
	$(MAKE) infra-ps
	@for svc in $(ALL_SERVICES); do \
		echo "\n=== $$svc ==="; \
		$(MAKE) svc-ps SVC=$$svc; \
	done

# -----------------------------------------------------------------------------
# UTILITIES
# -----------------------------------------------------------------------------
env-example:
	@echo "Creating .env files from .env.example templates..."
	@cp -n .env.example .env 2>/dev/null && echo "  Created root .env" || echo "  Root .env exists, skipping"
	@for svc in $(ALL_SERVICES); do \
		if [ -f "$(SVC_DIR)/$$svc/.env.example" ]; then \
			cp -n "$(SVC_DIR)/$$svc/.env.example" "$(SVC_DIR)/$$svc/.env" 2>/dev/null && \
			echo "  Created $(SVC_DIR)/$$svc/.env" || \
			echo "  $(SVC_DIR)/$$svc/.env exists, skipping"; \
		fi; \
	done
	@if [ -f "infra_stack_application/.env.example" ]; then \
		cp -n "infra_stack_application/.env.example" "infra_stack_application/.env" 2>/dev/null && \
		echo "  Created infra_stack_application/.env" || \
		echo "  infra_stack_application/.env exists, skipping"; \
	fi
	@echo ""
	@echo "Done. Edit the .env files and fill in required values (marked with 'change_me')."
	@echo "For Infisical bootstrap values, see Infisical UI: Machine Identities → Universal Auth."

db-provision:
	@echo "Provisioning databases on shared Postgres..."
	@docker compose -f $(INFRA_COMPOSE) exec -T postgres psql -U $${POSTGRES_APP_USER:-apps_rw_user} -d postgres -c "CREATE DATABASE langfuse_db;" 2>/dev/null && echo "  Created langfuse_db" || echo "  langfuse_db exists or error"
	@docker compose -f $(INFRA_COMPOSE) exec -T postgres psql -U $${POSTGRES_APP_USER:-apps_rw_user} -d postgres -c "CREATE DATABASE infisical_db;" 2>/dev/null && echo "  Created infisical_db" || echo "  infisical_db exists or error"
	@docker compose -f $(INFRA_COMPOSE) exec -T postgres psql -U $${POSTGRES_APP_USER:-apps_rw_user} -d postgres -c "CREATE DATABASE clickhouse_db;" 2>/dev/null && echo "  Created clickhouse_db" || echo "  clickhouse_db exists or error"
	@echo "Done."

health:
	@echo "Checking service health endpoints..."
	@curl -sf http://traefik.localhost/ping >/dev/null && echo "  ✓ traefik" || echo "  ✗ traefik"
	@curl -sf http://minio.localhost/minio/health/live >/dev/null && echo "  ✓ minio" || echo "  ✗ minio"
	@curl -sf http://clickhouse.localhost/ping >/dev/null && echo "  ✓ clickhouse" || echo "  ✗ clickhouse"
	@curl -sf http://langfuse.localhost/api/public/health >/dev/null && echo "  ✓ langfuse" || echo "  ✗ langfuse"
	@curl -sf http://presidio.localhost/health >/dev/null && echo "  ✓ presidio-analyzer" || echo "  ✗ presidio-analyzer"
	@curl -sf http://presidio-anonymizer.localhost/health >/dev/null && echo "  ✓ presidio-anonymizer" || echo "  ✗ presidio-anonymizer"
	@curl -sf http://infisical.localhost/api/status >/dev/null && echo "  ✓ infisical" || echo "  ✗ infisical"

clean:
	@echo "Stopping and removing all containers, volumes, networks..."
	@for svc in $(ALL_SERVICES); do \
		docker compose -f $(SVC_DIR)/$$svc/docker-compose.yml down -v 2>/dev/null || true; \
	done
	@docker compose -f $(INFRA_COMPOSE) down -v 2>/dev/null || true
	@docker network rm infra_net 2>/dev/null || true
	@echo "Done."
