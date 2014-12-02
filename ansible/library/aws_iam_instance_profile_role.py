#!/usr/bin/python

import sys
import time

try:
    import boto.iam
except ImportError:
    print "failed=True msg='boto required for this module'"
    sys.exit(1)

#  add-role-to-instance-profile --region $(REGION) --instance-profile-name $$role-InstanceProfile --role-name $$role
def main():
    argument_spec = ec2_argument_spec()    
    argument_spec.update(dict(
            profile_name = dict(default=None,required=True),
            role_name = dict(default=None,required=True), 
            state = dict(default='present', choices=['present', 'absent']),
        )
    )

    module = AnsibleModule(
        argument_spec=argument_spec
    )

    profile_name = module.params.get('profile_name')
    role_name = module.params.get('role_name')
 
    region, ec2_url, aws_connect_params = get_aws_connection_info(module)
    iam = connect_to_aws(boto.iam, region, **aws_connect_params)
  
    changed = False

    missing = True
    try:
        response = iam.get_instance_profile(profile_name)
        # todo: does not really check if the role is what we want
        missing = len(response.get_instance_profile_result.instance_profile.roles) == 0
    except boto.exception.BotoServerError as e:
        if e.status == 404:
         missing = True

    state = module.params.get('state')

    if state == 'present':
        if missing:
            response = iam.add_role_to_instance_profile(profile_name, role_name)
        module.exit_json(changed = missing)
    elif state == 'absent':
        if not missing:
            response = iam.remove_role_from_instance_profile(profile_name, role_name)
        module.exit_json(changed = not missing)

# import module snippets
from ansible.module_utils.basic import *
from ansible.module_utils.ec2 import *

main()