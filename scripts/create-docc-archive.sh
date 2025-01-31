#!/bin/bash

readonly XCODE=$(xcodebuild -version | grep Xcode | cut -d " " -f2)

readonly TOP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
readonly BUILD_DIR="${TOP_DIR}/.build"
readonly DOCUMENTATION_DIR="${BUILD_DIR}/docs"
readonly XCCONFIG_DIR="${TOP_DIR}/FrameworkXCConfigs/"

readonly PROJECT_NAME="SwiftUploadSDKExample"
readonly PROJECT_PATH="${TOP_DIR}/Example/SwiftUploadSDKExample/${PROJECT_NAME}.xcodeproj"
readonly SCHEME="MuxUploadSDK"
readonly BUILD_CONFIGURATION="Release"
readonly BASE_XCCONFIG_FILENAME="Base"
readonly XCCONFIG_FILENAME="Release-Production"

readonly DOCC_ARCHIVE_NAME="${SCHEME}.doccarchive"
readonly DOCC_ARCHIVE_PATH="${BUILD_DIR}/${DOCC_ARCHIVE_NAME}"

echo "YO PROJECT PATH IS ${PROJECT_PATH}"

# Subdirectory of the devdocs S3 bucket where SDK static docs are stored
# in a directory corresponding to the SDKs version. Ex: "${DOCS_ROOT_DIR}/1.0.0"
readonly DOCS_ROOT_DIR="spaces-ios"

if ! command -v xcbeautify &> /dev/null
then
    echo -e "\033[1;31m ERROR: xcbeautify could not be found please install it... \033[0m"
    exit 1
fi

set -eu pipefail

rm -rf ${BUILD_DIR}

echo "▸ Using Xcode Version: ${XCODE}"

echo "▸ Building Documentation Catalog for ${SCHEME} located in ${PROJECT_PATH}"

mkdir -p $DOCUMENTATION_DIR

expanded_xcconfig_path="${XCCONFIG_DIR}/${XCCONFIG_FILENAME}.xcconfig"

# -xcconfig $expanded_xcconfig_path \
xcodebuild docbuild -project $PROJECT_PATH \
                    -scheme $SCHEME \
                    -configuration $BUILD_CONFIGURATION \
                    -destination 'generic/platform=iOS' \
                    -sdk iphoneos \
                    -derivedDataPath "${DOCUMENTATION_DIR}" | xcbeautify \

cd ${BUILD_DIR}

echo "▸ Finished building Documentation Archive"

echo "▸ Searching for ${DOCC_ARCHIVE_NAME} inside ${DOCUMENTATION_DIR}"
docc_built_archive_path=$(find docs -type d -name "${DOCC_ARCHIVE_NAME}")

if [ -z "${docc_built_archive_path}" ]
then
echo -e "\033[1;31m ERROR: Failed to locate Documentation Archive \033[0m"
    exit 1
else
    echo "▸ Located documentation archive at ${docc_built_archive_path}"
    mv ${docc_built_archive_path} ${BUILD_DIR}
    zip -qry "${DOCC_ARCHIVE_NAME}.zip" "${DOCC_ARCHIVE_NAME}"
fi

expanded_base_xcconfig_path="${XCCONFIG_DIR}/${BASE_XCCONFIG_FILENAME}.xcconfig"

# Locates the SDK marketing version and extracts it to a variable
#
# Uses the substitute (s) command to lines containing 'MARKETING_VERSION = ' 
# substring then captures everything on that line after the subscript (\(.*\)) 
# then prints the first such match
sdk_semantic_version="$(sed -n 's/MARKETING_VERSION = \(.*\)/\1/p' $expanded_base_xcconfig_path)"

# When deploying a new version the contents of the latest subdirectory 
# gets replaced with the generated documentation from the new version 
latest_subdirectory_name="latest"

static_documentation_versioned_path="${DOCS_ROOT_DIR}/${sdk_semantic_version}"

source_archive_path=${DOCC_ARCHIVE_PATH}
output_path=$sdk_semantic_version
hosting_base_path=$static_documentation_versioned_path

echo "▸ Processing documentation archive with source archive path: ${source_archive_path} hosting base path: ${hosting_base_path} output path: ${output_path}"

mkdir -p $output_path

$(xcrun --find docc) process-archive transform-for-static-hosting "${source_archive_path}" \
    --output-path "${output_path}" \
    --hosting-base-path "${hosting_base_path}"

# Replace index.html with a redirect to documentation/muxspaces/
sed -e "s/__VERSION__/${sdk_semantic_version}/" "${TOP_DIR}/scripts/index.html.template" > ${output_path}/index.html

mkdir -p $DOCS_ROOT_DIR

mkdir -p $DOCS_ROOT_DIR/$latest_subdirectory_name

# Replace index.html with a redirect to documentation/muxspaces/
sed -e "s/__VERSION__/${latest_subdirectory_name}/" "${TOP_DIR}/scripts/index.html.template" > $DOCS_ROOT_DIR/${latest_subdirectory_name}/index.html

cp -r ./$output_path/. ./$DOCS_ROOT_DIR/$latest_subdirectory_name

mv $output_path $DOCS_ROOT_DIR

zip -qry "${DOCS_ROOT_DIR}.zip" "${DOCS_ROOT_DIR}"

cd ..

exit
