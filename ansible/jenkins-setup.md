Jenkins Master setup
====================

## Deployment and provisioning

- user: admin
- user: jenkins-swarm-agent

- folder: WinContrail
    - pipeline: WinCI
        - jenkinsfile: `jenkinsfiles/Jenkinsfile.winci` z https://github.com/sodar/contrail-windows-ci.git
        - TODO: trigger z githuba ?
- folder: WinContrail-infra
    - pipeline: deploy-builder
        - param: VM_TEMPLATE
        - Prepare an environment for the run > Keep Jenkins Environment Variables
        - Prepare an environment for the run > Keep Jenkins Build Variables
        - Prepare an environment for the run > properties: `CREDENTIALS_ID` oraz `ANSIBLE_VAULT_KEY_FILE`
        - jenkinsfile: `jenkinsfiles/Jenkinsfile.deploy-builder` z https://github.com/sodar/contrail-windows-ci.git
    - pipeline: deploy-demo-env
        - param: string DEMOENV_NAME
        - param: choice DEMOENV_VLAN
            - TODO: insert our brand new vlans
        - param: string CONTROLLER_TEMPLATE
            - TODO: add default
        - param: string WINTB_TEMPLATE
            - TODO: add default
        - TODO: pipeline script to jenkinsfile
    - pipeline: deploy-tester
        - param: string VM_TEMPLATE
            - TODO: add default
        - TODO: pipeline script to jenkinsfile
    - pipeline: destroy-demo-env
        - param: string DEMOENV_NAME
        - TODO: pipeline script to jenkinsfile
    - folder: templates
        - pipeline: create-builder-template
            - TODO: jenkinsfile w repo
        - pipeline: create-testbed-template
            - do not allow concurrent builds
            - TODO: jenkinsfile w repo
        - pipeline: create-tester-template
            - do not allow concurrent builds
            - TODO: jenkinsfile w repo

- credentials
    - username with password: username/password to vCenter
        - vCenter: add jenkins user to vsphere.local
    - secret text: ansible vaul secret
    - ssh private key with password: for jenkins user

- thinbackup
    - dir: /jenkins_bck
    - sched full backup: `H 0 * * 7`
    - sched diff backup: `H 0 * * 1-5`
    - max backup sets: `30`
    - things to backup
        - build results
        - userContent folder
        - next build number file
        - plugins archives
        - clean up diff backups
        - move old backups to zips
