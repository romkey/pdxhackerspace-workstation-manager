PLAYBOOK ?= playbooks/site.yml
LIMIT ?=
EXTRA_ARGS ?=
IMAGE_COMPOSE_FILE ?= docker-compose.image.yml

COMPOSE_RUN = docker compose run --rm ansible
IMAGE_COMPOSE_RUN = docker compose -f $(IMAGE_COMPOSE_FILE) run --rm ansible

.PHONY: build shell playbook ping shell-image playbook-image ping-image

build:
	docker compose build ansible

shell:
	$(COMPOSE_RUN) bash

playbook:
	$(COMPOSE_RUN) ansible-playbook $(PLAYBOOK) $(if $(LIMIT),--limit $(LIMIT),) $(EXTRA_ARGS)

ping:
	$(COMPOSE_RUN) ansible all -m ping

shell-image:
	$(IMAGE_COMPOSE_RUN) bash

playbook-image:
	$(IMAGE_COMPOSE_RUN) ansible-playbook $(PLAYBOOK) $(if $(LIMIT),--limit $(LIMIT),) $(EXTRA_ARGS)

ping-image:
	$(IMAGE_COMPOSE_RUN) ansible all -m ping
