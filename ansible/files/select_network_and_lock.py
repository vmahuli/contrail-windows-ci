#!/usr/bin/env python

import time
import re
import random
from pyVim.connect import SmartConnection
from vmware_api import *


TIME_TO_SLEEP_BEFORE_RETRY = 10
NETWORK_NAME_PATTERN = re.compile('^VLAN_([0-9]+)_TestEnv$')


def get_args():
    parser = VmwareArgumentParser()

    parser.add_argument('--folder',
                        required=True,
                        action='store',
                        help='Folder in which the lock directory will be created')

    parser.add_argument('--network-name-out-file',
                        required=True,
                        action='store',
                        help='File in which the network name will be saved')

    parser.add_argument('--first-network-id',
                        required=True,
                        action='store',
                        type=int,
                        help='First network ID to use')

    parser.add_argument('--networks-count',
                        required=True,
                        action='store',
                        type=int,
                        help='Number of networks to use')

    return parser.parse_args()


def is_network_a_testnet(name, testnets_range):
    match = NETWORK_NAME_PATTERN.match(name)
    if not match:
        return False

    return testnets_range[0] <= int(match.group(1)) <= testnets_range[1]


def select_network_and_lock(api, args):
    folder = api.get_vm_folder(args.folder)
    if not folder:
        raise ResourceNotFound("Couldn't find the Folder with the provided name "
                               "'{}'".format(args.folder))

    testnets_range = (
        args.first_network_id,
        args.first_network_id + args.networks_count - 1
    )

    available_testnets = [
        net.name for net in api.get_datacenter_networks() if is_network_a_testnet(net.name, testnets_range)
    ]

    if not available_testnets:
        raise ResourceNotFound("No networks available")

    # For even networks distributions
    random.shuffle(available_testnets)

    while True:
        for name in available_testnets:
            if not api.get_vm_folder('{}/{}'.format(args.folder, name)):
                with open(args.network_name_out_file, 'w') as f:
                    f.write(name)

                subfolder = folder.CreateFolder(name)
                if not subfolder:
                    raise ResourceNotFound("Couldn't create the Folder with the selected name "
                                           "'{}'".format(name))
                return

        time.sleep(TIME_TO_SLEEP_BEFORE_RETRY)


def main():
    args = get_args()
    conn_params = get_connection_params(args)
    with SmartConnection(**conn_params) as si:
        api = VmwareApi(si, datacenter_name=args.datacenter, cluster_name=None)
        select_network_and_lock(api, args)


if __name__ == "__main__":
    main()
