ifeq ("$(origin APP_ENV)", "undefined")
	APP_ENV := dev
endif

#
#
#

PROJECT := AnsibleTemplateTest
REGION := us-east-1

IAM_ROLE_NAME := $(PROJECT)-$(APP_ENV)

KEY_NAME := $(PROJECT)-$(APP_ENV)

PRIVATE_KEY := $(PROJECT)-$(REGION)-$(APP_ENV).pem

TIMESTAMP := $(shell date +%Y%m%d%H%M%S)
GIT_COMMIT_HASH := $(shell git rev-parse --verify HEAD)

ANSIBLE_OPTS := -e project_name=$(PROJECT) \
				-e app_env=$(APP_ENV) \
				-e key_name=$(KEY_NAME) \
				-e region=$(REGION) \
				--private-key=$(PRIVATE_KEY) \
				-u ubuntu

# https://gist.github.com/prwhite/8168133
help: ## This help dialog.
	@IFS=$$'\n' ; \
	help_lines=(`fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##/:/'`); \
	printf "%-30s %s\n" "target" "help" ; \
	printf "%-30s %s\n" "------" "----" ; \
	for help_line in $${help_lines[@]}; do \
		IFS=$$':' ; \
		help_split=($$help_line) ; \
		help_command=`echo $${help_split[0]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
		help_info=`echo $${help_split[2]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
		printf '\033[36m'; \
		printf "%-30s %s" $$help_command ; \
		printf '\033[0m'; \
		printf "%s\n" $$help_info; \
	done

all: help

setup: ## Create AWS setup needed by the project
	cd ansible && ansible-playbook aws_setup.yml -i inventory/local $(ANSIBLE_OPTS)

setup: ## Teardown AWS setup
	cd ansible && ansible-playbook aws_setup.yml -i inventory/local $(ANSIBLE_OPTS)

launch: ## Launch servers, will create new ones if needed
	cd ansible && ansible-playbook launch_servers.yml -i inventory/local $(ANSIBLE_OPTS)

install: ## Install software on servers
	cd ansible && ansible-playbook -i inventory/dev/ec2.py setup_servers.yml $(ANSIBLE_OPTS)

deploy: ## Deploy the application to servers 
	cd ansible && ansible-playbook -i inventory/dev/ec2.py deploy.yml $(ANSIBLE_OPTS)

ping: ## Test connection to boxes
	cd ansible && ansible -i inventory/dev/ec2.py -u ubuntu "*" -m ping --private-key=$(PRIVATE_KEY)

.PHONY: launch setup all ping install deploy