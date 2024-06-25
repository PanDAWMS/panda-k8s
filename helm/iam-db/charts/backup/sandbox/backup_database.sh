#!/bin/bash


filename=${IAM_DB_NAME}_${IAM_DB_HOST}_$(date "+%Y.%m.%d-%H.%M.%S")
destfile=/mnt/special-data/panda_jobs/backup/${filename}
mkdir -p /mnt/special-data/panda_jobs/backup

# dump the db
mysqldump -u ${IAM_DB_USERNAME} -p${IAM_DB_PASSWORD} --databases ${IAM_DB_NAME}  -h ${IAM_DB_HOST} > /tmp/${filename}

cp /tmp/${filename} $destfile
