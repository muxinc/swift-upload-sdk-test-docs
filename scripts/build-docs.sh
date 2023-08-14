WORKSPACE_ROOT="${GITHUB_WORKSPACE:=docs-output}"
DOCS_OUTPUT_PATH="${PROJECT_DOCS_ROOT:=docs}"

dir_name=${PWD##*/}          # to assign to a variable
dir_name=${dir_name:-/}        # to correct for the case where PWD=/

OUTPUT_ROOT="${REPO_NAME:=$dir_name}"

FINAL_OUTPUT_DIR=$WORKSPACE_ROOT/$OUTPUT_ROOT
echo $FINAL_OUTPUT_DIR

printf '%s\n' "${PWD##*/}" # to print to stdout
                           # ...more robust than echo for unusual names
                           #    (consider a directory named -e or -n)

mkdir docs
xcodebuild docbuild -scheme MuxUploadSDK \
    -destination 'generic/platform=iOS' \
    -sdk iphoneos \
    OTHER_DOCC_FLAGS="--transform-for-static-hosting --hosting-base-path swift-upload-sdk --output-path docs"

echo "STARTING COPY"
mkdir -p $FINAL_OUTPUT_DIR
cp -r $DOCS_OUTPUT_PATH $FINAL_OUTPUT_DIR
echo "FINISHED COPY"
ls -al $FINAL_OUTPUT_DIR