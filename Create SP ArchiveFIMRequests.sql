/* Copyright (c) 2014, Unify Solutions Pty Ltd
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; 
OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
USE [FIMReporting]
GO

/****** Object:  StoredProcedure [dbo].[ArchiveFIMRequests] ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Carol Wapshere
-- Create date: August 2012
-- Description:	Archives the Requests history from the FIMService database
-- =============================================
CREATE PROCEDURE [dbo].[ArchiveFIMRequests]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    
truncate table FIMReporting.dbo.fim_requests_new;

/*** Find completed Request objects not already in the log table ***/

insert into FIMReporting.dbo.fim_requests_new
select o.ObjectKey, 'ObjectKey' as Attribute, o.ObjectKey as Value
from FIMService.fim.Objects o
left outer join dbo.fim_requests_log l
on o.ObjectKey = l.ObjectKey
inner join FIMService.fim.ObjectValueString s
on o.ObjectKey = s.ObjectKey
where o.ObjectTypeKey = 26
and l.ObjectKey is null
and s.AttributeKey = 66;

/*** Add values of the different data types for the Requests we found in the step above ***/

/* Boolean */
insert into FIMReporting.dbo.fim_requests_new
select v.ObjectKey, a.Name as Attribute, CAST(v.ValueBoolean as nvarchar) as Value
from FIMService.fim.ObjectValueBoolean v
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_requests_new n
on v.ObjectKey = n.ObjectKey
where n.Attribute = 'ObjectKey';

/* DateTime converted to local time */
insert into FIMReporting.dbo.fim_requests_new
select v.ObjectKey, a.Name as Attribute, DateAdd(hour, DATEDIFF (HH, GETUTCDATE(), GETDATE()), v.ValueDateTime) as Value
from FIMService.fim.ObjectValueDateTime v
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_requests_new n
on v.ObjectKey = n.ObjectKey
where n.Attribute = 'ObjectKey';

/* Integer */
insert into FIMReporting.dbo.fim_requests_new
select v.ObjectKey, a.Name as Attribute, CAST(ValueInteger as nvarchar) as Value
from FIMService.fim.ObjectValueInteger v
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_requests_new n
on v.ObjectKey = n.ObjectKey
where n.Attribute = 'ObjectKey';

/* Reference GUID */
insert into FIMReporting.dbo.fim_requests_new
select v.ObjectKey, Name as Attribute, o.ObjectID as Value
from FIMService.fim.ObjectValueReference v
join FIMService.fim.Objects o
on v.ValueReference = o.ObjectKey
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_requests_new n
on v.ObjectKey = n.ObjectKey
where n.Attribute = 'ObjectKey';

/* Referenced object DisplayName */
insert into FIMReporting.dbo.fim_requests_new
select v.ObjectKey, (a.Name + 'Name') as Attribute, name.ValueString as Value
from FIMService.fim.ObjectValueReference v
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_requests_new n
on v.ObjectKey = n.ObjectKey
join FIMService.fim.Objects ref
on v.ValueReference = ref.ObjectKey
join FIMService.fim.ObjectValueString name
on ref.ObjectKey = name.ObjectKey
where n.Attribute = 'ObjectKey'
and name.AttributeKey = 66;

/* Strings */
insert into FIMReporting.dbo.fim_requests_new
select v.ObjectKey, Name as Attribute, ValueString as Value
from FIMService.fim.ObjectValueString v
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_requests_new n
on v.ObjectKey = n.ObjectKey
where n.Attribute = 'ObjectKey';

/* Text */
insert into FIMReporting.dbo.fim_requests_new
select v.ObjectKey, Name as Attribute, ValueText as Value
 from FIMService.fim.ObjectValueText v
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_requests_new n
on v.ObjectKey = n.ObjectKey
where n.Attribute = 'ObjectKey';


/*** Use a Pivot to insert listed values as a row per Request in the log table ***/
insert into dbo.fim_requests_log
SELECT ObjectKey,Creator as Requestor,CreatorName as RequestorName,CreatedTime as RequestTime,
		Operation,[Target],TargetName,TargetObjectType,RequestStatus,null as ObjectID
FROM
    (select * from dbo.fim_requests_new
	where ObjectKey in (
	select ObjectKey from dbo.fim_requests_new
	where Attribute = 'RequestStatus'
	and Value in ('Completed','Failed','Denied','PostProcessingError') )) as src
PIVOT
( MAX(Value) FOR Attribute
    IN ( Creator,CreatorName,CreatedTime,Operation,[Target],TargetName,TargetObjectType,RequestStatus,ObjectID )
) AS pvt;


/*** Add the ObjectID ***/
update dbo.fim_requests_log 
set dbo.fim_requests_log.ObjectID = f.ObjectID
from FIMService.fim.[Objects] f 
inner join dbo.fim_requests_log l
on l.ObjectKey = f.ObjectKey
where l.ObjectID is null;


/*** Multi-valued details about individual attribute changes go in the details table ***/
insert into dbo.fim_requests_details
select 
	ObjectKey,
	cast(Value as XML).value('(/RequestParameter/PropertyName)[1]','varchar(250)') as 'Property',
	cast(Value as XML).value('(/RequestParameter/Value)[1]','varchar(250)') as 'Value',
	null as 'DisplayName'
from dbo.fim_requests_new
where Attribute='RequestParameter'
and cast(Value as XML).value('(/RequestParameter/PropertyName)[1]','varchar(250)') is not null;

update dbo.fim_requests_details
set DisplayName = s.ValueString 
from dbo.fim_requests_details rd
join FIMService.fim.AttributeInternal a
on rd.Property = a.Name
join FIMService.fim.[Objects] o
on rd.Value = CAST(o.ObjectID as nvarchar(50))
join FIMService.fim.ObjectValueString s
on o.ObjectKey = s.ObjectKey
where a.DataType = 'Reference'
and s.AttributeKey = 66;

END


GO


