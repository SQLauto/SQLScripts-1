--#region XE Metadata Views
-- All XE Packages and objects
SELECT p.name         AS package_name
	   ,o.name        AS object_name
	   ,o.object_type AS object_type
	   ,o.description AS object_description
FROM   sys.dm_xe_packages AS p
	   JOIN sys.dm_xe_objects AS o ON p.guid = o.package_guid
WHERE  (p.capabilities IS NULL
	 OR p.capabilities & 1 = 0);

-- Available Events
SELECT p.name  AS package_name
	   ,o.name AS event_name
	   ,o.description
FROM   sys.dm_xe_packages AS p
	   JOIN sys.dm_xe_objects AS o ON p.guid = o.package_guid
WHERE  p.capabilities IS NULL
	OR p.capabilities & 1 = 0
	   AND o.object_type = 'event';

-- Schema definition for XE Event and Target objects
SELECT oc.name          AS column_name
	   ,oc.column_type  AS column_type
	   ,oc.column_value AS column_value
	   ,oc.description  AS column_description
	   ,oc.type_name    AS column_data_type
FROM   sys.dm_xe_packages AS p
	   JOIN sys.dm_xe_objects AS o ON p.guid = o.package_guid
	   JOIN sys.dm_xe_object_columns AS oc ON o.name = oc.object_name
											  AND o.package_guid = oc.object_package_guid
WHERE
(
	p.capabilities IS NULL
	 OR p.capabilities & 1 = 0
)
AND o.object_type = 'event'
AND o.name = 'wait_info';

-- Available Actions
SELECT p.name  AS package_name
	   ,o.name AS action_name
	   ,o.description
FROM   sys.dm_xe_packages AS p
	   JOIN sys.dm_xe_objects AS o ON p.guid = o.package_guid
WHERE
(
	p.capabilities IS NULL
	 OR p.capabilities & 1 = 0
)
AND o.object_type = 'action';

-- Targets
SELECT p.name  AS package_name
	   ,o.name AS target_name
	   ,o.description
FROM   sys.dm_xe_packages AS p
	   JOIN sys.dm_xe_objects AS o ON p.guid = o.package_guid
WHERE
(
	p.capabilities IS NULL
	 OR p.capabilities & 1 = 0
)
AND o.object_type = 'target';

-- Target Columns
SELECT oc.name AS column_name
	   ,oc.column_id
	   ,oc.type_name
	   ,oc.capabilities_desc
	   ,oc.description
FROM   sys.dm_xe_packages AS p
	   JOIN sys.dm_xe_objects AS o ON p.guid = o.package_guid
	   JOIN sys.dm_xe_object_columns AS oc ON o.name = oc.object_name
											  AND o.package_guid = oc.object_package_guid
WHERE
(
	p.capabilities IS NULL
	 OR p.capabilities & 1 = 0
)
AND o.object_type = 'target'
AND o.name = 'asynchronous_file_target';

-- Predicates
SELECT p.name  AS package_name
	   ,o.name AS source_name
	   ,o.description
FROM   sys.dm_xe_objects AS o
	   JOIN sys.dm_xe_packages AS p ON o.package_guid = p.guid
WHERE
(
	p.capabilities IS NULL
	 OR p.capabilities & 1 = 0
)
AND o.object_type = 'pred_source';

-- Predicate Comparison Operators
SELECT p.name  AS package_name
	   ,o.name AS source_name
	   ,o.description
FROM   sys.dm_xe_objects AS o
	   JOIN sys.dm_xe_packages AS p ON o.package_guid = p.guid
WHERE
(
	p.capabilities IS NULL
	 OR p.capabilities & 1 = 0
)
AND o.object_type = 'pred_compare';

-- Maps
SELECT name
	   ,map_key
	   ,map_value
FROM   sys.dm_xe_map_values
WHERE  name = 'wait_types';

--#endregion XE Metadata Views
--#region Session Definition Views
-- XE defined sessions
SELECT *
FROM   sys.server_event_sessions;

-- XE defined session events
SELECT sese.package    AS event_package
	   ,sese.name      AS event_name
	   ,sese.predicate AS event_predicate
FROM   sys.server_event_sessions AS ses
	   JOIN sys.server_event_session_events AS sese ON ses.event_session_id = sese.event_session_id
WHERE  ses.name = 'system_health';

-- XE defined session event actions
SELECT sese.package    AS event_package
	   ,sese.name      AS event_name
	   ,sese.predicate AS event_predicate
	   ,sesa.package   AS action_package
	   ,sesa.name      AS action_name
FROM   sys.server_event_sessions AS ses
	   JOIN sys.server_event_session_events AS sese ON ses.event_session_id = sese.event_session_id
	   JOIN sys.server_event_session_actions AS sesa ON ses.event_session_id = sesa.event_session_id
														AND sese.event_id = sesa.event_id
WHERE  ses.name = 'system_health';

-- XE defined session event targets
SELECT ses.name    AS session_name
	   ,sest.name  AS target_name
	   ,sesf.name  AS option_name
	   ,sesf.value AS option_value
FROM   sys.server_event_sessions AS ses
	   JOIN sys.server_event_session_targets AS sest ON ses.event_session_id = sest.event_session_id
	   JOIN sys.server_event_session_fields AS sesf ON sest.event_session_id = sesf.event_session_id
													   AND sest.target_id = sesf.object_id
WHERE  ses.name = 'system_health';

--#endregion Session Definition Views
--#region Active Session Views
-- Active session Actions
SELECT s.name             AS session_name
	   ,e.event_name      AS event_name
	   ,e.event_predicate AS event_predicate
	   ,ea.action_name    AS action_name
FROM   sys.dm_xe_sessions AS s
	   JOIN sys.dm_xe_session_events AS e ON s.address = e.event_session_address
	   JOIN sys.dm_xe_session_event_actions AS ea ON e.event_session_address = ea.event_session_address
													 AND e.event_name = ea.event_name
WHERE  s.name = 'system_health';

-- Active session Targets
SELECT s.name                   AS session_name
	   ,t.target_name           AS target_name
	   ,t.execution_count       AS execution_count
	   ,t.execution_duration_ms AS execution_duration
	   ,t.target_data           AS target_data
FROM   sys.dm_xe_sessions AS s
	   JOIN sys.dm_xe_session_targets AS t ON s.address = t.event_session_address
WHERE  s.name = 'system_health';

-- Active sessions Configurable Columns
SELECT DISTINCT s.name AS session_name
				,oc.object_name
				,oc.object_type
				,oc.column_name
				,oc.column_value
FROM   sys.dm_xe_sessions AS s
	   JOIN sys.dm_xe_session_targets AS t ON s.address = t.event_session_address
	   JOIN sys.dm_xe_session_events AS e ON s.address = e.event_session_address
	   JOIN sys.dm_xe_session_object_columns AS oc ON s.address = oc.event_session_address
													  AND
													  (
														  (
															  oc.object_type = 'target'
															  AND t.target_name = oc.object_name
														  )
														   OR
														  (
															  oc.object_type = 'event'
															  AND e.event_name = oc.object_name
														  )
													  )
WHERE  s.name = 'system_health';

--#endregion Active Session Views
SELECT *
FROM   sys.dm_xe_session_targets


