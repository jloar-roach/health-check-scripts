# Cluster Health Check Script

`cluster_health_check.sh` is used to run important health checks for a specific cluster in `staging` or `prod`. This is useful because you do not have to login to the bastion or connect to the AWS console. The main menu will loop until specifying the option to `Quit`.

`env_health_check.sh` is used to run multiple health checks for every cluster in `staging` or `prod`. The health checks are: `Orphan Nodes`, `ASG Unhealthy Instances`, and `ETL Load Balancer Instance Health`.

## Requirements:
* Connections can be made to the cluster via `crdb` and `ssh`

### Usage:
`./cluster_health_check.sh`
* Please run the script from the macbook and make sure to be on the VPN
* The script will walk through a few steps to prepare. It will ask for:
    - The environment (staging or prod)
    - The cluster name (search capable)
    - Then it will present the main menu in which a health check or function will be selected

`./env_health_check.sh`
* Please run the script from the macbook and make sure to be on the VPN
* The script will walk through a few steps to prepare. It will ask for:
    - The environment (staging or prod)
    - Then it will present the main menu. Select the option to run the health check or quit the script.

### Visual Examples:

* Main Menu
```
staging or prod : prod

Input the cluster name (partial name search compatible) : weather

1) weather_service_prod-crdb
#? 1

 1) Node Status for Cluster
 2) Check CRDB Version for Mismatch
 3) Protected Timestamp Records
 4) Changefeed Health
 5) Open Intents
 6) Check for Orphaned Nodes
 7) Check for Volume Mismatches
 8) ASG Health Check
 9) ETL Load Balancer Health Check
10) Quit
```
* Node Status
```
Displaying the CRDB Node Status for  <cluster_name>


  id |       address       |                    sql_address                    |  build  |         started_at         |         updated_at         |                         locality                         | is_available | is_live
-----+---------------------+---------------------------------------------------+---------+----------------------------+----------------------------+----------------------------------------------------------+--------------+----------
   1 | <ip>:26256 | <cluster_name>.us-west-2.aws.ddnw.net:26257 | v22.1.9 | 2022-11-11 15:04:54.900176 | 2022-11-24 21:28:28.001232 | country=us,region=us-west-2,az=us-west-2a,pg=us-west-2a1 | true         | true
   2 | <ip>:26256  | <cluster_name>.us-west-2.aws.ddnw.net:26257 | v22.1.9 | 2022-11-11 15:05:42.900072 | 2022-11-24 21:28:26.485257 | country=us,region=us-west-2,az=us-west-2a,pg=us-west-2a2 | true         | true
   3 | <ip>:26256  | <cluster_name>.us-west-2.aws.ddnw.net:26257 | v22.1.9 | 2022-11-11 15:06:40.852478 | 2022-11-24 21:28:25.949568 | country=us,region=us-west-2,az=us-west-2b,pg=us-west-2b1 | true         | true
   4 | <ip>:26256  | <cluster_name>.us-west-2.aws.ddnw.net:26257 | v22.1.9 | 2022-11-11 15:07:36.623035 | 2022-11-24 21:28:27.704543 | country=us,region=us-west-2,az=us-west-2b,pg=us-west-2b2 | true         | true
   5 | <ip>:26256  | <cluster_name>.us-west-2.aws.ddnw.net:26257 | v22.1.9 | 2022-11-11 15:08:34.272601 | 2022-11-24 21:28:26.854677 | country=us,region=us-west-2,az=us-west-2c,pg=us-west-2c1 | true         | true
   6 | <ip>:26256 | <cluster_name>.us-west-2.aws.ddnw.net:26257 | v22.1.9 | 2022-11-11 15:09:30.132157 | 2022-11-24 21:28:24.202198 | country=us,region=us-west-2,az=us-west-2c,pg=us-west-2c2 | true         | true
(6 rows)
```

* Check for Orphaned Nodes
```
Displaying the Orphaned Nodes for  weather_service_prod

All nodes are healthy
Running instances for weather_service_prod
EC2 :  6
CRDB:  6
```

* ASG Health Check
```
Displaying all unhealthy instances for the growth_journey_prod cluster

Auto Scaling Group Name:  growth_journey_prod-asg

{
  "Instance ID": "i-012345abcdef",
  "Instance Type": "m6i.xlarge",
  "Availability Zone": "us-west-2a",
  "Lifecycle State": "InService",
  "Health Status": "Unhealthy"
}
```

* Env Health Check Example Output
```
Environment Health Check for the delivery-state-change_prod cluster
Running instances for delivery-state-change_prod

EC2 :  38
CRDB:  29
Displaying all unhealthy instances for the delivery-state-change_prod cluster

Auto Scaling Group Name:  delivery-state-change_prod-asg

{
  "Instance ID": "i-012345abcdef",
  "Instance Type": "m6i.4xlarge",
  "Availability Zone": "us-west-2b",
  "Lifecycle State": "InService",
  "Health Status": "Unhealthy"
}
{
  "Instance ID": "i-012345abcdef",
  "Instance Type": "m6i.4xlarge",
  "Availability Zone": "us-west-2c",
  "Lifecycle State": "InService",
  "Health Status": "Unhealthy"
}
{
  "Instance ID": "i-012345abcdef",
  "Instance Type": "m6i.4xlarge",
  "Availability Zone": "us-west-2c",
  "Lifecycle State": "InService",
  "Health Status": "Unhealthy"
}
Missing Instances from the ETL Load Balancer, Please Review for Issues
EC2 Instances           : 29
Load Balancer Instances : 37
```
