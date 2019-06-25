#!/bin/bash

## This script is meant to deploy an AWS route53 healthcheck based on a JSON syntax configuration. It also takes care of updating the healthcheck with a Name tag for easy organization of tenants. Finally, it will create a CloudWatch alarm to adhere to a notification policy when the healtcheck fails. 

# I wrote this script in a hurry, it's sloppy and there are things that can be done better, but this is how i got it done. 
# this script assumes you're either authenticated with the aws cli already, or you're running this from a machine with the proper iam roles. 

# pass the FQDN as an argument to the script
URL=$1

# this updates the value 'test' to whatever we want our URL to be in the healthcheck configuration
echo "Updating health-check.json FQDN..."
sed -i "s/test/$URL/g" health-check.json

echo "Creating route53 healthcheck...."
aws route53 create-health-check --caller-reference $URL --health-check-config file://health-check.json
sleep 5

# when the healthcheck gets created in the previous step, it's not assigned a Name tag by default, this will go back and update it (think the Name column in Route53 UI HealthChecks UI) 
echo "Updating Name tag for healthcheck...."
echo "Resource ID is $(aws route53 list-health-checks | grep -B6 $URL | grep -i id | cut -d \" -f4)"
aws route53 change-tags-for-resource --resource-type healthcheck --resource-id "$(aws route53 list-health-checks | grep -B6 $URL | grep -i id | cut -d \" -f4)" --add-tags Key=Name,Value="$URL"

# This step will create a CloudWatch alarm based on the Route53 healthcheck that was just created. 
## this step assumes you have an ARN, you'll need to substitute your ARN in this command. to get your ARN ID, go to the AWS console -> SNS -> Topics
## you'll also need to update your preferred region, unless already specified in your local awscli configuration
echo "Create cloudwatch alarm based off of heatlcheck..." 
aws cloudwatch put-metric-alarm --alarm-name "$URL" --alarm-actions "arn:<<YOUR ARN GOES HERE>>" --metric-name "HealthCheckStatus" --namespace "AWS/Route53" --statistic "Minimum" --dimensions Name=HealthCheckId,Value="$(aws route53 list-health-checks | grep -B6 $URL | grep -i id | cut -d \" -f4)" --period 60 --evaluation-periods 1 --threshold 1 --comparison-operator LessThanThreshold --region <<YOUR REGION HERE>>

# Change FQDN in health-check.json back to 'test' for easy substituion later
echo "Changing FQDN back to test in health-check.json" 
sed -i "s/$URL/test/g" health-check.json
