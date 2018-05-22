# contrail-windows-ci monitoring

# Deployment 

### Dependencies

Requirements:
- Linux
- Python: `>= 3.5.2`
- Install the following packages:

    ```
    $ sudo apt-get install libpython3-dev libmysqlclient-dev
    ```

- Preferably use `virtualenv` and install monitoring PyPi dependencies:

    ```
    $ virtualenv -p /usr/bin/python3 venv
    $ . venv/bin/activate
    (venv) $ pip install -r requirements.txt
    ```

Note: To run tests Windows, use `requirements_windows.txt` instead of `requirements.txt`.

### Provisioning production database

- `provision_mysql_database.py` script deploys schema on provided database

    ```
    $ python3 provision_mysql_database.py \
        --mysql-host MYSQL_HOST \
        --mysql-username MYSQL_USER \
        --mysql-password MYSQL_PASSWORD \
        --mysql-database MYSQL_DATABASE
    ```

# Development

### Running tests

Tests are written using `unittest` module from Python's standard library.

- See Dependencies chapter for requirements
- To run tests, execute the following command:

    ```
    $ python3 -m tests.monitoring_tests
    ```

Note: part of the test suite will fail on Windows. However, it's possible to develop
platform independent parts of the script and run most of the unit tests.

### Grafana dashboards

Grafana dashboards are described in YAML files.
These files are consumed by `grafana-dashboard` tool from [https://docs.openstack.org/infra/grafyaml/](https://docs.openstack.org/infra/grafyaml/).
To update dashboards on the running instance of Grafana:

- Install the dependencies from `requirements.txt`
- Copy `grafyaml.conf.sample` file to `grafyaml.conf`
- Fill `grafyaml.conf` with
    - URL to Grafana
    - Grafana API key (it can be generated in the Grafana's settings)
- Run the following command to validate dashboards' descriptions

    ```bash
    $ grafana-dashboard --debug --config-file grafana/grafyaml.conf validate grafana
    INFO:grafana_dashboards.cmd:Validating schema in grafana
    SUCCESS!
    ```

- Run the following command to update dashboard

    ```bash
    $ grafana-dashboard --debug --config-file grafana/grafyaml.conf update grafana
    INFO:grafana_dashboards.cmd:Updating schema in grafana
    DEBUG:grafana_dashboards.cache:Using cache: /home/user/.cache/grafyaml/cache.dbm
    INFO:grafana_dashboards.builder:Number of datasources to be updated: 0
    INFO:grafana_dashboards.builder:Number of dashboards to be updated: 1
    DEBUG:grafana_dashboards.parser:Dashboard build-statistics-v2: 32f4f558f2c8a404f4c4ed99d61ac6b9
    DEBUG:urllib3.connectionpool:Starting new HTTP connection (1): grafana.example.com
    DEBUG:urllib3.connectionpool:http://grafana.example.com:3000 "POST /api/dashboards/db/ HTTP/1.1" 200 129
    DEBUG:urllib3.connectionpool:http://grafana.example.com:3000 "GET /api/dashboards/db/build-statistics-v2 HTTP/1.1" 200 None
    ```
