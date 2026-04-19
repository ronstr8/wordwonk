# wordwonk Polyglot Stack Makefile

# Localhost is always allowed as an insecure registry by Docker
REGISTRY = localhost:5000
# Single point of truth for versions is helm/values.yaml
TAG ?= $(shell grep -m 1 "imageTag:" helm/values.yaml | sed 's/.*imageTag:[[:space:]]*//' | tr -d ' "')
DOCKER_BUILD_FLAGS ?= --progress=plain
NAMESPACE = wordwonk
DOMAIN = wordwonk.fazigu.org

SERVICES = frontend backend wordd ollama

.PHONY: all build clean deploy undeploy help backup $(SERVICES)

all: build

help:
	@echo "wordwonk Build System (Kind)"
	@echo "Usage:"
	@echo "  make build              - Build and push all microservice Docker images"
	@echo "  make deploy             - Install/Upgrade using Helm umbrella chart"
	@echo "  make <service>          - Build, Push, and Restart a specific service"

# Docker Build & Push Targets
build: $(SERVICES)

frontend:
	docker build $(DOCKER_BUILD_FLAGS) -t $(REGISTRY)/wordwonk-frontend:$(TAG) ./srv/frontend
	docker push $(REGISTRY)/wordwonk-frontend:$(TAG)
	kubectl rollout restart deployment/frontend -n $(NAMESPACE) || true
	kubectl rollout status deployment/frontend -n $(NAMESPACE) || true

wordd:
	docker build $(DOCKER_BUILD_FLAGS) -t $(REGISTRY)/wordwonk-wordd:$(TAG) ./srv/wordd
	docker push $(REGISTRY)/wordwonk-wordd:$(TAG)
	kubectl rollout restart deployment/wordd -n $(NAMESPACE) || true
	kubectl rollout status deployment/wordd -n $(NAMESPACE) || true

backend:
	docker build $(DOCKER_BUILD_FLAGS) -t $(REGISTRY)/wordwonk-backend:$(TAG) ./srv/backend
	docker push $(REGISTRY)/wordwonk-backend:$(TAG)
	kubectl rollout restart deployment/backend -n $(NAMESPACE) || true
	kubectl rollout status deployment/backend -n $(NAMESPACE) || true

ollama:
	docker build $(DOCKER_BUILD_FLAGS) -t $(REGISTRY)/wordwonk-ollama:$(TAG) ./srv/ollama
	docker push $(REGISTRY)/wordwonk-ollama:$(TAG)
	kubectl rollout restart deployment/ollama -n $(NAMESPACE) || true
	kubectl rollout status deployment/ollama -n $(NAMESPACE) || true

migrate: ## Run pending database migrations inside the cluster
	kubectl exec -n $(NAMESPACE) -it deploy/backend -- perl -Ilib bin/migrate.pl

backup: ## Create a timestamped SQL backup of the wordwonk database
	bash scripts/backup-db.sh


# Helm Commands
# i18n Note: Master truth lives in helm/share/locale/
# Both frontend and backend mount the wordwonk-locales ConfigMap.

deploy:
	node scripts/sync-version.js
	@mkdir -p helm/share/locale
	helm dependency update ./helm
	kubectl delete configmap wordwonk-locales --namespace $(NAMESPACE) --ignore-not-found
	helm upgrade --install wordwonk ./helm \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--values ./helm/values.yaml \
		--values ./helm/secrets.yaml \
		--set global.registry=localhost:5000 \
		--set global.domain=$(DOMAIN)

undeploy:
	helm uninstall wordwonk --namespace $(NAMESPACE)

# Hot-reload i18n via ConfigMap
locales:
	@echo "Updating shared locales ConfigMap..."
	@kubectl delete configmap wordwonk-locales --namespace $(NAMESPACE) --ignore-not-found
	@kubectl create configmap wordwonk-locales \
		--namespace $(NAMESPACE) \
		--from-file=en.json=helm/share/locale/en.json \
		--from-file=es.json=helm/share/locale/es.json \
		--from-file=fr.json=helm/share/locale/fr.json \
		--from-file=de.json=helm/share/locale/de.json \
		--from-file=ru.json=helm/share/locale/ru.json
	@echo "✅ ConfigMap updated. Pods will pick up changes within 5 minutes."

# Lexicon generation from Hunspell dictionaries
HUNSPELL_DICTS ?= /usr/share/hunspell
WORDD_ROOT ?= srv/wordd/share/words
LANGS = de en es fr ru

lexicon:
	@if [ -z "$(LANG)" ]; then echo "Usage: make lexicon LANG=en"; exit 1; fi
	@echo "Generating lexicon for $(LANG)..."
	@mkdir -p $(WORDD_ROOT)/$(LANG)
	@find $(HUNSPELL_DICTS) -name "$(LANG)_[A-Z]*.dic" | xargs perl scripts/hunspell-to-lexicon.pl > $(WORDD_ROOT)/$(LANG)/lexicon.txt
	@echo "✅ $(LANG) lexicon generated: $$(wc -l < $(WORDD_ROOT)/$(LANG)/lexicon.txt) words"

lexicons:
	@for lang in $(LANGS); do \
		$(MAKE) lexicon LANG=$$lang; \
	done
	@echo "✅ All lexicons generated."
	@wc -l $(WORDD_ROOT)/*/lexicon.txt

# Cleanup
clean:
	@echo "Cleaning up local artifacts..."
	rm -rf helm/share
	rm -rf srv/frontend/dist
	rm -rf srv/frontend/node_modules
	rm -rf srv/wordd/target
	rm -rf srv/playerd/target
	rm -f srv/gatewayd/gatewayd
	find . -name "*.exe" -delete
	find . -name "tilemasters" -type f -not -path "./srv/tilemasters/cmd/tilemasters/*" -delete

