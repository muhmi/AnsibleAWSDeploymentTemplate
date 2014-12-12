
# 
PROJECT := DeployTest
PROJECT_S3_BUCKET := somehow-uniq-deploytest
REGION := us-east-1

# *Note*
# You can run all ansible tasks in check like this:
#
#    $ DRY_RUN=1 make iam-setup 
# 
# That does the same as providing "-C" to ansible-playbook 
#

# ^- Little gotcha there that the Ansible scripts (for now) assume you have ansible/iam/{project}*.json files
# It can feed to IAM as policy documents

# Ubuntu from market place, we install our software on to and make our AMI from
BASE_AMI_ID := ami-2651904e
BASE_AMI_SNAPSHOT_ID := snap-a74a6e0f

# private key
KEY_NAME := $(PROJECT)

# you should limit its access to S3 buckets really needed 
# for. ex. http://docs.aws.amazon.com/codedeploy/latest/userguide/how-to-create-iam-instance-profile.html
IAM_ROLE_NAME := $(PROJECT)

# This role is only used for creating AMIs it needs more access to EC2, fix ansible/iam/{IAM_ROLE_NAME}Baker*.json
BAKE_IAM_ROLE_NAME := $(IAM_ROLE_NAME)Baker

# List of IAM roles managed by us
IAM_ROLES := $(IAM_ROLE_NAME) $(BAKE_IAM_ROLE_NAME) CodeDeploy

TIMESTAMP := $(shell date +%Y%m%d%H%M%S)
GIT_COMMIT_HASH := $(shell git rev-parse --verify HEAD)

APP_VERSION_LOG := "$(TIMESTAMP) $(shell git log --oneline -1)"
APP_S3_KEY := "$(TIMESTAMP)-$(PROJECT).zip"

ifneq ("$(origin DRY_RUN)", "undefined")
	ANSIBLE_OPTS := -C
endif


setup: iam-setup ec2-setup

teardown: ec2-teardown iam-teardown

iam-setup: generate_vars
	@cd ansible && for role in $(IAM_ROLES); do \
		echo "Creating IAM Role $$role"; \
		ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
			-i inventory/local \
			plays/iam_setup.yml \
			--extra-vars="timestamp=$(TIMESTAMP); iam_role=$$role" $(ANSIBLE_OPTS); \
	done

test:
	echo $(ANSIBLE_OPTS)

iam-teardown: generate_vars
	@cd ansible && for role in $(IAM_ROLES); do \
		echo "Teardown IAM $$role"; \
		ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
			-i inventory/local \
			plays/iam_teardown.yml \
			--extra-vars="timestamp=$(TIMESTAMP); iam_role=$$role" $(ANSIBLE_OPTS); \
	done

ec2-setup: generate_vars
	cd ansible && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
		-i inventory/local \
		plays/ec2_setup.yml \
		--extra-vars="timestamp=$(TIMESTAMP)" $(ANSIBLE_OPTS) 

ec2-teardown: generate_vars
	cd ansible && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
		-i inventory/local \
		plays/ec2_teardown.yml \
		--extra-vars="timestamp=$(TIMESTAMP)" $(ANSIBLE_OPTS) 

# After setup you can run this to create the "golden AMI"
# remember to update GAME_SERVER_AMI_ID after that!
ami-bake: generate_vars
	cd ansible && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
		--private-key=generated/$(REGION)-$(KEY_NAME).pem \
		-i inventory/ec2.py \
		plays/bake.yml \
		--extra-vars="timestamp=$(TIMESTAMP)" $(ANSIBLE_OPTS) 

# adding codedeploy stuff here so I remember what I need to do

codedeploy-create-app:
	aws deploy create-application --application-name $(PROJECT)

# target ec2 instances with certain tag for deployment
codedeploy-create-deployment:
	aws deploy create-deployment-group \
		--application-name $(PROJECT) \
		--deployment-group-name $(PROJECT)Instances \
		--ec2-tag-filters "Key=Group,Value=$(PROJECT),Type=KEY_AND_VALUE" \
		--service-role-arn $(shell aws iam get-role --role-name CodeDeploy --query "Role.Arn" --output text)

# package and upload a new version of the application
codedeploy-push:
	aws deploy push \
		--application-name $(PROJECT) \
		--description $(APP_VERSION_LOG) \
		--ignore-hidden-files \
		--s3-location s3://$(PROJECT_S3_BUCKET)/$(APP_S3_KEY) \
		--source application

# Yeah... but for now I want to drive some parameters from this Makefile instead of just using Ansible
generate_vars: 
	$(shell echo '---' > ansible/vars.yml)
	$(shell echo "project_name: $(PROJECT)" >> ansible/vars.yml)
	$(shell echo "private_key: $(KEY_NAME)" >> ansible/vars.yml)
	$(shell echo "region: $(REGION)" >> ansible/vars.yml)
	$(shell echo "baker_iam: $(BAKE_IAM_ROLE_NAME)"  >> ansible/vars.yml)
	$(shell echo "instance_iam: $(IAM_ROLE_NAME)"  >> ansible/vars.yml)
	$(shell echo "base_ami: $(BASE_AMI_ID)"  >> ansible/vars.yml)
	$(shell echo "key_name: $(KEY_NAME)" >> ansible/vars.yml)
	$(shell echo "creator: $$USER" >> ansible/vars.yml)
	$(shell echo "git_commit: $(GIT_COMMIT_HASH)" >> ansible/vars.yml)
	$(shell echo "project_s3_bucket: $(PROJECT_S3_BUCKET)" >> ansible/vars.yml)

ami-describe:
	@aws ec2 describe-images --image-id $(AMI_ID)

.PHONY: launch-instance clean bake setup teardown ec2-setup ec2-teardown iam-setup iam-teardown ami-describe generate_vars
