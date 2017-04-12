#!/bin/bash

if [ -z "$1" ] ; then
        echo "usage: $0 acccount|--all|--list"
        echo "example:"
        echo -e "$0 --all                \t# will cleanup all database "
        echo -e "$0 --list customers.txt \t# will take the account number from the eg. customers.txt and cleanup all related data in databases"
        echo -e "\t\t\t\t\t# (if second argument not given, it will search for user.list in current folder)"
        echo -e "$0 100001               \t# will remove account 100001 and all related data in databases"
        exit 1
fi

if [ ! -z "$2" ] ; then
    LIST_PATH=$2
else
    LIST_PATH="user.list"
fi

DBUSER="atomia"
CUSTOMER_ACCOUNT=

### Create Function AtomiaUserManagement
psql atomiausermanagement $DBUSER << 'EOF'
CREATE OR REPLACE FUNCTION "public"."purgetestdata"(int4)
  RETURNS "pg_catalog"."varchar" AS $BODY$
BEGIN
	DELETE FROM users_roles WHERE user_id = $1;
	DELETE FROM users WHERE user_id = $1;
	RETURN 'User ' || $1 || ' is removed from AtomiaUserManagement!';
END
$BODY$
  LANGUAGE 'plpgsql' VOLATILE COST 100
;
ALTER FUNCTION "public"."purgetestdata"(int4) OWNER TO "atomia";
EOF

### Create Function AtomiaIdentity
psql atomiaidentity $DBUSER << 'EOF'
CREATE OR REPLACE FUNCTION "public"."purgetestdata"(varchar)
  RETURNS "pg_catalog"."varchar" AS $BODY$
BEGIN
	DELETE FROM identity_properties WHERE username = $1;
	DELETE FROM one_time_login_tokens WHERE username = $1;
	DELETE FROM reset_password_requests WHERE username = $1;
	RETURN 'User ' || $1 || ' is removed from AtomiaIdentity!';
END
$BODY$
  LANGUAGE 'plpgsql' VOLATILE COST 100
;
ALTER FUNCTION "public"."purgetestdata"(varchar) OWNER TO "atomia";
EOF

### Create Function AtomiaProvisioning2
psql atomiaprovisioning2 $DBUSER << 'EOF'
CREATE OR REPLACE FUNCTION "public"."purgetestdata"(int4)
  RETURNS "pg_catalog"."varchar" AS $BODY$
DECLARE _account_number VARCHAR;
DECLARE _maxLevel INTEGER;
BEGIN

_account_number := $1::VARCHAR;

DROP TABLE IF EXISTS _servicestruct;
CREATE TEMP TABLE _servicestruct (
	ParentId uuid,
	lserviceid uuid not null,
	pserviceid uuid not null,
	servicelevel int not null
);

WITH RECURSIVE _parentstruct (ParentId, ServiceId, PSID, Level)
	AS
	(
	-- Anchor member definition
		SELECT s.parent_id, s.lid, s.fk_sid, 
			0 AS Level
		FROM service_logical_struct AS s
		WHERE s.parent_id IS NULL and s.fk_account_id = _account_number::VARCHAR
		UNION ALL
	-- Recursive member definition
		SELECT s.parent_id, s.lid, s.fk_sid,
			Level + 1
		FROM service_logical_struct AS s
		INNER JOIN _parentstruct AS d
			ON s.parent_id = d.ServiceId and s.fk_account_id = _account_number::VARCHAR
	)
	-- Statement that executes the CTE
	INSERT INTO _servicestruct (SELECT ParentId, ServiceId, PSID, Level	FROM _parentstruct);
	SELECT max(servicelevel) INTO _maxLevel FROM _servicestruct;

	WHILE _maxLevel >= 0 
	LOOP
		DELETE FROM sspa_extension WHERE fk_sspa_id IN (SELECT sspa.id FROM simple_service_provisioning_actions sspa inner join _servicestruct ss ON sspa.fk_logical_service_id = ss.lserviceid WHERE ss.servicelevel = _maxlevel);
		DELETE FROM sspa_original_properties WHERE fk_sspa IN (SELECT sspa.id FROM simple_service_provisioning_actions sspa inner join _servicestruct ss ON sspa.fk_logical_service_id = ss.lserviceid WHERE ss.servicelevel = _maxlevel);
		DELETE FROM simple_service_provisioning_actions WHERE fk_logical_service_id IN (SELECT lserviceid FROM _servicestruct WHERE servicelevel = _maxlevel);
		DELETE FROM service_logical_struct WHERE lid IN (SELECT lserviceid FROM _servicestruct WHERE servicelevel = _maxlevel);
		_maxLevel := _maxLevel - 1;
	END LOOP;
	
	DELETE FROM services_in_command WHERE fk_service_id IN (SELECT pserviceid FROM _servicestruct);
	DELETE FROM params WHERE fk_sid IN (SELECT pserviceid FROM _servicestruct);
	DELETE FROM original_service WHERE fk_sid IN (SELECT pserviceid FROM _servicestruct);
	DELETE FROM dpc_original_properties WHERE fk_op IN (SELECT id FROM original_properties WHERE fk_sid IN (SELECT pserviceid FROM _servicestruct));
	DELETE FROM original_properties WHERE fk_sid IN (SELECT pserviceid FROM _servicestruct);
	DELETE FROM ucp_services WHERE service_id IN (SELECT pserviceid FROM _servicestruct);
	DELETE FROM ext_packages_limits WHERE fk_extendid IN (SELECT id FROM extending_packages WHERE fk_pid IN (SELECT id FROM packages WHERE account_id = _account_number));
	DELETE FROM extending_packages WHERE fk_pid IN (SELECT id FROM packages WHERE account_id = _account_number);
	DELETE FROM packages WHERE account_id = _account_number;
	DELETE FROM account_properties WHERE fk_account_id = _account_number;
	DELETE FROM accounts WHERE account = _account_number;

	DROP TABLE IF exists _requests;
	CREATE TEMP TABLE _requests (
	requestid UUID NOT NULL
	);

	INSERT INTO _requests (SELECT rid FROM provisioning_request WHERE account_id = _account_number);
	DELETE FROM sspa_extension WHERE fk_sspa_id IN (SELECT id FROM simple_service_provisioning_actions WHERE fk_dbcmd_id IN (SELECT id FROM database_provisioning_commands WHERE fk_rid IN (SELECT requestid FROM _requests)));
	DELETE FROM sspa_original_properties WHERE fk_sspa IN (SELECT id FROM simple_service_provisioning_actions WHERE fk_dbcmd_id IN (SELECT id FROM database_provisioning_commands WHERE fk_rid IN (SELECT requestid FROM _requests)));
	DELETE FROM simple_service_provisioning_actions WHERE fk_dbcmd_id IN (SELECT id FROM database_provisioning_commands WHERE fk_rid IN (SELECT requestid FROM _requests));
	DELETE FROM dpc_original_properties WHERE fk_dpc IN (SELECT id FROM database_provisioning_commands WHERE fk_rid IN (SELECT requestid FROM _requests));
	DELETE FROM database_provisioning_commands WHERE fk_rid IN (SELECT requestid FROM _requests);
	DELETE FROM original_service WHERE fk_rid IN (SELECT requestid FROM _requests);
	DELETE FROM sspa_extension WHERE fk_sspa_id IN (SELECT id FROM simple_service_provisioning_actions WHERE fk_resource_cmd_id IN (SELECT resource_cmd_id FROM resource_provisioning_commands WHERE fk_rid IN (SELECT requestid FROM _requests)));
	DELETE FROM sspa_original_properties WHERE fk_sspa IN (SELECT id FROM simple_service_provisioning_actions WHERE fk_resource_cmd_id IN (SELECT resource_cmd_id FROM resource_provisioning_commands WHERE fk_rid IN (SELECT requestid FROM _requests)));
	DELETE FROM simple_service_provisioning_actions WHERE fk_resource_cmd_id IN (SELECT resource_cmd_id FROM resource_provisioning_commands WHERE fk_rid IN (SELECT requestid FROM _requests));
	DELETE FROM provisioning_journal WHERE fk_cmd_id IN (SELECT resource_cmd_id FROM resource_provisioning_commands WHERE fk_rid IN (SELECT requestid FROM _requests));
	DELETE FROM services_in_command WHERE fk_cmd_id IN (SELECT resource_cmd_id FROM resource_provisioning_commands WHERE fk_rid IN (SELECT requestid FROM _requests));
	DELETE FROM resource_provisioning_commands WHERE fk_rid IN (SELECT requestid FROM _requests);
	DELETE FROM resource_request_description_extension WHERE fk_resource_request_description_id IN (SELECT id FROM resource_request_description WHERE fk_provisioning_request_id IN (SELECT requestid FROM _requests));
	DELETE FROM resource_request_description WHERE fk_provisioning_request_id IN (SELECT requestid FROM _requests);
	DELETE FROM sspa_extension WHERE fk_sspa_id IN (SELECT id FROM simple_service_provisioning_actions WHERE fk_rid IN (SELECT requestid FROM _requests));
	DELETE FROM sspa_original_properties WHERE fk_sspa IN (SELECT id FROM simple_service_provisioning_actions WHERE fk_rid IN (SELECT requestid FROM _requests));
	DELETE FROM simple_service_provisioning_actions WHERE fk_rid IN (SELECT requestid FROM _requests);
	DELETE FROM provisioning_request WHERE rid IN (SELECT requestid FROM _requests);
	DELETE FROM disabled_service_properties WHERE dsid IN (SELECT id FROM disabled_packages_log WHERE accountid = _account_number);
	DELETE FROM disabled_packages_log WHERE accountid = _account_number;
	DELETE FROM ucp_extended_log_data WHERE log_entry_id IN (SELECT id FROM ucp_log_data WHERE account_id = _account_number);
	DELETE FROM ucp_log_data WHERE account_id = _account_number;

	RETURN 'User ' || $1 || ' is removed from AtomiaProvisioning2!';
END
$BODY$
  LANGUAGE 'plpgsql' VOLATILE COST 100
;
ALTER FUNCTION "public"."purgetestdata"(int4) OWNER TO "atomia";
EOF

### Create Function AtomiaBilling
psql atomiabilling $DBUSER << 'EOF'
CREATE OR REPLACE FUNCTION "public"."purgetestdata"(int4)
  RETURNS "pg_catalog"."varchar" AS $BODY$
DECLARE _account_id UUID;
DECLARE _account_options_id UUID;
DECLARE _main_address_id uuid;
DECLARE _billing_address_id uuid;
DECLARE _shipping_address_id uuid;
BEGIN
	SELECT id INTO _account_id FROM account WHERE name = $1::VARCHAR ;
	--RAISE NOTICE '_account_id is %', _account_id;

	DELETE FROM pay_file_record_custom_attribute WHERE fk_pay_file_record_id IN (SELECT id FROM pay_file_record WHERE fk_pay_file_process_log_id IN (SELECT id FROM pay_file_process_log WHERE fk_account_id = _account_id));
	DELETE FROM pay_file_record WHERE fk_pay_file_process_log_id IN (SELECT id FROM pay_file_process_log WHERE fk_account_id = _account_id);
	DELETE FROM pay_file_process_log WHERE fk_account_id = _account_id;

	DELETE FROM usage_log WHERE fk_customer_id = _account_id;

	DELETE FROM account_status_change_request_custom_attribute WHERE fk_account_status_change_request IN (SELECT id FROM account_status_change_request WHERE fk_customer_id = _account_id);
	DELETE FROM account_status_change_request WHERE fk_customer_id = _account_id;

	DELETE FROM account_note WHERE fk_account_id = _account_id;

	DELETE FROM account_details_custom_attribute WHERE fk_account_id = _account_id;

	SELECT fk_account_options_id INTO _account_options_id FROM account_details WHERE account_id = _account_id;
	--RAISE NOTICE '_account_options_id is %', _account_options_id;

	DELETE FROM account_details WHERE account_id = _account_id;
	DELETE FROM outstanding_balance_limit WHERE fk_account_options_id = _account_options_id;

	--WHILE _account_options_id IS NOT NULL
	--loop
	--	DECLARE _tmp_options_id uuid = _account_options_id;
	--	SELECT fk_subaccount_options_id INTO _account_options_id FROM account_options WHERE id = _tmp_options_id;
	--	DELETE FROM account_options WHERE id = _tmp_options_id;
	--END loop;

	DROP TABLE IF EXISTS _bulkjobs;
	CREATE temp TABLE _bulkjobs (
		jobid uuid NOT NULL
	);

	INSERT INTO _bulkjobs	SELECT fk_bulk_send_job_id FROM bulk_send_status WHERE external_id = _account_id;

	DELETE FROM bulk_send_status WHERE external_id = _account_id;
	DELETE FROM bulk_send_job WHERE id IN (SELECT jobid FROM _bulkjobs);

	DROP TABLE IF EXISTS _invoiceids;
	CREATE temp TABLE _invoiceids (
		invoiceid uuid NOT NULL
	);

	INSERT INTO _invoiceids	SELECT id FROM invoice WHERE customer_id = _account_id;

	DELETE FROM credited_invoice_line_custom_attribute WHERE fk_invoice_line_id IN (SELECT id FROM credited_invoice_line WHERE fk_invoice_id IN (SELECT id FROM credited_invoice WHERE fk_invoice_id IN (SELECT invoiceid FROM _invoiceids)));
	DELETE FROM created_invoice_line_tax WHERE fk_invoice_line_id IN (SELECT id FROM credited_invoice_line WHERE fk_invoice_id IN (SELECT id FROM credited_invoice WHERE fk_invoice_id IN (SELECT invoiceid FROM _invoiceids)));
	DELETE FROM credited_invoice_line WHERE fk_invoice_id IN (SELECT id FROM credited_invoice WHERE fk_invoice_id IN (SELECT invoiceid FROM _invoiceids));
	DELETE FROM credited_invoice_custom_attribute WHERE fk_invoice_id IN (SELECT id FROM credited_invoice WHERE fk_invoice_id IN (SELECT invoiceid FROM _invoiceids));
	DELETE FROM credited_invoice WHERE fk_invoice_id IN (SELECT invoiceid FROM _invoiceids);

	DELETE FROM invoice_line_custom_attribute WHERE fk_invoice_line_id IN (SELECT id FROM invoice_line WHERE fk_invoice_id IN (SELECT invoiceid FROM _invoiceids));
	DELETE FROM invoice_line_item_usage WHERE fk_invoice_line_id IN (SELECT id FROM invoice_line WHERE fk_invoice_id IN (SELECT invoiceid FROM _invoiceids));
	DELETE FROM invoice_line_tax WHERE fk_invoice_line_id IN (SELECT id FROM invoice_line WHERE fk_invoice_id IN (SELECT invoiceid FROM _invoiceids));
	DELETE FROM invoice_line_custom_attribute WHERE fk_invoice_line_id IN (SELECT id FROM invoice_line WHERE fk_invoice_id IN (SELECT invoiceid FROM _invoiceids));
	DELETE FROM invoice_line WHERE fk_invoice_id IN (SELECT invoiceid FROM _invoiceids);

	DELETE FROM invoice_custom_attribute WHERE fk_invoice_id IN (SELECT invoiceid FROM _invoiceids);

	DELETE FROM payment_custom_attribute WHERE fk_payment_id IN (SELECT id FROM payment WHERE fk_invoice_id IN (SELECT invoiceid FROM _invoiceids));
	DELETE FROM payment WHERE fk_invoice_id IS NULL AND fk_original_payment_id IN (SELECT id FROM payment WHERE fk_invoice_id IN (SELECT invoiceid FROM _invoiceids));
	DELETE FROM payment WHERE fk_invoice_id IN (SELECT invoiceid FROM _invoiceids);
	DELETE FROM payment WHERE new_invoice_id IN (SELECT invoiceid FROM _invoiceids);

	DELETE FROM payment_transaction_custom_attribute_data WHERE fk_payment_transaction_id IN (SELECT id FROM payment_transaction WHERE transaction_reference_type = '1' AND transaction_reference IN (SELECT reference_number FROM invoice WHERE customer_id = _account_id));
	DELETE FROM payment_transaction WHERE transaction_reference_type = '1' AND transaction_reference IN (SELECT reference_number FROM invoice WHERE customer_id = _account_id);

	DELETE FROM provisioning_action_custom_attribute WHERE fk_provisioning_action_id IN (SELECT id FROM provisioning_action WHERE item_id IN (SELECT id FROM subscription WHERE fk_customer_id = _account_id));
	DELETE FROM provisioning_action WHERE item_id IN (SELECT id FROM subscription WHERE fk_customer_id = _account_id);
	DELETE FROM subscription_price WHERE fk_subscription_id IN (SELECT id FROM subscription WHERE fk_customer_id = _account_id);
	DELETE FROM subscription_custom_attribute WHERE fk_subscription_id IN (SELECT id FROM subscription WHERE fk_customer_id = _account_id);
	DELETE FROM subscription WHERE fk_customer_id = _account_id;

	DELETE FROM invoice WHERE customer_id = _account_id;

	DELETE FROM order_line_tax WHERE fk_order_line_id IN (SELECT id FROM order_line WHERE fk_order_id IN (SELECT id FROM order_data WHERE customer_id = _account_id));
	DELETE FROM order_line_custom_attribute WHERE fk_order_line_id IN (SELECT id FROM order_line WHERE fk_order_id IN (SELECT id FROM order_data WHERE customer_id = _account_id));
	DELETE FROM order_line WHERE fk_order_id IN (SELECT id FROM order_data WHERE customer_id = _account_id);

	DELETE FROM order_custom_attribute WHERE fk_order_id IN (SELECT id FROM order_data WHERE customer_id = _account_id);
	DELETE FROM attached_document WHERE fk_external_id IN (SELECT id FROM order_data WHERE customer_id = _account_id);

	DELETE FROM payment_transaction_custom_attribute_data WHERE fk_payment_transaction_id IN (SELECT id FROM payment_transaction WHERE transaction_reference_type = '2' AND transaction_reference IN (SELECT NUMBER FROM order_data WHERE customer_id = _account_id));
	DELETE FROM payment_transaction WHERE transaction_reference_type = '2' AND transaction_reference IN (SELECT NUMBER FROM order_data WHERE customer_id = _account_id);

	DELETE FROM order_data WHERE customer_id = _account_id;

	DELETE FROM tasks_to_run WHERE customer_id = _account_id;

	DELETE FROM account_lifecycle_custom_attribute WHERE fk_account_id = _account_id;

	DELETE FROM autocredit_request WHERE fk_customer_id = _account_id;

	DELETE FROM billing_authorization_schema_login WHERE fk_account_id = _account_id;
	DELETE FROM billing_authorization_schema_role WHERE fk_account_id = _account_id;

	DELETE FROM _bulkjobs;

	INSERT INTO _bulkjobs
	SELECT fk_bulk_send_job_id FROM bulk_send_status WHERE external_id IN (SELECT invoiceid FROM _invoiceids) AND entity = 'Invoice';

	DELETE FROM bulk_send_status WHERE external_id IN (SELECT invoiceid FROM _invoiceids) AND entity = 'Invoice';
	DELETE FROM bulk_send_job WHERE id IN (SELECT jobid FROM _bulkjobs);

	DELETE FROM log_extended_data WHERE log_entry_id IN (SELECT id FROM log_data WHERE account_id = $1::VARCHAR );
	DELETE FROM log_data WHERE account_id = $1::VARCHAR ;

	DROP TABLE IF EXISTS _mailinglists;
	CREATE temp TABLE _mailinglists (
		listid uuid NOT NULL
	);

	INSERT INTO _mailinglists	SELECT fk_mailing_list_id FROM mailing_list_subscription WHERE customer_id = _account_id;

	DELETE FROM mailing_list_subscription WHERE customer_id = _account_id;
	DELETE FROM mailing_list WHERE id IN (SELECT listid FROM _mailinglists);

	DELETE FROM notification WHERE external_id IN (SELECT invoiceid FROM _invoiceids) AND discriminator = 'Invoice';
	DELETE FROM usage_log WHERE fk_customer_id = _account_id;

	RETURN 'User ' || $1 || ' is removed from AtomiaBilling!';
END
$BODY$
  LANGUAGE 'plpgsql' VOLATILE COST 100
;
ALTER FUNCTION "public"."purgetestdata"(int4) OWNER TO "atomia";
EOF

### Create Function AtomiaAccount
psql atomiaaccount $DBUSER << 'EOF'
CREATE OR REPLACE FUNCTION "public"."purgetestdata"(int4)
  RETURNS "pg_catalog"."varchar" AS $BODY$
DECLARE _account_id uuid;
DECLARE _main_address_id uuid;
DECLARE _billing_address_id uuid;
DECLARE _shipping_address_id uuid;
BEGIN
	--Routine body goes here...
	SELECT id, fk_main_address_id, fk_billing_address_id, fk_shipping_address_id
	INTO _account_id, _main_address_id, _billing_address_id, _shipping_address_id
	FROM account
	WHERE name = $1::VARCHAR;

	DELETE FROM login WHERE fk_account_id = _account_id;
	DELETE FROM account_custom_attribute WHERE fk_account_id = _account_id;
	DELETE FROM account WHERE id = _account_id;
	DELETE FROM account_address WHERE id = _main_address_id;
	DELETE FROM account_address WHERE id = _billing_address_id;
	DELETE FROM account_address WHERE id = _shipping_address_id;
	
	RETURN 'User ' || $1 || ' is removed from AtomiaAccount!';
END
$BODY$
  LANGUAGE 'plpgsql' VOLATILE COST 100
;
ALTER FUNCTION "public"."purgetestdata"(int4) OWNER TO "atomia";
EOF

###### EXECUTE ######

function remove {

CUSTOMER_ACCOUNT=$1
echo "----- Removing $CUSTOMER_ACCOUNT -----"

psql -X -U atomia -c "select AA_l.username from login AA_l inner join account AA_a on AA_l.fk_account_id = AA_a.id where AA_a.name = '$CUSTOMER_ACCOUNT';" --single-transaction --set AUTOCOMMIT=off --set ON_ERROR_STOP=on --no-align -t --field-separator ' ' --quiet -d atomiaaccount | \
while read username; do 
	psql -X -U atomia -c "select user_id from users where user_name = '$username';" --single-transaction --set AUTOCOMMIT=off --set ON_ERROR_STOP=on --no-align -t --field-separator ' ' --quiet -d atomiausermanagement | \
	while read user_id; do 
		## Execute Function AtomiaUserManagement
		echo "-- Cleaning AtomiaUserManagement --"
		psql -X -U atomia -c "SELECT purgetestdata('$user_id');" -d atomiausermanagement
	done
	## Execute Function AtomiaIdentity
	echo "-- Cleaning AtomiaIdentity --"
	psql -X -U atomia -c "SELECT purgetestdata('$username');" -d atomiaidentity
done

# Execute Function AtomiaProvisioning2
	echo "-- Cleaning AtomiaProvisioning2 --"
	psql -X -U atomia -c "SELECT purgetestdata('$CUSTOMER_ACCOUNT');" -d atomiaprovisioning2

# Execute Function AtomiaBilling
	echo "-- Cleaning AtomiaBilling --"
	psql -X -U atomia -c "SELECT purgetestdata('$CUSTOMER_ACCOUNT');" -d atomiabilling

# Execute Function AtomiaAccount
	echo "-- Cleaning AtomiaAccount --"
	psql -X -U atomia -c "SELECT purgetestdata('$CUSTOMER_ACCOUNT');" -d atomiaaccount
}

function removefromlist {
for LIST in $(cat $LIST_PATH)
	do
		remove $LIST
	done
exit 1
}

function removeall {
psql -X -U atomia -c "select name from account where name != '100000';" --single-transaction --set AUTOCOMMIT=off --set ON_ERROR_STOP=on --no-align -t --field-separator ' ' --quiet -d atomiaaccount | \
while read name; do
	remove $name
done
exit 1
}

while [ "$1" != "" ]; do
    case $1 in
        -a | --all )            removeall
                                ;;
        -l | --list )           removefromlist
                                ;;
        * )                     remove $1
                                exit 1
    esac
done