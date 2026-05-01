#!/bin/bash
# =============================================================
# WSO2 APIM Mock Data Generator — Run All
# Runs all data generation scripts in the correct order.
# =============================================================

set -e  # Exit immediately on any error

SCRIPTS=(
  "api_creator.sh"
  "api_publisher.sh"
  "devportal_app_creator.sh"
  "app_keys_gen.sh"
  "subscribe_APIs.sh"
)

# ---- Preflight checks ----------------------------------------

if [ ! -f "config.env" ]; then
  echo ""
  echo "  ERROR: config.env not found."
  echo "  Copy the template and fill in your settings:"
  echo "    cp config.env.template config.env"
  echo ""
  exit 1
fi

for script in "${SCRIPTS[@]}"; do
  if [ ! -f "$script" ]; then
    echo "ERROR: Required script not found: $script"
    exit 1
  fi
  chmod +x "$script"
done

if ! command -v jq &> /dev/null; then
  echo "ERROR: 'jq' is not installed. Install it first:"
  echo "  macOS:  brew install jq"
  echo "  Linux:  sudo apt-get install jq"
  exit 1
fi

# ---- Source config for the readiness check -------------------

source config.env

echo ""
echo "=================================================="
echo " WSO2 APIM Mock Data Generator"
echo " Host: https://$HOST:$SERVLET_PORT"
echo " Apps to create: $NUM_APPS"
echo "=================================================="
echo ""

# ---- Verify APIM is reachable --------------------------------

echo "Checking APIM connectivity..."
if ! curl -s -k --max-time 10 "https://$HOST:$SERVLET_PORT/services/Version" > /dev/null; then
  echo ""
  echo "  ERROR: Cannot reach WSO2 APIM at https://$HOST:$SERVLET_PORT"
  echo "  Make sure APIM is running and the HOST/SERVLET_PORT in config.env are correct."
  echo ""
  exit 1
fi
echo "APIM is reachable."
echo ""

# ---- Run scripts in order ------------------------------------

TOTAL=${#SCRIPTS[@]}
STEP=0

for script in "${SCRIPTS[@]}"; do
  STEP=$((STEP + 1))
  echo "--------------------------------------------------"
  echo "  Step $STEP/$TOTAL: $script"
  echo "--------------------------------------------------"
  ./"$script"
  echo ""
  echo "  Step $STEP/$TOTAL complete."
  echo ""
done

# ---- Done ----------------------------------------------------

echo "=================================================="
echo " All steps completed successfully!"
echo ""
echo " You can now:"
echo "   - Browse APIs:   https://$HOST:$SERVLET_PORT/publisher"
echo "   - Browse Apps:   https://$HOST:$SERVLET_PORT/devportal"
echo "=================================================="
