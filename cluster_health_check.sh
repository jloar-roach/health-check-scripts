#!/bin/bash

region=us-west-2
cls='printf \033c'

# Text Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
NC='\033[0m'

#Add New Lines Function
newlines () {
for i in $(seq 1 $1)
  do
    echo " "
  done
}

# Node Status Check Function
node_status_check () {
$cls
echo -e "Displaying the CRDB Node Status for ${PURPLE} $cluster_name ${NC}"
newlines 2
tsh ssh -A root@$first_node 'crdb node status --format table'
newlines 2
}

# Check for Version Mismatch Function
version_mismatch_check () {
$cls
echo -e "Displaying the CRDB Version Mismatch for ${PURPLE}$cluster_name ${NC}"
newlines 1
tsh ssh -A root@$first_node 'crdb node status --format table' > node_status.out
crdb_version_count=$(cat node_status.out | awk '(NR>1){print $7}' | sort -u | grep -c '.')
node_status_error=$(cat node_status.out | head -n 1)

if [[ $node_status_error == *"ERROR"* ]]
  then
    echo -e "${RED}ERROR: ${NC}Unable to run crdb node status for the ${PURPLE}$cluster_name${NC} cluster."
    newlines 1
    echo -e "Please check the tsh connection to the node and verify the cluster is healthy"
    newlines 1
  else
    if [ $crdb_version_count -gt 1 ]
      then
        echo -e "${RED}Version Mismatch Present${NC}"
        newlines 1
        cat node_status.out | awk '(NR>1){print $7}' | sort -u | awk NF
        newlines 1
      else
        echo -e "${GREEN}All Nodes are Running the Same Version${NC}"
        newlines 1
    fi
fi
}

# Protected Timestamp Records Health Check Function
protected_timestamp_records () {
$cls
echo -e "Displaying the Protected Timestamp Records for ${PURPLE} $cluster_name ${NC}"
newlines 2

tsh ssh -A root@$first_node "crdb sql -f /tmp/sql_scripts/protected_timestamp_records.sql --format table" > protected_timestamp_records.out

PTS_VALUE=$(cat protected_timestamp_records.out | tail -n +3 | cut -b 1-8)

if [[ "$PTS_VALUE" != "(0 rows)" ]]
  then
    echo -e "${RED}Protected Timestamp Records${NC}"
    newlines 1
    cat protected_timestamp_records.out
    newlines 1
  else
    newlines 1
    echo -e "${GREEN}No Protected Timestamp Records Found${NC}"
fi

# Cleanup
rm protected_timestamp_records.out
newlines 1
}

# Changefeed Health Check Function
changefeed_health () {
$cls
echo -e "Displaying the Changefeed Health for ${PURPLE} $cluster_name ${NC}"
newlines 2

tsh ssh -A root@$first_node "crdb sql -f /tmp/sql_scripts/changefeed_health_check.sql --format table" > changefeed_health_check.out

CF_VALUE=$(cat changefeed_health_check.out | tail -n +3 | cut -b 1-8)

if [[ "$CF_VALUE" != "(0 rows)" ]]
  then
    echo -e "${RED}Changefeeds Not Running${NC}"
    cat changefeed_health_check.out
    newlines 1
  else
    newlines 1
    echo -e "${GREEN}All Changefeeds are Healthy${NC}"
fi

# Cleanup
rm changefeed_health_check.out
newlines 1
}

# Open Intents Health Check Function
open_intents () {
$cls
echo -e "Displaying the Open Intents for ${PURPLE} $cluster_name ${NC}"
newlines 2
    
tsh ssh -A root@$first_node "crdb sql -f /tmp/sql_scripts/open_intents.sql --format table" > open_intents.out

OI_VALUE=$(cat open_intents.out | tail -n +3 | cut -b 1-8)

if [[ "$OI_VALUE" != "(0 rows)" ]]
  then
    newlines 1
    echo -e "${RED}Open Intents${NC}"
    newlines 1
    cat open_intents.out
    newlines 1
  else
    newlines 1
    echo -e "${GREEN}Intents are Healthy${NC}"
fi

# Cleanup
rm open_intents.out
newlines 1
}

# Check for Orphaned Nodes Function
orphan_node_check () {
$cls
echo -e "Displaying the Orphaned Nodes for ${PURPLE} $cluster_name ${NC}"

ec2_count=$(AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region aws ec2 describe-instances --filter Name=tag:crdb_cluster_name,Values=$cluster_name --query "Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddress" --output text | wc -l | tr -s " ")

if [ $ec2_count -eq 0 ]
    then
        echo "No EC2 Instances Found for $cluster_name. Please check the cluster name in the script settings and verify the tag in AWS"
        break
fi

tsh ssh -A root@$first_node "crdb node status --format table" > node_status.out

crdb_count=$(cat node_status.out | awk '(NR>1){print $3}' | cut -d : -f1 | grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -c '.')
node_status_error=$(cat node_status.out | head -n 1)

if [[ $node_status_error == *"ERROR"* ]]
  then
    newlines 1
    echo -e "${RED}ERROR: ${NC}Unable to run crdb node status for the ${PURPLE}$cluster_name${NC} cluster. Please check the tsh connection to the node."
    newlines 1
  else
    if [ $ec2_count != $crdb_count ]
      then
        newlines 1
        echo -e "${RED}Orphaned Nodes Present${NC}"
        echo -e "Running instances for ${PURPLE}$cluster_name${NC}"
        echo -e "${BLUE}EC2 : ${GREEN}$ec2_count${NC}"
        echo -e "${BLUE}CRDB:  ${GREEN}$crdb_count${NC}"
        echo $ec2_running
        echo $crdb_running
        newlines 1
      else
        newlines 1
        echo -e "${GREEN}All nodes are healthy${NC}"
        echo -e "Running instances for ${PURPLE}$cluster_name${NC}"
        echo -e "${BLUE}EC2 : ${GREEN}$ec2_count${NC}"
        echo -e "${BLUE}CRDB:  ${GREEN}$crdb_count${NC}"
        newlines 1
    fi
fi

# Cleanup
rm node_status.out
newlines 1
}

# Auto Scaling Group Health Check Function
asg_health_check () {
$cls

asg_name=$(AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region aws autoscaling describe-auto-scaling-groups --filter Name=tag:crdb_cluster_name,Values=$cluster_name --query "AutoScalingGroups[*].AutoScalingGroupName" --output text)
asg_instances=$(AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region aws autoscaling describe-auto-scaling-groups --filter Name=tag:crdb_cluster_name,Values=$cluster_name --query "AutoScalingGroups[*].Instances[*]" --output json)
asg_unhealthy_id_count=$(echo $asg_instances | jq -r '.[][] | select(.LifecycleState=="InService" and .HealthStatus=="Unhealthy").InstanceId' | wc -l | tr -s " ")

if [ $asg_unhealthy_id_count != 0 ]
  then
    # Display Unhealthy
    echo -e "Displaying all unhealthy instances for the ${PURPLE}$cluster_name${NC} cluster"
    newlines 1
    echo -e "${BLUE}Auto Scaling Group Name${NC}:  ${GREEN}$asg_name${NC}"
    newlines 1
    
    echo $asg_instances | \
    jq -r '.[][] | select(.LifecycleState=="InService" and .HealthStatus=="Unhealthy").InstanceId' | \
    while read unhealthy_ids
      do echo $asg_instances | \
      jq -r --arg unhealthy_id "$unhealthy_ids" '.[][] | select(.InstanceId==$unhealthy_id) | {"Instance ID":.InstanceId,"Instance Type":.InstanceType,"Availability Zone":.AvailabilityZone,"Lifecycle State":.LifecycleState,"Health Status":.HealthStatus}'
    done
  else
    # Display Healthy
    newlines 1
    echo -e "ASG health check for the ${PURPLE}$cluster_name${NC} cluster"
    newlines 1
    echo -e "${GREEN}All instances are healthy${NC}"
fi

newlines 2
}

# Load Balancer Healthy Instance Check Function
etl_load_balancer_health_check () {
$cls
echo -e "Displaying all unhealthy ETL instances for the ${PURPLE}$cluster_name${NC} cluster"
if [ $environment != staging ]
  then
    AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region aws elb describe-load-balancers --load-balancer-names $cluster_name_etl > /dev/null 2>&1
    if [[ $? -eq 0 ]]
      then
        lb_instance_count=$(AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region aws elb describe-load-balancers --load-balancer-names $cluster_name_etl --query "LoadBalancerDescriptions[*].Instances" --output text | grep -c '.')
        ec2_instance_count=$(AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region aws elb describe-instance-health --load-balancer-name $cluster_name_etl --query "InstanceStates[*].State[]" | grep "InService" | grep -c '.')
        if [ $lb_instance_count != $ec2_instance_count ]
          then
            newlines 1
            echo -e "${RED}Missing Instances from the ETL Load Balancer, Please Review for Issues${NC}"
            echo -e "${BLUE}EC2 Instances           : ${RED}$ec2_instance_count${NC}"
            echo -e "${BLUE}Load Balancer Instances : ${RED}$lb_instance_count${NC}"
            newlines 1
            echo -e "Possible Causes:"
            echo -e "- Orphaned Instances Still Present on the Load Balancer and they are Out of Service"
            echo -e "- Cluster was recently repaved and needs an empty PR to refresh the Load Balancers"
            echo -e "- The seed node is still present and needs to be removed/disabled"
            newlines 1
          else
            newlines 1
            echo -e "${GREEN}All instances are healthy for the ETL Load Balancer${NC}"
            newlines 1
        fi
      else
        newlines 1
        echo -e "${RED}The ETL Load Balancer does not exist for $cluster_name${NC}"
        newlines 1
    fi
fi
}

# Volume Mismatch Check Function
volume_mismatch_check () {
$cls
echo -e "Checking for Volume Mismatch for the ${PURPLE}$cluster_name${NC} cluster"
newlines 1

launch_template_id=$(AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region aws ec2 describe-launch-templates \
  --filter Name=tag:crdb_cluster_name,Values=$cluster_name \
  --query "LaunchTemplates[].LaunchTemplateId" --output text)
launch_template_volume_specs=$(AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region aws ec2 describe-launch-template-versions \
  --launch-template-id $launch_template_id \
  --query "LaunchTemplateVersions[0].LaunchTemplateData.BlockDeviceMappings[1].Ebs" | \
  jq -r '.VolumeSize, .Iops, .Throughput')
instance_volumes=$(AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region aws ec2 describe-instances \
  --filter Name=tag:crdb_cluster_name,Values=$cluster_name \
  --query "Reservations[*].Instances[*]" | \
  jq -r '.[][].BlockDeviceMappings[1].Ebs.VolumeId')
result="success"

for volume_id in $instance_volumes
  do
    volume_specs=$(AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region aws ec2 describe-volumes \
      --volume-ids $volume_id \
      --query "Volumes" | \
      jq -r '.[] | .Size, .Iops, .Throughput')
    if [[ $volume_specs != $launch_template_volume_specs ]]
      then
        launch_template_size=$(echo $launch_template_volume_specs | awk '{print $1}')
        launch_template_iops=$(echo $launch_template_volume_specs | awk '{print $2}')
        launch_template_throughput=$(echo $launch_template_volume_specs | awk '{print $3}')
        volume_size=$(echo $volume_specs | awk '{print $1}')
        volume_iops=$(echo $volume_specs | awk '{print $2}')
        volume_throughput=$(echo $volume_specs | awk '{print $3}')
        echo -e "${RED}Volume Mismatch Present${NC}"
        echo -e "========================================"
        newlines 1
        echo -e "${BLUE}Volume ID: ${GREEN}$volume_id${NC}"
        newlines 1
        echo -e "Volume Specs"
        echo -e "========================================"
        echo -e "${BLUE}Size: ${GREEN}$volume_size${NC} ${BLUE}IOPS: ${GREEN}$volume_iops${NC} ${BLUE}Throughput: ${GREEN}$volume_throughput${NC}"
        newlines 1
        echo -e "Launch Template Specs"
        echo -e "========================================"
        echo -e "${BLUE}Size: ${GREEN}$launch_template_size${NC} ${BLUE}IOPS: ${GREEN}$launch_template_iops${NC} ${BLUE}Throughput: ${GREEN}$launch_template_throughput${NC}"
        newlines 1
        echo -e "Please Check the Volumes for the ${PURPLE}$cluster_name${NC} cluster using volumectl"
        newlines 1
        echo -e "Verify the volume specs are set correctly in terraform for the ${PURPLE}$cluster_name${NC} cluster"
        newlines 1
        echo -e "Volumectl Tool:  https://github.com/doordash/crdb/tree/main/dbops/tools/volumectl"
        result="failure"
        break
    fi
done

if [[ $result == "success" ]]
  then
    echo -e "${GREEN}All Volumes are Running the Same Specs${NC}"
    newlines 1
fi
}

# Script Start - Definitions
$cls
read -p "staging or prod : " environment
newlines 1

if [ $environment == staging ]
  then
    aws_profile="okta-staging-pe-crl-engineer"
  else
    aws_profile="okta-prod-pe-crl-engineer"
fi

read -p "Input the cluster name (partial name search compatible) : " cluster_search
newlines 1

basedir="$(dirname "$0")"

search_clusters=$(AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region \
  aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[*].PlacementGroup' | \
  jq -r '.[]' | grep -v null | grep crdb | grep $cluster_search)

select cluster in $search_clusters
  do
    cluster_name=$(sed -e 's/-crdb//g' <<< $cluster) && \
    cluster_name_etl=$(echo $cluster | sed -e 's/_/-/g' | sed -e 's/-prod//g;s/-staging//g' | sed -e 's/$/-etl/') && \
    first_node=$(tsh ls service=crdb,aws_account=$environment,crdb_cluster_name=$cluster_name | awk '(NR>2){print $1}' | head -n 1) && \
    tsh scp -qr "$basedir"/sql_scripts root@$first_node:/tmp/ && \
    break
done

# Selection Menu
display_menu () {
newlines 2
PS3="Select the operation: "
COLUMNS=12
selections=("Node Status for Cluster" "Check CRDB Version for Mismatch" "Protected Timestamp Records" "Changefeed Health" "Open Intents" "Check for Orphaned Nodes" "Check for Volume Mismatches" "ASG Health Check" "ETL Load Balancer Health Check" "Quit")
select option in "${selections[@]}"; do
  case $option in
    "Node Status for Cluster")
      newlines 1
      node_status_check
      break
      ;;
    "Check CRDB Version for Mismatch")
      newlines 1
      version_mismatch_check
      break
      ;;
    "Protected Timestamp Records")
      newlines 1
      protected_timestamp_records
      break
      ;;
    "Changefeed Health")
      newlines 1
      changefeed_health
      break
      ;;
    "Open Intents")
      newlines 1
      open_intents
      break
      ;;
    "Check for Orphaned Nodes")
      newlines 1
      orphan_node_check
      break
      ;;
    "Check for Volume Mismatches")
      newlines 1
      volume_mismatch_check
      break
      ;;
    "ASG Health Check")
      newlines 1
      asg_health_check
      break
      ;;
    "ETL Load Balancer Health Check")
      newlines 1
      etl_load_balancer_health_check
      break
      ;;
    "Quit")
      echo "Exiting the script"
      exit
      ;;
    *) echo "invalid option $REPLY";;
  esac
done
}
unset COLUMNS

# loop forever
while :
do
display_menu
done