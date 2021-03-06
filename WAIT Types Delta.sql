


-- CAPTURE POINT-IN-TIME
SELECT wait_type, waiting_tasks_count,
		wait_time_ms, max_wait_time_ms,
		signal_wait_time_ms
INTO #OriginalWaitStatSnapshot
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
        'CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 'SLEEP_TASK',
        'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH', 'WAITFOR', 'LOGMGR_QUEUE',
        'CHECKPOINT_QUEUE', 'REQUEST_FOR_DEADLOCK_SEARCH', 'XE_TIMER_EVENT', 'BROKER_TO_FLUSH',
        'BROKER_TASK_STOP', 'CLR_MANUAL_EVENT', 'CLR_AUTO_EVENT', 'DISPATCHER_QUEUE_SEMAPHORE',
        'FT_IFTS_SCHEDULER_IDLE_WAIT', 'XE_DISPATCHER_WAIT', 'XE_DISPATCHER_JOIN', 'BROKER_EVENTHANDLER',
        'TRACEWRITE', 'FT_IFTSHC_MUTEX', 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        'BROKER_RECEIVE_WAITFOR', 'ONDEMAND_TASK_QUEUE', 'DBMIRROR_EVENTS_QUEUE',
        'DBMIRRORING_CMD', 'BROKER_TRANSMITTER', 'SQLTRACE_WAIT_ENTRIES',
        'SLEEP_BPOOL_FLUSH', 'SQLTRACE_LOCK')

-- WAIT FOR X AMOUNT OF TIME
WAITFOR DELAY '00:00:05'

-- COLLECT AGAIN
SELECT wait_type, waiting_tasks_count,
		wait_time_ms, max_wait_time_ms,
		signal_wait_time_ms
INTO #LatestWaitStatSnapshot
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
        'CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 'SLEEP_TASK',
        'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH', 'WAITFOR', 'LOGMGR_QUEUE',
        'CHECKPOINT_QUEUE', 'REQUEST_FOR_DEADLOCK_SEARCH', 'XE_TIMER_EVENT', 'BROKER_TO_FLUSH',
        'BROKER_TASK_STOP', 'CLR_MANUAL_EVENT', 'CLR_AUTO_EVENT', 'DISPATCHER_QUEUE_SEMAPHORE',
        'FT_IFTS_SCHEDULER_IDLE_WAIT', 'XE_DISPATCHER_WAIT', 'XE_DISPATCHER_JOIN', 'BROKER_EVENTHANDLER',
        'TRACEWRITE', 'FT_IFTSHC_MUTEX', 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        'BROKER_RECEIVE_WAITFOR', 'ONDEMAND_TASK_QUEUE', 'DBMIRROR_EVENTS_QUEUE',
        'DBMIRRORING_CMD', 'BROKER_TRANSMITTER', 'SQLTRACE_WAIT_ENTRIES',
        'SLEEP_BPOOL_FLUSH', 'SQLTRACE_LOCK')

-- COMPARE THE RESULTS
SELECT l.wait_type,
	(l.wait_time_ms - o.wait_time_ms) accum_wait_ms
FROM #OriginalWaitStatSnapshot o
	INNER JOIN #LatestWaitStatSnapshot l ON o.wait_type = l.wait_type
WHERE l.wait_time_ms > o.wait_time_ms
ORDER BY l.wait_time_ms DESC

drop table #OriginalWaitStatSnapshot
drop table #LatestWaitStatSnapshot

