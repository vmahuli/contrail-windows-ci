#!/usr/bin/env python
"""
Written by Dann Bohn (add_disk_to_vm.py)
Github: https://github.com/whereismyjetpack
Email: dannbohn@gmail.com

Changed by Wojciech Urbanski 
Github: https://github.com/wurbanski
to provide other functionality (get multiple vms with a name).

"""
from pyVmomi import vim
from pyVmomi import vmodl
from pyVim.connect import SmartConnectNoSSL, Disconnect
import atexit
import argparse
import getpass


def get_args():
    parser = argparse.ArgumentParser(
        description='Arguments for talking to vCenter')

    parser.add_argument('-s', '--host',
                        required=True,
                        action='store',
                        help='vSphere service to connect to')

    parser.add_argument('-o', '--port',
                        type=int,
                        default=443,
                        action='store',
                        help='Port to connect on')

    parser.add_argument('-u', '--user',
                        required=True,
                        action='store',
                        help='User name to use')

    parser.add_argument('-p', '--password',
                        required=False,
                        action='store',
                        help='Password to use')

    parser.add_argument('-v', '--vm-name',
                        required=True,
                        action='store',
                        help='name of the vm')

    args = parser.parse_args()

    if not args.password:
        args.password = getpass.getpass(
            prompt='Enter password')

    return args


def get_first_free_id(content, vimtype, name):
    id = 1
    container = content.viewManager.CreateContainerView(
        content.rootFolder, vimtype, True)

    vms = tuple(int(c.name.split('-')[-1])
                for c in container.view
                if name in c.name)

    for i, num in enumerate(sorted(vms)):
        if i + 1 != num:
            id = i + 1
            break
    else:
        id = len(vms) + 1

    return id


def main():
    args = get_args()

    # connect this thing
    si = SmartConnectNoSSL(
        host=args.host,
        user=args.user,
        pwd=args.password,
        port=args.port)
    # disconnect this thing
    atexit.register(Disconnect, si)

    id = None
    content = si.RetrieveContent()
    id = get_first_free_id(content, [vim.VirtualMachine], args.vm_name)

    print id
    return 0


# start this thing
if __name__ == "__main__":
    exit(main())
