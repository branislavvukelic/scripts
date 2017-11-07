-- Script to set recovery to simple
-- and shrink all databases
CREATE TABLE #DataBases (ID INT IDENTITY, Name NVARCHAR(100))

INSERT #DataBases
SELECT NAME FROM sys.databases WHERE NAME NOT IN ('master','model','msdb','tempdb')

DECLARE @Count INT = 1
DECLARE @NrOfDBs INT = 0

SELECT @NrOfDBs = COUNT(0) FROM #DataBases

DECLARE @DBName NVARCHAR(100), @SQL NVARCHAR(MAX)

WHILE (@Count < @NrOfDBs)
BEGIN
     SELECT @DBName = Name FROM #DataBases WHERE ID = @Count

     SELECT @SQL = 'ALTER DATABASE [' + @DBName + '] SET RECOVERY SIMPLE'

     PRINT(@SQL)
     EXEC(@SQL)

     --Shrink Database
     DBCC SHRINKDATABASE (@DBName , 0)
     
     SET @Count = @Count + 1
END

DROP TABLE #DataBases