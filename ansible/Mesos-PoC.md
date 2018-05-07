# Mesos PoC

```bash
# Provide your controller's IP
controllerIp=CONTROLLER_IP

# Do stuff
sed -e "s/CHANGEME/${controllerIp}/" inventory.mesos-poc > inventory
ansible-playbook -i inventory mesos-poc-master.yml
```
