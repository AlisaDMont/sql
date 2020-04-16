USE ShellTest;
GO

-------------------------------------------------------------------------------------------
---Sheet 1  - LFMODSTUDYAREAS ----

CREATE TABLE dbo.LFModSARecieve (
						[DeliveryDate] DATE NOT NULL,
						[HourEnding] VARCHAR(10) NOT NULL,
						[Valley] DECIMAL (9,4) NULL,
						[Model] CHAR (5)NOT NULL,
						[DSTFlag] CHAR (1) NOT NULL);
				GO



CREATE TABLE dbo.DeliverDate (DateID INT IDENTITY NOT NULL, --<= DELIVERYDATE TBL
							[DeliveryDate] DATE NOT NULL
				CONSTRAINT PK_DATE PRIMARY KEY  CLUSTERED (DateID));

							GO

CREATE TABLE dbo.HourEnding (HourEndID INT IDENTITY NOT NULL, --<= HOURENDING TBL
							 [HourEnding]  varchar(10) NOT NULL
				CONSTRAINT PK_Hour PRIMARY KEY  CLUSTERED (HourEndID));

							GO
CREATE TABLE dbo.LFModStudyArea (LForcastID INT IDENTITY NOT NULL,
						[DateID] INT NOT NULL,
						HourEndID INT NOT NULL,
						[Valley] DECIMAL (9,4) NULL,
						[ModelID] INT NOT NULL,
						[DSTFlag] CHAR (1) NOT NULL
					CONSTRAINT PK_LFMSA PRIMARY KEY CLUSTERED (LForcastID));
				GO

ALTER TABLE [dbo].LFModStudyArea WITH  CHECK ADD CONSTRAINT FK_Date FOREIGN KEY (DateID)
REFERENCES dbo.DeliverDate (DateID);
GO

ALTER TABLE [dbo].LFModStudyArea  CHECK CONSTRAINT FK_Date;

GO

ALTER TABLE [dbo].LFModStudyArea WITH  CHECK ADD CONSTRAINT FK_Hour FOREIGN KEY (HourEndID)
REFERENCES dbo.HourEnding (HourEndID);
GO

ALTER TABLE [dbo].LFModStudyArea  CHECK CONSTRAINT FK_Hour;

GO
ALTER TABLE [dbo].LFModStudyArea WITH  CHECK ADD CONSTRAINT FK_Model FOREIGN KEY (ModelID)
REFERENCES dbo.LoadModel(ModelID);
GO

ALTER TABLE [dbo].LFModStudyArea  CHECK CONSTRAINT FK_Model;

GO

-----TRIGGERS ----

CREATE TRIGGER TR_DATE ON  dbo.LFModSARecieve
AFTER INSERT, UPDATE
AS
BEGIN
BEGIN TRY

INSERT INTO dbo.DeliverDate (DeliveryDate)

SELECT DISTINCT DeliveryDate
FROM INSERTED
WHERE NOT EXISTS( SELECT * FROM dbo.DeliverDate where DeliveryDate = INSERTED.DeliveryDate)
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW;
PRINT ' DeliveryDate already exists'
END CATCH
END;

GO

CREATE TRIGGER TR_Hour ON  dbo.LFModSARecieve
AFTER INSERT, UPDATE
AS
BEGIN
BEGIN TRY

INSERT INTO dbo.HourEnding (HourEnding)

SELECT DISTINCT HourEnding
FROM INSERTED
WHERE NOT EXISTS( SELECT * FROM dbo.HourEnding where HourEnding = INSERTED.HourEnding)
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW;
PRINT ' HourEnding already exists'
END CATCH
END;

GO
alter TRIGGER TR_LFMSA ON  dbo.LFModSARecieve
AFTER INSERT, UPDATE
AS
BEGIN
BEGIN TRY

INSERT INTO dbo.LFModStudyArea ([DateID],
						HourEndID,
						[Valley],
						[ModelID],
						[DSTFlag])

SELECT [DateID],HourEndID,[Valley],[ModelID],[DSTFlag]
FROM [dbo].[LFModSARecieve] INSERTED 
JOIN dbo.LoadModel m ON m.Model = inserted.Model 
JOIN dbo.DeliverDate d ON d.DeliveryDate = inserted.Deliverydate
JOIN dbo.HourEnding h ON h.HourEnding = inserted.HourEnding
WHERE NOT EXISTS( SELECT * FROM dbo.LFModStudyArea 
where DateID = d.DateID)
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW;
PRINT ' Records already exist'
END CATCH
END


----------------------------------------------------------------------------------------------
---Sheet 2 - LoadModelWF ---

CREATE TABLE dbo.LoadModelWeatherForecastRecieve
(	[DeliveryDate] DATE not NULL,
	[HourEnding] [varchar](10) NOT NULL,
	[Coast] DECIMAL (9,4) NULL,
	[East] DECIMAL (9,4) NULL,
	[FarWest] DECIMAL (9,4) NULL,
	[North] DECIMAL (9,4) NULL,
	[NorthCentral] DECIMAL (9,4) NULL,
	[SouthCentral] DECIMAL (9,4) NULL,
	[Southern] DECIMAL (9,4) NULL,
	[West] DECIMAL (9,4) NULL,
	[SystemTotal] DECIMAL (9,4) NULL,
	[Model] [varchar](6) NULL,
	[InUseFlag] [char](1) NULL,
	[DSTFlag] [char](1) NULL);


	CREATE TABLE Regions ( RegionID INT  not null identity,
	Regions varchar (20)
	CONSTRAINT PK_Regions PRIMARY KEY  CLUSTERED (RegionID));
	GO
	

	CREATE TABLE LoadModel (ModelID INT not null identity,
	[Model] [varchar](6) NULL
	CONSTRAINT PK_LoadModel PRIMARY KEY CLUSTERED (ModelID));

	CREATE TABLE dbo.LoadModelWeatherForecast
	(ForcastID INT not NULL IDENTITY,
	[DateID]  INT not NULL,
	[HourEndID] INT NOT NULL,
	RegionID int not null,
	RegionData DECIMAL (9,4) null,
	[SystemTotal] DECIMAL (9,4) NULL,
	ModelID int not null,
	[InUseFlag] [char](1) NULL,
	[DSTFlag] [char](1) NULL
	CONSTRAINT PK_Forkast PRIMARY KEY CLUSTERED (ForcastID));
	GO

ALTER TABLE [dbo].[LoadModelWeatherForecast] WITH  CHECK ADD CONSTRAINT FK_Regions  FOREIGN KEY (RegionID)
REFERENCES [dbo].[Regions] (RegionID);
GO

ALTER TABLE [dbo].[LoadModelWeatherForecast]   CHECK CONSTRAINT FK_Regions;


ALTER TABLE [dbo].[LoadModelWeatherForecast] WITH  CHECK ADD CONSTRAINT FK_LoadModel FOREIGN KEY (ModelID)
REFERENCES [dbo].[LoadModel] (ModelID);
GO

ALTER TABLE [dbo].[LoadModelWeatherForecast]   CHECK CONSTRAINT FK_LoadModel;

ALTER TABLE [dbo].[LoadModelWeatherForecast]  WITH  CHECK ADD CONSTRAINT FK_Delivery_Date_ID FOREIGN KEY (DateID)
REFERENCES [dbo].[DeliverDate] (DateID);
GO

ALTER TABLE [dbo].[LoadModelWeatherForecast]   CHECK CONSTRAINT FK_Delivery_Date_ID;

GO

ALTER TABLE [dbo].[LoadModelWeatherForecast]   WITH  CHECK ADD CONSTRAINT FK_Hour_Ending_ID FOREIGN KEY (HourEndID)
REFERENCES [dbo].[HourEnding] (HourEndID);
GO

ALTER TABLE [dbo].[LoadModelWeatherForecast]  CHECK CONSTRAINT FK_Hour_Ending_ID;

GO
---TRIGGER UNPIVOTED---

CREATE TRIGGER TR_Regios on [dbo].[LoadModelWeatherForecastRecieve]
After insert
AS
BEGIN
Begin Try
INSERT INTO [dbo].[Regions](Regions)

SELECT distinct Regions 
FROM ( SELECT  [Coast],[East],[FarWest],[North],
[NorthCentral],[SouthCentral],[Southern],[West]
 FROM inserted) P
UNPIVOT 
([SystemTotal] FOR Regions in ([Coast],[East],[FarWest],[North],
[NorthCentral],[SouthCentral],[Southern],[West])) as unpvt
where not exists ( select* from [dbo].[Regions] where Regions = unpvt.Regions)
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW
PRINT ' Region already exists'
END CATCH
END;

GO


CREATE TRIGGER TR_LModel ON [dbo].[LoadModelWeatherForecastRecieve]
AFTER INSERT
AS
BEGIN 
BEGIN TRY
INSERT INTO [dbo].[LoadModel] (Model)
SELECT DISTINCT [Model] FROM INSERTED
WHERE NOT EXISTS (SELECT*FROM[dbo].[LoadModel] WHERE [Model] = INSERTED.[Model])
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW
PRINT ' This Model already exists'
END CATCH
END



CREATE TRIGGER TR_LMWF ON [dbo].[LoadModelWeatherForecastRecieve]
AFTER INSERT
AS
BEGIN
BEGIN TRY
INSERT INTO [dbo].[LoadModelWeatherForecast]([DateID],[HourEndID],[RegionID],[RegionData],
[SystemTotal],[ModelID],[InUseFlag],[DSTFlag])

SELECT [DateID],[HourEndID],RegionID,[RegionData],[SystemTotal],[ModelID],
[InUseFlag],[DSTFlag]
FROM ( SELECT [DeliveryDate],[HourEnding], [Coast],[East],[FarWest],[North],
[NorthCentral],[SouthCentral],[Southern],[West],[SystemTotal],[Model],[InUseFlag],[DSTFlag]
 FROM inserted) p
UNPIVOT 
(RegionData FOR Regions in ([Coast],[East],[FarWest],[North],
[NorthCentral],[SouthCentral],[Southern],[West])) as unpvt
 join [dbo].[Regions] rg on rg.Regions = unpvt.Regions
 join [dbo].[LoadModel] m on m.[Model] = unpvt.[Model]
 join [dbo].[DeliverDate] d on d.[DeliveryDate] = unpvt.[DeliveryDate]
 join [HourEnding] h on h.[HourEnding] = unpvt.[HourEnding];
 WHERE NOT EXISTS (SELECT* FROM [dbo].[LoadModelWeatherForecast]
 WHERE [DateID] = d.DateID)
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW
PRINT ' These Records already exist'
END CATCH
END


 ---pivot test FOR [dbo].[LoadModelWeatherForecast]---
SELECT* FROM
(select [DateID],[HourEndID],[RegionID],[RegionData],[SystemTotal],[ModelID],[InUseFlag],[DSTFlag]
 FROM [dbo].[LoadModelWeatherForecast]) pvt
 PIVOT
 (  max ([RegionData]) FOR [RegionID] IN ([1],[2],[3],[4],[5],[6],[7],[8])) PvtResult
 order by HourEndID,ModelID;

 GO



----------------------------------------------------------------------------------
---SHEET 3 - ASPlan--


CREATE TABLE [dbo].[ASPlanRecieve](
	[DeliveryDate] date not NULL,
	[HourEnding]  VARCHAR (10) not NULL,
	[AncillaryType] varchar (20) NOT NULL,
	[Quantity] integer NULL,
	[DSTFlag] char(1) NULL
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[AncillaryType]( TypeID int not null identity, 
	[AncillaryType] [varchar] (20) NOT NULL
	CONSTRAINT PK_TypeID PRIMARY KEY  CLUSTERED (TypeID));

GO
 CREATE TABLE [dbo].[ASPlan]( RecordID int not null identity,
	[DateID] INT not NULL,
	[HourEndID]  INT not NULL,
	[TypeID] INT NOT NULL,
	[Quantity] integer NULL,
	[DSTFlag] char(1) not NULL
	CONSTRAINT PK_DataID PRIMARY KEY  CLUSTERED (RecordID));
GO
ALTER TABLE [dbo].[ASPlan]  WITH  CHECK ADD CONSTRAINT FK_TypeID FOREIGN KEY (TypeID)
REFERENCES [dbo].[AncillaryType] (TypeID);
GO

ALTER TABLE [dbo].[ASPlan]  CHECK CONSTRAINT FK_TypeID;

GO
ALTER TABLE [dbo].[ASPlan]  WITH  CHECK ADD CONSTRAINT FK_DateID FOREIGN KEY (DateID)
REFERENCES [dbo].[DeliverDate] (DateID);
GO

ALTER TABLE [dbo].[ASPlan]  CHECK CONSTRAINT FK_DateID;

GO

ALTER TABLE [dbo].[ASPlan]  WITH  CHECK ADD CONSTRAINT FK_HourID FOREIGN KEY (HourEndID)
REFERENCES [dbo].[HourEnding] (HourEndID);
GO

ALTER TABLE [dbo].[ASPlan]  CHECK CONSTRAINT FK_HourID;

GO


----TRIGGERS---

CREATE TRIGGER TR_Type ON [dbo].[ASPlanRecieve]
AFTER INSERT, UPDATE 
AS
Begin			
BEGIN TRY
INSERT INTO [dbo].[AncillaryType] ([AncillaryType])
SELECT DISTINCT ([AncillaryType]) FROM inserted
where not exists (select * from [dbo].[AncillaryType] where  [AncillaryType] = inserted.[AncillaryType])
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW;
PRINT ' AncillaryType record already exists'
END CATCH
END



CREATE TRIGGER TR_ASPlan ON [dbo].[ASPlanRecieve]
AFTER INSERT, UPDATE 
AS
Begin 
Begin TRY
INSERT INTO [dbo].[ASPlan]
SELECT  
	   [DateID]
      ,[HourEndID]
      ,[TypeID]
      ,[Quantity]
      ,[DSTFlag]
	   FROM inserted
	   join [dbo].[AncillaryType] tp on tp.[AncillaryType] = inserted.[AncillaryType]
	   join [dbo].[DeliverDate] d ON d.DeliveryDate = inserted.Deliverydate
    JOIN dbo.HourEnding h ON h.HourEnding = inserted.HourEnding
WHERE NOT EXISTS( SELECT * FROM [dbo].[ASPlan] where DateID = d.DateID)
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW;
PRINT ' Records already exist'
END CATCH
END

 --pivot--

   DECLARE @ColSQL VARCHAR(MAX),
		  @pvtSQL NVARCHAR(MAX)
   SELECT  @ColSQL = STUFF((SELECT DISTINCT ','+QUOTENAME([AncillaryType])
          FROM [dbo].[AncillaryType]
          FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)') 
    ,1,1,'')
   PRINT @ColSQL
 
SELECT @pvtSQL = '
SELECT * FROM
(	SELECT 
	   [DateID]
      ,[HourEndID]
      ,[AncillaryType]
      ,[Quantity]
      ,[DSTFlag]
	  FROM [dbo].[ASPlan] pl
  join [dbo].[AncillaryType] tp on tp.[TypeID] = pl.[TypeID]
  
   ) pivotdata

PIVOT

( MAX ([Quantity]) for [AncillaryType] IN (' + @ColSQL + ')) PivotResult' 

 exec (@pvtSQL)


 ------------------------------------------------------------------------------------------
 ---Sheet 4 HourlyResOutCap ---

 CREATE TABLE dbo.HrResOutCapRecieve ([Date] DATE NOT NULL,
								[HourEnding] VARCHAR (10) not null,
								[TotalResourceMW] INT NULL,
								[TotalIRRMW] INT NULL,
								[TotalNewEquipResourceMW] INT NULL)
				GO

CREATE TABLE dbo.HourlyResOutCap ( [OutageCapID] INT IDENTITY NOT NULL,
								[DateID] INT NOT NULL,
								[HourEndID] INT not null,
								[TotalResourceMW] INT NULL,
								[TotalIRRMW] INT NULL,
								[TotalNewEquipResourceMW] INT NULL
							
				CONSTRAINT PK_OutageCap PRIMARY KEY  CLUSTERED (OutageCapID));


									GO

CREATE TABLE dbo.HrResOutCap_Nrm (HrOutageCapID INT IDENTITY NOT NULL,
								[DateId] INT NOT NULL,
								[HourEndID] INT NOT NULL,
								ResourceType CHAR (30) NOT NULL,
								TotalMW INT NULL
							CONSTRAINT PK_HrOutageCap PRIMARY KEY  CLUSTERED (HrOutageCapID));	
						GO
ALTER TABLE  dbo.HourlyResOutCap  WITH  CHECK ADD CONSTRAINT FK_DDATE FOREIGN KEY (DateID)
REFERENCES [dbo].[DeliverDate] (DateID);
GO

ALTER TABLE dbo.HourlyResOutCap  CHECK CONSTRAINT FK_DDATE;

GO

ALTER TABLE dbo.HourlyResOutCap WITH  CHECK ADD CONSTRAINT FK_HOUR_ID FOREIGN KEY (HourEndID)
REFERENCES [dbo].[HourEnding] (HourEndID);
GO

ALTER TABLE dbo.HourlyResOutCap CHECK CONSTRAINT FK_HOUR_ID;

GO

ALTER TABLE  dbo.HrResOutCap_Nrm  WITH  CHECK ADD CONSTRAINT FK_D_DATE FOREIGN KEY (DateID)
REFERENCES [dbo].[DeliverDate] (DateID);
GO

ALTER TABLE dbo.HrResOutCap_Nrm  CHECK CONSTRAINT FK_D_DATE;

GO

ALTER TABLE dbo.HrResOutCap_Nrm WITH  CHECK ADD CONSTRAINT FK_H_id FOREIGN KEY (HourEndID)
REFERENCES [dbo].[HourEnding] (HourEndID);
GO

ALTER TABLE dbo.HrResOutCap_Nrm CHECK CONSTRAINT FK_H_id;

GO


----TRIGGERS ---


CREATE TRIGGER TR_OutageCap ON dbo.HrResOutCapRecieve
AFTER INSERT, UPDATE
AS 
BEGIN
BEGIN TRY
INSERT INTO dbo.HourlyResOutCap ([DateID],
								[HourEndID],
								[TotalResourceMW],
								[TotalIRRMW],
								[TotalNewEquipResourceMW])

SELECT d.[DateID],h.[HourEndID][TotalResourceMW],[TotalIRRMW],[TotalNewEquipResourceMW]
FROM  inserted 
JOIN [dbo].[DeliverDate] d ON d.Deliverydate = inserted.[Date]
join [dbo].[HourEnding] h ON h.HourEnding = inserted.HourEnding
WHERE NOT EXISTS ( SELECT * FROM dbo.HourlyResOutCap WHERE [Date] = INSERTED.[Date])
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW;
PRINT ' These recods already exist'
END CATCH
END;

GO



CREATE TRIGGER  TR_UNPIV_HROC ON dbo.HourlyResOutCap
AFTER INSERT, UPDATE
AS
BEGIN
BEGIN TRY
INSERT INTO  dbo.HrResOutCap_Nrm ([DateID],[HourEndID],[ResourceType],[TotalMW])

SELECT DISTINCT [DateID],[HourEndID],[ResourceType],[TotalMW] FROM
(SELECT [DateID],[HourEndID], [TotalResourceMW],[TotalIRRMW],[TotalNewEquipResourceMW]
FROM INSERTED ) P
UNPIVOT
( [TotalMW] FOR [ResourceType] IN ( [TotalResourceMW],[TotalIRRMW],
								[TotalNewEquipResourceMW]))  AS  UNPIV
WHERE NOT EXISTS ( SELECT *FROM [dbo].[HrResOutCap_Nrm] WHERE [DateID] = UNPIV.[DateID])
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW
PRINT ' Unpivot records already exist'
END CATCH
END;

---------------------------------------------------------------------------------
----Sheet 5 SystemWideDemand---

CREATE TABLE dbo.SystemWideDemandRecieve (
	[DeliveryDate] date not NULL,
	[TimeEnding]  TIME not NULL,
	[Demand] decimal (10,4) NULL,
	[DSTFlag] char(1) NULL
) ON [PRIMARY]
GO

CREATE TABLE dbo.SYSWideDemand ( SWDemandID int not null identity, 
	[DateID] INT NOT NULL,
	[TimeEnding] TIME NOT NULL,
	 [Demand] DECIMAL (9,4)  NULL,
	[DSTFlag] CHAR (1) NOT NULL
	CONSTRAINT PK_SWDID PRIMARY KEY  CLUSTERED (SWDemandID));

GO

ALTER TABLE  dbo.SYSWideDemand   WITH  CHECK ADD CONSTRAINT FK_DeliveryDate FOREIGN KEY (DateID)
REFERENCES [dbo].[DeliverDate] (DateID);
GO

ALTER TABLE  dbo.SYSWideDemand   CHECK CONSTRAINT FK_DeliveryDate;

GO

---TRIGGERS ---
	CREATE TRIGGER TR_SYS_W_DEM ON dbo.SystemWideDemandRecieve
	AFTER INSERT, UPDATE
	AS
	BEGIN 
	BEGIN TRY
	INSERT INTO [dbo].[SYSWideDemand]
           ([DateID]
           ,[TimeEnding]
           ,[Demand]
           ,[DSTFlag])

SELECT [DateID],
           [TimeEnding]
           ,[Demand]
           ,[DSTFlag]
FROM INSERTED
join [dbo].[DeliverDate] d  ON  d.[DeliveryDate] = INSERTED.[DeliveryDate]
 WHERE NOT EXISTS( SELECT * FROM [dbo].[SYSWideDemand] where DateID = d.DateID)
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW;
PRINT 'These Records already exist'
END CATCH
END

--------------------------------------------------------------
----Sheet 6 - WIND--- 

create TABLE dbo.WindPowerPrRecieve ( 
						DeliveryDate DATETIME NOT NULL,
						 HourEnding varchar (10) NOT NULL,
						ACTUAL_SYSTEM_WIDE decimal (7,2) NULL,
						COP_HSL_SYSTEM_WIDE  decimal (7,2) NULL,
						STWPF_SYSTEM_WIDE decimal (7,2) NULL,
						WGRPP_SYSTEM_WIDE decimal (7,2) NULL,
						ACTUAL_LZ_SOUTH_HOUSTON decimal (7,2) NULL,
						COP_HSL_LZ_SOUTH_HOUSTON decimal (7,2) NULL,
						STWPF_LZ_SOUTH_HOUSTON decimal (7,2) NULL,
						WGRPP_LZ_SOUTH_HOUSTON decimal (7,2) NULL,
						ACTUAL_LZ_WEST decimal (7,2) NULL,
						COP_HSL_LZ_WEST decimal (7,2) NULL,
						STWPF_LZ_WEST decimal (7,2) NULL,
						WGRPP_LZ_WEST decimal (7,2) NULL,
						ACTUAL_LZ_NORTH decimal (7,2) NULL,
						COP_HSL_LZ_NORTH decimal (7,2) NULL,
						STWPF_LZ_NORTH decimal (7,2) NULL,
						WGRPP_LZ_NORTH decimal (7,2) NULL,
						DSTFlag CHAR(1)  NULL
						);
						 GO

						 
CREATE TABLE dbo.Indicators (IndicatorID INTEGER IDENTITY NOT NULL,
						 Indicator NVARCHAR(200) NOT NULL
						 CONSTRAINT PK_Indicator_ID PRIMARY KEY  CLUSTERED (IndicatorID));
						 GO



Create TABLE dbo.Wind_PowerProduction ( WPPID int not null identity, 
							DateID INT NOT NULL,
							HourEndID INT NOT NULL,
							IndicatorID INT NOT NULL,
							PowerProduction decimal (7,2) NULL, 
							DSTFlag CHAR(1) NOT NULL
							CONSTRAINT PK_WPP PRIMARY KEY clustered (WPPID));
							GO


ALTER TABLE dbo.Wind_PowerProduction   WITH  CHECK ADD CONSTRAINT FK_DeliveryDate_ID FOREIGN KEY (DateID)
REFERENCES [dbo].[DeliverDate] (DateID);
GO

ALTER TABLE dbo.Wind_PowerProduction  CHECK CONSTRAINT FK_DeliveryDate_ID;

GO

ALTER TABLE dbo.Wind_PowerProduction  WITH  CHECK ADD CONSTRAINT FK_HrEndid FOREIGN KEY (HourEndID)
REFERENCES [dbo].[HourEnding] (HourEndID);
GO

ALTER TABLE dbo.Wind_PowerProduction  CHECK CONSTRAINT FK_Hrendid;

GO
ALTER TABLE dbo.Wind_PowerProduction  WITH  CHECK ADD CONSTRAINT FK_Indicator FOREIGN KEY (IndicatorID)
REFERENCES dbo.Indicators (IndicatorID);
GO

ALTER TABLE dbo.Wind_PowerProduction  CHECK CONSTRAINT FK_Indicator;

GO


---TRIGGERS---


ALTER TRIGGER TR_DDate_Wind ON dbo.WindPowerPrRecieve
AFTER INSERT, UPDATE
AS
BEGIN
BEGIN TRY
INSERT INTO dbo.Indicators (Indicator)
SELECT DISTINCT Indicator
FROM
( SELECT  [ACTUAL_SYSTEM_WIDE], [COP_HSL_SYSTEM_WIDE],
		 [STWPF_SYSTEM_WIDE], [WGRPP_SYSTEM_WIDE],
		 [ACTUAL_LZ_SOUTH_HOUSTON],[COP_HSL_LZ_SOUTH_HOUSTON],
[STWPF_LZ_SOUTH_HOUSTON], [WGRPP_LZ_SOUTH_HOUSTON],
[ACTUAL_LZ_WEST],[COP_HSL_LZ_WEST],[STWPF_LZ_WEST],[WGRPP_LZ_WEST],[ACTUAL_LZ_NORTH],
[COP_HSL_LZ_NORTH],[STWPF_LZ_NORTH],[WGRPP_LZ_NORTH]
  FROM inserted 
) AS cp
UNPIVOT 
(
  DeliveryDate FOR Indicator  IN ( [ACTUAL_SYSTEM_WIDE], [COP_HSL_SYSTEM_WIDE],
		 [STWPF_SYSTEM_WIDE], [WGRPP_SYSTEM_WIDE],
		 [ACTUAL_LZ_SOUTH_HOUSTON],[COP_HSL_LZ_SOUTH_HOUSTON],
[STWPF_LZ_SOUTH_HOUSTON], [WGRPP_LZ_SOUTH_HOUSTON],
[ACTUAL_LZ_WEST],[COP_HSL_LZ_WEST],[STWPF_LZ_WEST],[WGRPP_LZ_WEST],[ACTUAL_LZ_NORTH],
[COP_HSL_LZ_NORTH],[STWPF_LZ_NORTH],[WGRPP_LZ_NORTH])) AS unp
where not exists (Select * FROM dbo.Indicators where Indicator = unp.Indicator)
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW;
PRINT 'Indicators already exist'
END CATCH
END


ALTER TRIGGER TR_WP_PROD ON dbo.WindPowerPrRecieve
AFTER INSERT, UPDATE 
AS
BEGIN
BEGIN TRY
INSERT INTO dbo.Wind_PowerProduction ( 
										[DateID],
										[HourEndID],
										[IndicatorID],
										[PowerProduction],
										[DSTFlag])

SELECT  DateID,[HourEndID],IndicatorID,PowerP,DSTFlag
FROM
( SELECT [DateID], HourEndID, DSTFlag, [ACTUAL_SYSTEM_WIDE], [COP_HSL_SYSTEM_WIDE],
		 [STWPF_SYSTEM_WIDE], [WGRPP_SYSTEM_WIDE],
		 [ACTUAL_LZ_SOUTH_HOUSTON],[COP_HSL_LZ_SOUTH_HOUSTON],
[STWPF_LZ_SOUTH_HOUSTON], [WGRPP_LZ_SOUTH_HOUSTON],
[ACTUAL_LZ_WEST],[COP_HSL_LZ_WEST],[STWPF_LZ_WEST],[WGRPP_LZ_WEST],[ACTUAL_LZ_NORTH],
[COP_HSL_LZ_NORTH],[STWPF_LZ_NORTH],[WGRPP_LZ_NORTH]
  FROM inserted
  JOIN [dbo].[DeliverDate] d ON d.DeliveryDate = inserted.DeliveryDate
JOIN [dbo].[HourEnding] h ON h.HourEnding = inserted.HourEnding 
)  cp
UNPIVOT 
(
  PowerP FOR Indicator  IN ( [ACTUAL_SYSTEM_WIDE], [COP_HSL_SYSTEM_WIDE],
		 [STWPF_SYSTEM_WIDE], [WGRPP_SYSTEM_WIDE],
		 [ACTUAL_LZ_SOUTH_HOUSTON],[COP_HSL_LZ_SOUTH_HOUSTON],
[STWPF_LZ_SOUTH_HOUSTON], [WGRPP_LZ_SOUTH_HOUSTON],
[ACTUAL_LZ_WEST],[COP_HSL_LZ_WEST],[STWPF_LZ_WEST],[WGRPP_LZ_WEST],[ACTUAL_LZ_NORTH],
[COP_HSL_LZ_NORTH],[STWPF_LZ_NORTH],[WGRPP_LZ_NORTH]))  unp
JOIN [dbo].[Indicators] i ON i.Indicator = unp.Indicator
WHERE NOT EXISTS ( SELECT * FROM dbo.Wind_PowerProduction WHERE DATEID = unp.DATEID)
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW;
PRINT 'Records already exist'
END CATCH
END


------------------------------------------------------------------------
--- SHeet 7 HourResOutCap---

CREATE TABLE dbo.HourlyResOutCapReieve ([DeliveryDate] date not null ,
									[HourEnding] varchar (6) not null,
									[TotalCapGenRes] decimal (8,2) null ,
									[TotalCapLoadRes] decimal (8,2)null,
									[OfflineAvailableMW] decimal (8,2) null,
									[DSTFlag] char(1) not null);

CREATE TABLE dbo.ResourseEntity ( REID INT IDENTITY NOT NULL,
						ResourseEntity varchar (20) NOT NULL,
						
					CONSTRAINT PK_RE PRIMARY KEY CLUSTERED (REID));


CREATE TABLE dbo.HourlyResOut (TCapREID INT IDENTITY NOT NULL,
						DateID int not null,
						HourEndID int not null,
						REID INT NOT NULL,
						TotalCapRE decimal (8,2) null,
						[OfflineAvailableMW] decimal (8,2) null,
						[DSTFlag] char(1) not null
						CONSTRAINT PK_TotalCap PRIMARY KEY CLUSTERED (TCapREID))


ALTER TABLE dbo.HourlyResOut  WITH  CHECK ADD CONSTRAINT FK_Del_DATE FOREIGN KEY (DateID)
REFERENCES [dbo].[DeliverDate] (DateID);
GO

ALTER TABLE dbo.HourlyResOut  CHECK CONSTRAINT FK_Del_DATE;

GO

ALTER TABLE dbo.HourlyResOut WITH  CHECK ADD CONSTRAINT FK_Hr_id FOREIGN KEY (HourEndID)
REFERENCES [dbo].[HourEnding] (HourEndID);
GO

ALTER TABLE dbo.HourlyResOut CHECK CONSTRAINT FK_Hr_id;

GO
ALTER TABLE dbo.HourlyResOut WITH  CHECK ADD CONSTRAINT FK_ResEnd FOREIGN KEY (REID)
REFERENCES dbo.ResourseEntity (REID);
GO

ALTER TABLE dbo.HourlyResOut CHECK CONSTRAINT FK_ResEnd;

GO

---TRIGGERS---

CREATE TRIGGER TR_RE ON  dbo.HourlyResOutCapReieve
AFTER INSERT,
UPDATE
AS 
BEGIN
BEGIN TRY 
INSERT INTO dbo.ResourseEntity  (ResourseEntity)

SELECT distinct  ResourseEntity
FROM (select [TotalCapGenRes],[TotalCapLoadRes]
from inserted) as p
unpivot
([DeliveryDate] for  ResourseEntity in ([TotalCapGenRes],[TotalCapLoadRes])) as unp
where not exists ( select*from  dbo.ResourseEntity where [DeliveryDate] = unp.[DeliveryDate])
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW;
PRINT 'RESOURS ENTITY already exist'
END CATCH
END

CREATE TRIGGER TR_TotalCapRE ON dbo.HourlyResOutCapReieve
AFTER INSERT,UPDATE
AS
BEGIN 
BEGIN TRY
INSERT INTO dbo.HourlyResOut (DateID,
						HourEndID,
						REID ,
						TotalCapRE ,
						[OfflineAvailableMW],
						[DSTFlag])
SELECT DateID,HourEndID,
		REID,TotalCapRE ,
		[OfflineAvailableMW],
		[DSTFlag]
FROM (SELECT  DateID,HourEndID,
		[TotalCapGenRes],[TotalCapLoadRes],[OfflineAvailableMW],
		[DSTFlag]  FROM  INSERTED
		 JOIN [dbo].[DeliverDate] d ON d.DeliveryDate = inserted.DeliveryDate
JOIN [dbo].[HourEnding] h ON h.HourEnding = inserted.HourEnding

) P
UNPIVOT
( TotalCapRE FOR  ResourseEntity in ([TotalCapGenRes],[TotalCapLoadRes])) UNP

JOIN  dbo.ResourseEntity r ON r.ResourseEntity = UNP.ResourseEntity
where not exists ( select * from  dbo.HourlyResOut where DATEID = unp.DATEID)
END TRY
BEGIN CATCH
IF XACT_STATE () <> 0
ROLLBACK TRANSACTION;
THROW;
PRINT 'Records already exist'
END CATCH
END

