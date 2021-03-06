#! /bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0


## set access keys, profile etc. -

# export AWS_ACCESS_KEY_ID=
# export AWS_SECRET_ACCESS_KEY=
# export AWS_SESSION_TOKEN=
# export AWS_REGION=

# instructions
# run make agreement to generate the configuration file at build/<publisher>.env
# this script load the environment

##

echo caller identity is $(aws sts get-caller-identity --query Arn)

source ./common.env
source ./publisher.env

echo running on behalf of $NAME

echo generating a 1MB file
dd if=/dev/urandom of=/tmp/$FILE_NAME count=1024 bs=1024 2>/dev/null
CHECKSUM=$(openssl dgst -sha256 /tmp/$FILE_NAME | cut -d' ' -f2)
echo checksum is $CHECKSUM

echo copying to s3
aws s3api put-object --bucket $BUCKET_NAME --key $FILE_NAME  --body /tmp/$FILE_NAME  --server-side-encryption aws:kms --ssekms-key-id $KMS_KEY_ID --grant-read id=$SUBSCRIBER_CANONICAL_ACCOUNT_ID

rm -rf /tmp/$FILE_NAME

echo getting list of objects
aws s3api list-objects-v2 --bucket $BUCKET_NAME --fetch-owner

aws events put-rule --name "XAccountEvents" --event-pattern "{\"source\":[\"$EVENT_SOURCE_NAME\"]}"
aws events put-targets --rule "XAccountEvents" --targets "Id"="XAccountEvents","Arn"="arn:aws:events:$AWS_REGION:$MEDIAEXCHANGE_ACCOUNTID:event-bus/default"

echo sending notification

EVENT_DETAIL="{\\\"eventSource\\\": \\\"$EVENT_SOURCE_NAME\\\",\\\"eventName\\\": \\\"AssetsShared\\\",\\\"awsRegion\\\": \\\"$AWS_REGION\\\",\\\"userAgent\\\": \\\"GNU bash, version 3.2.57(1)-release (x86_64-apple-darwin18)\\\",\\\"assets\\\": {\\\"bucket\\\": \\\"$BUCKET_NAME\\\",\\\"keys\\\": {\\\"$CHECKSUM\\\" : \\\"$FILE_NAME\\\"}},\\\"eventID\\\": \\\"1b0c5952-91c6-498d-bf5f-95c250920d8b\\\",\\\"eventType\\\": \\\"ApplicationEvent\\\"}"


aws --region $AWS_REGION events put-events --entries Source=$EVENT_SOURCE_NAME,DetailType="\"source=ApplicationEvent,subscribername=$SUBSCRIBER_NAME\"",Detail="\"$EVENT_DETAIL\""

#
aws events remove-targets --rule "XAccountEvents" --ids "XAccountEvents"
aws events delete-rule --name "XAccountEvents"
