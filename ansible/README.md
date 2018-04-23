contrail-windows-ci
===================


## Preparing

```bash
# Create virtualenv for Python3
virtualenv -p /usr/bin/python3 venv
. ./venv/bin/activate

# Install required Python packages
pip install -r python-requirements.txt

# Install required roles from Ansible Galaxy
ansible-galaxy install -r ansible-requirements.yml

# Create a file with Ansible vault password
echo PASSWORD > ~/ansible-vault-key
```

## Running ansible-linter

```bash
# Must be run outside `ansible/` directory
python3 ./StaticAnalysis/ansible_linter.py
```


## Running playbooks

**Important**: Playbook can be run without providing extra variables - you'll be prompted for all the required parameters.
Extra variables are provided here only for documentation purposes.


### Deploy testenv

```bash
ansible-playbook -i inventory.testenv vmware-deploy-testenv.yml \
    -e testenv_name=NAME \
    -e testenv_folder=DESTINATION_DIRECTORY \
    -e testenv_mgmt_network=MGMT_NETWORK \
    -e testenv_data_network=DATA_NETWORK \
    -e testenv_controller_template=CONTROLLER_TEMPLATE \
    -e testenv_testbed_template=TESTBED_TEMPLATE \
    -e vcenter_datastore_cluster=VCENTER_DATASTORE_CLUSTER
```


### Destroy testenv

```bash
ansible-playbook -i inventory.testenv vmware-destroy-testenv.yml \
    -e testenv_name=NAME \
    -e testenv_folder=DIRECTORY
```
