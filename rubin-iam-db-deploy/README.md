# rubin-iam-db
## Deployment framework for Rubin USDF IAM. 

## Bare minimum installation

This installation flavour provides the minimum resources required to run `mariadb-operator` in your cluster.

```bash
helm repo add mariadb-operator https://mariadb-operator.github.io/mariadb-operator
helm install -n panda-db mariadb-operator mariadb-operator/mariadb-operator
```

## install the mariadb

```bash
make apply
```
