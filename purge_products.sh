#!/bin/bash

if [ -z "$1" ] ; then
        echo "usage: $0 article-number|--all|--list"
        echo "example:"
        echo -e "$0 --all                \t# will cleanup all database "
        echo -e "$0 --list products.txt \t# will take the product id from the eg. products.txt and cleanup all related data in database"
        echo -e "\t\t\t\t\t\t# (if second argument not given, it will search for product.list in current folder)"
        echo -e "$0 DMN-COM               \t# will remove product DMN-COM and all related data in database"
        exit 1
fi

if [ ! -z "$2" ] ; then
    LIST_PATH=$2
else
    LIST_PATH="product.list"
fi

DBUSER="atomia"
ITEM_ID=


### Create Function AtomiaBilling
psql atomiabilling $DBUSER << 'EOF'
CREATE OR REPLACE FUNCTION "public"."purgeproductdata"(VARCHAR)
  RETURNS "pg_catalog"."varchar" AS $BODY$
DECLARE _product_id UUID;
BEGIN
	SELECT id INTO _product_id FROM item WHERE article_number = $1::VARCHAR ;
	--RAISE NOTICE '_product_id is %', _product_id;


	DELETE FROM international WHERE external_id = _product_id;
	DELETE FROM item_property WHERE fk_item_id = _product_id;
	DELETE FROM item_price WHERE fk_item_id = _product_id;
	DELETE FROM item_locations WHERE fk_item_id = _product_id;
	DELETE FROM item_locations WHERE fk_item_id = _product_id;
	DELETE FROM item_included_service_configuration_value WHERE fk_item_included_service_configuration_id IN (SELECT id FROM item_included_service_configuration WHERE fk_item_id = _product_id);
	DELETE FROM item_included_service_configuration WHERE fk_item_id = _product_id;


	DROP TABLE IF EXISTS _renewalperiod;
	CREATE temp TABLE _renewalperiod (
		periodid uuid NOT NULL
	);

	INSERT INTO _renewalperiod	SELECT id FROM renewal_period WHERE fk_item_id = _product_id;

	DELETE FROM item_price WHERE fk_renewal_period_id IN (SELECT periodid FROM _renewalperiod);
	DELETE FROM renewal_period WHERE fk_item_id = _product_id;

	DROP TABLE IF EXISTS _counters;
	CREATE temp TABLE _counters (
		counterid uuid NOT NULL
	);

	INSERT INTO _counters	SELECT id FROM counter_range WHERE fk_counter_type_id IN (SELECT id FROM counter_type WHERE fk_item_id = _product_id);

	DELETE FROM item_price WHERE fk_counter_range_id IN (SELECT counterid FROM _counters);
	DELETE FROM counter_range WHERE id IN (SELECT counterid FROM _counters);
	DELETE FROM counter_type WHERE fk_item_id = _product_id;

	DROP TABLE IF EXISTS _shopitems;
	CREATE temp TABLE _shopitems (
		shopitemid uuid NOT NULL
	);
	
	INSERT INTO _shopitems	SELECT id FROM shop_item WHERE fk_item_id = _product_id;
	
	DELETE FROM shop_item_shop_item_category WHERE fk_shop_item_id IN (SELECT shopitemid FROM _shopitems);
	DELETE FROM shop_item_property WHERE fk_shop_item_id IN (SELECT shopitemid FROM _shopitems);
	
	DELETE FROM shop_item WHERE fk_item_id = _product_id;
	
	DELETE FROM item WHERE article_number = _product_id;
	

	RETURN 'Product (' || $1 || ') is removed from AtomiaBilling!';
END
$BODY$
  LANGUAGE 'plpgsql' VOLATILE COST 100
;
ALTER FUNCTION "public"."purgeproductdata"(VARCHAR) OWNER TO "atomia";
EOF

###### EXECUTE ######

function remove {

ITEM_ID=$1
echo "----- Removing $ITEM_ID -----"

# Execute (purgeproductdata) function over AtomiaBilling db
	echo "-- Cleaning AtomiaBilling --"
	psql -X -U atomia -c "SELECT purgeproductdata('$ITEM_ID');" -d atomiabilling

}

function removefromlist {
for LIST in $(cat $LIST_PATH)
	do
		remove $LIST
	done
exit 1
}

function removeall {
psql -X -U atomia -c "select * from item;" --single-transaction --set AUTOCOMMIT=off --set ON_ERROR_STOP=on --no-align -t --field-separator ' ' --quiet -d atomiabilling | \
while read item; do
	remove $item
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