#!/usr/bin/env python
"""
Written by Dann Bohn (add_disk_to_vm.py)
Github: https://github.com/whereismyjetpack
Email: dannbohn@gmail.com

Changed by Wojciech Urbanski 
Github: https://github.com/wurbanski
to provide other functionality (mark as template).

"""
from __future__ import print_function
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
                        required=False,
                        action='store',
                        help='name of the vm')

    parser.add_argument('--uuid',
                        required=False,
                        action='store',
                        help='vmuuid of vm')

    args = parser.parse_args()

    if not args.password:
        args.password = getpass.getpass(
            prompt='Enter password')

    return args


def get_obj(content, vimtype, name):
    obj = None
    container = content.viewManager.CreateContainerView(
        content.rootFolder, vimtype, True)
    for c in container.view:
        if c.name == name:
            obj = c
            break
    return obj


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

    vm = None
    if args.uuid:
        search_index = si.content.searchIndex
        vm = search_index.FindByUuid(None, args.uuid, True)
    elif args.vm_name:
        content = si.RetrieveContent()
        vm = get_obj(content, [vim.VirtualMachine], args.vm_name)

    if vm:
        vm.MarkAsTemplate()
        print("VM %s marked as template." % args.vm_name)
        return 0
    else:
        print("VM not found")
        return 1


# start this thing
if __name__ == "__main__":
    exit(main())
