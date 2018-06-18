#!/usr/bin/env python
import argparse
import getpass
import signal
import sys
import time
from pyVim.connect import SmartConnection
from pyVim.task import WaitForTask
from pyVmomi import vmodl
from pyVmomi import vim
from vmware_api import *


class WorkingHostNotFoundError(Exception):
    pass


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


def wait_until_vm_does_not_exist(api, vm_name, retries=100, delay=10):
    for _ in range(retries):
        try:
            vm = api.get_vm(vm_name)
            if not vm:
                return
        except vmodl.fault.ManagedObjectNotFound as e:
            # NOTE: When this happens VM does not exist FOR REAL (kind of)
            # Caught error message:
            #   The object 'vim.VirtualMachine:vm-IDHERE' has already been deleted or has not been completely created
            print('vmodl.fault.ManagedObjectNotFound: {}'.format(e.msg))
            return
        time.sleep(delay)
    raise WaitForResourceDeletionTimeout('Timed out while waiting for VM clone task to be canceled')


def get_customization_data_from_args(args):
    return {
        'name': args.name,
        'org': 'Contrail',
        'username': args.vm_username,
        'password': args.vm_password,
        'data_ip_address': args.data_ip_address,
        'data_netmask': args.data_netmask
    }


def try_provision_in_specific_location(api, template, vm_name, folder, location, specs):
    host, datastore = location
    config_spec, customization_spec = specs

    relocate_spec = get_vm_relocate_spec(api.cluster, host, datastore)
    clone_spec = get_vm_clone_spec(template, config_spec, customization_spec, relocate_spec)

    try:
        task = template.Clone(name=vm_name, folder=folder, spec=clone_spec)
        WaitForTask(task)
    except (KeyboardInterrupt, SystemExit):
        if task is not None:
            # In this case we should at least try to cancel the task
            task.CancelTask()
            wait_until_vm_does_not_exist(api, vm_name)
        raise
    except vim.fault.InvalidHostState:
        # TODO: Post a warning about cloning failure to some monitoring service
        return False

    return True


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

    config_spec = get_vm_config_spec(api, vm=template, networks=[args.mgmt_network, args.data_network])

    customization_data = get_customization_data_from_args(args)
    customization_spec = get_vm_customization_spec(template, **customization_data)
    specs = (config_spec, customization_spec)

    hosts_and_datastores = api.iter_destination_hosts_and_datastores(args.datastore_cluster)
    for location in hosts_and_datastores:
        if try_provision_in_specific_location(api, template, name, folder, location, specs):
            return

    raise WorkingHostNotFoundError("Couldn't find any working location (host/datastore) for provisioning VM")


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
