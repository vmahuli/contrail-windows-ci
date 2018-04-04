#!/usr/bin/env python
import argparse
import getpass
import signal
import sys
from pyVim.connect import SmartConnection
from pyVim.task import WaitForTask
from vmware_api import *


def get_args():
    parser = VmwareArgumentParser()

    parser.add_argument('--cluster',
                        required=False,
                        action='store',
                        help='Cluster to use (if not provided, script will choose the first one available)')

    parser.add_argument('--datastore-cluster',
                        required=True,
                        action='store',
                        help='Datastore cluster to use')

    parser.add_argument('--template',
                        required=True,
                        action='store',
                        help='VM Template used for cloning new VM')

    parser.add_argument('--folder',
                        required=True,
                        action='store',
                        help='Folder in which the cloned VM will be placed')

    parser.add_argument('--name',
                        required=True,
                        action='store',
                        help='Name which will be given to the cloned VM')

    parser.add_argument('--mgmt-network',
                        required=True,
                        action='store',
                        help='Management network for VM')

    parser.add_argument('--data-network',
                        required=True,
                        action='store',
                        help='Data-plane network for VM')

    parser.add_argument('--data-ip-address',
                        required=True,
                        action='store',
                        help='Data-plane IP address')

    parser.add_argument('--data-netmask',
                        required=True,
                        action='store',
                        help='Data-plane netmask')

    parser.add_argument('--vm-username',
                        required=False,
                        default=None,
                        action='store',
                        help='Username to setup on Windows')

    parser.add_argument('--vm-password',
                        required=False,
                        default=None,
                        action='store',
                        help='Password to set for default user on Windows')

    args = parser.parse_args()

    if args.vm_username and not args.vm_password:
        raise IncorrectArgument('If vm-username is provided, then you have to provide vm-password as well')

    if args.vm_password and not args.vm_username:
        raise IncorrectArgument('If vm-password is provided, then you have to provide vm-username as well')

    return args


def provision_vm(api, args):
    name = args.name

    template = api.get_vm(args.template)
    if not template:
        raise ResourceNotFound("Couldn't find the template with the provided name "
                               "'{}'".format(args.template))

    folder = api.get_vm_folder(args.folder)
    if not folder:
        raise ResourceNotFound("Couldn't find the folder with the provided path "
                               "'{}'".format(args.folder))

    customization_data = {
        'name': args.name,
        'org': 'Contrail',
        'username': args.vm_username,
        'password': args.vm_password,
        'data_ip_address': args.data_ip_address,
        'data_netmask': args.data_netmask
    }

    config_spec = get_vm_config_spec(api, vm=template, networks=[args.mgmt_network, args.data_network])
    customization_spec = get_vm_customization_spec(template, **customization_data)
    relocate_spec = get_vm_relocate_spec(api.cluster)
    clone_spec = get_vm_clone_spec(config_spec, customization_spec, relocate_spec)

    datastore_cluster_name = args.datastore_cluster
    pod_selection_spec = get_vm_pod_selection_spec(api, datastore_cluster_name)
    storage_spec = get_vm_storage_spec(name, folder, pod_selection_spec, template, clone_spec, operation_type='clone')

    try:
        task = clone_template_to_datastore_cluster(api, storage_spec)
        WaitForTask(task)
    except (KeyboardInterrupt, SystemExit):
        if task is not None:
            # In this case we should at least try to cancel the task
            task.CancelTask()
        raise

def signal_handler(_signo, _stack_frame):
    # Raise an exception to trigger cleanup handlers
    sys.exit()

def main():
    args = get_args()
    conn_params = get_connection_params(args)
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGHUP, signal_handler)
    with SmartConnection(**conn_params) as si:
        api = VmwareApi(si, datacenter_name=args.datacenter, cluster_name=args.cluster)
        provision_vm(api, args)


if __name__ == '__main__':
    main()
