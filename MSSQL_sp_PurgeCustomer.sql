USE [master]
GO
/****** StoredProcedure [dbo].[PurgeCustomer] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[PurgeCustomer] @AccountName NVARCHAR(255)
AS
BEGIN
    begin tran
	-- set account number here:
	declare @account_number nvarchar(255) = @AccountName;
	declare @error bit = 0;

	begin try
	declare @Usernames table (
		username nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS not null
	);

	insert @Usernames
	select AA_l.username from AtomiaAccount..login AA_l
	inner join AtomiaAccount..account AA_a on AA_l.fk_account_id = AA_a.id
	where AA_a.name = @account_number;

	--==== AtomiaUserManagement =====--
	declare @UserIds table (
		userid uniqueidentifier not null
	);
		
	insert @UserIds
	select UserId from AtomiaUserManagement..aspnet_Users
	where UserName COLLATE DATABASE_DEFAULT in (select username from @Usernames);

	delete from AtomiaUserManagement..aspnet_Membership where UserId in (select userid from @UserIds)

	delete from AtomiaUserManagement..aspnet_PersonalizationPerUser where UserId in (select userid from @UserIds)

	delete from AtomiaUserManagement..aspnet_Profile where UserId in (select userid from @UserIds)

	delete from AtomiaUserManagement..aspnet_UsersInRoles where UserId in (select userid from @UserIds)

	delete from AtomiaUserManagement..aspnet_Users where UserId in (select userid from @UserIds)
	--==============================--

	--===== AtomiaIdentity =====--
	delete from AtomiaIdentity..identity_properties where username in (select username from @Usernames)

	delete from AtomiaIdentity..one_time_login_tokens where username in (select username from @Usernames)

	delete from AtomiaIdentity..reset_password_requests where username in (select username from @Usernames)
	--==============================--

	--===== AtomiaProvisioning2 =====--
	declare @ServiceStruct table (
		ParentId uniqueidentifier,
		LServiceId uniqueidentifier not null,
		PServiceId uniqueidentifier not null,
		ServiceLevel int not null
	);

	WITH ParentStruct (ParentId, ServiceId, PSID, Level)
	AS
	(
	-- Anchor member definition
		SELECT s.parent_id, s.lid, s.fk_sid, 
			0 AS Level
		FROM AtomiaProvisioning2..service_logical_struct AS s
		WHERE s.parent_id IS NULL and s.fk_account_id = @account_number
		UNION ALL
	-- Recursive member definition
		SELECT s.parent_id, s.lid, s.fk_sid,
			Level + 1
		FROM AtomiaProvisioning2..service_logical_struct AS s
		INNER JOIN ParentStruct AS d
			ON s.parent_id = d.ServiceId and s.fk_account_id = @account_number
	)
	-- Statement that executes the CTE
	insert @ServiceStruct
	SELECT ParentId, ServiceId, PSID, Level
	FROM ParentStruct;

	DECLARE @i int;
	select @i = max(ServiceLevel) from @ServiceStruct;

	WHILE @i >= 0 
	BEGIN
		delete from AtomiaProvisioning2..sspa_extension where fk_sspa_id in (select sspa.id from AtomiaProvisioning2..simple_service_provisioning_actions sspa
																				inner join @ServiceStruct ss on sspa.fk_logical_service_id = ss.LServiceId
																				where ss.ServiceLevel = @i);
		delete from AtomiaProvisioning2..sspa_original_properties where fk_sspa in (select sspa.id from AtomiaProvisioning2..simple_service_provisioning_actions sspa
																				inner join @ServiceStruct ss on sspa.fk_logical_service_id = ss.LServiceId
																				where ss.ServiceLevel = @i);
		delete from AtomiaProvisioning2..simple_service_provisioning_actions where fk_logical_service_id in (select LServiceId from @ServiceStruct where ServiceLevel = @i);
		delete from AtomiaProvisioning2..service_logical_struct where lid in (select LServiceId from @ServiceStruct where ServiceLevel = @i);
	    
		SET @i = @i - 1;
	END

	delete from AtomiaProvisioning2..services_in_command where fk_service_id in (select PServiceId from @ServiceStruct);
	delete from AtomiaProvisioning2..params where fk_sid in (select PServiceId from @ServiceStruct);
	delete from AtomiaProvisioning2..original_service where fk_sid in (select PServiceId from @ServiceStruct);
	delete from AtomiaProvisioning2..dpc_original_properties where fk_op in (select id from AtomiaProvisioning2..original_properties where fk_sid in (select PServiceId from @ServiceStruct));
	delete from AtomiaProvisioning2..original_properties where fk_sid in (select PServiceId from @ServiceStruct);
	delete from AtomiaProvisioning2..ucp_services where service_id in (select PServiceId from @ServiceStruct);

	delete from AtomiaProvisioning2..ext_packages_limits where fk_extendId in (select id from AtomiaProvisioning2..extending_packages where fk_pid in (select id from AtomiaProvisioning2..packages where account_id = @account_number));
	delete from AtomiaProvisioning2..extending_packages where fk_pid in (select id from AtomiaProvisioning2..packages where account_id = @account_number);
	delete from AtomiaProvisioning2..packages where account_id = @account_number;

	delete from AtomiaProvisioning2..account_properties where fk_account_id = @account_number;

	delete from AtomiaProvisioning2..accounts where account = @account_number;

	declare @Requests table (
		RequestId uniqueidentifier not null
	);

	insert @Requests
	select rid from AtomiaProvisioning2..provisioning_request where account_id = @account_number;

	delete from AtomiaProvisioning2..sspa_extension where fk_sspa_id in (select id from AtomiaProvisioning2..simple_service_provisioning_actions where fk_dbcmd_id in (select id from AtomiaProvisioning2..database_provisioning_commands where fk_rid in (select RequestId from @Requests)));
	delete from AtomiaProvisioning2..sspa_original_properties where fk_sspa in (select id from AtomiaProvisioning2..simple_service_provisioning_actions where fk_dbcmd_id in (select id from AtomiaProvisioning2..database_provisioning_commands where fk_rid in (select RequestId from @Requests)));
	delete from AtomiaProvisioning2..simple_service_provisioning_actions where fk_dbcmd_id in (select id from AtomiaProvisioning2..database_provisioning_commands where fk_rid in (select RequestId from @Requests));
	delete from AtomiaProvisioning2..dpc_original_properties where fk_dpc in (select id from AtomiaProvisioning2..database_provisioning_commands where fk_rid in (select RequestId from @Requests));
	delete from AtomiaProvisioning2..database_provisioning_commands where fk_rid in (select RequestId from @Requests);

	delete from AtomiaProvisioning2..original_service where fk_rid in (select RequestId from @Requests);

	delete from AtomiaProvisioning2..sspa_extension where fk_sspa_id in (select id from AtomiaProvisioning2..simple_service_provisioning_actions where fk_resource_cmd_id in (select resource_cmd_id from AtomiaProvisioning2..resource_provisioning_commands where fk_rid in (select RequestId from @Requests)));
	delete from AtomiaProvisioning2..sspa_original_properties where fk_sspa in (select id from AtomiaProvisioning2..simple_service_provisioning_actions where fk_resource_cmd_id in (select resource_cmd_id from AtomiaProvisioning2..resource_provisioning_commands where fk_rid in (select RequestId from @Requests)));
	delete from AtomiaProvisioning2..simple_service_provisioning_actions where fk_resource_cmd_id in (select resource_cmd_id from AtomiaProvisioning2..resource_provisioning_commands where fk_rid in (select RequestId from @Requests));
	delete from AtomiaProvisioning2..provisioning_journal where fk_cmd_id in (select resource_cmd_id from AtomiaProvisioning2..resource_provisioning_commands where fk_rid in (select RequestId from @Requests));
	delete from AtomiaProvisioning2..services_in_command where fk_cmd_id in (select resource_cmd_id from AtomiaProvisioning2..resource_provisioning_commands where fk_rid in (select RequestId from @Requests));
	delete from AtomiaProvisioning2..resource_provisioning_commands where fk_rid in (select RequestId from @Requests);

	delete from AtomiaProvisioning2..resource_request_description_extension where fk_resource_request_description_id in (select id from AtomiaProvisioning2..resource_request_description where fk_provisioning_request_id in (select RequestId from @Requests));
	delete from AtomiaProvisioning2..resource_request_description where fk_provisioning_request_id in (select RequestId from @Requests);

	delete from AtomiaProvisioning2..sspa_extension where fk_sspa_id in (select id from AtomiaProvisioning2..simple_service_provisioning_actions where fk_rid in (select RequestId from @Requests));
	delete from AtomiaProvisioning2..sspa_original_properties where fk_sspa in (select id from AtomiaProvisioning2..simple_service_provisioning_actions where fk_rid in (select RequestId from @Requests));
	delete from AtomiaProvisioning2..simple_service_provisioning_actions where fk_rid in (select RequestId from @Requests);

	delete from AtomiaProvisioning2..provisioning_request where rid in (select RequestId from @Requests);

	delete from AtomiaProvisioning2..disabled_service_properties where dsid in (select id from AtomiaProvisioning2..disabled_packages_log where accountId = @account_number);
	delete from AtomiaProvisioning2..disabled_packages_log where accountId = @account_number;

	delete from AtomiaProvisioning2..ucp_extended_log_data where log_entry_id in (select ID from AtomiaProvisioning2..ucp_log_data where account_id = @account_number);
	delete from AtomiaProvisioning2..ucp_log_data where account_id = @account_number;
	--==============================--

	--==== AtomiaBilling ====--
	declare @account_id uniqueidentifier;
	select @account_id = id from AtomiaAccount..account where name = @account_number;

	delete from AtomiaBilling..pay_file_record_custom_attribute where fk_pay_file_record_id in (select id from AtomiaBilling..pay_file_record where fk_pay_file_process_log_id in (select id from AtomiaBilling..pay_file_process_log where fk_account_id = @account_id));
	delete from AtomiaBilling..pay_file_record where fk_pay_file_process_log_id in (select id from AtomiaBilling..pay_file_process_log where fk_account_id = @account_id);
	delete from AtomiaBilling..pay_file_process_log where fk_account_id = @account_id;

	delete from AtomiaBilling..usage_log where fk_customer_id = @account_id;

	delete from AtomiaBilling..account_status_change_request_custom_attribute where fk_account_status_change_request in (select id from AtomiaBilling..account_status_change_request where fk_customer_id = @account_id);
	delete from AtomiaBilling..account_status_change_request where fk_customer_id = @account_id;

	delete from AtomiaBilling..account_note where fk_account_id = @account_id;

	delete from AtomiaBilling..account_details_custom_attribute where fk_account_id = @account_id;

	declare @account_options_id uniqueidentifier;
	select @account_options_id = fk_account_options_id from AtomiaBilling..account_details where account_id = @account_id;

	delete from AtomiaBilling..account_details where account_id = @account_id;
	delete from AtomiaBilling..outstanding_balance_limit where fk_account_options_id = @account_options_id;

	while @account_options_id is not null
	begin
		declare @tmp_options_id uniqueidentifier = @account_options_id;
		select @account_options_id = fk_subaccount_options_id from AtomiaBilling..account_options where id = @tmp_options_id;
		delete from AtomiaBilling..account_options where id = @tmp_options_id;
	end

	declare @BulkJobs table (
		JobId uniqueidentifier not null
	);

	insert @BulkJobs
	select fk_bulk_send_job_id from AtomiaBilling..bulk_send_status where external_id = @account_id;

	delete from AtomiaBilling..bulk_send_status where external_id = @account_id;
	delete from AtomiaBilling..bulk_send_job where id in (select JobId from @BulkJobs);

	declare @InvoiceIds table (
		InvoiceId uniqueidentifier not null
	);

	insert @InvoiceIds
	select id from AtomiaBilling..invoice where customer_id = @account_id;

	delete from AtomiaBilling..credited_invoice_line_custom_attribute where fk_invoice_line_id in (select id from AtomiaBilling..credited_invoice_line where fk_invoice_id in (select id from AtomiaBilling..credited_invoice where fk_invoice_id in (select InvoiceId from @InvoiceIds)));
	delete from AtomiaBilling..created_invoice_line_tax where fk_invoice_line_id in (select id from AtomiaBilling..credited_invoice_line where fk_invoice_id in (select id from AtomiaBilling..credited_invoice where fk_invoice_id in (select InvoiceId from @InvoiceIds)));
	delete from AtomiaBilling..credited_invoice_line where fk_invoice_id in (select id from AtomiaBilling..credited_invoice where fk_invoice_id in (select InvoiceId from @InvoiceIds));
	delete from AtomiaBilling..credited_invoice_custom_attribute where fk_invoice_id in (select id from AtomiaBilling..credited_invoice where fk_invoice_id in (select InvoiceId from @InvoiceIds));
	delete from AtomiaBilling..credited_invoice where fk_invoice_id in (select InvoiceId from @InvoiceIds);

	delete from AtomiaBilling..invoice_line_custom_attribute where fk_invoice_line_id in (select id from AtomiaBilling..invoice_line where fk_invoice_id in (select InvoiceId from @InvoiceIds));
	delete from AtomiaBilling..invoice_line_item_usage where fk_invoice_line_id in (select id from AtomiaBilling..invoice_line where fk_invoice_id in (select InvoiceId from @InvoiceIds));
	delete from AtomiaBilling..invoice_line_tax where fk_invoice_line_id in (select id from AtomiaBilling..invoice_line where fk_invoice_id in (select InvoiceId from @InvoiceIds));
	delete from AtomiaBilling..invoice_line_custom_attribute where fk_invoice_line_id in (select id from AtomiaBilling..invoice_line where fk_invoice_id in (select InvoiceId from @InvoiceIds));
	delete from AtomiaBilling..invoice_line where fk_invoice_id in (select InvoiceId from @InvoiceIds);

	delete from AtomiaBilling..invoice_custom_attribute where fk_invoice_id in (select InvoiceId from @InvoiceIds);

	delete from AtomiaBilling..payment_custom_attribute where fk_payment_id in (select id from AtomiaBilling..payment where fk_invoice_id in (select InvoiceId from @InvoiceIds));
	delete from AtomiaBilling..payment where fk_invoice_id is null and fk_original_payment_id in (select id from AtomiaBilling..payment where fk_invoice_id in (select InvoiceId from @InvoiceIds));
	delete from AtomiaBilling..payment where fk_invoice_id in (select InvoiceId from @InvoiceIds);
	delete from AtomiaBilling..payment where new_invoice_id in (select InvoiceId from @InvoiceIds);

	delete from AtomiaBilling..payment_transaction_custom_attribute_data where fk_payment_transaction_id in (select id from AtomiaBilling..payment_transaction where transaction_reference_type = '1' and transaction_reference in (select reference_number from AtomiaBilling..invoice where customer_id = @account_id));
	delete from AtomiaBilling..payment_transaction where transaction_reference_type = '1' and transaction_reference in (select reference_number from AtomiaBilling..invoice where customer_id = @account_id);

	delete from AtomiaBilling..provisioning_action_custom_attribute where fk_provisioning_action_id in (select id from AtomiaBilling..provisioning_action where item_id in (select id from AtomiaBilling..subscription where fk_customer_id = @account_id));
	delete from AtomiaBilling..provisioning_action where item_id in (select id from AtomiaBilling..subscription where fk_customer_id = @account_id);
	delete from AtomiaBilling..subscription_price where fk_subscription_id in (select id from AtomiaBilling..subscription where fk_customer_id = @account_id);
	delete from AtomiaBilling..subscription_custom_attribute where fk_subscription_id in (select id from AtomiaBilling..subscription where fk_customer_id = @account_id);
	delete from AtomiaBilling..subscription_termination_request where fk_subscription_id in (select id from AtomiaBilling..subscription where fk_customer_id = @account_id);
	delete from AtomiaBilling..subscription where fk_customer_id = @account_id;

	delete from AtomiaBilling..invoice where customer_id = @account_id;

	delete from AtomiaBilling..order_line_tax where fk_order_line_id in (select id from AtomiaBilling..order_line where fk_order_id in (select id from AtomiaBilling..order_data where customer_id = @account_id));
	delete from AtomiaBilling..order_line_custom_attribute where fk_order_line_id in (select id from AtomiaBilling..order_line where fk_order_id in (select id from AtomiaBilling..order_data where customer_id = @account_id));
	delete from AtomiaBilling..order_line where fk_order_id in (select id from AtomiaBilling..order_data where customer_id = @account_id);

	delete from AtomiaBilling..order_custom_attribute where fk_order_id in (select id from AtomiaBilling..order_data where customer_id = @account_id);
	delete from AtomiaBilling..attached_document where fk_external_id in (select id from AtomiaBilling..order_data where customer_id = @account_id);

	delete from AtomiaBilling..payment_transaction_custom_attribute_data where fk_payment_transaction_id in (select id from AtomiaBilling..payment_transaction where transaction_reference_type = '2' and transaction_reference in (select number from AtomiaBilling..order_data where customer_id = @account_id));
	delete from AtomiaBilling..payment_transaction where transaction_reference_type = '2' and transaction_reference in (select number from AtomiaBilling..order_data where customer_id = @account_id);

	delete from AtomiaBilling..order_data where customer_id = @account_id;

	delete from AtomiaBilling..tasks_to_run where customer_id = @account_id;

	delete from AtomiaBilling..account_lifecycle_custom_attribute where fk_account_id = @account_id;

	delete from AtomiaBilling..autocredit_request where fk_customer_id = @account_id;

	delete from AtomiaBilling..billing_authorization_schema_login where fk_account_id = @account_id;
	delete from AtomiaBilling..billing_authorization_schema_role where fk_account_id = @account_id;

	delete from @BulkJobs;
	insert @BulkJobs
	select fk_bulk_send_job_id from AtomiaBilling..bulk_send_status where external_id in (select InvoiceId from @InvoiceIds) and entity = 'Invoice';

	delete from AtomiaBilling..bulk_send_status where external_id in (select InvoiceId from @InvoiceIds) and entity = 'Invoice';
	delete from AtomiaBilling..bulk_send_job where id in (select JobId from @BulkJobs);

	delete from AtomiaBilling..log_extended_data where log_entry_id in (select id from AtomiaBilling..log_data where account_id = @account_number);
	delete from AtomiaBilling..log_data where account_id = @account_number;

	declare @MailingLists table (
		ListId uniqueidentifier not null
	);

	insert @MailingLists
	select fk_mailing_list_id from AtomiaBilling..mailing_list_subscription where customer_id = @account_id;

	delete from AtomiaBilling..mailing_list_subscription where customer_id = @account_id;
	delete from AtomiaBilling..mailing_list where id in (select ListId from @MailingLists);

	delete from AtomiaBilling..notification where external_id in (select InvoiceId from @InvoiceIds) and discriminator = 'Invoice';
	delete from AtomiaBilling..usage_log where fk_customer_id = @account_id;
	--==============================--

	--==== AtomiaAccount =====--
	declare @main_address_id uniqueidentifier, @billing_address_id uniqueidentifier, @shipping_address_id uniqueidentifier;
	select @main_address_id = fk_main_address_id, @billing_address_id = fk_billing_address_id, @shipping_address_id = fk_shipping_address_id
	from AtomiaAccount..account where id = @account_id;

	delete from AtomiaAccount..login where fk_account_id = @account_id;
	delete from AtomiaAccount..account_custom_attribute where fk_account_id = @account_id;
	delete from AtomiaAccount..account where id = @account_id;

	delete from AtomiaAccount..account_address where id = @main_address_id;
	delete from AtomiaAccount..account_address where id = @billing_address_id;
	delete from AtomiaAccount..account_address where id = @shipping_address_id;
	--==============================--
	end try

	begin catch
		rollback;
		set @error = 1;
		SELECT 
			ERROR_NUMBER() AS ErrorNumber,
			ERROR_MESSAGE() AS ErrorMessage,
			'Sucessful' as RollbackOnError;
	end catch;

	if @error = 0
	begin
		commit --put commit here when sure you want to delete permanently:
		--rollback
	end
END
