# Mariadb
## Deployment framework for mariadb. 

## Bare minimum installation

This installation flavour provides the minimum resources required to run `mariadb-operator` in your cluster.

```bash
helm repo add mariadb-operator https://mariadb-operator.github.io/mariadb-operator
helm install -n mariadb mariadb-operator mariadb-operator/mariadb-operator

```


## install the iam-db

```bash
helm install -n mariadb iam-db-dev helm/mariadb/iam-db/ -f helm/mariadb/iam-db/values.yaml  -f helm/mariadb/iam-db/values/values-lsst.yaml
```

## install the harvester-db

This mariadb operator doesn't allow same database name even with different stateful services. To avoid the same database name, the deployment below will create different database name for different deployment, where the database name is the same as the deployment name.

```bash
helm install -n mariadb harvester-db-dev-0 helm/mariadb/harvester-db/ -f helm/mariadb/harvester-db/values.yaml  -f helm/mariadb/harvester-db/values/values-lsst.yaml
helm install  -n mariadb harvester-db-dev-1 helm/mariadb/harvester-db/ -f helm/mariadb/harvester-db/values.yaml  -f helm/mariadb/harvester-db/values/values-lsst.yaml
```

Below is an example of the database name
```bash
mysql -h harvester-db-dev-2.mariadb.svc.cluster.local -u harvester -p<password>
MariaDB [(none)]> show databases;
+--------------------+
| Database           |
+--------------------+
| harvester-db-dev-2 |
| information_schema |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
5 rows in set (0.01 sec)

```

