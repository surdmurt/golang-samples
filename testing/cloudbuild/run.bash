#!/bin/bash

set -e

mv key.json /tmp/key.json
export GOOGLE_APPLICATION_CREDENTIALS=/tmp/key.json
export GOLANG_SAMPLES_KMS_KEYRING=ring1
export GOLANG_SAMPLES_KMS_CRYPTOKEY=key1

curl https://storage.googleapis.com/gimme-proj/linux_amd64/gimmeproj > /bin/gimmeproj && chmod +x /bin/gimmeproj;
gimmeproj version;
export GOLANG_SAMPLES_PROJECT_ID=$(gimmeproj -project golang-samples-tests lease 12m);
if [ -z "$GOLANG_SAMPLES_PROJECT_ID" ]; then
  echo "Lease failed."
  exit 1
fi
echo "Running tests in project $GOLANG_SAMPLES_PROJECT_ID";
trap "gimmeproj -project golang-samples-tests done $GOLANG_SAMPLES_PROJECT_ID" EXIT

set -x

date

if [[ -d /cache ]]; then
  time mv /cache/* .
  echo 'Uncached'
fi

# Re-organize files
export GOPATH=$PWD/gopath
oldfiles=$(ls | grep -v '^gopath$')
target=$GOPATH/src/github.com/GoogleCloudPlatform/golang-samples
mkdir -p $target
mv $oldfiles $target
cd $target

# Do the easy stuff first. Fail fast!
diff -u <(echo -n) <(gofmt -d -s .)
go vet ./...

# Check use of Go 1.7 context package
! grep -R '"context"$' * || { echo "Use golang.org/x/net/context"; false; }

# Download imports.
time go get -u -v $(go list -f '{{join .Imports "\n"}}{{"\n"}}{{join .TestImports "\n"}}' ./... | sort | uniq | grep -v golang-samples)

date

# Run all of the tests
go test -v ./...
