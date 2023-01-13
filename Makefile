.DEFAULT_GOAL: build-all

K8S_VERSION          ?= $(shell kubectl version --short | grep -i server | cut -d" " -f3 | cut -c2-)
KIND_IMAGE           ?= kindest/node:v1.25.2
KIND_NAME            ?= kind
USE_CONFIG           ?= standard

TOOLS_DIR                          := $(PWD)/.tools
KIND                               := $(TOOLS_DIR)/kind
KIND_VERSION                       := v0.17.0
HELM                               := $(TOOLS_DIR)/helm
HELM_VERSION                       := v3.10.1
KUTTL                              := $(TOOLS_DIR)/kubectl-kuttl
KUTTL_VERSION                      := v0.0.0-20230108220859-ef8d83c89156
TOOLS                              := $(KIND) $(HELM) $(KUTTL)

$(KIND):
	@echo Install kind... >&2
	@GOBIN=$(TOOLS_DIR) go install sigs.k8s.io/kind@$(KIND_VERSION)

$(HELM):
	@echo Install helm... >&2
	@GOBIN=$(TOOLS_DIR) go install helm.sh/helm/v3/cmd/helm@$(HELM_VERSION)

$(KUTTL):
	@echo Install kuttl... >&2
	@GOBIN=$(TOOLS_DIR) go install github.com/kyverno/kuttl/cmd/kubectl-kuttl@$(KUTTL_VERSION)

.PHONY: install-tools
install-tools: $(TOOLS)

.PHONY: clean-tools
clean-tools: 
	@echo Clean tools... >&2
	@rm -rf $(TOOLS_DIR)

###############
# KUTTL TESTS #
###############

.PHONY: test-kuttl
test-kuttl: $(KUTTL) ## Run kuttl tests
	@echo Running kuttl tests... >&2
	@$(KUTTL) test --config ./tests/kuttl-test/kuttl-test.yaml

## Create kind cluster
.PHONY: kind-create-cluster
kind-create-cluster: $(KIND) 
	@echo Create kind cluster... >&2
	@$(KIND) create cluster --name $(KIND_NAME) 

## Delete kind cluster
.PHONY: kind-delete-cluster
kind-delete-cluster: $(KIND) 
	@echo Delete kind cluster... >&2
	@$(KIND) delete cluster --name $(KIND_NAME)

###############
## TODO ##
# BUild image and update values.yam, to install kyverno and kyverno operator.
###############
.PHONY: kind-deploy-kyverno-operator
kind-deploy-kyverno-operator: $(HELM)
	@echo Install kyverno chart... >&2
	@$(HELM) repo add nirmata https://nirmata.github.io/kyverno-charts 
	@$(HELM) install kyverno-operator --namespace nirmata-kyverno-operator --create-namespace nirmata/kyverno-operator --set imagePullSecret.create=false

.PHONY: kind-deploy-kyverno
kind-deploy-kyverno: $(HELM) 
	@echo Install kyverno chart... >&2
	@$(HELM) repo add nirmata https://nirmata.github.io/kyverno-charts
	@$(HELM) install kyverno --namespace nirmata-kyverno --create-namespace nirmata/kyverno --set licenseManager.licenseKey="RAZduwNI821LZFMWOgsMKDiVIg8dEOP3mFUFu3ukYxN8N/H3Qu1kNvw7jdK85OuFFWCbF+GQtkeF0ETzfS45/HuawTKz+W5medZmktkX2mESxaQz5fJ2uMdPq+7PZD7XW4aRfVQDDOobAHgL8HFFRb5Pi+sadWv8JQGwo3TS1udS0x9EVt2EjUAAAajpYJKel7KFxuavBILuNSTpIneRMZbHjEJgxAMQPNShhCrso+gt9tu1nWYSZIdRlv+Y9V+GfLLn6yjVN43yiK+gskdR+9TncBnHqpPPbrHeXD7QS5o=",licenseManager.apiKey="ovQFlCiQqmPgBPS6FBbULjLGwDuDz/UvVs8z95KUtO4IMzVhL2aDPUiU8WlLim1addPyw9Rz5ytYmbnSDwU2zQ==",licenseManager.callHomeServer="staging.nirmata.co"

.PHONY: kind-deploy-kyverno-policies
kind-deploy-kyverno-policies: 
	@echo Install kyverno-policies ... >&2
	@kubectl apply -k ./best-practices/

.PHONY: kind-deploy-all
kind-deploy-all: | kind-deploy-kyverno-operator kind-deploy-kyverno kind-deploy-kyverno-policies
