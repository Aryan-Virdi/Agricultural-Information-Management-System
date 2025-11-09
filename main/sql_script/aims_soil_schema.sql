CREATE TABLE Farmer (
    FarmerID INT PRIMARY KEY,
    FarmerName VARCHAR(100) NOT NULL,
    ContactNumber VARCHAR(20),
    Address VARCHAR(255)
);

CREATE TABLE Field (
    FieldID INT PRIMARY KEY,
    FarmerID INT NOT NULL,
    TypeID INT, 
    SizeAcres DECIMAL(10, 2) NOT NULL,
    LocationAddress VARCHAR(255),
    FOREIGN KEY (FarmerID) REFERENCES Farmer(FarmerID),
    FOREIGN KEY (TypeID) REFERENCES SoilType(TypeID)
);

CREATE TABLE Maintenance (
    MaintenanceID INT PRIMARY KEY,
    ActivityName VARCHAR(100) NOT NULL,
    Description TEXT,
    CostPerUnit DECIMAL(10, 2)
);

CREATE TABLE FieldMaintenance (
    FieldID INT NOT NULL,
    MaintenanceID INT NOT NULL,
    ScheduledDate DATE NOT NULL,
    CompletionDate DATE,
    ActualCost DECIMAL(10, 2),
    PRIMARY KEY (FieldID, MaintenanceID, ScheduledDate),
    FOREIGN KEY (FieldID) REFERENCES Field(FieldID),
    FOREIGN KEY (MaintenanceID) REFERENCES Maintenance(MaintenanceID)
);

CREATE TABLE SoilType (
    TypeID INT PRIMARY KEY,
    TypeName VARCHAR(50) NOT NULL UNIQUE,
    TextureClass VARCHAR(50),
    Description TEXT
);

CREATE TABLE SoilSample (
    SampleID INT PRIMARY KEY,
    FieldID INT NOT NULL,
    TypeID INT,
    DateTaken DATE NOT NULL,
    PHLevel DECIMAL(3, 2),
    Nitrogen_ppm DECIMAL(9,2),
    Phosphorus_ppm DECIMAL(9,2),
    Potassium_ppm DECIMAL(9,2),
    OrganicMatterPct DECIMAL(5,2),
    CEC DECIMAL(7,2),
    Salinity_EC_dS_m DECIMAL(6,3),
    BulkDensity_g_cm3 DECIMAL(4,3),
    Depth_cm INT,
    NutrientAnalysis TEXT,
    LabComments TEXT,
    FOREIGN KEY (FieldID) REFERENCES Field(FieldID),
    FOREIGN KEY (TypeID) REFERENCES SoilType(TypeID)
);

CREATE TABLE ContaminantType (
    ContaminantID INT PRIMARY KEY,
    ContaminantName VARCHAR(100) NOT NULL UNIQUE,
    TypicalUnit VARCHAR(20) DEFAULT 'ppm',
    RegulatoryThreshold DECIMAL(12,4),
    ThresholdUnit VARCHAR(20),
    Notes TEXT
);

CREATE TABLE SoilSampleContaminant (
    SampleID INT NOT NULL,
    ContaminantID INT NOT NULL,
    Concentration DECIMAL(12,4) NOT NULL,
    DetectionLimit DECIMAL(12,4), 
    LabMethod VARCHAR(100),
    Unit VARCHAR(20) DEFAULT 'ppm',
    PRIMARY KEY (SampleID, ContaminantID),
    FOREIGN KEY (SampleID) REFERENCES SoilSample(SampleID) ON DELETE CASCADE,
    FOREIGN KEY (ContaminantID) REFERENCES ContaminantType(ContaminantID)
);

CREATE TABLE Season (
    SeasonID INT PRIMARY KEY,
    SeasonName VARCHAR(50) NOT NULL UNIQUE,
    StartDate DATE,
    EndDate DATE
);

CREATE TABLE Crop (
    CropID INT PRIMARY KEY,
    CropName VARCHAR(100) NOT NULL UNIQUE,
    Variety VARCHAR(50),
    IdealGrowingTemp DECIMAL(5, 2)
);

CREATE TABLE CropSeason (
    CropID INT NOT NULL,
    SeasonID INT NOT NULL,
    PRIMARY KEY (CropID, SeasonID),
    FOREIGN KEY (CropID) REFERENCES Crop(CropID),
    FOREIGN KEY (SeasonID) REFERENCES Season(SeasonID)
);

CREATE TABLE FieldCrop (
    FieldID INT NOT NULL,
    CropID INT NOT NULL,
    DatePlanted DATE NOT NULL,
    ExpectedHarvestDate DATE,
    YieldActual DECIMAL(10, 2),
    PRIMARY KEY (FieldID, CropID, DatePlanted),
    FOREIGN KEY (FieldID) REFERENCES Field(FieldID),
    FOREIGN KEY (CropID) REFERENCES Crop(CropID)
);
