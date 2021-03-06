USE AdventureWorks2012
GO


CREATE TABLE #Emps
    (
        EmployeeId INT,
        ManagerID INT,
        Num INT   
    );


INSERT INTO #Emps
        (
         EmployeeId
        ,ManagerID
        ,Num
        )
SELECT 
    e.NationalIDNumber AS EmployeeID
    ,e2.NationalIDNumber AS ManagerID
    ,ROW_NUMBER() OVER (PARTITION BY e2.NationalIDNumber ORDER BY e2.NationalIDNumber) 
FROM HumanResources.Employee AS e
    INNER JOIN HumanResources.Employee AS e2 ON e.OrganizationNode.GetAncestor(1) = e2.OrganizationNode;

WITH paths (path, EmployeeID)
AS
(
    SELECT hierarchyid::GetRoot() AS LeaderHierarchyID
        ,CAST(NationalIDNumber AS INT)
    FROM HumanResources.Employee AS e
    WHERE e.OrganizationNode.ToString() = '/'
    UNION ALL
    SELECT 
        CAST(p.path.ToString() + CAST(e.Num AS VARCHAR(30)) + '/' AS HIERARCHYID)
        ,e.EmployeeId
    FROM #Emps AS e
        INNER JOIN paths AS p ON e.ManagerID = p.EmployeeID
)
SELECT p.path 
    ,hre.NationalIDNumber AS EmployeeID
    ,hre.OrganizationNode
FROM HumanResources.Employee AS hre
    INNER JOIN paths AS p ON hre.NationalIDNumber = p.EmployeeID;

DROP TABLE #Emps;



