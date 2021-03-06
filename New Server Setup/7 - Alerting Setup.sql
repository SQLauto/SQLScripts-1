/*
This will create a set of SQL Agent Alerts with notifications.

Developer: Dan Denney
Date: 2015-10-14
*/
USE [msdb]
GO


EXEC msdb.dbo.sp_add_alert @name=N'Severity 017 - Insufficient Resources',
@message_id=0,
@severity=17,
@enabled=1,
@delay_between_responses=600,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO

EXEC msdb.dbo.sp_add_alert @name=N'Severity 018 - Nonfatal Internal Error',
@message_id=0,
@severity=18,
@enabled=1,
@delay_between_responses=600,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO

EXEC msdb.dbo.sp_add_alert @name=N'Severity 019 - Fatal Error in Resource',
@message_id=0,
@severity=19,
@enabled=1,
@delay_between_responses=600,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO

EXEC msdb.dbo.sp_add_alert @name=N'Severity 020 - Fatal Error in Current Process',
@message_id=0,
@severity=20,
@enabled=1,
@delay_between_responses=600,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO

EXEC msdb.dbo.sp_add_alert @name=N'Severity 021 - Fatal Error in Database Processes',
@message_id=0,
@severity=21,
@enabled=1,
@delay_between_responses=600,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 021 - Fatal Error in Database Processes', 
    @operator_name=N'FSD AppDev DBAs', @notification_method = 7;
GO

EXEC msdb.dbo.sp_add_alert @name=N'Severity 022 - Fatal Error: Table Integrity Suspect',
@message_id=0,
@severity=22,
@enabled=1,
@delay_between_responses=300,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 022 - Fatal Error: Table Integrity Suspect', 
    @operator_name=N'FSD AppDev DBAs', @notification_method = 7;
GO
EXEC msdb.dbo.sp_add_alert @name=N'Severity 023 - Fatal Error: Database Integrity Suspect',
@message_id=0,
@severity=23,
@enabled=1,
@delay_between_responses=300,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 023 - Fatal Error: Database Integrity Suspect', 
    @operator_name=N'FSD AppDev DBAs', @notification_method = 7;
GO

EXEC msdb.dbo.sp_add_alert @name=N'Severity 024 - Fatal Error: Hardware Error',
@message_id=0,
@severity=24,
@enabled=1,
@delay_between_responses=180,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 024 - Fatal Error: Hardware Error', 
    @operator_name=N'FSD AppDev DBAs', @notification_method = 7;
GO
EXEC msdb.dbo.sp_add_alert @name=N'Severity 025 - Fatal Error',
@message_id=0,
@severity=25,
@enabled=1,
@delay_between_responses=300,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 025 - Fatal Error', 
    @operator_name=N'FSD AppDev DBAs', @notification_method = 7;
GO

EXEC msdb.dbo.sp_add_alert @name=N'823 - Hard I/O Error',
@message_id=823,
@severity=0,
@enabled=1,
@delay_between_responses=180,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'823 - Hard I/O Error', 
    @operator_name=N'FSD AppDev DBAs', @notification_method = 7;
GO

EXEC msdb.dbo.sp_add_alert @name=N'824 - Soft I/O Error',
@message_id=824,
@severity=0,
@enabled=1,
@delay_between_responses=180,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'824 - Soft I/O Error', 
    @operator_name=N'FSD AppDev DBAs', @notification_method = 7;
GO

EXEC msdb.dbo.sp_add_alert @name=N'825 - Read-Retry Error',
@message_id=825,
@severity=0,
@enabled=1,
@delay_between_responses=180,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'825 - Read-Retry Error', 
    @operator_name=N'FSD AppDev DBAs', @notification_method = 7;
GO


