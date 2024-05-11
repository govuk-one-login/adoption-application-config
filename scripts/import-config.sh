#!/usr/bin/env bash
BASE_DIR="$(dirname "${BASH_SOURCE[0]}")"
ROOT_DIR="$BASE_DIR/.."

set -eu

usage() {
  cat << 'EOF'
This script imports existing resources into a stack.

Usage:
    -n      --stack-name        [required] The name of the configuration stack.
    -a      --application       [required] The name of the the application this configuration belongs to.
    -e      --environment       [required] The environment parameter passed to the stack.
    -h      --help              Prints this help message and exits

It is expected that there is an 'import.json' file in the application directory, which is a json list of objects:
{
    "ResourceType":"AWS::SSM::Parameter",
    "LogicalResourceId":"LogicalNameOfResourceInTemplate",
    "ResourceIdentifier": {
      "Name":"/application/path/to-param-name"
    }
}

see https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/resource-import-existing-stack.html#resource-import-existing-stack-cli

Once the changes are successfully imported the 'import.json' file should be removed.
EOF
}

while [[ -n "${1:-}" ]]; do
  case $1 in
    -n | --stack-name)
      shift
      STACK_NAME="${1:0:23}" # Must be less than 23 characters
      ;;
    -a | --application)
      shift
      APPLICATION="$1"
      ;;
    -e | --environment)
      shift
      ENVIRONMENT="$1"
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo -e "Unknown option $1...\n"
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ -z ${STACK_NAME+x} ]] || [[ -z ${APPLICATION+x} ]] || [[ -z ${ENVIRONMENT+x} ]]; then
  echo -e "Missing required parameters.\n"
  usage
  exit 1
fi

echo "Creating changeset for stack '$STACK_NAME'"
output="$(aws cloudformation create-change-set \
            --stack-name "$STACK_NAME" \
            --change-set-name ImportChangeSet \
            --change-set-type IMPORT \
            --resources-to-import "file://${ROOT_DIR}/${APPLICATION}/import.json" \
            --template-body "file://${ROOT_DIR}/${APPLICATION}/config.template.yml" \
            --parameters \
              ParameterKey=Environment,ParameterValue="'dev'" \
           2>&1 \
          && aws cloudformation wait change-set-create-complete \
               --change-set-name ImportChangeSet \
               --stack-name "$STACK_NAME" \
          || echo "Error" )"

if [[ "$output" =~ "ValidationError" ]]; then
  echo "Changeset for stack '$STACK_NAME' failed with output:"
  echo "$output"
  exit 1
fi

if aws cloudformation describe-change-set --change-set-name ImportChangeSet --stack-name "$STACK_NAME" > /dev/null; then
  echo "Executing changeset for stack '$STACK_NAME'"
  aws cloudformation execute-change-set --change-set-name ImportChangeSet --stack-name "$STACK_NAME"
fi
