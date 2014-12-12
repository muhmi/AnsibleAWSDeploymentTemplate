
![Ansible all the things](http://cdn.meme.am/instances/500x/56738879.jpg)

# Ansible AWS project template 

Aiming to handle as much as possible of managing an AWS project with Ansible.

Note: I am building this to match my needs, things will shift as I learn how to do them.

# Goal

1. Setup VPC, IAM roles, security groups etc needed for a project. 

2. Build AMIs for running a simple service, pre-installing things like Elixir.

3. Launch an ASG with from that AMI. (maybe with ELB based health checks?) 

4. Deploy a simple "hello world" app through AWS CodeDeploy on those instances

# TODO
- Update my custom IAM modules to support inlining policy documents?
- Provisioning instances, setup ASG (+ELB?)
- Create some example hello world deployment with CodeDeploy

	
