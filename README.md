# mongodb-backup-s3-kubernetes

    apiVersion: v1
    kind: Secret
    metadata:
      name: mongo-backup-secrets
      labels:
        app: mongo-backup
    data:
      aws-access-id: QUtJQVVKQ1dZQ1dfghbjnE9DMlZZNlk=
      aws-secret-key: S3lzNVVkTjZpMTRoVdrftvgVGM2lGRUl5SFJYVDJiQmwxZw==
      mongo-database-user: bWFpbl9hZG1pbg==
      mongo-database-password: YWJjMTIz

    # Encode base 64
    # echo -n wordpress123|base64
    # Decode base 64
    # echo -n d29yZHByZXNzMTIz |base64 -d

# Configure a Cronjob in Kubernetes
    apiVersion: batch/v1beta1
    kind: CronJob
    metadata:
      name: mongo-database-backup
    #  namespace: dev
    spec:
      schedule: "*/2 * * * *"
      jobTemplate:
        spec:
          template:
            spec:
              containers:
              - name: mongo-database-backup
                image: yphani/mongodb-backup-s3
                imagePullPolicy: Always
                env:
                  - name: AWS_ACCESS_KEY_ID
                    valueFrom:
                       secretKeyRef:
                         name: mongo-backup-secrets
                         key: aws-access-id
                  - name: AWS_SECRET_ACCESS_KEY
                    valueFrom:
                      secretKeyRef:
                        name: mongo-backup-secrets
                        key: aws-secret-key
                  - name: BUCKET_REGION
                    value: "eu-central-1"
                  - name: BUCKET
                    value: "mongo-backup-phani"
                  - name: BACKUP_FOLDER
                    value: "backup/"
                  - name: MONGODB_HOST
                    value: "mongodb-service"
                  - name: MONGODB_PORT
                    value: "27017"
                  - name: MONGODB_DB
                    value: "test"
                  - name: INIT_BACKUP
                    value: "true"
                  - name: EXTRA_OPTS
                    value: '--authenticationDatabase "admin"'
                  - name: MONGODB_USER
                    valueFrom:
                      secretKeyRef:
                        name: mongo-backup-secrets
                        key: mongo-database-user
                  - name: MONGODB_PASS
                    valueFrom:
                      secretKeyRef:
                        name: mongo-backup-secrets
                        key: mongo-database-password
              restartPolicy: Never

## Usage in Docker:

```
docker run -d \
  --env AWS_ACCESS_KEY_ID=awsaccesskeyid \
  --env AWS_SECRET_ACCESS_KEY=awssecretaccesskey \
  --env BUCKET=mybucketname
  --env MONGODB_HOST=mongodb.host \
  --env MONGODB_PORT=27017 \
  --env MONGODB_USER=admin \
  --env MONGODB_PASS=password \
  deenoize/mongodb-backup-s3
```

If you link `deenoize/mongodb-backup-s3` to a mongodb container with an alias named mongodb, this image will try to auto load the `host`, `port`, `user`, `pass` if possible. Like this:

```
docker run -d \
  --env AWS_ACCESS_KEY_ID=myaccesskeyid \
  --env AWS_SECRET_ACCESS_KEY=mysecretaccesskey \
  --env BUCKET=mybucketname \
  --env BACKUP_FOLDER=a/sub/folder/path/ \
  --env INIT_BACKUP=true \
  --link my_mongo_db:mongodb \
  deenoize/mongodb-backup-s3
```

If your bucket in not standard region and you get `A client error (PermanentRedirect) occurred when calling the PutObject operation: The bucket you are attempting to access must be addressed using the specified endpoint. Please send all future requests to this endpoint` use BUCKET_REGION env var like this:

```
docker run -d \
  --env AWS_ACCESS_KEY_ID=myaccesskeyid \
  --env AWS_SECRET_ACCESS_KEY=mysecretaccesskey \
  --env BUCKET=mybucketname \
  --env BUCKET_REGION=mybucketregion \
  --env BACKUP_FOLDER=a/sub/folder/path/ \
  --env INIT_BACKUP=true \
  --link my_mongo_db:mongodb \
  deenoize/mongodb-backup-s3
```

Add to a docker-compose.yml to enhance your robotic army:

For automated backups
```
mongodbbackup:
  image: 'deenoize/mongodb-backup-s3:latest'
  links:
    - mongodb
  environment:
    - AWS_ACCESS_KEY_ID=myaccesskeyid
    - AWS_SECRET_ACCESS_KEY=mysecretaccesskey
    - BUCKET=my-s3-bucket
    - BACKUP_FOLDER=prod/db/
  restart: always
```

Or use `INIT_RESTORE` with `DISABLE_CRON` for seeding/restoring/starting a db (great for a fresh instance or a dev machine)
```
mongodbbackup:
  image: 'deenoize/mongodb-backup-s3:latest'
  links:
    - mongodb
  environment:
    - AWS_ACCESS_KEY_ID=myaccesskeyid
    - AWS_SECRET_ACCESS_KEY=mysecretaccesskey
    - BUCKET=my-s3-bucket
    - BACKUP_FOLDER=prod/db/
    - INIT_RESTORE=true
    - DISABLE_CRON=true
```

## Parameters

`AWS_ACCESS_KEY_ID` - your aws access key id (for your s3 bucket)

`AWS_SECRET_ACCESS_KEY`: - your aws secret access key (for your s3 bucket)

`BUCKET`: - your s3 bucket

`BUCKET_REGION`: - your s3 bucket' region (eg `us-east-2` for Ohio). Optional. Add if you get an error `A client error (PermanentRedirect)`

`BACKUP_FOLDER`: - name of folder or path to put backups (eg `myapp/db_backups/`). defaults to root of bucket.

`MONGODB_HOST` - the host/ip of your mongodb database

`MONGODB_PORT` - the port number of your mongodb database

`MONGODB_USER` - the username of your mongodb database. If MONGODB_USER is empty while MONGODB_PASS is not, the image will use admin as the default username

`MONGODB_PASS` - the password of your mongodb database

`MONGODB_DB` - the database name to dump. If not specified, it will dump all the databases

`EXTRA_OPTS` - any extra options to pass to mongodump command

`CRON_TIME` - the interval of cron job to run mongodump. `0 3 * * *` by default, which is every day at 03:00hrs.

`TZ` - timezone. default: `US/Eastern`

`CRON_TZ` - cron timezone. default: `US/Eastern`

`INIT_BACKUP` - if set, create a backup when the container launched

`INIT_RESTORE` - if set, restore from latest when container is launched

`DISABLE_CRON` - if set, it will skip setting up automated backups. good for when you want to use this container to seed a dev environment.

## Restore from a backup

To see the list of backups, you can run:
```
docker exec mongodb-backup-s3 /listbackups.sh
```

To restore database from a certain backup, simply run (pass in just the timestamp part of the filename):

```
docker exec mongodb-backup-s3 /restore.sh 20170406T155812
```

To restore latest just:
```
docker exec mongodb-backup-s3 /restore.sh
```

## Acknowledgements

  * forked from [halvves/mongodb-backup-s3](https://github.com/halvves/mongodb-backup-s3) fork of [futurist](https://github.com/futurist)'s fork of [tutumcloud/mongodb-backup](https://github.com/tutumcloud/mongodb-backup)
