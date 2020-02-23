USE ShellTest;
GO
drop table rtdindicativelmp

CREATE TABLE [dbo].[RTDIndicativeLMP](
	[RTDTimestamp] datetime NULL,
	[RepeatedHourFlag] [char](1) NULL,
	[IntervalId] int not NULL,
	[IntervalEnding] datetime NULL,
	[IntervalRepeatedHourFlag] [char](1) NULL,
	[SettlementPoint] [VARCHAR](25) NULL,
	[SettlementPointType] [VARCHAR](25) NULL,
	[LMP] numeric (10,2)  NULL
) ON [PRIMARY]
GO


create Table dbo. RTDInterval (	TimestampID integer not Null identity,
								IntervalID INTEGER  NOT NULL,
								RTDTimestamp DATETIME NOT NULL,
								IntervalEnding DATETIME NOT NULL, 
								IntervalRepeatedHourFlag char(1) NOT NULL,
								RepeatedHourFlag  CHAR (1) NOT NULL
									CONSTRAINT PK_RTDInterval_IntervalID PRIMARY KEY  CLUSTERED (TimestampID));

									GO

ALTER TABLE dbo. RTDInterval WITH CHECK ADD CONSTRAINT CK_Interval_EndDate CHECK ((IntervalEnding>=RTDTimestamp));
GO

ALTER TABLE dbo. RTDInterval CHECK  CONSTRAINT CK_Interval_EndDate ;

GO

create TABLE dbo.SettlementPointType (	SettlementPointTypeID  INTEGER  NOT NULL IDENTITY,
										SettlementPointType			VARCHAR (25) NOT NULL
										CONSTRAINT PK_SettlementPointTypeID PRIMARY KEY clustered (SettlementPointTypeID));

					 GO


create TABLE dbo. SettlementPoint (	SettlementPointID  INTEGER  NOT NULL IDENTITY,
									SettlementPoint VARCHAR (25) NOT NULL,
									 SettlementPointTypeID  INTEGER  NOT NULL,	

									CONSTRAINT PK_SettlementPointID PRIMARY KEY clustered (SettlementPointID));
			GO


ALTER TABLE dbo. SettlementPoint  WITH  CHECK ADD CONSTRAINT FK_Settlement_Point_ID FOREIGN KEY (SettlementPointTypeID)
REFERENCES dbo.SettlementPointType (	SettlementPointTypeID);
GO

ALTER TABLE dbo. SettlementPoint   CHECK CONSTRAINT FK_Settlement_Point_ID;

GO



create TABLE dbo.Settlement (	SettlementID INT  NOT NULL identity,
								TimestampID	INT   NOT NULL,
								IntervalID INTEGER   NOT NULL,
								SettlementPointID INTEGER  NOT NULL ,
								LMP Numeric (10,2) NULL 
							    CONSTRAINT PK_SettlementID PRIMARY KEY CLUSTERED (SettlementID))
								
							GO

ALTER TABLE dbo. Settlement  WITH  CHECK ADD CONSTRAINT FK_Settlement_ID FOREIGN KEY (SettlementPointID)
REFERENCES dbo.SettlementPoint (SettlementPointID);
GO

ALTER TABLE dbo. Settlement   CHECK CONSTRAINT FK_Settlement_ID;

GO
ALTER TABLE dbo. Settlement  WITH  CHECK ADD CONSTRAINT FK_Time_ID FOREIGN KEY (TimestampID )
REFERENCES [dbo].[RTDInterval] (TimestampID	);
GO

ALTER TABLE [dbo]. Settlement CHECK CONSTRAINT FK_Time_ID;





select * from RTDIndicativeLMP


 