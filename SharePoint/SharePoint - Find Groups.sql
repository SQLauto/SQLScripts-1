-- FiNDS ALL ALERTS FOR GROUPS
SELECT TOP 1000 
      [UserEmail]
      ,[SiteUrl] + [weburl] +'/' + [listurl]    
FROM [coxSharePointContent].[dbo].[ImmedSubscriptions] im
	inner join userinfo ui on im.userid = ui.tp_id
where tp_DomainGroup >0
union all
SELECT TOP 1000 
      [UserEmail]
      ,[SiteUrl] + [weburl] +'/' + [listurl]    
FROM [coxSharePointContent].[dbo].[schedSubscriptions] im
	inner join userinfo ui on im.userid = ui.tp_id
where tp_DomainGroup >0
order by UserEmail



-- FINDS WHICH GROUPS ARE MEMBERS OF WHICH SUB-SITE
SELECT --top 10 *
	fullurl,
	tp_login
  FROM [coxSharePointContent].[dbo].[WebMembers] wm
	inner join webs w on wm.webid = w.id
	inner join userinfo ui on wm.userid = ui.tp_id	
where ui.tp_DomainGroup >0



-- FIND which AD Groups are a part of which SharePoint Group
select 
	ui.tp_login,
	g.title	
from groupmembership gm
	inner join userinfo ui on gm.memberid = ui.tp_id
	inner join groups g on gm.groupid = g.id
where ui.tp_domaingroup > 0
order by ui.tp_login