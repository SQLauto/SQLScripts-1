USE AdventureWorks2012
GO


SELECT e.OrganizationNode.ToString(),
    e2.OrganizationNode.ToString() AS ParentOrgNode
    ,e.JobTitle
    ,e2.JobTitle AS ParentJobTitle
FROM HumanResources.Employee AS e
    INNER JOIN HumanResources.Employee AS e2 ON e.OrganizationNode.GetAncestor(1) = e2.OrganizationNode