# Mariadb
## Deployment framework for mariadb. 

## Bare minimum installation

This installation flavour provides the minimum resources required to run `mariadb-operator` in your cluster.

```bash
helm repo add mariadb-operator https://mariadb-operator.github.io/mariadb-operator
helm install -n mariadb mariadb-operator mariadb-operator/mariadb-operator

# when mariadb-operator fails to be delete, run these commands
kubectl delete clusterrole mariadb-manager-role
kubectl delete ClusterRoleBinding mariadb-manager-rolebinding
kubectl delete ValidatingWebhookConfiguration mariadb-operator-webhook
```


## install the mariadb

```bash
helm install --dry-run -n mariadb iam-db-test helm/iam-db/ -f helm/iam-db/values.yaml  -f helm/iam-db/values/values-lsst.yaml
```
