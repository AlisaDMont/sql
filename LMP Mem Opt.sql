use ShellTest;
go

ALTER DATABASE ShellTest
	Add FILEGROUP shell_mod CONTAINS MEMORY_OPTIMIZED_DATA;

		ALTER DATABASE ShellTest
		ADD FILE (name = 'shell_modfg', filename ='C:\shell_mod') TO FILEGROUP shell_mod;


---------- CREATE MEM.OPT.Tables

CREATE TABLE [dbo].[RTDIndicativeLMP]( RecordID integer not Null identity primary key nonclustered,
	[RTDTimestamp] datetime NULL,
	[RepeatedHourFlag] [char](1) NULL,
	[IntervalId] INTEGER  NOT NULL index IX_InervalID	NONClUSTERED HASH with (bucket_count = 55),
	[IntervalEnding] datetime NULL,
	[IntervalRepeatedHourFlag] [char](1) NULL,
	[SettlementPoint]  VARCHAR (70) NOT NULL  index IX_Set_Point NONClUSTERED HASH with (bucket_count = 2400),
	[SettlementPointType]  VARCHAR (70) NOT NULL  index IX_Set_Type NONClUSTERED HASH with (bucket_count = 100),
	[LMP] numeric (10,2)  NULL)
	 WITH ( MEMORY_OPTIMIZED = ON);

GO




CREATE Table dbo. RTDInterval (	TimestampID integer not Null identity primary key nonclustered,
								IntervalID INTEGER  NOT NULL index IX_InervalID	NONClUSTERED HASH with (bucket_count = 55),
								RTDTimestamp DATETIME NOT NULL,
								IntervalEnding DATETIME NOT NULL, 
								IntervalRepeatedHourFlag char(1) NOT NULL,
								RepeatedHourFlag  CHAR (1) NOT NULL)
									WITH ( MEMORY_OPTIMIZED = ON);
	GO

CREATE TABLE dbo.SettlementPointType (	SettlementPointTypeID  INTEGER  NOT NULL IDENTITY primary key nonclustered,
										SettlementPointType			VARCHAR (25) NOT NULL)
										WITH ( MEMORY_OPTIMIZED = ON);
					 GO


CREATE TABLE dbo. SettlementPoint (	SettlementPointID  INTEGER  NOT NULL IDENTITY PRIMARY KEY NONCLUSTERED,
									SettlementPoint VARCHAR (25) NOT NULL,
									 SettlementPointTypeID  INTEGER  NOT NULL index IX_SettlementPTID	NONClUSTERED HASH with (bucket_count = 40))	
									WITH ( MEMORY_OPTIMIZED = ON);
								
			GO
CREATE TABLE dbo.Settlement (	SettlementID INT  NOT NULL IDENTITY PRIMARY KEY NONCLUSTERED,
								TimestampID	INT   NOT NULL,
								IntervalID INTEGER   NOT NULL  index IX_Interval_ID	NONClUSTERED HASH with (bucket_count = 55), 
								SettlementPointID INTEGER  NOT NULL index IX_SettlementPID	NONClUSTERED HASH with (bucket_count = 2400),
								LMP Numeric (10,2)  NULL )
							   WITH ( MEMORY_OPTIMIZED = ON);
			  GO

CREATE TABLE dbo.SetPoint_TypeCombo  ( ComboID INTEGER NOT NULL IDENTITY  PRIMARY KEY NONCLUSTERED,
								[SettlementID] INTEGER not null ,
								IntervalID INTEGER  NOT NULL,
								SettlementPointTypeCombo VARCHAR (70) NOT NULL  index IX_ComboID	NONClUSTERED HASH with (bucket_count = 2400))
								 WITH ( MEMORY_OPTIMIZED = ON);

GO

