# contrail-windows-ci monitoring

### Dependencies

- Required Python: `>= 3.5.2`
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

### Provisioning database

- `provision.py` script deploys schema on provided database

    ```
    $ python3 provision.py --mysql-host MYSQL_HOST \
        --mysql-username MYSQL_USER \
        --mysql-password MYSQL_PASSWORD \
        --mysql-database MYSQL_DATABASE
    ```

### Running tests

- Tests are written using `unittest` module from Python's standard library.
  To run tests, just execute the following command:

    ```
    $ python3 test_stats.py
    ```
