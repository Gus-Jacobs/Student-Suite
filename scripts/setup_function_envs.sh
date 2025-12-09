#!/usr/bin/env bash
# setup_function_envs.sh
# Usage: Edit the VARIABLES section below, then run in Bash (Linux, macOS, WSL, or Git Bash):
#   bash ./scripts/setup_function_envs.sh
# This script will create or update Secret Manager secrets for sensitive values
# and deploy the gen2 Cloud Function `createStripeCheckout` with secret bindings
# and non-secret environment variables. It prints clear success/failure messages.

set -euo pipefail
IFS=$'\n\t'

# -----------------------------
# EDIT THESE VALUES BEFORE RUN
# -----------------------------
PROJECT="student-suite-9ae1d"
REGION="us-central1"            # Function region
FUNCTION_NAME="createStripeCheckout"

# Secret names to create in Secret Manager (you can change these names)
SECRET_STRIPE_KEY="stripe-secret"
SECRET_STRIPE_WEBHOOK="stripe-webhook-secret"
SECRET_GMAIL_EMAIL="gmail-email"
SECRET_GMAIL_PASSWORD="gmail-password"
SECRET_APPLE_PRIVATE_KEY="apple-iap-private-key"
SECRET_APPLE_SHARED_SECRET="apple-shared-secret"
SECRET_OPENAI_API_KEY="openai-api-key"
SECRET_GEMINI_API_KEY="gemini-api-key"

# Non-secret environment variables (set to empty string if not used)
# For Apple IAP IDs (these are safe as env vars, not secrets)
APPLE_IAP_KEY_ID=""        # e.g. ABCDEFG123
APPLE_IAP_ISSUER_ID=""     # e.g. 12345678-ABCD-...-EF

# For multi-line Apple private key: either set APPLE_PRIVATE_KEY_FILE to a .p8 file path
# or set APPLE_PRIVATE_KEY_HEREDOC to a literal pasted block (not recommended on CI).
APPLE_PRIVATE_KEY_FILE=""   # e.g. /home/user/keys/AuthKey_ABC123.p8
APPLE_PRIVATE_KEY_HEREDOC="" # If non-empty, will be written to a temp file and used

# Other optional env vars
ENABLE_IAP_DEBUG_LOGS="true"
RESTART_TRIGGER="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# -----------------------------
# END EDIT SECTION
# -----------------------------

GCLOUD="gcloud --project=${PROJECT}"

function echo_step() { echo; echo "========== $1 =========="; }

# Helper: ensure secret exists (create if missing)
function ensure_secret() {
  local name="$1"
  if ${GCLOUD} secrets describe "${name}" >/dev/null 2>&1; then
    echo "Secret ${name} already exists.";
  else
    echo "Creating secret ${name}..."
    ${GCLOUD} secrets create "${name}" --replication-policy="automatic"
    echo "Created secret ${name}."
  fi
}

# Helper: add secret version from file or stdin
function add_secret_version_from_file() {
  local name="$1"; local file="$2"
  if [ -z "$file" ] || [ "$file" = "-" ]; then
    echo "Adding secret version for ${name} from stdin..."
    ${GCLOUD} secrets versions add "${name}" --data-file=-
  else
    echo "Adding secret version for ${name} from file ${file}..."
    ${GCLOUD} secrets versions add "${name}" --data-file="${file}"
  fi
}

# Main flow
echo_step "Starting secret & env setup for ${FUNCTION_NAME} in project ${PROJECT} (${REGION})"

# 1) Ensure Secret Manager secrets exist
ensure_secret "${SECRET_STRIPE_KEY}"
ensure_secret "${SECRET_STRIPE_WEBHOOK}"
ensure_secret "${SECRET_GMAIL_EMAIL}"
ensure_secret "${SECRET_GMAIL_PASSWORD}"
ensure_secret "${SECRET_APPLE_PRIVATE_KEY}"
ensure_secret "${SECRET_APPLE_SHARED_SECRET}"
ensure_secret "${SECRET_OPENAI_API_KEY}"
ensure_secret "${SECRET_GEMINI_API_KEY}"

# 2) Add secret versions. The script expects you to supply values now.
# You can either pipe values into this script or edit and run interactively.

echo_step "Adding secret versions - follow prompts"

# Stripe secret
read -r -p "Enter Stripe secret key (leave blank to skip adding a version now): " stripe_val
if [ -n "$stripe_val" ]; then
  echo "$stripe_val" | ${GCLOUD} secrets versions add "${SECRET_STRIPE_KEY}" --data-file=-
  echo "Added version to ${SECRET_STRIPE_KEY}";
else
  echo "Skipped adding stripe secret version.";
fi

# Stripe webhook secret
read -r -p "Enter Stripe webhook secret (leave blank to skip): " stripe_webhook_val
if [ -n "$stripe_webhook_val" ]; then
  echo "$stripe_webhook_val" | ${GCLOUD} secrets versions add "${SECRET_STRIPE_WEBHOOK}" --data-file=-
  echo "Added version to ${SECRET_STRIPE_WEBHOOK}";
else
  echo "Skipped adding stripe webhook secret version.";
fi

# Gmail creds
read -r -p "Enter GMAIL_EMAIL (leave blank to skip): " gmail_email_val
if [ -n "$gmail_email_val" ]; then
  echo "$gmail_email_val" | ${GCLOUD} secrets versions add "${SECRET_GMAIL_EMAIL}" --data-file=-
  echo "Added version to ${SECRET_GMAIL_EMAIL}";
else
  echo "Skipped adding gmail email secret version.";
fi

read -r -s -p "Enter GMAIL_PASSWORD (input hidden, leave blank to skip): " gmail_pass_val
echo
if [ -n "$gmail_pass_val" ]; then
  echo "$gmail_pass_val" | ${GCLOUD} secrets versions add "${SECRET_GMAIL_PASSWORD}" --data-file=-
  echo "Added version to ${SECRET_GMAIL_PASSWORD}";
else
  echo "Skipped adding gmail password secret version.";
fi

# Apple shared secret (app store shared secret)
read -r -p "Enter APPLE_SHARED_SECRET (leave blank to skip): " apple_shared_val
if [ -n "$apple_shared_val" ]; then
  echo "$apple_shared_val" | ${GCLOUD} secrets versions add "${SECRET_APPLE_SHARED_SECRET}" --data-file=-
  echo "Added version to ${SECRET_APPLE_SHARED_SECRET}";
else
  echo "Skipped adding apple shared secret version.";
fi

# Apple private key (multi-line). Prefer pointing to an existing .p8 file.
if [ -n "${APPLE_PRIVATE_KEY_FILE}" ]; then
  if [ -f "${APPLE_PRIVATE_KEY_FILE}" ]; then
    ${GCLOUD} secrets versions add "${SECRET_APPLE_PRIVATE_KEY}" --data-file="${APPLE_PRIVATE_KEY_FILE}"
    echo "Added Apple private key from file ${APPLE_PRIVATE_KEY_FILE} to secret ${SECRET_APPLE_PRIVATE_KEY}";
  else
    echo "APPLE_PRIVATE_KEY_FILE is set but file not found: ${APPLE_PRIVATE_KEY_FILE}. Skipping.";
  fi
elif [ -n "${APPLE_PRIVATE_KEY_HEREDOC}" ]; then
  tmpfile=$(mktemp)
  cat > "$tmpfile" <<'EOF'
${APPLE_PRIVATE_KEY_HEREDOC}
EOF
  ${GCLOUD} secrets versions add "${SECRET_APPLE_PRIVATE_KEY}" --data-file="$tmpfile"
  rm -f "$tmpfile"
  echo "Added Apple private key from heredoc to secret ${SECRET_APPLE_PRIVATE_KEY}";
else
  echo "No APPLE_PRIVATE_KEY_FILE or HEREDOC provided. You can add a version interactively now.";
  read -r -p "Add Apple private key now from a local file? Enter path or leave blank to skip: " apple_key_path
  if [ -n "$apple_key_path" ] && [ -f "$apple_key_path" ]; then
    ${GCLOUD} secrets versions add "${SECRET_APPLE_PRIVATE_KEY}" --data-file="$apple_key_path"
    echo "Added Apple private key from $apple_key_path";
  else
    echo "Skipped Apple private key addition.";
  fi
fi

# OpenAI / Gemini API keys
read -r -p "Enter OPENAI_API_KEY (leave blank to skip): " openai_val
if [ -n "$openai_val" ]; then
  echo "$openai_val" | ${GCLOUD} secrets versions add "${SECRET_OPENAI_API_KEY}" --data-file=-
  echo "Added version to ${SECRET_OPENAI_API_KEY}";
else
  echo "Skipped adding OPENAI_API_KEY.";
fi

read -r -p "Enter GEMINI_API_KEY (leave blank to skip): " gemini_val
if [ -n "$gemini_val" ]; then
  echo "$gemini_val" | ${GCLOUD} secrets versions add "${SECRET_GEMINI_API_KEY}" --data-file=-
  echo "Added version to ${SECRET_GEMINI_API_KEY}";
else
  echo "Skipped adding GEMINI_API_KEY.";
fi

# 3) Deploy / update the Gen2 Cloud Function with secret bindings
# We will bind secrets via --set-secrets and set non-secret env vars via --set-env-vars

echo_step "Deploying function ${FUNCTION_NAME} with secret bindings (this will create a new revision)"

SECRETS_BINDING=(
  "STRIPE_SECRET_KEY=${SECRET_STRIPE_KEY}:latest"
  "STRIPE_WEBHOOK_SECRET=${SECRET_STRIPE_WEBHOOK}:latest"
  "GMAIL_EMAIL=${SECRET_GMAIL_EMAIL}:latest"
  "GMAIL_PASSWORD=${SECRET_GMAIL_PASSWORD}:latest"
  "APPLE_IAP_PRIVATE_KEY=${SECRET_APPLE_PRIVATE_KEY}:latest"
  "APPLE_SHARED_SECRET=${SECRET_APPLE_SHARED_SECRET}:latest"
  "OPENAI_API_KEY=${SECRET_OPENAI_API_KEY}:latest"
  "GEMINI_API_KEY=${SECRET_GEMINI_API_KEY}:latest"
)

SECRETS_CLI=""
for s in "${SECRETS_BINDING[@]}"; do
  if [ -z "$SECRETS_CLI" ]; then
    SECRETS_CLI="--set-secrets=${s}"
  else
    SECRETS_CLI+=" --set-secrets=${s}"
  fi
done

ENV_VARS=(
  "APPLE_IAP_KEY_ID=${APPLE_IAP_KEY_ID}"
  "APPLE_IAP_ISSUER_ID=${APPLE_IAP_ISSUER_ID}"
  "ENABLE_IAP_DEBUG_LOGS=${ENABLE_IAP_DEBUG_LOGS}"
  "RESTART_TRIGGER=${RESTART_TRIGGER}"
)
ENV_CLI=$(IFS=,; echo "${ENV_VARS[*]}")

# Build the deploy command
DEPLOY_CMD=( gcloud functions deploy "${FUNCTION_NAME}" --gen2 --region="${REGION}" --runtime=nodejs20 --source="functions" --entry-point="createStripeCheckout" --trigger-topic="projects/${PROJECT}/topics/eventarc-nam5-createstripecheckout-058382-063" )

# Append secrets (note: we assembled SECRETS_CLI string)
# We cannot safely expand SECRETS_CLI in array; use eval to run the full command string

FULL_CMD_STR="${DEPLOY_CMD[*]} ${SECRETS_CLI} --set-env-vars=${ENV_CLI} --project=${PROJECT} --quiet"

echo "About to run deploy command for function. This may take a few minutes."
echo "Command: ${FULL_CMD_STR}"

# Confirm with user
read -r -p "Proceed with deploy? (y/N): " proceed
if [ "${proceed,,}" != "y" ]; then
  echo "Aborting deployment. You can run the command manually when ready.";
  exit 0
fi

# Run the command
set +e
eval ${FULL_CMD_STR}
RET=$?
set -e
if [ ${RET} -ne 0 ]; then
  echo "ERROR: Function deploy failed with exit code ${RET}. Check output above.";
  exit ${RET}
fi

echo_step "Deployment finished. Verifying function state..."

${GCLOUD} functions describe "${FUNCTION_NAME}" --region=${REGION} --format="yaml" | sed -n '1,200p'

echo_step "All done. Next steps:"
echo " - Wait a minute then trigger a checkout from the client and tail logs:"
echo "     gcloud functions logs read ${FUNCTION_NAME} --region=${REGION} --project=${PROJECT} --limit=200"
echo " - Check your Firestore checkout_sessions doc for a 'url' field after triggering the flow."

echo "Success: secrets created/updated and function deployed (or updated)." 

exit 0
