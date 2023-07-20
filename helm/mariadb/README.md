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

```bash
helm install -n mariadb harvester-db-dev-0 helm/mariadb/harvester-db/ -f helm/mariadb/harvester-db/values.yaml  -f helm/mariadb/harvester-db/values/values-lsst.yaml
```
