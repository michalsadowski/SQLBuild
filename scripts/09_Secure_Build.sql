DECLARE @DomainName VARCHAR(128) 
DECLARE @hr INT 
DECLARE @SysInfo INT 

EXEC @hr = sp_OACreate 'ADSystemInfo', @SysInfo OUTPUT  
EXEC @hr = sp_OAGetProperty @SysInfo, 'DomainShortName', @DomainName OUTPUT 
EXEC @hr = sp_OADestroy @SysInfo

/* Enable Ad Hoc Distributed Queries feature */
EXEC sys.sp_configure N'show advanced options', N'1'  
RECONFIGURE WITH OVERRIDE
EXEC sys.sp_configure N'Ad Hoc Distributed Queries', N'0'
RECONFIGURE WITH OVERRIDE

/* Disable CLR Feature  */
EXEC sys.sp_configure N'clr enabled', N'0'
RECONFIGURE WITH OVERRIDE
PRINT 'Disabled CLR Feature; Enable manually ONLY when necessary'

/* Enable Remote DAC (Dedicated Administrator Connection) Feature  */
EXEC sys.sp_configure N'remote admin connections', N'1'
RECONFIGURE WITH OVERRIDE
PRINT 'Enabled Remote DAC (Dedicated Administrator Connection) Feature'

EXEC sys.sp_configure N'Database Mail XPs', N'1'
RECONFIGURE WITH OVERRIDE
PRINT 'Enabled Database Mail Feature'

EXEC sys.sp_configure N'Ole Automation Procedures', N'1'
RECONFIGURE WITH OVERRIDE

EXEC sys.sp_configure N'xp_cmdshell', N'0'
RECONFIGURE WITH OVERRIDE
EXEC sys.sp_configure N'show advanced options', N'0'  
RECONFIGURE WITH OVERRIDE

	--DECLARE @SRV VARCHAR(100)
	DECLARE @COMPNAME VARCHAR(100)
	DECLARE @GRANT1 VARCHAR(100)
	DECLARE @GRANT2 VARCHAR(100)
	SELECT @COMPNAME = RTRIM((SELECT CONVERT(char(20), SERVERPROPERTY('MachineName'))))
--	PRINT @COMPNAME 

SELECT @COMPNAME = (SELECT CONVERT(char(20), SERVERPROPERTY('MachineName')))
--PRINT @COMPNAME 
GO
--
-- Check if SQLServer is a Default instance or Named Instance Then change listening port.
--
DECLARE @Instance_name SYSNAME
DECLARE @RegKey VARCHAR(250) 
DECLARE @DynamicPort VARCHAR(10)
DECLARE @TCPPort VARCHAR(10)

EXEC master.dbo.xp_regread 
	@rootkey		= 'HKEY_LOCAL_MACHINE'
	,@key			= 'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'
	,@value_name	= @@SERVICENAME 
	,@value			= @Instance_name OUTPUT
	
--
-- Disabling network protocols - Named Pipes, VIA
--
SET @RegKey = 'SOFTWARE\Microsoft\\Microsoft SQL Server\'+@instance_name+'\MSSQLServer\SuperSocketNetLib\Np'
EXEC master.dbo.xp_regwrite N'HKEY_LOCAL_MACHINE', @RegKey ,N'Enabled',N'REG_DWORD',0

PRINT 'Disabled Named Pipes network protocol'
SET @RegKey = 'SOFTWARE\Microsoft\\Microsoft SQL Server\'+@instance_name+'\MSSQLServer\SuperSocketNetLib\Via'
EXEC master.dbo.xp_regwrite N'HKEY_LOCAL_MACHINE', @RegKey ,N'Enabled',N'REG_DWORD',0

PRINT 'Disabled Via network protocol'

--
-- Enable full auditing to monitor failed-only access to the SQL Server.
-- 
SET @RegKey = 'SOFTWARE\Microsoft\\Microsoft SQL Server\'+@instance_name+'\MSSQLServer'
EXEC master.dbo.xp_regwrite 'HKEY_LOCAL_MACHINE',@RegKey ,N'AuditLevel',N'REG_DWORD',2
PRINT 'SQL Server System Security Audit Level changed to FailureOnly for the instance'




--
-- Disable SA ID
--					
ALTER LOGIN [sa] DISABLE			
GO
PRINT 'Database User ID ''sa'' has been disabled'

--
-- Remove BUILTIN\Administrators
--	

IF EXISTS (SELECT * FROM master.dbo.syslogins WHERE name = N'BUILTIN\Administrators')
BEGIN
	DROP LOGIN [BUILTIN\Administrators]
END
GO
PRINT 'Database User ID [BUILTIN\Administrators] has been dropped'


---------------------------------------------------------------------------------------------------------------
--
-- Removing Guest from all databases exluding master, tempdb, msdb
--
---------------------------------------------------------------------------------------------------------------
declare @cmd1 varchar(500)
declare @cmd2 varchar(500)
declare @cmd3 varchar(500)
declare @cmd4 varchar(500)

CREATE TABLE #DBs (DBName varchar(500))

INSERT 	INTO #DBs 
SELECT 	NAME 
FROM 	sysdatabases
WHERE 	NAME NOT IN ('master', 'MASTER', 'tempdb', 'TEMPDB', 'msdb', 'MSDB')

DECLARE @DBNAME_C varchar(500)
DECLARE DBName_Cursor CURSOR FOR 
SELECT 	DBName 
FROM 	#DBs
OPEN	DBName_Cursor 
FETCH	NEXT FROM DBName_Cursor INTO @DBNAME_C

WHILE	@@FETCH_STATUS = 0
BEGIN	
   -- AS 2008/03/06 
	SELECT  @cmd1 = 'USE ['+ @DBNAME_C + ']'+ CHAR(13) + 'REVOKE CONNECT FROM GUEST' + CHAR(13) 
	EXEC(@cmd1)
	PRINT 'Disable GUEST account in  ' + @DBNAME_C + ' database'
	SELECT  @cmd4 = ' GUEST user in database '+ @DBNAME_C + ' has been dropped' + CHAR(13)
	--PRINT @cmd4
	FETCH	NEXT FROM DBName_Cursor INTO @DBNAME_C
END
CLOSE	DBName_Cursor
DEALLOCATE DBName_Cursor

DROP TABLE #DBs 
PRINT 'Guest database user ID has been disabled from all the databases excluding master and tempdb databases'
PRINT 'NOTE: THIS CODE SHOULD BE CHECKED FOR SUCCESS - RUN:  SELECT hasdbaccess from sysusers where name = guest'
PRINT 'AGAINST ALL DATABASES - FOR master and tempdbs SHOULD BE 1, FOR ALL OTHER DATABASES SHOULD BE 0'
-------------------------------------------------------------------------------------------------------------


PRINT 'Revoking EXECUTE permission to public from dangerous procedures'

USE master
GO

deny execute on sp_replwritetovarbin to public
GO

REVOKE EXECUTE ON sys.sp_add_agent_parameter TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_add_agent_profile TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_add_log_shipping_alert_job TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_add_log_shipping_primary_database TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_add_log_shipping_primary_secondary TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_add_log_shipping_secondary_database TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_add_log_shipping_secondary_primary TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addapprole TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addarticle TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_adddatatype TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_adddatatypemapping TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_adddistpublisher TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_adddistributiondb TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_adddistributor TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_adddynamicsnapshot_job TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addextendedproperty TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_AddFunctionalUnitToComponent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addlinkedserver TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addlinkedsrvlogin TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addlogin TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addlogreader_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addmergealternatepublisher TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addmergearticle TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addmergefilter TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addmergelogsettings TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addmergepartition TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addmergepublication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addmergepullsubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addmergepullsubscription_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addmergepushsubscription_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addmergesubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addmessage TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addpublication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addpublication_snapshot TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addpullsubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addpullsubscription_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addpushsubscription_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addqreader_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addqueued_artinfo TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addremotelogin TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addrole TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addrolemember TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addscriptexec TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addserver TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addsrvrolemember TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addsubscriber TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addsubscriber_schedule TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addsubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addsynctriggers TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addsynctriggerscore TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addtabletocontents TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addtype TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_addumpdevice TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_adduser TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_adjustpublisheridentityrange TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_altermessage TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_approlepassword TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_attach_db TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_attach_single_file_db TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_attachsubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_change_agent_parameter TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_change_agent_profile TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_change_log_shipping_primary_database TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_change_log_shipping_secondary_database TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_change_log_shipping_secondary_primary TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_change_subscription_properties TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_change_users_login TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changearticle TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changearticlecolumndatatype TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changedbowner TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changedistpublisher TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changedistributiondb TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changedistributor_password TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changedistributor_property TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changedynamicsnapshot_job TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changelogreader_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changemergearticle TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changemergefilter TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changemergelogsettings TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changemergepublication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changemergepullsubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changemergesubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changeobjectowner TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changepublication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changepublication_snapshot TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changeqreader_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changereplicationserverpasswords TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changesubscriber TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changesubscriber_schedule TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changesubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changesubscriptiondtsinfo TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_changesubstatus TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_cleanmergelogfiles TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_cleanup_log_shipping_history TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_configure TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_control_dbmasterkey_password TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_control_plan_guide TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_copymergesnapshot TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_copysnapshot TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_copysubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_create_plan_guide TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_createmergepalrole TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_createorphan TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_createstats TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_createtranpalrole TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dbfixedrolepermission TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_defaultdb TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_defaultlanguage TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_delete_http_namespace_reservation TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_delete_log_shipping_alert_job TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_delete_log_shipping_primary_database TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_delete_log_shipping_primary_secondary TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_delete_log_shipping_secondary_database TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_delete_log_shipping_secondary_primary TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_deletemergeconflictrow TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_deletepeerrequesthistory TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_deletetracertokenhistory TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_denylogin TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_drop_agent_parameter TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_drop_agent_profile TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropanonymousagent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropanonymoussubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropapprole TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_droparticle TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropdatatypemapping TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropdevice TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropdistpublisher TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropdistributiondb TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropdistributor TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropdynamicsnapshot_job TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropextendedproperty TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_droplinkedsrvlogin TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_droplogin TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropmergealternatepublisher TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropmergearticle TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropmergefilter TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropmergelogsettings TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropmergepartition TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropmergepublication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropmergepullsubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropmergesubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropmessage TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_droporphans TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_droppublication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_droppublisher TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_droppullsubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropremotelogin TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_droprole TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_droprolemember TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropserver TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropsrvrolemember TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropsubscriber TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropsubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_droptype TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_dropuser TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_enable_heterogeneous_subscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_enableagentoffload TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_enum_oledb_providers TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_enumcustomresolvers TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_enumdsn TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_enumeratependingschemachanges TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_enumerrorlogs TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_enumfullsubscribers TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_enumoledbdatasources TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_expired_subscription_cleanup TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_generatefilters TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_grant_publication_access TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_grantdbaccess TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_grantlogin TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_link_publication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_markpendingschemachange TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_marksubscriptionvalidation TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_mergearticlecolumn TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_mergecleanupmetadata TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_mergedummyupdate TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_mergemetadataretentioncleanup TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_mergesubscription_cleanup TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_mergesubscriptionsummary TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MS_replication_installed TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSacquireHeadofQueueLock TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSacquireserverresourcefordynamicsnapshot TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSacquireSlotLock TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSacquiresnapshotdeliverysessionlock TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSactivate_auto_sub TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSactivatelogbasedarticleobject TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSactivateprocedureexecutionarticleobject TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_anonymous_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_article TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_compensating_cmd TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_distribution_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_distribution_history TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_dynamic_snapshot_location TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_filteringcolumn TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_log_shipping_error_detail TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_log_shipping_history_detail TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_logreader_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_logreader_history TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_merge_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_merge_anonymous_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_merge_history TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_merge_history90 TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_merge_subscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_mergereplcommand TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_mergesubentry_indistdb TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_publication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_qreader_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_qreader_history TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_repl_alert TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_repl_command TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_repl_commands27hp TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_repl_error TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_replcmds_mcit TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_replmergealert TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_snapshot_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_snapshot_history TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_subscriber_info TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_subscriber_schedule TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_subscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_subscription_3rd TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_tracer_history TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadd_tracer_token TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSaddanonymousreplica TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadddynamicsnapshotjobatdistributor TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSaddguidcolumn TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSaddguidindex TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSaddinitialarticle TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSaddinitialpublication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSaddinitialschemaarticle TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSaddinitialsubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSaddlightweightmergearticle TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSaddmergedynamicsnapshotjob TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSaddmergetriggers TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSaddmergetriggers_from_template TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSaddmergetriggers_internal TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSaddpeerlsn TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSaddsubscriptionarticles TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSadjust_pub_identity TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSallocate_new_identity_range TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSalreadyhavegeneration TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSarticlecleanup TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchange_article TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchange_distribution_agent_properties TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchange_logreader_agent_properties TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchange_merge_agent_properties TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchange_mergearticle TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchange_mergepublication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchange_priority TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchange_publication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchange_retention TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchange_retention_period_unit TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchange_snapshot_agent_properties TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchange_subscription_dts_info TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchangearticleresolver TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchangedynamicsnapshotjobatdistributor TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchangedynsnaplocationatdistributor TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSchangeobjectowner TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScleanup_agent_entry TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScleanup_conflict TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScleanup_publication_ADinfo TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScleanup_subscription_distside_entry TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScleanupdynamicsnapshotfolder TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScleanupdynsnapshotvws TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSCleanupForPullReinit TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScleanupmergepublisher_internal TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSclear_dynamic_snapshot_location TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSclearresetpartialsnapshotprogressbit TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScreate_all_article_repl_views TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScreate_article_repl_views TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScreate_dist_tables TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScreate_logical_record_views TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScreate_sub_tables TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScreatedisabledmltrigger TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScreatedummygeneration TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScreateglobalreplica TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScreatelightweightinsertproc TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScreatelightweightmultipurposeproc TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScreatelightweightprocstriggersconstraints TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScreatelightweightupdateproc TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScreatemergedynamicsnapshot TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MScreateretry TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdelete_tracer_history TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdeletefoldercontents TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdeletemetadataactionrequest TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdeleteretry TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdeletetranconflictrow TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdelgenzero TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdelrow TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdelrowsbatch TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdelrowsbatch_downloadonly TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdelsubrows TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdelsubrowsbatch TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_6x_publication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_6x_replication_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_anonymous_entry TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_article TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_distribution_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_distribution_agentid_dbowner_proxy TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_dynamic_snapshot_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_logreader_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_merge_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_merge_subscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_publication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_qreader_history TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_snapshot_agent TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_snapshot_dirs TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_subscriber_info TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_subscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdrop_subscription_3rd TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdroparticleconstraints TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdroparticletombstones TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdropconstraints TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdropdynsnapshotvws TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdropfkreferencingarticle TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdropmergearticle TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdropmergedynamicsnapshotjob TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdropretry TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSdroptemptable TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSinsert_identity TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSinsertdeleteconflict TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSinserterrorlineage TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSinsertgenerationschemachanges TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSinsertgenhistory TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSinsertlightweightschemachange TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSinsertschemachange TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSkilldb TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdate_agenttype_default TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdate_singlelogicalrecordmetadata TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdate_subscriber_info TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdate_subscriber_schedule TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdate_subscriber_tracer_history TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdate_subscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdate_tracer_history TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdatecachedpeerlsn TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdategenhistory TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdateinitiallightweightsubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdatelastsyncinfo TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdatepeerlsn TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdaterecgen TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdatereplicastate TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSupdatesysmergearticles TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_MSwritemergeperfcounter TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_posttracertoken TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_procoption TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_register_custom_scripting TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_registercustomresolver TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_reinitmergepullsubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_reinitmergesubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_reinitpullsubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_reinitsubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_remoteoption TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_removedbreplication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_removedistpublisherdbreplication TO PUBLIC
GO

--REVOKE EXECUTE ON sys.sp_rename TO PUBLIC
--GO

REVOKE EXECUTE ON sys.sp_renamedb TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_revoke_publication_access TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_revokedbaccess TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_revokelogin TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_serveroption TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_subscription_cleanup TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_update_agent_profile TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_update_user_instance TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_updateextendedproperty TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_updatestats TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_upgrade_log_shipping TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_validatelogins TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_validatemergepublication TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_validatemergepullsubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.sp_validatemergesubscription TO PUBLIC
GO

REVOKE EXECUTE ON sys.xp_dirtree TO PUBLIC
GO

REVOKE EXECUTE ON sys.xp_fileexist TO PUBLIC
GO

REVOKE EXECUTE ON sys.xp_fixeddrives TO PUBLIC
GO

REVOKE EXECUTE ON sys.xp_getnetname TO PUBLIC
GO

REVOKE EXECUTE ON sys.xp_grantlogin TO PUBLIC
GO

--REVOKE EXECUTE ON sys.xp_instance_regread TO PUBLIC
--GO

REVOKE EXECUTE ON sys.xp_msver TO PUBLIC
GO

REVOKE EXECUTE ON sys.xp_regread TO PUBLIC
GO

REVOKE EXECUTE ON sys.xp_revokelogin TO PUBLIC
GO

REVOKE EXECUTE ON sys.xp_sprintf TO PUBLIC
GO

REVOKE EXECUTE ON sys.xp_sscanf TO PUBLIC
GO
