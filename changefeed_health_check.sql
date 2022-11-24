select job_id,coordinator_id,((high_water_timestamp/1000000000)::int::timestamp)-now() as "changefeed latency",status,created,finished,left(description,70),high_water_timestamp from crdb_internal.jobs where job_type = 'CHANGEFEED' and status != 'running' and status != 'canceled' order by created desc;