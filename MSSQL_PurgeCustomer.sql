-- This script will remove all customer accounts except 100000 
-- and remove related data using sp_PurgeCustomer
SET NOCOUNT ON;

SELECT name as Name
INTO #AccountNamesTable
FROM [AtomiaAccount]..account
WHERE fk_parent_account_id IS NOT NULL
ORDER BY name DESC

DECLARE @AccountName NVARCHAR(255);

DECLARE account_cursor CURSOR FOR 
SELECT Name
FROM #AccountNamesTable

OPEN account_cursor

FETCH NEXT FROM account_cursor 
INTO @AccountName

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Purging customer ' + @AccountName    
    
    EXEC PurgeCustomer @AccountName
    
    PRINT 'Purged customer ' + @AccountName
    
    FETCH NEXT FROM account_cursor 
    INTO @AccountName
END 
CLOSE account_cursor;
DEALLOCATE account_cursor;
DROP TABLE #AccountNamesTable