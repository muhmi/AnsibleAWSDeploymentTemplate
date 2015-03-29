#!/usr/bin/python

import sys

try:
    import boto.iam
except ImportError:
    print "failed=True msg='boto required for this module'"
    sys.exit(1)

def main():
    argument_spec = ec2_argument_spec()
    argument_spec.update(dict(
            profile_name = dict(default=None,required=True),
            state = dict(default='present', choices=['present', 'absent']),
        )
    )

    module = AnsibleModule(
        argument_spec=argument_spec
    )

    profile_name = module.params.get('profile_name')

    region, ec2_url, aws_connect_params = get_aws_connection_info(module)
    iam = connect_to_aws(boto.iam, region, **aws_connect_params)

    state = module.params.get('state')

    missing = False
    try:
        iam.get_instance_profile(profile_name)
    except boto.exception.BotoServerError as e:
       if e.status == 404:
         missing = True

    if state == 'present':
        if missing:
            iam.create_instance_profile(profile_name)
        module.exit_json(changed = missing)
    elif state == 'absent':
        if not missing:
          iam.delete_instance_profile(profile_name)
        module.exit_json(changed = not missing)

# import module snippets
from ansible.module_utils.basic import *
from ansible.module_utils.ec2 import *

main()