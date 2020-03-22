Use ShellTest;
go

CREATE TABLE dbo.HrResOutCapRecieve ([Date] DATE NOT NULL,
								[HourEnding] float not null,
								[TotalResourceMW] INT NULL,
								[TotalIRRMW] INT NULL,
								[TotalNewEquipResourceMW] INT NULL)
				GO

CREATE TABLE dbo.HourlyResOutCap ( [OutageCapID] INT IDENTITY NOT NULL,
								[Date] DATE NOT NULL,
								[HourEnding] float not null,
								[TotalResourceMW] INT NULL,
								[TotalIRRMW] INT NULL,
								[TotalNewEquipResourceMW] INT NULL
							
				CONSTRAINT PK_OutageCap PRIMARY KEY  CLUSTERED (OutageCapID));


									GO
CREATE TABLE dbo.HrResOutCap_Nrm (HrOutageCapID INT IDENTITY NOT NULL,
								[Date] DATE NOT NULL,
								[HourEnding] float NOT NULL,
								ResourceType CHAR (30) NOT NULL,
								TotalMW INT NULL
							CONSTRAINT PK_HrOutageCap PRIMARY KEY  CLUSTERED (HrOutageCapID));	
						GO

----DATA INSERT TRIGGERS ---



CREATE TRIGGER TR_OutageCap ON dbo.HrResOutCapRecieve
AFTER INSERT, UPDATE
AS 
BEGIN
BEGIN TRY
INSERT INTO dbo.HourlyResOutCap ([Date],
								[HourEnding],
								[TotalResourceMW],
								[TotalIRRMW],
								[TotalNewEquipResourceMW])

SELECT [Date],[HourEnding],[TotalResourceMW],[TotalIRRMW],[TotalNewEquipResourceMW]
FROM inserted
WHERE NOT EXISTS ( SELECT * FROM dbo.HourlyResOutCap WHERE [Date] = INSERTED.[Date])
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW;
PRINT ' These recods already exist'
END CATCH
END



CREATE TRIGGER  TR_UNPIV_HROC ON dbo.HourlyResOutCap
AFTER INSERT, UPDATE
AS
BEGIN
BEGIN TRY
INSERT INTO  dbo.HrResOutCap_Nrm ([Date],[HourEnding],[ResourceType],[TotalMW])

SELECT DISTINCT [Date],[HourEnding],[ResourceType],[TotalMW] FROM
(SELECT [Date],[HourEnding], [TotalResourceMW],[TotalIRRMW],[TotalNewEquipResourceMW]
FROM INSERTED ) P
UNPIVOT
( [TotalMW] FOR [ResourceType] IN ( [TotalResourceMW],[TotalIRRMW],
								[TotalNewEquipResourceMW]))  AS  UNPIV
WHERE NOT EXISTS ( SELECT *FROM [dbo].[HrResOutCap_Nrm] WHERE [Date] = UNPIV.[Date])
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW
PRINT ' Unpivot records already exist'
END CATCH
END;










INSERT INTO [dbo].[HrResOutCapRecieve] ([Date],[HourEnding],
[TotalResourceMW],[TotalIRRMW],[TotalNewEquipResourceMW])

SELECT CONVERT( DATE, [ns1:Date])
      ,[ns1:HourEnding]
      ,CAST ([ns1:TotalResourceMW] AS INT)
      ,CAST ([ns1:TotalIRRMW] AS INT)
      ,cAST ([ns1:TotalNewEquipResourceMW] AS INT)
  FROM [ShellTest].[dbo].[dbo.HResOutCap]



								
DELETE  FROM [dbo].[HourlyResOutCap]
DELETE FROM [dbo].[HrResOutCap_Nrm]
DELETE FROM [dbo].[HrResOutCapRecieve]





 

SELECT OBJECT_SCHEMA_NAME(tables.object_id,db_id()) AS SchemaName,
tables.name As TableName
FROM sys.tables tables join sys.indexes indexes
ON tables.object_id=indexes.object_id
WHERE indexes.is_primary_key=0
GO