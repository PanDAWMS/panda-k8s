# Mariadb
## Deployment framework for mariadb. 

## Bare minimum installation

This installation flavour provides the minimum resources required to run `mariadb-operator` in your cluster.

```bash
helm repo add mariadb-operator https://mariadb-operator.github.io/mariadb-operator
helm install -n iam-db mariadb-operator mariadb-operator/mariadb-operator

# when mariadb-operator fails to be delete, run these commands
kubectl delete clusterrole mariadb-manager-role
kubectl delete ClusterRoleBinding mariadb-manager-rolebinding
kubectl delete ValidatingWebhookConfiguration mariadb-operator-webhook
```


## install the mariadb

```bash
helm install --dry-run -n mariadb harvester-db-test helm/mariadb/harvester-db/ -f helm/mariadb/harvester-db/values.yaml  -f helm/mariadb/harvester-db/values/values-lsst.yaml
```
