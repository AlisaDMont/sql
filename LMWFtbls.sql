use Project12;
GO

select* from [dbo].[SheetLMWF]

----CREATE TABLES--- 
CREATE TABLE dbo.LoadModelWeatherForecastRecieve
(	[DeliveryDate] DATE not NULL,
	[HourEnding] [varchar](6) NOT NULL,
	[Coast] numeric (9,4) NULL,
	[East] numeric (9,4) NULL,
	[FarWest] numeric (9,4) NULL,
	[North] numeric (9,4) NULL,
	[NorthCentral] numeric (9,4) NULL,
	[SouthCentral] numeric (9,4) NULL,
	[Southern] numeric (9,4) NULL,
	[West] numeric (9,4) NULL,
	[SystemTotal] numeric (9,4) NULL,
	[Model] [nvarchar](5) NULL,
	[InUseFlag] [char](1) NULL,
	[DSTFlag] [char](1) NULL);


	CREATE TABLE Regions ( RegionID int not null identity,
	Regions varchar (20)
	CONSTRAINT PK_Regions PRIMARY KEY  CLUSTERED (RegionID));
	GO
	

	CREATE TABLE LoadModel (ModelID int not null identity,
	[Model] [nvarchar](5) NULL
	CONSTRAINT PK_LoadModel PRIMARY KEY CLUSTERED (ModelID));


	CREATE TABLE dbo.LoadModelWeatherForecast
	(ForcastID int not NULL IDENTITY (1,1),
	[DeliveryDate] DATE not NULL,
	[HourEnding] [varchar](6) NOT NULL,
	RegionID int not null,
	RegionData numeric (9,4) null,
	[SystemTotal] numeric (9,4) NULL,
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

---INSERT TRIGGER UNPIVOTED---

CREATE TRIGGER TR_Regios on [dbo].[LoadModelWeatherForecastRecieve]
after insert
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

---INSERT TRIGGER---

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

--INSERT TRIGGER--

 CREATE TRIGGER TR_LMWF ON [dbo].[LoadModelWeatherForecastRecieve]
AFTER INSERT
AS
BEGIN
 
INSERT INTO [dbo].[LoadModelWeatherForecast]([DeliveryDate],[HourEnding],[RegionID],[RegionData],
[SystemTotal],[ModelID],[InUseFlag],[DSTFlag])

SELECT [DeliveryDate],[HourEnding],RegionID,[RegionData],[SystemTotal],[ModelID],
[InUseFlag],[DSTFlag]
FROM ( SELECT [DeliveryDate],[HourEnding], [Coast],[East],[FarWest],[North],
[NorthCentral],[SouthCentral],[Southern],[West],[SystemTotal],[Model],[InUseFlag],[DSTFlag]
 FROM inserted ) P
UNPIVOT 
(RegionData FOR Regions in ([Coast],[East],[FarWest],[North],
[NorthCentral],[SouthCentral],[Southern],[West])) as unpvt
 join [dbo].[Regions] rg on rg.Regions = unpvt.Regions
 join [dbo].[LoadModel] m on m.[Model] = unpvt.[Model]

END

-----------------------------------------------
select*FROM [dbo].[LoadModelWeatherForecast]
select* FROM [dbo].[LoadModelWeatherForecastRecieve]


 ---pivot test FOR [dbo].[LoadModelWeatherForecast]---
SELECT* FROM
(select [DeliveryDate],[HourEnding],[RegionID],[RegionData],[SystemTotal],[ModelID],[InUseFlag],[DSTFlag]
 FROM [dbo].[LoadModelWeatherForecast]) pvt
 PIVOT
 (  max ([RegionData]) FOR [RegionID] IN ([1],[2],[3],[4],[5],[6],[7],[8])) PvtResult
 order by HourEnding,ModelID

 

---test sheet insertion---


INSERT INTO [dbo].[LoadModelWeatherForecastRecieve]
           ([DeliveryDate]
           ,[HourEnding]
           ,[Coast]
           ,[East]
           ,[FarWest]
           ,[North]
           ,[NorthCentral]
           ,[SouthCentral]
           ,[Southern]
           ,[West]
           ,[SystemTotal]
           ,[Model]
           ,[InUseFlag]
           ,[DSTFlag])
   SELECT  Convert (date,[ns1:DeliveryDate])
      ,Cast([ns1:HourEnding] as varchar (6))
      ,Cast ([ns1:Coast] as numeric (9,4))
      ,cast ([ns1:East] as numeric (9,4))
      ,cast([ns1:FarWest]as numeric (9,4))
      ,Cast ([ns1:North]as numeric (9,4))
      ,Cast ([ns1:NorthCentral]as numeric (9,4))
      ,Cast([ns1:SouthCentral]as numeric (9,4))
      ,Cast([ns1:Southern]as numeric (9,4))
      ,Cast([ns1:West]as numeric (9,4))
      ,Cast ([ns1:SystemTotal]as numeric (9,4))
      ,Cast ([ns1:Model] as nvarchar (5))
      ,Cast ([ns1:InUseFlag] as char (1))
      ,Cast([ns1:DSTFlag] as Char (1))
  FROM [ShellTest].[dbo].[SheetLMWF]




