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

/****** Object:  StoredProcedure [dbo].[ArchiveFIMApprovals]  ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Carol Wapshere
-- Create date: 24/08/2012
-- Description:	Archives Approvals history from the FIMService database
-- =============================================
CREATE PROCEDURE [dbo].[ArchiveFIMApprovals]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    
truncate table FIMReporting.dbo.fim_approvals_new;


/*** Get Approval and Approval Response objects for logged Requests ***/

insert into FIMReporting.dbo.fim_approvals_new
select o.ObjectKey, 'ObjectKey' as Attribute, o.ObjectKey as Value
from FIMService.fim.Objects o
left outer join dbo.fim_requests_log l
on o.ObjectKey = l.ObjectKey
inner join FIMService.fim.ObjectValueString s
on o.ObjectKey = s.ObjectKey
where (o.ObjectTypeKey = 2 or o.ObjectTypeKey = 3)
and l.ObjectKey is null
and s.AttributeKey = 66;


/*** Get attributes of different data types ***/

/* Boolean */
insert into FIMReporting.dbo.fim_approvals_new
select v.ObjectKey, a.Name as Attribute, CAST(v.ValueBoolean as nvarchar) as Value
from FIMService.fim.ObjectValueBoolean v
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_approvals_new n
on v.ObjectKey = n.ObjectKey
where n.Attribute = 'ObjectKey';

/* DateTime converted to Local time */
insert into FIMReporting.dbo.fim_approvals_new
select v.ObjectKey, a.Name as Attribute, DateAdd(hour, DATEDIFF (HH, GETUTCDATE(), GETDATE()), v.ValueDateTime) as Value
from FIMService.fim.ObjectValueDateTime v
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_approvals_new n
on v.ObjectKey = n.ObjectKey
where n.Attribute = 'ObjectKey';

/* Integer */
insert into FIMReporting.dbo.fim_approvals_new
select v.ObjectKey, a.Name as Attribute, CAST(ValueInteger as nvarchar) as Value
from FIMService.fim.ObjectValueInteger v
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_approvals_new n
on v.ObjectKey = n.ObjectKey
where n.Attribute = 'ObjectKey';

/* Referenced object DisplayName */
insert into FIMReporting.dbo.fim_approvals_new
select v.ObjectKey, (a.Name + 'Name') as Attribute, name.ValueString as Value
from FIMService.fim.ObjectValueReference v
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_approvals_new n
on v.ObjectKey = n.ObjectKey
join FIMService.fim.Objects ref
on v.ValueReference = ref.ObjectKey
join FIMService.fim.ObjectValueString name
on ref.ObjectKey = name.ObjectKey
where n.Attribute = 'ObjectKey'
and name.AttributeKey = 66;

/* Referenced object ObjectKey - used ti link back to Request object */
insert into FIMReporting.dbo.fim_approvals_new
select v.ObjectKey, Name as Attribute, ValueReference as Value
from FIMService.fim.ObjectValueReference v
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_approvals_new n
on v.ObjectKey = n.ObjectKey
where n.Attribute = 'ObjectKey';

/* Reference GUID */
insert into FIMReporting.dbo.fim_approvals_new
select v.ObjectKey, (a.Name + 'GUID') as Attribute, o.ObjectID as Value
from FIMService.fim.ObjectValueReference v
join FIMService.fim.Objects o
on v.ValueReference = o.ObjectKey
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_approvals_new n
on v.ObjectKey = n.ObjectKey
where n.Attribute = 'ObjectKey';

/* String */
insert into FIMReporting.dbo.fim_approvals_new
select v.ObjectKey, Name as Attribute, ValueString as Value
from FIMService.fim.ObjectValueString v
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_approvals_new n
on v.ObjectKey = n.ObjectKey
where n.Attribute = 'ObjectKey';

/* Text */
insert into FIMReporting.dbo.fim_approvals_new
select v.ObjectKey, Name as Attribute, ValueText as Value
 from FIMService.fim.ObjectValueText v
join FIMService.fim.AttributeInternal a
on v.AttributeKey = a.[Key]
join FIMReporting.dbo.fim_approvals_new n
on v.ObjectKey = n.ObjectKey
where n.Attribute = 'ObjectKey';


/*** Insert un-logged approvals into log table ***/
insert into dbo.fim_approvals_log (ObjectKey)
	SELECT n.ObjectKey from dbo.fim_approvals_new n
	left outer join dbo.fim_approvals_log l
	on n.ObjectKey = l.ObjectKey
	where n.Attribute = 'ObjectType'
	and n.Value = 'ApprovalResponse'
	and l.ObjectKey is NULL;

/*** Add values to the logged approvals ***/
update dbo.fim_approvals_log
set Approver = Value
from dbo.fim_approvals_log l
join dbo.fim_approvals_new n
on l.ObjectKey = n.ObjectKey
and n.Attribute = 'CreatorGUID';
	
update dbo.fim_approvals_log
set ApproverName = Value
from dbo.fim_approvals_log l
join dbo.fim_approvals_new n
on l.ObjectKey = n.ObjectKey
and n.Attribute = 'CreatorName';

update dbo.fim_approvals_log
set ApprovalTime = Value
from dbo.fim_approvals_log l
join dbo.fim_approvals_new n
on l.ObjectKey = n.ObjectKey
and n.Attribute = 'CreatedTime';

update dbo.fim_approvals_log
set Request = ap.Value
from dbo.fim_approvals_log l
join dbo.fim_approvals_new ar
on ar.ObjectKey = l.ObjectKey
join dbo.fim_approvals_new ap
on ar.Value = ap.ObjectKey
and ar.Attribute = 'Approval'
and ap.Attribute = 'Request';

update dbo.fim_approvals_log
set Decision = Value
from dbo.fim_approvals_log l
join dbo.fim_approvals_new n
on l.ObjectKey = n.ObjectKey
and n.Attribute = 'Decision';

update dbo.fim_approvals_log
set Reason = Value
from dbo.fim_approvals_log l
join dbo.fim_approvals_new n
on l.ObjectKey = n.ObjectKey
and n.Attribute = 'Reason';


END



GO


