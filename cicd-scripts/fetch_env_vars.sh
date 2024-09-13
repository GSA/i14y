#!/bin/bash
set -x
# Move to a writable location
cd /home/search/cicd_temp 

# Leave PARAM_PATH empty to fetch all parameters in the region
PARAM_PATH=""

# Clear the .env file if it exists
> .env

echo "Starting the script"
# Fetch all parameter names in the region
echo $AWS_REGION
if [ -n "$PARAM_PATH" ]; then
    PARAM_KEYS=$(aws ssm get-parameters-by-path --path "$PARAM_PATH"  --recursive --query "Parameters[*].Name" --output text --region us-east-2)
else
    PARAM_KEYS=$(aws ssm describe-parameters  --query "Parameters[*].Name" --output text --region us-east-2)
fi
echo "Fetched parameter keys: $PARAM_KEYS"

# Loop through each parameter key
for PARAM in $PARAM_KEYS; do
    # Exclude parameters that start with "DEPLOY_" or match "*_EC2_PEM_KEY" or match LOGIN_DOT_GOV_PEM
    if [[ $PARAM != DEPLOY_* && ! $PARAM =~ .*_EC2_PEM_KEY$ && $PARAM != "LOGIN_DOT_GOV_PEM" ]]; then
        # Fetch the parameter value from SSM
        VALUE=$(aws ssm get-parameter --name "$PARAM" --with-decryption --query "Parameter.Value" --output text --region us-east-2)
        
        # Rename parameters that start with "SEARCH_AWS_" to "AWS_"
        if [[ $PARAM == SEARCH_AWS_* ]]; then
            PARAM=${PARAM/SEARCH_AWS_/AWS_}
        fi

        # Write the key=value pair to the .env file
        echo "$PARAM=$VALUE" >> .env
    fi
done

# Output the result
# echo ".env file created with the following content:"
# cat .env
cp /home/search/cicd_temp/.env /home/search/i14y/shared/


# create puma folders and files

# Create  directories if they do not already exist
[ ! -d /home/search/i14y/shared/tmp/pids/ ] && mkdir -p /home/search/i14y/shared/tmp/pids/
[ ! -d /home/search/i14y/shared/log ] && mkdir -p /home/search/i14y/shared/log

# Create log files if they do not already exist
[ ! -f /home/search/i14y/shared/log/puma_access.log ] && touch /home/search/i14y/shared/log/puma_access.log
[ ! -f /home/search/i14y/shared/log/puma_error.log ] && touch /home/search/i14y/shared/log/puma_error.log


sudo chown -R search:search /home/search/i14y/
sudo chmod -R 777 /home/search/i14y/

find /home/search/i14y/ -type d -exec chmod 2777 {} \;

umask 000

sudo rm -rf /home/search/cicd_temp/*
