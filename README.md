# ArchiveRequestsApprovals
Archive Requests and Approvals

# Author
Carol Wapshere

Archive information about completed Requests and Approvals from the FIMService database and place them in a seperate FIMReporting database.

Steps:

1. Create the FIMReporting database,
   1. This may be created on the same SQL Server as the FIM database(s), however if FIM is very active it may be preferable to host the FIMReporting database on a different SQL server.
1. Create the tables by running the "Create Table*" scripts,
1. Create the Stored Procedures by running the "Create SP*" scripts,
1. Create a SQL Agent job that runs the three Stored Procedures at or after midnight. The Stored Procedures will archive all completed requests and approvals that have not yet been archived.