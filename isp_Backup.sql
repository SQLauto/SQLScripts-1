IF OBJECT_ID(N'[dbo].[isp_Backup]') IS NOT NULL
	DROP PROC [dbo].[isp_Backup]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------------------------------------------
-- OBJECT NAME	        : isp_Backup
--
-- AUTHOR               : Tara Kizer
--
-- INPUTS				: @path - location of the backups, default backup directory used if @path is null
--						  @dbType - which database(s) to backup
--							All, System, User, or dash followed by database name (ex. -Toolbox)
--						  @bkpType - type of backup to perform
--							Full, TLog, Diff
--						  @retention - number of days to retain backups, -1 to retain all files
--						  @bkpSwType - which software package to use for the backup
--							NV (Native), NC (Native compression), LS (Quest LiteSpeed), SB (Red Gate SQL Backup)
--						  @archiveBit
--							0 - ignore the archive bit of the files
--							1 - archive bit must be enabled in order to delete the files past the retention period;
--								archive bit gets enabled when files are backed up to tape
--						  @copyOnly - whether or not to use the COPY_ONLY option (see BOL for details)
--
-- OUTPUTS				: None
--
-- RETURN CODES			: 1-13 (see @rm at the end for the messages)
--
-- DEPENDENCIES	        : None
--
-- DESCRIPTION	        : Performs backups for SQL Server 2005 and 2008.
--
-- NOTES				: If you do not have Quest's LiteSpeed and Red Gate's SQL Backup
--						  products installed, ignore the warnings when you create/alter this
--						  stored procedure.  They are warnings only and not errors.
--
-- EXAMPLES (optional)  : 
/*			
						  EXEC isp_Backup 
							@path = 'E:\MSSQL\Backup\', 
							@dbType = 'All', 
							@bkpType = 'Full', 
							@retention = 5, 
							@bkpSwType = 'NV',
							@archiveBit = 0,
							@copyOnly = 0
*/
/*
	http://weblogs.sqlteam.com/tarad/archive/2009/04/07/Backup-SQL-Server-DatabasesAgain.aspx
		Bug Fix	- fully qualified backupset table to msdb.dbo.backupset
		Bug Fix	- fixed full backup check for SIMPLE recovery model databases
		Feature - Red Gate functionality
	http://weblogs.sqlteam.com/tarad/archive/2009/09/08/Backup-SQL-Server-2005-and-2008-Databases.aspx
		Bug	Fix	- removed ReportServerTempdb from exclusion list
		Bug Fix - fixed file retention code to handle database names with spaces
		Feature - support for SQL Server 2008 including compression
		Feature - archive bit option
		Feature - COPY_ONLY option
		Feature - removed support for SQL Server 2000
	http://weblogs.sqlteam.com/tarad/archive/2009/12/29/Backup-SQL-Server-2005-and-2008-DatabasesAgain.aspx
		Feature - continue backing up other databases even on error	
*/
----------------------------------------------------------------------------------------------------
CREATE PROC [dbo].[isp_Backup]
(
	@path varchar(100), 
	@dbType sysname = 'All', 
	@bkpType char(4) = 'Full', 
	@retention smallint = 2, 
	@bkpSwType char(2) = 'NV',
	@archiveBit bit = 0,
	@copyOnly bit = 0
)
AS

SET NOCOUNT ON

DECLARE 
	 @now char(14) 				-- current date in the form of yyyymmddhhmmss
	,@dbName sysname 			-- database name that is currently being processed
	,@cmd nvarchar(4000)		-- dynamically created DOS command
	,@sql nvarchar(4000)		-- dynamically create SQL command
	,@result int 				-- result of the dir DOS command
	,@rowCnt int 				-- @@ROWCOUNT
	,@fileName varchar(500)		-- path and file name of the BAK file
	,@rc int					-- return code
	,@extension char(4)			-- extension for backup file
	,@version tinyint			-- SQL Server version number, i.e. 9 (2005), or 10 (2008)
	,@missingFull bit			-- is there a missing full backup?
	,@dateSetting char(1)		-- registry value for date setting
	,@bkpFailure varchar(2047)	-- which databases failed to backup, in CSV format
	,@edition tinyint			-- edition of SQL Server 
								-- (2 - Standard or Workgroup; 3 - Developer or Enterprise; 4 - Express or Embedded SQL)

SET @version = LEFT(CONVERT(varchar(20), SERVERPROPERTY('ProductVersion')), CHARINDEX('.', CONVERT(varchar(20), SERVERPROPERTY('ProductVersion'))) - 1)

IF @version NOT IN (9, 10)
BEGIN
	SET @rc = 1
	GOTO EXIT_ROUTINE
END

SET @edition = CONVERT(tinyint, SERVERPROPERTY('EngineEdition'))

-- validate input parameters
IF @dbType IS NOT NULL AND @dbType NOT IN ('All', 'System', 'User') AND @dbType NOT LIKE '-%'
BEGIN
	SET @rc = 2
	GOTO EXIT_ROUTINE
END

IF @dbType LIKE '-%'
BEGIN
	IF NOT EXISTS (SELECT * FROM master.sys.databases WHERE [name] = SUBSTRING(@dbType, 2, DATALENGTH(@dbType)))
	BEGIN
		SET @rc = 3
		GOTO EXIT_ROUTINE
	END
END

IF @bkpType IS NOT NULL AND @bkpType NOT IN ('Full', 'TLog', 'Diff')
BEGIN
	SET @rc = 4
	GOTO EXIT_ROUTINE
END

IF @dbType = 'System' AND @bkpType <> 'Full'
BEGIN
	SET @rc = 5
	GOTO EXIT_ROUTINE
END

IF @bkpSwType IS NOT NULL AND @bkpSwType NOT IN ('NV', 'NC', 'LS', 'SB')
BEGIN
	SET @rc = 6
	GOTO EXIT_ROUTINE
END

-- native compression is only available in 2008 Ent/Dev editions
IF @bkpSwType = 'NC' AND (@version <> 10 OR @edition <> 3)
BEGIN
	SET @rc = 13
	GOTO EXIT_ROUTINE
END

-- use the default backup directory if @path is null
IF @path IS NULL
	EXEC master.dbo.xp_instance_regread 
		N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\MSSQLServer',N'BackupDirectory', 
		@path OUTPUT, 
		'no_output'

-- we need the backslash after the path, so add it if it wasn't provided in the input parameter
IF RIGHT(@path, 1) <> '\'
	SET @path = @path + '\'

CREATE TABLE #WhichDatabase(dbName sysname NOT NULL)

-- put the databases to be backed up into temp table
IF @dbType LIKE '-%'
BEGIN
	IF @bkpType = 'TLog' AND 
		DATABASEPROPERTYEX(SUBSTRING(@dbType, 2, DATALENGTH(@dbType)), 'RECOVERY') = 'SIMPLE'
	BEGIN
		SET @rc = 7
		GOTO EXIT_ROUTINE
	END
	
	IF @edition = 3
	BEGIN
		IF EXISTS 
		(
			SELECT * 
			FROM msdb.dbo.log_shipping_primary_databases 
			WHERE primary_database = SUBSTRING(@dbType, 2, DATALENGTH(@dbType))
		)
		BEGIN
			SET @rc = 8
			GOTO EXIT_ROUTINE
		END
	END

	IF EXISTS 
	(
		SELECT * 
		FROM master.sys.databases 
		WHERE [name] = SUBSTRING(@dbType, 2, DATALENGTH(@dbType)) AND source_database_id IS NOT NULL
	)
	BEGIN
		SET @rc = 11
		GOTO EXIT_ROUTINE
	END

	INSERT INTO #WhichDatabase(dbName)
	VALUES(SUBSTRING(@dbType, 2, DATALENGTH(@dbType))) 
END
ELSE IF @dbType = 'All' 
BEGIN
	IF @edition = 3
		INSERT INTO #WhichDatabase (dbName)
		SELECT [name]
		FROM master.sys.databases
		WHERE 
			[name] <> 'tempdb' AND
			[name] NOT IN (SELECT primary_database FROM msdb.dbo.log_shipping_primary_databases) AND
			DATABASEPROPERTYEX([name], 'IsInStandBy') = 0 AND
			DATABASEPROPERTYEX([name], 'Status') = 'ONLINE'
		ORDER BY [name]
	ELSE 
		INSERT INTO #WhichDatabase (dbName)
		SELECT [name]
		FROM master.sys.databases
		WHERE 
			[name] <> 'tempdb' AND
			DATABASEPROPERTYEX([name], 'IsInStandBy') = 0 AND
			DATABASEPROPERTYEX([name], 'Status') = 'ONLINE'
		ORDER BY [name]
END
ELSE IF @dbType = 'System'
	INSERT INTO #WhichDatabase (dbName)
	SELECT [name]
	FROM master.sys.databases
	WHERE [name] IN ('master', 'model', 'msdb')
	ORDER BY [name]
ELSE IF @dbType = 'User'
BEGIN
	IF @edition = 3
		INSERT INTO #WhichDatabase (dbName)
		SELECT [name]
		FROM master.sys.databases
		WHERE 
			[name] NOT IN ('master', 'model', 'msdb', 'tempdb') AND
			[name] NOT IN (SELECT primary_database FROM msdb.dbo.log_shipping_primary_databases) AND
			DATABASEPROPERTYEX([name], 'IsInStandBy') = 0 AND
			DATABASEPROPERTYEX([name], 'Status') = 'ONLINE'
		ORDER BY [name]
	ELSE
		INSERT INTO #WhichDatabase (dbName)
		SELECT [name]
		FROM master.sys.databases
		WHERE 
			[name] NOT IN ('master', 'model', 'msdb', 'tempdb') AND
			DATABASEPROPERTYEX([name], 'IsInStandBy') = 0 AND
			DATABASEPROPERTYEX([name], 'Status') = 'ONLINE'
		ORDER BY [name]
END
ELSE -- no databases to be backed up
BEGIN
	SET @rc = 9
	GOTO EXIT_ROUTINE
END

-- Remove snapshots
DELETE t
FROM #WhichDatabase t 
INNER JOIN master.sys.databases d
ON t.dbName = d.[name]
WHERE d.source_database_id IS NOT NULL

-- Get the database to be backed up
SELECT TOP 1 @dbName = dbName
FROM #WhichDatabase

SET @rowCnt = @@ROWCOUNT

-- Iterate throught the temp table until no more databases need to be backed up
WHILE @rowCnt <> 0
BEGIN
	SET @missingFull = 0

	-- Check for date setting in the registry
	EXEC master..xp_regread @rootkey='HKEY_CURRENT_USER',
		@key='Control Panel\International',
		@value_name='iDate',
		@value=@dateSetting OUTPUT

	IF @dateSetting = 0
		SET DATEFORMAT mdy
	ELSE IF @dateSetting = 1
		SET DATEFORMAT dmy
	ELSE -- @dateSetting = 2
		SET DATEFORMAT ymd

	IF @bkpType = 'TLog' AND @dbType IN ('All', 'User') AND DATABASEPROPERTYEX(@dbName, 'RECOVERY') = 'SIMPLE'
		PRINT 'Skipping transaction log backup of ' + @dbName
	ELSE IF @bkpType = 'Diff' AND @dbName IN ('master', 'model', 'msdb')
		PRINT 'Skipping differential backup of ' + @dbName
	ELSE
	BEGIN
		SET @extension =
			CASE
				WHEN @bkpType = 'Full' THEN '.BAK'
				WHEN @bkpType = 'TLog' THEN '.TRN'
				ELSE '.DIF'
			END
			
		-- Build the dir command that will check to see if the directory exists
		SET @cmd = 'dir "' + @path + @dbName + '"'

		-- Run the dir command, put output of xp_cmdshell into @result
		EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT
	
		-- If the directory does not exist, we must create it
		IF @result <> 0
		BEGIN
			-- Build the mkdir command		
			SET @cmd = 'mkdir "' + @path + @dbName + '"'
	
			-- Create the directory
			EXEC master..xp_cmdshell @cmd, NO_OUTPUT
	
			IF @@ERROR <> 0
			BEGIN
				SET @rc = 10
				GOTO EXIT_ROUTINE
			END
		END
		-- The directory exists, so let's delete files older than two days
		ELSE IF @retention <> -1
		BEGIN
			-- Stores the name of the file to be deleted
			DECLARE @whichFile VARCHAR(1000)
			
			-- Stores file information
			CREATE TABLE #DeleteOldFiles(DirInfo VARCHAR(7000))
			
			-- Stores just the file names
			CREATE TABLE #FileNames ([fileName] sysname NULL)
	
			-- Build the command that will list out all of the files in a directory
			SET @cmd = 'dir ' + CASE WHEN @archiveBit = 1 THEN '/AA ' ELSE '' END + '"' + @path + @dbName + '\*' + @extension + '" /OD'
	
			INSERT INTO #DeleteOldFiles
			EXEC master..xp_cmdshell @cmd
			
			-- Build the command that will list out just the file names
			SET @cmd = 'dir ' + CASE WHEN @archiveBit = 1 THEN '/AA ' ELSE '' END + '"' + @path + @dbName + '\*' + @extension + '" /OD /B'

			INSERT INTO #FileNames
			EXEC master..xp_cmdshell @cmd
	
			-- Delete all rows from the temp table except the ones that correspond to the files to be deleted
			DELETE FROM #DeleteOldFiles
			WHERE 
				ISDATE(SUBSTRING(DirInfo, 1, 10)) = 0 OR 
				DirInfo LIKE '%<DIR>%' OR 
				SUBSTRING(DirInfo, 1, 10) >= GETDATE() - @retention
			
			-- Sync #FileNames with #DeleteOldFiles
			DELETE fn
			FROM #FileNames fn
			LEFT JOIN #DeleteOldFiles dof
			ON dof.DirInfo LIKE '%' + fn.[fileName] + '%'
			WHERE dof.DirInfo IS NULL
	
			-- Get the file name portion of the row that corresponds to the file to be deleted
			SELECT TOP 1 @whichFile = [fileName]
			FROM #FileNames
			ORDER BY [fileName]
	
			SET @rowCnt = @@ROWCOUNT
			
			-- Interate through the temp table until there are no more files to delete
			WHILE @rowCnt <> 0
			BEGIN
				-- Build the del command
				SET @cmd = 'del "' + @path + @dbName + '\' + @whichFile + '" /Q /F'
				
				-- Delete the file
				EXEC master..xp_cmdshell @cmd, NO_OUTPUT
				
				-- Get the next file to be deleted
				SELECT TOP 1 @whichFile = [fileName]
				FROM #FileNames
				WHERE [fileName] > @whichFile
				ORDER BY [fileName]
			
				SET @rowCnt = @@ROWCOUNT
			END
			DROP TABLE #DeleteOldFiles, #FileNames
		END
		-- Get the current date using style 120, remove all dashes, spaces, and colons
		SET @now = REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(50), GETDATE(), 120), '-', ''), ' ', ''), ':', '')

		-- check for missing full backup or broken transaction log chain
		IF @bkpType <> 'FULL'
		BEGIN
			SELECT @missingFull =
				CASE 
					WHEN last_log_backup_lsn IS NULL THEN 1 
					ELSE 0 
				END
			FROM master.sys.database_recovery_status 
			WHERE database_id = DB_ID(@dbName)

			-- Database could be in SIMPLE recovery model, so above could show a broken
			-- transaction log chain
			IF @missingFull = 1
				SELECT @missingFull = 
					CASE
						WHEN backup_date IS NULL THEN 1
						WHEN backup_date < restore_date THEN 1
						WHEN backup_date < create_date THEN 1
						ELSE 0
					END
				FROM
				(
					SELECT
						create_date, 
						restore_date = 
							(
								SELECT MAX(restore_date) AS restore_date
								FROM msdb.dbo.restorehistory
								WHERE destination_database_name = @dbName
							),
						backup_date = 
							(
								SELECT MAX(backup_start_date) AS backup_date
								FROM msdb.dbo.backupset
								WHERE database_name = @dbName AND type = 'D' --full backup
							)
					FROM master.sys.databases
					WHERE name = @dbName
				) t
		END
		
		-- Build the backup path and file name, backup the database
		IF @bkpSwType IN ('NV', 'NC')
		BEGIN
			SET @fileName = @path + @dbName + '\' + @dbName + '_' + @now + @extension
			
			IF @bkpType = 'Full' OR @missingFull = 1
			BEGIN
				SET @fileName = LEFT(@fileName, DATALENGTH(@fileName) - 4) + '.BAK'
				
				SET @sql = 'BACKUP DATABASE ' + QUOTENAME(@dbName) + ' TO DISK = ''' + @filename + ''' WITH INIT'
				
				IF @bkpSwType = 'NC'
					SET @sql = @sql + ', COMPRESSION'
				
				IF @copyOnly = 1 AND @missingFull = 0
					SET @sql = @sql + ', COPY_ONLY'
				
				BEGIN TRY
					EXEC (@sql)
				END TRY
				BEGIN CATCH
					IF @bkpFailure IS NULL
						SET @bkpFailure = @dbName
					ELSE
						SET @bkpFailure = @bkpFailure + ', ' + @dbName
				END CATCH
									
				SET @fileName = LEFT(@fileName, DATALENGTH(@fileName) - 4) + @extension
			END

			IF @bkpType = 'Diff'
			BEGIN
				SET @sql = 'BACKUP DATABASE ' + QUOTENAME(@dbName) + ' TO DISK = ''' + @filename + ''' WITH INIT, DIFFERENTIAL'
				
				IF @bkpSwType = 'NC'
					SET @sql = @sql + ', COMPRESSION'
					
				BEGIN TRY
					EXEC (@sql)
				END TRY
				BEGIN CATCH
					IF @bkpFailure IS NULL
						SET @bkpFailure = @dbName
					ELSE
						SET @bkpFailure = @bkpFailure + ', ' + @dbName
				END CATCH
			END
			ELSE IF @bkpType = 'TLog'
			BEGIN
				SET @sql = 'BACKUP LOG ' + QUOTENAME(@dbName) + ' TO DISK = ''' + @filename + ''' WITH INIT'
				
				IF @bkpSwType = 'NC'
					SET @sql = @sql + ', COMPRESSION'
					
				IF @copyOnly = 1
					SET @sql = @sql + ', COPY_ONLY'
					
				BEGIN TRY
					EXEC (@sql)
				END TRY
				BEGIN CATCH
					IF @bkpFailure IS NULL
						SET @bkpFailure = @dbName
					ELSE
						SET @bkpFailure = @bkpFailure + ', ' + @dbName
				END CATCH
			END
		END
		ELSE IF @bkpSwType = 'LS'
		BEGIN
			DECLARE @regOutput varchar(20) -- stores the output from the registry
			DECLARE @numProcs int -- stores the number of processors that the server has registered

			-- Get the number of processors that the server has
			EXEC master..xp_regread 
				  @rootkey = 'HKEY_LOCAL_MACHINE', 
				  @key = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment\',
				  @value_name = 'NUMBER_OF_PROCESSORS',
				  @value = @regOutput OUTPUT
			
			--  We want n - 1 threads up to 4, where n is the number of processors
			SELECT @numProcs = MIN(procs)
			FROM (SELECT CONVERT(int, @regOutput) - 1 AS procs UNION ALL SELECT 4) t
			
			SET @fileName = @path + @dbName + '\' + @dbName + '_LS_' + @now + @extension
	
			IF @bkpType = 'Full' OR @missingFull = 1
			BEGIN
				SET @fileName = LEFT(@fileName, DATALENGTH(@fileName) - 4) + '.BAK'
				
				SET @sql = 'EXEC master.dbo.xp_backup_database @database = ''' + @dbName + ''', @filename = '''
				SET @sql = @sql + @fileName + ''', @threads = ' + CONVERT(varchar(2), @numProcs) + ', @init = 1'
				
				IF @copyOnly = 1 AND @missingFull = 0
					SET @sql = @sql + ', @with = ''COPY_ONLY'''
					
				BEGIN TRY
					EXEC (@sql)
				END TRY
				BEGIN CATCH
					IF @bkpFailure IS NULL
						SET @bkpFailure = @dbName
					ELSE
						SET @bkpFailure = @bkpFailure + ', ' + @dbName
				END CATCH
					
				SET @fileName = LEFT(@fileName, DATALENGTH(@fileName) - 4) + @extension
			END

			IF @bkpType = 'Diff'
				BEGIN TRY
					EXEC master.dbo.xp_backup_database
						@database = @dbName,
						@filename = @fileName,
						@threads = @numProcs,
						@init = 1,
						@with = 'DIFFERENTIAL'
				END TRY
				BEGIN CATCH
					IF @bkpFailure IS NULL
						SET @bkpFailure = @dbName
					ELSE
						SET @bkpFailure = @bkpFailure + ', ' + @dbName
				END CATCH
			ELSE IF @bkpType = 'TLog'
			BEGIN
				SET @sql = 'EXEC master.dbo.xp_backup_log @database = ''' + @dbName + ''', @filename = '''
				SET @sql = @sql + @fileName + ''', @threads = ' + CONVERT(varchar(2), @numProcs) + ', @init = 1'
				
				IF @copyOnly = 1 AND @missingFull = 0
					SET @sql = @sql + ', @with = ''COPY_ONLY'''
					
				BEGIN TRY
					EXEC (@sql)
				END TRY
				BEGIN CATCH
					IF @bkpFailure IS NULL
						SET @bkpFailure = @dbName
					ELSE
						SET @bkpFailure = @bkpFailure + ', ' + @dbName
				END CATCH
			END
		END
		ELSE -- @bkpSwType = 'SB'
		BEGIN
			DECLARE @exitcode int, @sqlerrorcode int

			SET @fileName = @path + @dbName + '\' + @dbName + '_SB_' + @now + @extension

			IF @bkpType = 'Full' OR @missingFull = 1
			BEGIN
				SET @fileName = LEFT(@fileName, DATALENGTH(@fileName) - 4) + '.BAK'

				SET @sql = '-SQL "BACKUP DATABASE ' + QUOTENAME(@dbName) + ' TO DISK = [' + @fileName + '] WITH INIT'
				
				IF @copyOnly = 1 AND @missingFull = 0
					SET @sql = @sql + ', COPY_ONLY'
					
				SET @sql = @sql + '"'
				
				BEGIN TRY
					EXEC master.dbo.sqlbackup @sql, @exitcode OUTPUT, @sqlerrorcode OUTPUT
				END TRY
				BEGIN CATCH
					IF @bkpFailure IS NULL
						SET @bkpFailure = @dbName
					ELSE
						SET @bkpFailure = @bkpFailure + ', ' + @dbName
				END CATCH

				IF @exitcode <> 0
				BEGIN
					SET @rc = 12
					GOTO EXIT_ROUTINE
				END
				
				SET @fileName = LEFT(@fileName, DATALENGTH(@fileName) - 4) + @extension
			END

			IF @bkpType = 'Diff'
			BEGIN
				SET @sql = '-SQL "BACKUP DATABASE ' + QUOTENAME(@dbName) + ' TO DISK = [' + @fileName + '] WITH INIT, DIFFERENTIAL"'

				BEGIN TRY
					EXEC master.dbo.sqlbackup @sql, @exitcode OUTPUT, @sqlerrorcode OUTPUT
				END TRY
				BEGIN CATCH
					IF @bkpFailure IS NULL
						SET @bkpFailure = @dbName
					ELSE
						SET @bkpFailure = @bkpFailure + ', ' + @dbName
				END CATCH

				IF @exitcode <> 0
				BEGIN
					SET @rc = 12
					GOTO EXIT_ROUTINE
				END
			END
			ELSE IF @bkpType = 'TLog'
			BEGIN
				SET @sql = '-SQL "BACKUP LOG ' + QUOTENAME(@dbName) + ' TO DISK = [' + @fileName + '] WITH INIT'
				
				IF @copyOnly = 1
					SET @sql = @sql + ', COPY_ONLY'
					
				SET @sql = @sql + '"'

				BEGIN TRY
					EXEC master.dbo.sqlbackup @sql, @exitcode OUTPUT, @sqlerrorcode OUTPUT
				END TRY
				BEGIN CATCH
					IF @bkpFailure IS NULL
						SET @bkpFailure = @dbName
					ELSE
						SET @bkpFailure = @bkpFailure + ', ' + @dbName
				END CATCH
					
				IF @exitcode <> 0
				BEGIN
					SET @rc = 12
					GOTO EXIT_ROUTINE
				END
			END
		END
	END
		-- To move onto the next database, the current database name needs to be deleted from the temp table
		DELETE FROM #WhichDatabase
		WHERE dbName = @dbName
	
		-- Get the database to be backed up
		SELECT TOP 1 @dbName = dbName
		FROM #WhichDatabase
	
		SET @rowCnt = @@ROWCOUNT
END

SET @rc = 0

EXIT_ROUTINE:

IF @rc <> 0
BEGIN
	DECLARE @rm varchar(500)
	
	SELECT @rm = 
		CASE @rc
			WHEN  1 THEN 'Version is not 2005 or 2008'
			WHEN  2 THEN 'Invalid option passed to @dbType'
			WHEN  3 THEN 'Database passed to @dbType does not exist'
			WHEN  4 THEN 'Invalid option passed to @bkpType'
			WHEN  5 THEN 'Only full backups are allowed on system databases'
			WHEN  6 THEN 'Invalid option passed to @bkpSwType' 
			WHEN  7 THEN 'Can not backup tlog when using SIMPLE recovery model'
			WHEN  8 THEN 'Will not backup the tlog on a log shipped database'
			WHEN  9 THEN 'No databases to be backed up'
			WHEN 10 THEN 'Unable to create directory'
			WHEN 11 THEN 'Can not backup database snapshots'
			WHEN 12 THEN 'Red Gate SQL Backup failed with exit code ' + CONVERT(varchar(4), @exitcode)
			WHEN 13 THEN 'Native compression is available only in 2008 Enterprise and Developer editions'
			ELSE         'Invalid return message'
		END

	RAISERROR(@rm, 16, 1)
END

IF @bkpFailure IS NOT NULL
BEGIN
	SET @bkpFailure = 'The following database(s) failed to backup: ' + @bkpFailure + '.'
	RAISERROR (@bkpFailure, 16, 1)
END

RETURN @rc


GO