#!/usr/bin/python

import sys
import time

try:
    import boto.iam
except ImportError:
    print "failed=True msg='boto required for this module'"
    sys.exit(1)

def main():
    argument_spec = ec2_argument_spec()    
    argument_spec.update(dict(
            role_name = dict(default=None,required=True),
            assume_role_policy_document = dict(default=None,required=False),
            state = dict(default='present', choices=['present', 'absent']),
        )
    )

    module = AnsibleModule(
        argument_spec=argument_spec
    )

    role_name = module.params.get('role_name')
    assume_role_policy_document = module.params.get('assume_role_policy_document')

    region, ec2_url, aws_connect_params = get_aws_connection_info(module)
    iam = connect_to_aws(boto.iam, region, **aws_connect_params)

    changed = False

    state = module.params.get('state')

    role_missing = False
    role_data = None
    try:
        response = iam.get_role(role_name)
        role_data = response.get_role_result.role
    except boto.exception.BotoServerError as e:
       if e.status == 404:
         role_missing = True

    if state == 'present':
        if role_missing:

            policy = None
            with open(assume_role_policy_document, 'r') as f:
                policy = f.read()

            response = iam.create_role(role_name, policy)
            module.exit_json(changed = True, role = response.create_role_result.role)
        else:
            module.exit_json(changed = False, role = role_data)
    elif state == 'absent':
        if not role_missing:
            response = iam.delete_role(role_name)
        module.exit_json(changed = not role_missing)

# import module snippets
from ansible.module_utils.basic import *
from ansible.module_utils.ec2 import *

main()