
# 
PROJECT := DeployTest
REGION := eu-central-1

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

TIMESTAMP := $(shell date +%Y%m%d%H%M%S)
GIT_COMMIT_HASH := $(shell git rev-parse --verify HEAD)

setup: iam-setup ec2-setup

teardown: ec2-setup iam-setup

iam-setup: ansible/vars.yml
	@cd ansible && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
		-i hosts iam_setup.yml \
		--extra-vars="timestamp=$(TIMESTAMP)"

iam-teardown: ansible/vars.yml
	@cd ansible && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
		-i hosts iam_teardown.yml \
		--extra-vars="timestamp=$(TIMESTAMP)"

ec2-setup: ansible/vars.yml
	@cd ansible && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
		-i hosts ec2_setup.yml \
		--extra-vars="timestamp=$(TIMESTAMP)"

ec2-teardown: ansible/vars.yml
	@cd ansible && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
		-i hosts ec2_teardown.yml \
		--extra-vars="timestamp=$(TIMESTAMP)"

# After setup you can run this to create the "golden AMI"
# remember to update GAME_SERVER_AMI_ID after that!
ami-bake: ansible/vars.yml
	@cd ansible && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
		--private-key=$(REGION)-$(KEY_NAME).pem \
		-i hosts bake.yml \
		--extra-vars="timestamp=$(TIMESTAMP)"

# this will contain all the stuff needed to create an Application for AWS CodeDeploy
#codedeploy-setup:
#	@aws deploy create-application --application-name $(PROJECT)
#	@aws deploy create-deployment-group \
#		--application-name $(PROJECT) \
#		--deployment-group-name $(PROJECT)Instances \
#		--ec2-tag-filters "Key=Group,Value=$(IAM_ROLE_NAME)InstanceProfile"

# Yeah... but for now I want to drive some parameters from this Makefile instead of just using Ansible
ansible/vars.yml: 
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

ami-describe:
	@aws ec2 describe-images --image-id $(AMI_ID)

clean:
	@rm -f ansible/vars.yml

.PHONY: launch-instance clean bake setup teardown ec2-setup ec2-teardown iam-setup iam-teardown ami-describe
