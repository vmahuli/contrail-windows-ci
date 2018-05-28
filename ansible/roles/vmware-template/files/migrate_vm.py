#!/usr/bin/env python

import ssl
import argparse
import getpass
from pyVmomi import vim
from pyVim.connect import SmartConnection
from pyVim.task import WaitForTask


class ResourceNotFound(Exception):
    pass


class OperationFailed(Exception):
    pass


def get_connection_params(args):
    context = ssl.SSLContext(ssl.PROTOCOL_SSLv23)
    context.verify_mode = ssl.CERT_NONE
    params = {
        'host': args.host,
        'user': args.user,
        'pwd': args.password,
        'sslContext': context
    }
    return params


def get_args():
    parser = argparse.ArgumentParser(description='Arguments for talking to vCenter')

    parser.add_argument('--host',
                        required=True,
                        action='store',
                        help='vSphere service to connect to')

    parser.add_argument('--user',
                        required=True,
                        action='store',
                        help='Username used to connect to vSphere')

    parser.add_argument('--password',
                        required=False,
                        action='store',
                        help='Username used to connect to vSphere')

    parser.add_argument('--uuid',
                        required=True,
                        action='store',
                        help='UUID of VM to migrate')

    parser.add_argument('--datastore',
                        required=True,
                        action='store',
                        help='Name of the datastore where the VM should be moved')

    args = parser.parse_args()

    if not args.password:
        args.password = getpass.getpass(prompt='Enter password')

    return args


def get_vm_by_uuid(connection, vm_uuid):
    search_index = connection.content.searchIndex

    vm = search_index.FindByUuid(None, vm_uuid, True)
    if vm is None:
        raise ResourceNotFound("Couldn't find the VM with UUID {}".format(vm_uuid))

    return vm


def get_datastore_by_name(connection, datastore_name):
    content = connection.content
    container = content.viewManager.CreateContainerView(content.rootFolder, [vim.Datastore], True)

    datastore = next((obj for obj in container.view if obj.name == datastore_name), None)
    if datastore is None:
        raise ResourceNotFound("Datastore '{}' cannot be found".format(datastore_name))

    return datastore


def migrate_vm_to_datastore(vm, datastore):
    relocate_spec = vim.vm.RelocateSpec(datastore=datastore)
    relocation_task = vm.Relocate(relocate_spec)

    WaitForTask(relocation_task)

    if relocation_task.info.state != 'success':
        raise OperationFailed(
            "Migration of the VM '{}' to datastore '{}' failed with the following error: {}".format(
                vm.name, datastore.name, relocation_task.info.error.localizedMessage))


def main():
    args = get_args()
    conn_params = get_connection_params(args)
    with SmartConnection(**conn_params) as si:
        vm = get_vm_by_uuid(si, args.uuid)
        datastore = get_datastore_by_name(si, args.datastore)
        migrate_vm_to_datastore(vm, datastore)


if __name__ == "__main__":
    main()
