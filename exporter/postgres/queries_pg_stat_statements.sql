ccp_stat_statements:
  query: "SELECT queryid,query,calls,total_time,min_time,max_time,mean_time,stddev_time,rows,shared_blks_hit,shared_blks_read,shared_blks_dirtied,shared_blks_written,local_blks_hit,local_blks_read,local_blks_dirtied,local_blks_written,temp_blks_read,temp_blks_written,blk_read_time,blk_write_time FROM monitor.pg_stat_statements()" 
  metrics:
    - queryid:
        usage: "LABEL"
        description: "Internal hash code, computed from the statement's parse tree" 
    - query:
        usage: "LABEL"
        description: "Text of a representative statement"
    - calls:
        usage: "COUNTER"
        description: "Number of times executed"
    - total_time:
        usage: "GAUGE"
        description: "Total time spent in the statement, in milliseconds"
    - min_time:
        usage: "GAUGE" 
        description: "Minimum time spent in the statement, in milliseconds" 
    - max_time:
        usage: "GAUGE" 
        description: "Maximum time spent in the statement, in milliseconds" 
    - mean_time:
        usage: "GAUGE" 
        description: "Mean time spent in the statement, in milliseconds" 
    - stddev_time:
        usage: "GAUGE" 
        description: "Population standard deviation of time spent in the statement, in milliseconds" 
    - rows:
        usage: "GAUGE"
        description: "Total number of rows retrieved or affected by the statement"
    - shared_blks_hit:
        usage: "GAUGE"
        description: "Total number of shared block cache hits by the statement"
    - shared_blks_read:
        usage: "GAUGE"
        description: "Total number of shared blocks read by the statement"
    - shared_blks_dirtied:
        usage: "GAUGE"
        description: "Total number of shared blocks dirtied by the statement"
    - shared_blks_written:
        usage: "GAUGE"
        description: "Total number of shared blocks written by the statement"
    - local_blks_hit:
        usage: "GAUGE"
        description: "Total number of local block cache hits by the statement"
    - local_blks_read:
        usage: "GAUGE"
        description: "Total number of local blocks read by the statement"
    - local_blks_dirtied:
        usage: "GAUGE"
        description: "Total number of local blocks dirtied by the statement"
    - local_blks_written:
        usage: "GAUGE"
        description: "Total number of local blocks written by the statement"
    - temp_blks_read:
        usage: "GAUGE"
        description: "Total number of temp blocks read by the statement"
    - temp_blks_written:
        usage: "GAUGE"
        description: "Total number of temp blocks written by the statement"
    - blk_read_time:
        usage: "GAUGE"
        description: "Total time the statement spent reading blocks, in milliseconds (if track_io_timing is enabled, otherwise zero)"
    - blk_write_time:
        usage: "GAUGE"
        description: "Total time the statement spent writing blocks, in milliseconds (if track_io_timing is enabled, otherwise zero)"


