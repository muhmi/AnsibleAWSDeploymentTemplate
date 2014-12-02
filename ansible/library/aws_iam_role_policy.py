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
            policy_name =  dict(default=None,required=True),
            policy_document = dict(default=None,required=False),
            state = dict(default='present', choices=['present', 'absent']),
        )
    )

    module = AnsibleModule(
        argument_spec=argument_spec
    )

    role_name = module.params.get('role_name')
    policy_name = module.params.get('policy_name')
    policy_document = module.params.get('policy_document')

    region, ec2_url, aws_connect_params = get_aws_connection_info(module)
    iam = connect_to_aws(boto.iam, region, **aws_connect_params)
  
    changed = False

    state = module.params.get('state')

    missing = False
    try:
        response = iam.get_role_policy(role_name, policy_name)
    except boto.exception.BotoServerError as e:
       if e.status == 404:
         missing = True

    if state == 'present':
        policy = None
        with open(policy_document, 'r') as f:
            policy = f.read()
        response = iam.put_role_policy(role_name, policy_name, policy)
        module.exit_json(changed = True)
    elif state == 'absent':
        if not missing:
          response = iam.delete_role_policy(role_name, policy_name)
        module.exit_json(changed = not missing)

# import module snippets
from ansible.module_utils.basic import *
from ansible.module_utils.ec2 import *

main()