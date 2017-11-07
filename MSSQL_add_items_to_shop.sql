SET NOCOUNT ON
USE AtomiaBilling

-- Common for all shops
DECLARE
	@reseller_id uniqueidentifier = 'B77B8B91-741B-4CF1-88B4-FEB21550055C',
	@ShopName VARCHAR(255),
	@default_shop bit = 1,
	@active_from datetime = '2016-01-01 00:00:00.000',
	@active_to datetime = '2066-01-01 00:00:00.000',
	@created_time datetime = '2016-03-15 00:00:00.000',
	@last_update_time datetime = '2016-03-15 00:00:00.000',
	@deleted_shop bit = 0

SET @ShopName = 'DefaultShop' 

	BEGIN
		-- Adding shop
		IF NOT EXISTS (SELECT * FROM shop WHERE name = @ShopName)
			BEGIN
			PRINT 'ADDING SHOP: ' + @ShopName
			INSERT INTO shop VALUES
			(NEWID(), @reseller_id, @default_shop, @ShopName, @active_from, @active_to, @created_time, @last_update_time, @deleted_shop)
			END
		ELSE
			BEGIN
			PRINT 'UPDATE ONLY: ' + @ShopName
			UPDATE shop SET
			fk_reseller_id = @reseller_id,
			default_shop = @default_shop,
			active_from = @active_from,
			active_to = @active_to,
			created_time = @created_time,
			last_update_time = @last_update_time,
			deleted = @deleted_shop
			WHERE name = @ShopName
			END
		PRINT 'Done... '
	END


-- Adding Products to Shops
DECLARE @ItemName NVARCHAR(255)
DECLARE @ItemGroup NVARCHAR(255)
DECLARE @ShopNamed NVARCHAR(255)
DECLARE @ItemShop VARCHAR(MAX)
DECLARE @ItemID uniqueidentifier
DECLARE @ShopItemCategory NVARCHAR(255)
DECLARE @ShopID uniqueidentifier
DECLARE @MaxOrder integer
DECLARE @ShopItemID nvarchar(255)

DECLARE item_cursor CURSOR
FOR
SELECT article_number
FROM item

OPEN item_cursor

FETCH NEXT
FROM item_cursor
INTO @ItemName

set @ItemShop = @ShopName


WHILE @@FETCH_STATUS = 0
	BEGIN
		set @ItemGroup = 'General' -- set Shop Item Category 
		-- we pull shop id from shop
		set @ItemID = ( SELECT id FROM AtomiaBilling.dbo.item WHERE article_number = @ItemName )
		IF @ItemID IS NULL 
			BEGIN
			PRINT 'MISSING ITEM NAME: ' + @ItemName
				FETCH NEXT
				FROM item_cursor
				INTO @ItemName
			END
		ELSE
			BEGIN
			set @ShopItemCategory = ( SELECT id FROM AtomiaBilling.dbo.shop_item_category WHERE category_name = @ItemGroup )
			-- Add ITEM to Shop
			set @ShopID = ( SELECT id FROM AtomiaBilling.dbo.shop WHERE name = @ItemShop )
			IF NOT EXISTS ( SELECT * FROM shop_item WHERE fk_shop_id = @ShopID and fk_item_id = @ItemID )
					BEGIN
					
					set @MaxOrder = (SELECT 
						CASE WHEN ( SELECT MAX(order_by) FROM shop_item WHERE fk_shop_id = @ShopID ) IS NULL THEN 0 
							 ELSE ( SELECT MAX(order_by) FROM shop_item WHERE fk_shop_id = @ShopID ) END
					) + 1 
						
					INSERT INTO shop_item (id, fk_shop_id, fk_item_id, order_by) VALUES
					(NEWID(), @ShopID, @ItemID, @MaxOrder)
					END

				set @ShopItemID = ( SELECT id FROM shop_item WHERE fk_shop_id = @ShopID and fk_item_id = @ItemID )
				IF NOT EXISTS ( SELECT * FROM shop_item_shop_item_category WHERE fk_shop_item_id = @ShopItemID and fk_category_id = @ShopItemCategory )
					BEGIN
					INSERT INTO shop_item_shop_item_category VALUES
					(NEWID(), @ShopItemID, @ShopItemCategory)
					END
			--PRINT 'Done... '
			
			FETCH NEXT
			FROM item_cursor
			INTO @ItemName
		END
	END

CLOSE item_cursor
DEALLOCATE item_cursor