#!/bin/bash
set -e

TERRAFORM_DIR="/root/openstack/terraform"

usage() {
    echo "Usage: $0 <number|folder> [plan|apply|destroy]"
    echo ""
    echo "  $0 01           # 01-base terraform apply"
    echo "  $0 01 plan      # 01-base terraform plan"
    echo "  $0 01 destroy   # 01-base terraform destroy"
    echo "  $0 all          # all folders apply"
    echo "  $0 all plan     # all folders plan"
    echo ""
    echo "Folders:"
    ls -d ${TERRAFORM_DIR}/[0-9]*/ 2>/dev/null | xargs -I{} basename {}
    exit 1
}

[ -z "$1" ] && usage

TARGET="$1"
ACTION="${2:-apply}"

run_terraform() {
    local dir="$1"
    local action="$2"
    local name
    name=$(basename "$dir")

    echo "=== [$name] terraform $action ==="
    cd "$dir"

    terraform init -input=false -no-color > /dev/null 2>&1

    case "$action" in
        plan)
            terraform plan -input=false
            ;;
        apply)
            terraform apply -input=false -auto-approve
            ;;
        destroy)
            terraform destroy -input=false -auto-approve
            ;;
        *)
            echo "Unknown action: $action"
            exit 1
            ;;
    esac

    echo "=== [$name] done ==="
    echo ""
}

if [ "$TARGET" = "all" ]; then
    for dir in $(ls -d ${TERRAFORM_DIR}/[0-9]*/ | sort); do
        run_terraform "$dir" "$ACTION"
    done
else
    if [[ "$TARGET" =~ ^[0-9]+$ ]]; then
        MATCHED=$(ls -d ${TERRAFORM_DIR}/${TARGET}-*/ 2>/dev/null | head -1)
    else
        MATCHED=$(ls -d ${TERRAFORM_DIR}/${TARGET}/ 2>/dev/null | head -1)
    fi

    if [ -z "$MATCHED" ]; then
        echo "Folder not found: $TARGET"
        usage
    fi

    run_terraform "$MATCHED" "$ACTION"
fi
