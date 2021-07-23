#!/usr/bin/bash -le

# Define environment variables for script to work
# ENVIRONMENT must be set like so ex: ENVIRONMENT="nonprd-tst"
# ACTION must be set like so ex: ACTION="STOP"
# REGION must be set like so ex: REGION="us-east-1"

# Generate list of instances to stop/start
EC2_INSTANCE_ID_RUNNING=$(aws ec2 describe-instances --filters Name=tag-value,Values="${ENVIRONMENT}" Name=instance-state-name,Values=running --region ${REGION} --query 'Reservations[*].Instances[*].[State.Name, InstanceId]' --output text | cut -f2)
EC2_INSTANCE_ID_STOPPED=$(aws ec2 describe-instances --filters Name=tag-value,Values="${ENVIRONMENT}" Name=instance-state-name,Values=stopped --region ${REGION} --query 'Reservations[*].Instances[*].[State.Name, InstanceId]' --output text | cut -f2)


# Generate list of autoscaling groups to stop/start
ASG_ID_RUNNING=$(aws ec2 describe-instances --filters Name=tag-value,Values="${ENVIRONMENT}" Name=instance-state-name,Values=running --region ${REGION} --query 'Reservations[*].Instances[*].Tags[?Key==`aws:autoscaling:groupName`].Value' --output text | uniq)
ASG_ID_STOPPED=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[? Tags[? (Key=='environment') && Value=='${ENVIRONMENT}']]".AutoScalingGroupName --output text | uniq)

if [ "${ACTION}" = "STOP" ]
then
# Perform stop for environment: Suspend ASG autoscaling, terminate instances, stop rds instance 
echo -e "\033[1mStopping below ASG:\033[0m"
echo -e "\033[1m${ASG_ID_RUNNING}\033[0m"
aws autoscaling suspend-processes \
--auto-scaling-group-name ${ASG_ID_RUNNING} \
--region ${REGION}

echo -e "\033[1mStopping below Instances:\033[0m"
echo -e "\033[1m${EC2_INSTANCE_ID_RUNNING}\033[0m"
aws ec2 terminate-instances \
--instance-ids ${EC2_INSTANCE_ID_RUNNING} \
--region ${REGION}

echo -e "\033[1mStopping below RDS Instances:\033[0m"
echo -e "\033[1m${ENVIRONMENT}\033[0m"
aws rds stop-db-cluster \
--db-cluster-identifier ${ENVIRONMENT}

# Get Status of RDS. Print to screen a status until RDS is no long in available or stopping state. Print Final status when done
STATUS=$(aws rds describe-db-clusters --db-cluster-identifier ${ENVIRONMENT} --query "*[].{DBClusters:Status}" --output text)
echo -e "\033[1mWaiting for RDS cluster to be stopped ...\033[0m"
sleep 10

while [ "${STATUS}" == "available" ] || [ "${STATUS}" == "stopping" ]; do
END_STATUS=$(aws rds describe-db-clusters --db-cluster-identifier ${ENVIRONMENT} --query "*[].{DBClusters:Status}" --output text)
sleep 10
echo " status = ${END_STATUS}"
STATUS="${END_STATUS}"
done

echo -e "\033[0;32mFinished stopping ${ENVIRONMENT} environment.\033[0m"

else
# Perform start for environment: resume asg(which will spin up instances), start rds instance
echo -e "\033[1mStarting below ASG:\033[0m"
echo -e "\033[1m${ASG_ID_STOPPED}\033[0m"
aws autoscaling resume-processes \
--auto-scaling-group-name ${ASG_ID_STOPPED} \
--region ${REGION}

echo -e "\033[1mStarting below RDS Instances:\033[0m"
echo -e "\033[1m${ENVIRONMENT}\033[0m"
aws rds start-db-cluster \
--db-cluster-identifier ${ENVIRONMENT}

# Get Status of RDS. Print to screen a status until RDS is no long in stopped or starting state. Print Final status when done
STATUS=$(aws rds describe-db-clusters --db-cluster-identifier ${ENVIRONMENT} --query "*[].{DBClusters:Status}" --output text)
echo -e "\033[1mWaiting for RDS cluster to start up ...\033[0m"
sleep 10

while [ "${STATUS}" == "stopped" ] || [ "${STATUS}" == "starting" ]; do
END_STATUS=$(aws rds describe-db-clusters --db-cluster-identifier ${ENVIRONMENT} --query "*[].{DBClusters:Status}" --output text)
sleep 10
echo " status = ${END_STATUS}"
STATUS="${END_STATUS}"
done

echo -e "\033[0;32mFinished starting ${ENVIRONMENT} environment.\033[0m"
fi
