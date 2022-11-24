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

# Check for Version Mismatch Function
version_mismatch_check () {
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
    fi
fi
}

# Protected Timestamp Records Health Check Function
protected_timestamp_records () {
tsh ssh -A root@$first_node "crdb sql -f /tmp/sql_scripts/protected_timestamp_records.sql --format table" > protected_timestamp_records.out

PTS_VALUE=$(cat protected_timestamp_records.out | tail -n +3 | cut -b 1-8)

if [[ "$PTS_VALUE" != "(0 rows)" ]]
  then
    echo -e "${RED}Protected Timestamp Records${NC}"
    newlines 1
    cat protected_timestamp_records.out
    newlines 1
fi

# Cleanup
rm protected_timestamp_records.out
}

# Changefeed Health Check Function
changefeed_health () {
tsh ssh -A root@$first_node "crdb sql -f /tmp/sql_scripts/changefeed_health_check.sql --format table" > changefeed_health_check.out

CF_VALUE=$(cat changefeed_health_check.out | tail -n +3 | cut -b 1-8)

if [[ "$CF_VALUE" != "(0 rows)" ]]
  then
    echo -e "${RED}Changefeeds Not Running${NC}"
    newlines 1
    cat changefeed_health_check.out
    newlines 1
fi

# Cleanup
rm changefeed_health_check.out
}

# Open Intents Health Check Function
open_intents () {
tsh ssh -A root@$first_node "crdb sql -f /tmp/sql_scripts/open_intents.sql --format table" > open_intents.out

OI_VALUE=$(cat open_intents.out | tail -n +3 | cut -b 1-8)

if [[ "$OI_VALUE" != "(0 rows)" ]]
  then
    echo -e "${RED}Open Intents${NC}"
    newlines 1
    cat open_intents.out
    newlines 1
fi

# Cleanup
rm open_intents.out
}

# Check for Orphaned Nodes Function
orphan_node_check () {
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
    echo -e "${RED}ERROR: ${NC}Unable to run crdb node status for the ${PURPLE}$cluster_name${NC} cluster. Please check the tsh connection to the node."
    newlines 1
  else
    if [ $ec2_count != $crdb_count ]
      then
        echo -e "${RED}Orphaned Nodes Present${NC}"
        echo -e "Running instances for ${PURPLE}$cluster_name${NC}"
        echo -e "${BLUE}EC2 : ${GREEN}$ec2_count${NC}"
        echo -e "${BLUE}CRDB:  ${GREEN}$crdb_count${NC}"
        echo $ec2_running
        echo $crdb_running
        newlines 1
    fi
fi

# Cleanup
rm node_status.out
}

# Auto Scaling Group Health Check Function
asg_health_check () {
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
    newlines 1
fi
}

# Load Balancer Healthy Instance Check Function
etl_load_balancer_health_check () {
if [ $environment != staging ]
  then
    AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region aws elb describe-load-balancers --load-balancer-names $cluster_name_etl > /dev/null 2>&1
    if [[ $? -eq 0 ]]
      then
        lb_instance_count=$(AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region aws elb describe-load-balancers --load-balancer-names $cluster_name_etl --query "LoadBalancerDescriptions[*].Instances" --output text | grep -c '.')
        ec2_instance_count=$(AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region aws elb describe-instance-health --load-balancer-name $cluster_name_etl --query "InstanceStates[*].State[]" | grep "InService" | grep -c '.')
        if [ $lb_instance_count != $ec2_instance_count ]
          then
            echo -e "${RED}Missing Instances from the ETL Load Balancer, Please Review for Issues${NC}"
            echo -e "${BLUE}EC2 Instances           : ${RED}$ec2_instance_count${NC}"
            echo -e "${BLUE}Load Balancer Instances : ${RED}$lb_instance_count${NC}"
            newlines 1
            echo -e "Possible Causes:"
            echo -e "- Orphaned Instances Still Present on the Load Balancer and they are Out of Service"
            echo -e "- Cluster was recently repaved and needs an empty PR to refresh the Load Balancers"
            echo -e "- The seed node is still present and needs to be removed/disabled"
            newlines 1
        fi
    fi
fi
}

# Volume Mismatch Check Function
volume_mismatch_check () {
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
        newlines 1
        echo -e "${RED}Volume Mismatch Present${NC}"
        echo -e "Volume Specs"
        echo -e "${BLUE}Size: ${GREEN}$volume_size${NC} ${BLUE}IOPS: ${GREEN}$volume_iops${NC} ${BLUE}Throughput: ${GREEN}$volume_throughput${NC}"
        newlines 1
        echo -e "Launch Template Specs"
        echo -e "${BLUE}Size: ${GREEN}$launch_template_size${NC} ${BLUE}IOPS: ${GREEN}$launch_template_iops${NC} ${BLUE}Throughput: ${GREEN}$launch_template_throughput${NC}"
        newlines 1
        break
    fi
done
}

# # EBS Volume Health Check Function
# ebs_volume_health_check () {
# instance_volumes=$(AWS_DEFAULT_REGION=$region aws ec2 describe-instances --filter Name=tag:crdb_cluster_name,Values=$cluster_name --query "Reservations[*].Instances[*]" --output json | jq -r '.[][].BlockDeviceMappings[].Ebs.VolumeId')

# for volume_id in $instance_volumes
#   do
#     volume_status=$(AWS_DEFAULT_REGION=$region aws ec2 describe-volume-status --volume-ids $volume_id --query "VolumeStatuses[].VolumeStatus.Status" --output text)

#     if [ $volume_status != "ok" ]
#       then
#         echo -e "${RED}Please check the health of volume: ${NC}$volume_id"
#         echo -e "${BLUE}$volume_id status: ${RED}$volume_status"
#     fi
# done
# }

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

all_clusters=$(AWS_PROFILE=$aws_profile AWS_DEFAULT_REGION=$region \
  aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[*].PlacementGroup' | \
  jq -r '.[]' | grep -v null | grep crdb)

date=$(date +"%Y-%m-%d")
basedir="$(dirname "$0")"
mkdir -p "$basedir"/logs/

# Selection Menu
display_menu () {
  newlines 2
  PS3="Select the operation: "
  COLUMNS=12
  selections=("Env Health Check" "Quit")
  select option in "${selections[@]}"; do
    case $option in
      "Env Health Check")
        newlines 1
        echo -e "================================================================================"
        newlines 1
        for cluster in $all_clusters
          do
            cluster_name=$(sed -e 's/-crdb//g' <<< $cluster)
            cluster_name_etl=$(echo $cluster | sed -e 's/_/-/g' | sed -e 's/-prod//g;s/-staging//g' | sed -e 's/$/-etl/')
            first_node=$(tsh ls service=crdb,aws_account=$environment,crdb_cluster_name=$cluster_name 2>&1 | awk '(NR>2){print $1}' | head -n 1)
            if [[ -z $first_node ]]
              then
                echo -e "${RED}Zero nodes found in teleport for ${PURPLE}$cluster_name${NC}"
                newlines 1
                echo -e "================================================================================"
                newlines 1
              else
                tsh scp -qr "$basedir"/sql_scripts root@$first_node:/tmp/
                echo -e "Environment Health Check for: ${PURPLE}$cluster_name${NC}"
                newlines 1
                version_mismatch_check
                orphan_node_check
                volume_mismatch_check
                asg_health_check
                etl_load_balancer_health_check
                protected_timestamp_records
                changefeed_health
                open_intents
                echo -e "================================================================================"
                newlines 1
            fi
        done | tee "$basedir"/logs/"$date"_"$environment"_health_check.txt 2>&1
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
