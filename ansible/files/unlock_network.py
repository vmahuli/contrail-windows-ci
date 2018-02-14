#!/usr/bin/env python

from pyVim.connect import SmartConnection
from pyVim.task import WaitForTask
from vmware_api import *


def get_args():
    parser = VmwareArgumentParser()

    parser.add_argument('--folder',
                        required=True,
                        action='store',
                        help='Folder in which the lock directory has been created')

    parser.add_argument('--network-name',
                        required=True,
                        action='store',
                        help='Network to unlock')

    return parser.parse_args()


def unlock_network(api, args):
    folder_name = '{}/{}'.format(args.folder, args.network_name)
    folder = api.get_vm_folder(folder_name)
    if not folder:
        raise ResourceNotFound("Couldn't find the Folder with the provided name "
                               "'{}'".format(folder_name))

    if folder.childEntity:
        raise IncorrectArgument("The folder '{}' is not empty".format(folder_name))

    task = folder.Destroy_Task()
    WaitForTask(task)


def main():
    args = get_args()
    conn_params = get_connection_params(args)
    with SmartConnection(**conn_params) as si:
        api = VmwareApi(si, datacenter_name=args.datacenter, cluster_name=None)
        unlock_network(api, args)


if __name__ == "__main__":
    main()
