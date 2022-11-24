# Cluster Health Check Script

`cluster_health_check.sh` is used to run important health checks for a specific cluster in `staging` or `prod`. This is useful because you do not have to login to the bastion or connect to the AWS console. The main menu will loop until specifying the option to `Quit`.

`env_health_check.sh` is used to run multiple health checks for every cluster in `staging` or `prod`. The health checks are: `Orphan Nodes`, `ASG Unhealthy Instances`, and `ETL Load Balancer Instance Health`.

## Requirements:
* Bastion Access
* Connections can be made to the cluster via `crdb` and `ssh`
* `crdb/certs` directory exists on the bastion for your user and has the cluster folders
* Cluster folders have the cluster certs and `id_rsa.pub`

### Usage:
`./cluster_health_check.sh`
* Please run the script from the macbook and make sure to be on the VPN
* The script will walk through a few steps to prepare. It will ask for:
    - The environment (staging or prod)
    - The cluster name (search ability enabled)
    - Then it will present the main menu in which a health check or function will be selected

`./env_health_check.sh`
`./cluster_health_check.sh`
* Please run the script from the macbook and make sure to be on the VPN
* The script will walk through a few steps to prepare. It will ask for:
    - The environment (staging or prod)
    - Then it will present the main menu. Select the option to run the health check or quit the script.

### Visual Examples:

* Node Status
```
staging or prod : staging

Input the cluster name (partial name search compatible) : benchmark

1) crdb_benchmark_staging-crdb
#? 1

1) Node Status for Cluster	   4) ASG Detach Instance
2) Check for Orphaned Nodes	   5) ETL Load Balancer Health Check
3) ASG Health Check		   6) Quit
Select the operation: 1

Displaying the CRDB Node Status for  crdb_benchmark_staging
#####################################################
#      NOTE: This SSH session will be recorded      #
#####################################################


  id |      address       |                   sql_address                    |  build  |         started_at         |         updated_at         |                         locality                         | is_available | is_live
-----+--------------------+--------------------------------------------------+---------+----------------------------+----------------------------+----------------------------------------------------------+--------------+----------
  12 | 10.4.112.35:26256  | crdb-benchmark-crdb.us-west-2.aws.ddnw.net:26257 | v22.1.5 | 2022-08-22 17:36:35.699823 | 2022-08-26 03:04:22.782319 | country=us,region=us-west-2,az=us-west-2a,pg=us-west-2a5 | true         | true
  13 | 10.4.112.66:26256  | crdb-benchmark-crdb.us-west-2.aws.ddnw.net:26257 | v22.1.5 | 2022-08-10 22:56:08.301395 | 2022-08-26 03:04:20.964788 | country=us,region=us-west-2,az=us-west-2a,pg=us-west-2a6 | true         | true
  14 | 10.4.112.230:26256 | crdb-benchmark-crdb.us-west-2.aws.ddnw.net:26257 | v22.1.5 | 2022-08-22 20:02:26.392365 | 2022-08-26 03:04:20.653893 | country=us,region=us-west-2,az=us-west-2a,pg=us-west-2a1 | true         | true
(3 rows)
```

* Check for Orphaned Nodes
```
staging or prod : staging

Input the cluster name (partial name search compatible) : bench

1) crdb_benchmark_staging-crdb
#? 1
1) Node Status for Cluster	   4) ASG Detach Instance
2) Check for Orphaned Nodes	   5) ETL Load Balancer Health Check
3) ASG Health Check		   6) Quit
Select the operation: 2

#####################################################
#      NOTE: This SSH session will be recorded      #
#####################################################
Running instances for crdb_benchmark_staging

EC2 :  8
CRDB: 3
```

* ASG Health Check and Detach Function
```
staging or prod : staging

Input the cluster name (partial name search compatible) : bench

1) crdb_benchmark_staging-crdb
#? 1
1) Node Status for Cluster	   4) ASG Detach Instance
2) Check for Orphaned Nodes	   5) ETL Load Balancer Health Check
3) ASG Health Check		   6) Quit
Select the operation: 4

Displaying all unhealthy instances for the crdb_benchmark_staging cluster

Auto Scaling Group Name:  crdb_benchmark_staging-20220805204225232300000021

{
  "Instance ID": "i-022a3579ede3120dd",
  "Instance Type": "m6i.4xlarge",
  "Availability Zone": "us-west-2c",
  "Lifecycle State": "InService",
  "Health Status": "Unhealthy"
}
{
  "Instance ID": "i-03eeab316e1b0c837",
  "Instance Type": "m6i.2xlarge",
  "Availability Zone": "us-west-2c",
  "Lifecycle State": "InService",
  "Health Status": "Unhealthy"
}
{
  "Instance ID": "i-04edd9ea04e448a28",
  "Instance Type": "m5.2xlarge",
  "Availability Zone": "us-west-2a",
  "Lifecycle State": "InService",
  "Health Status": "Unhealthy"
}
{
  "Instance ID": "i-06dd569d5a14f5aeb",
  "Instance Type": "m5.2xlarge",
  "Availability Zone": "us-west-2a",
  "Lifecycle State": "InService",
  "Health Status": "Unhealthy"
}
{
  "Instance ID": "i-0836e8050300669d6",
  "Instance Type": "m6i.2xlarge",
  "Availability Zone": "us-west-2c",
  "Lifecycle State": "InService",
  "Health Status": "Unhealthy"
}
{
  "Instance ID": "i-0c50e792e99dfc5d4",
  "Instance Type": "m5.2xlarge",
  "Availability Zone": "us-west-2a",
  "Lifecycle State": "InService",
  "Health Status": "Unhealthy"
}
{
  "Instance ID": "i-0de2fda1d92a751a3",
  "Instance Type": "m5.2xlarge",
  "Availability Zone": "us-west-2a",
  "Lifecycle State": "InService",
  "Health Status": "Unhealthy"
}
Would you like to detach the unhealthy instances listed above? Y/N y
Deatching instance i-022a3579ede3120dd from crdb_benchmark_staging-20220805204225232300000021
Deatching instance i-03eeab316e1b0c837 from crdb_benchmark_staging-20220805204225232300000021
Deatching instance i-04edd9ea04e448a28 from crdb_benchmark_staging-20220805204225232300000021
Deatching instance i-06dd569d5a14f5aeb from crdb_benchmark_staging-20220805204225232300000021
Deatching instance i-0836e8050300669d6 from crdb_benchmark_staging-20220805204225232300000021
Deatching instance i-0c50e792e99dfc5d4 from crdb_benchmark_staging-20220805204225232300000021
Deatching instance i-0de2fda1d92a751a3 from crdb_benchmark_staging-20220805204225232300000021
```

`Env Health Check`
```
Environment Health Check for the delivery-experience_prod cluster
Environment Health Check for the delivery-state-change_prod cluster
Running instances for delivery-state-change_prod

EC2 :  38
CRDB:  29
Displaying all unhealthy instances for the delivery-state-change_prod cluster

Auto Scaling Group Name:  delivery-state-change_prod-2021011418533490370000000d

{
  "Instance ID": "i-04c39c262ed3c96cb",
  "Instance Type": "m6i.4xlarge",
  "Availability Zone": "us-west-2b",
  "Lifecycle State": "InService",
  "Health Status": "Unhealthy"
}
{
  "Instance ID": "i-07c641cf9ccfc5748",
  "Instance Type": "m6i.4xlarge",
  "Availability Zone": "us-west-2c",
  "Lifecycle State": "InService",
  "Health Status": "Unhealthy"
}
{
  "Instance ID": "i-09895ed8021ea82d4",
  "Instance Type": "m6i.4xlarge",
  "Availability Zone": "us-west-2c",
  "Lifecycle State": "InService",
  "Health Status": "Unhealthy"
}
Missing Instances from the ETL Load Balancer, Please Review for Issues
EC2 Instances           : 29
Load Balancer Instances : 37
Environment Health Check for the delivery_intel_platform_prod cluster
Environment Health Check for the delivery_prod cluster
```
