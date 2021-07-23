# stop-start
This is a script that will stop and start an AWS environment for cost savings. It expects an ECS cluster with an ASG and RDS cluster howevor these can be easily updated to match whatevor infrastructure you have in your own account. This can also easily be put into a pipeline to run from Jenkins, with the environment variables set as parameters of the job instead of being hardcoded in the script.

This script Expects three environment variables to be set
ENVIRONMENT 
  This variable is looking in your tags for a value set to this environment name
ACTION
  This variable must be set to either STOP or START
REGION
  This variable is looking for your aws region for your infrastructure

