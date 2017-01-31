USE [master]
GO

IF NOT EXISTS (SELECT 1 FROM master.dbo.syslogins WHERE name = 'CORP\CATL0FieldAppDevDBADev')
    BEGIN
        CREATE LOGIN [CORP\CATL0FieldAppDevEngineerDev] FROM WINDOWS WITH DEFAULT_DATABASE=[master];

        ALTER SERVER ROLE [sysadmin] ADD MEMBER [CORP\CATL0FieldAppDevEngineerDev];
    END;
GO

IF NOT EXISTS (SELECT 1 FROM master.dbo.syslogins WHERE name = 'CORP\CATL0FieldAppDevEngineerDev')
    BEGIN
        CREATE LOGIN [CORP\CATL0FieldAppDevEngineerDev] FROM WINDOWS WITH DEFAULT_DATABASE=[master];

    END;
GO
