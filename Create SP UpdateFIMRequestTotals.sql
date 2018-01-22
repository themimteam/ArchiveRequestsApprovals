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

/****** Object:  StoredProcedure [dbo].[UpdateFIMRequestTotals] ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Carol Wapshere
-- Create date: 24/08/2012
-- Description:	Summary data about how long it took for requests to be approved
--              denoted as <12hrs, 12-24hrs, 24-48hrs, >48hrs
-- =============================================
CREATE PROCEDURE [dbo].[UpdateFIMRequestTotals]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here

declare @daysback int;    
set @daysback = 1;

declare @allreqs int;
set @allreqs = 
	(select count (*) from dbo.fim_requests_log
	where DATEDIFF(dd,RequestTime,GETDATE()) >= @daysback
	and DATEDIFF(dd,RequestTime,GETDATE()) < (@daysback + 1));
    
declare @userreqs int;
set @userreqs = 
	(select count (*) from dbo.fim_requests_log
	where DATEDIFF(dd,RequestTime,GETDATE()) >= @daysback
	and DATEDIFF(dd,RequestTime,GETDATE()) < (@daysback + 1)
	and RequestorName <> 'Forefront Identity Manager Service Account'
	and RequestorName <> 'FIMService, Service'
	and RequestorName <> 'EventBroker, Service'
	and RequestorName <> 'Built-in Synchronization Account');

declare @approvals int;
set @approvals = 
    (select count (*) from dbo.fim_approvals_log
	where DATEDIFF(dd,ApprovalTime,GETDATE()) >= @daysback
	and DATEDIFF(dd,ApprovalTime,GETDATE()) < (@daysback + 1)    
    );

declare @lt12 int;
set @lt12 =
	(select COUNT (*) from dbo.fim_approvals_log a
	join dbo.fim_requests_log r on a.Request = r.ObjectKey
	where DATEDIFF(dd,ApprovalTime,GETDATE()) >= @daysback
	and DATEDIFF(dd,ApprovalTime,GETDATE()) < (@daysback + 1)
	and datediff(HH,RequestTime,ApprovalTime) <= 12);

declare @gt12 int;
set @gt12 =
	(select COUNT (*) from dbo.fim_approvals_log a
	join dbo.fim_requests_log r on a.Request = r.ObjectKey
	where DATEDIFF(dd,ApprovalTime,GETDATE()) >= @daysback
	and DATEDIFF(dd,ApprovalTime,GETDATE()) < (@daysback + 1)
	and datediff(HH,RequestTime,ApprovalTime) > 12
	and datediff(HH,RequestTime,ApprovalTime) <= 24);

declare @gt24 int;
set @gt24 =
	(select COUNT (*) from dbo.fim_approvals_log a
	join dbo.fim_requests_log r on a.Request = r.ObjectKey
	where DATEDIFF(dd,ApprovalTime,GETDATE()) >= @daysback
	and DATEDIFF(dd,ApprovalTime,GETDATE()) < (@daysback + 1)
	and datediff(HH,RequestTime,ApprovalTime) > 24
	and datediff(HH,RequestTime,ApprovalTime) <= 48);
	
declare @gt48 int;
set @gt48 =
	(select COUNT (*) from dbo.fim_approvals_log a
	join dbo.fim_requests_log r on a.Request = r.ObjectKey
	where DATEDIFF(dd,ApprovalTime,GETDATE()) >= @daysback
	and DATEDIFF(dd,ApprovalTime,GETDATE()) < (@daysback + 1)
	and datediff(HH,RequestTime,ApprovalTime) > 48);
	    
insert into dbo.fim_requests_totals
select cast(dateadd(dd,-@daysback,getdate()) as date),@allreqs,@userreqs,@approvals,@lt12,@gt12,@gt24,@gt48;


END




GO


