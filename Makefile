# Swikko — commandes du projet. `make` seul affiche l'aide.
#
# Deux environnements :
#   dev   sur le Mac : Docker (base + API seedée + Mailpit), app branchée sur le Mac
#   prod  sur le NAS : compose.nas.yaml, app branchée sur https://studyflow-dev.duckdns.org

.DEFAULT_GOAL := help
.PHONY: help setup dev dev-api dev-down dev-reset dev-logs dev-psql dev-status \
        app-dev app-prod app-demo app-web test test-api test-app deploy-api

help: ## Affiche cette aide
	@awk 'BEGIN {FS = ":.*## "; printf "\nSwikko\n\n"} \
		/^## / {printf "\n\033[1m%s\033[0m\n", substr($$0, 4)} \
		/^[a-z-]+:.*## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo

## Mise en route
setup: ## Vérifie les outils, crée .env, récupère les dépendances
	@./scripts/dev.sh setup

## Environnement de développement (Mac)
dev: ## Base + API (seedée) + Mailpit dans Docker
	@./scripts/dev.sh up

dev-api: ## Base + Mailpit dans Docker, API sur le Mac avec rechargement à chaud
	@./scripts/dev.sh api

dev-reset: ## Efface la base de dev et la reseed
	@./scripts/dev.sh reset

dev-down: ## Arrête l'environnement de dev (les données restent)
	@./scripts/dev.sh down

dev-logs: ## Journaux de l'API Docker
	@./scripts/dev.sh logs

dev-psql: ## Console SQL sur la base de dev
	@./scripts/dev.sh psql

dev-status: ## État des services de dev
	@./scripts/dev.sh status

## Application
app-dev: ## Installe l'app branchée sur l'API du Mac (appareil connecté)
	@./scripts/install_app.sh --env=dev

app-prod: ## Installe l'app de production (NAS), en release
	@./scripts/install_app.sh --env=prod --release

app-demo: ## Installe l'app de démonstration (données fictives, sans serveur)
	@./scripts/install_app.sh --env=demo

app-web: ## Lance l'app dans Chrome, branchée sur l'API du Mac
	@./scripts/run_app.sh --env=dev --device=chrome

## Qualité
test: test-api test-app ## Tous les tests

test-api: ## Tests du backend (Docker requis)
	dotnet test tests/StudyFlow.Api.Tests --nologo

test-app: ## Analyse et tests Flutter
	cd src/app && flutter analyze && flutter test

## Production (NAS)
deploy-api: ## Construit l'API sur le Mac et l'envoie au NAS (voir la skill swikko-deploy)
	@./scripts/nas_ship_api.sh
