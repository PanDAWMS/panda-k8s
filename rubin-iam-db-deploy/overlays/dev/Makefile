get-secrets:
	mkdir -p mariadb/etc/.secrets
	vault kv get --field=iamdb-root-password secret/rubin/usdf-panda-dev/usdf-panda-iam-db  > mariadb/etc/.secrets/iamdb-root-password
	vault kv get --field=iamdb-iam-username secret/rubin/usdf-panda-dev/usdf-panda-iam-db  > mariadb/etc/.secrets/iamdb-iam-username
	vault kv get --field=iamdb-iam-password secret/rubin/usdf-panda-dev/usdf-panda-iam-db  > mariadb/etc/.secrets/iamdb-iam-password

clean-secrets:
	rm -rf iam/etc/.secrets mariadb/etc/.secrets

run-dump: 
	kubectl kustomize .

dump: get-secrets run-dump clean-secrets

run-apply:  
	kubectl apply -k .

apply: get-secrets run-apply clean-secrets

# run-destroy:
# 	kubectl delete -k .

# destroy: get-secrets run-destroy clean-secrets


