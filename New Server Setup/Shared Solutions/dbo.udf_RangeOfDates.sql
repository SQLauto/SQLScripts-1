USE [EMTT]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[ufd_RangeOfDates]
    /*********************************************************************************
	   Name:       dbo.ufd_RangeOfDates
     
	   Author:     Dan Denney
     
	   Purpose:    This function will generate a list of dates.
    			      
	   Notes:								
     
	   Date        Initials    Description
	   ----------------------------------------------------------------------------
	   2013-3-27	DDD		  Initial Release 	   
	   ----------------------------------------------------------------------------
    *********************************************************************************
	    Usage: 		
		    SELECT DateValue
			 FROM dbo.ufd_RangeOfDates('1/1/2013','2/1/2013')
    *********************************************************************************/
    (	
	    @paramStartDT	DATETIME2
	    ,@paramEndDT	DATETIME2
    )
RETURNS TABLE WITH SCHEMABINDING AS
RETURN 
    WITH cteTally1(N) AS 
		    ( --10E+1 or 10 rows 
			    SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 
			    UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 
			    UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 
			    UNION ALL SELECT 1 
		    ),                             
	    cteTally2(N) AS 
		    ( --10E+2 or 100 rows 
			    SELECT 1 FROM cteTally1 a, cteTally1 b 
		    ), 
	    cteTally3(N) AS 
		    ( --10E+4 or 10,000 rows max 
			    SELECT 1 FROM cteTally2 a, cteTally2 b 
		    ) 
    SELECT TOP (DATEDIFF(DAY, @paramStartDT, @paramEndDT) + 1) 
	    @paramStartDT + ((ROW_NUMBER() OVER (ORDER BY (SELECT 1))) - 1) AS [DateValue] 
    FROM cteTally3;

