PLAYBOOK ?= playbooks/site.yml
LIMIT ?=
EXTRA_ARGS ?=

COMPOSE_RUN = docker compose run --rm ansible

.PHONY: build shell playbook ping

build:
	docker compose build ansible

shell:
	$(COMPOSE_RUN) bash

playbook:
	$(COMPOSE_RUN) ansible-playbook $(PLAYBOOK) $(if $(LIMIT),--limit $(LIMIT),) $(EXTRA_ARGS)

ping:
	$(COMPOSE_RUN) ansible all -m ping
