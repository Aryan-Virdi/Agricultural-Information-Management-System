CREATE TABLE IF NOT EXISTS farmer (
    f_farmerkey     DECIMAL(9,0) PRIMARY KEY,
    f_fieldkey      DECIMAL(12,0) NOT NULL,
    f_firstname     VARCHAR(25) NOT NULL,
    f_surname       VARCHAR(25) NOT NULL,
    FOREIGN KEY (f_fieldkey) REFERENCES field(fld_fieldkey)
);

CREATE TABLE IF NOT EXISTS field (
    fld_fieldkey    DECIMAL(12,0) PRIMARY KEY,
    fld_farmerkey   DECIMAL(9,0) NOT NULL,
    fld_soilkey     DECIMAL(3,0),
    FOREIGN KEY (fld_farmerkey) REFERENCES farmer(f_farmerkey),
    FOREIGN KEY (fld_soilkey) REFERENCES soiltype(st_soilkey)
);

CREATE TABLE IF NOT EXISTS soiltype (
    st_soilkey      DECIMAL(3,0) PRIMARY KEY,
    -- Percentages to be expressed as xxx.yy (0.01 precision, scale of 5).
    -- This data is not meant to be used to measure true soil composition.
    -- It is meant to indicate the average percentages for this particular soil type.
    st_sand_pct     DECIMAL(5,2) NOT NULL,
    st_silt_pct     DECIMAL(5,2) NOT NULL,
    st_clay_pct     DECIMAL(5,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS soilsample (
    ss_samplekey            DECIMAL(12,0) PRIMARY KEY,
    ss_fieldkey             DECIMAL(12,0) NOT NULL,
    ss_sampledate           DATE NOT NULL,
    ss_sand                 DECIMAL(3,2) NOT NULL,
    ss_silt                 DECIMAL(3,2) NOT NULL,
    ss_clay                 DECIMAL(3,2) NOT NULL,
    ss_ph                   DECIMAL(4,2) NOT NULL,
    -- NPK expressed in parts per million with scale of 5 and 0.01 precision (xxxxx.yy)
    ss_nitrogen_ppm         DECIMAL(7,2) NOT NULL,
    ss_phosphorus_ppm       DECIMAL(7,2) NOT NULL,
    ss_potassium_ppm        DECIMAL(7,2) NOT NULL,
    -- Organic matter in percentage
    ss_organicmatter_pct    DECIMAL(5,2) NOT NULL,
    ss_cec                  DECIMAL(6,2) NOT NULL,
    -- Heavy metal contaminants in ppm with 0.001 precision and scale of 8. (xxxxxxxx.yyy).
    ss_lead_ppm         DECIMAL(8,3) NOT NULL,
    ss_mercury_ppm      DECIMAL(8,3) NOT NULL,
    ss_nickel_ppm       DECIMAL(8,3) NOT NULL,
    ss_copper_ppm       DECIMAL(8,3) NOT NULL,
    ss_chromium_ppm     DECIMAL(8.3) NOT NULL,
    ss_cadmium_ppm      DECIMAL(8,3) NOT NULL,
    ss_arsenic_ppm      DECIMAL(8,3) NOT NULL,
    ss_zinc_ppm         DECIMAL(8,3) NOT NULL,
    -- Reamining notes and comments.
    ss_comment          VARCHAR(500),
    FOREIGN KEY (ss_fieldkey) REFERENCES field(fld_fieldkey)
);

CREATE TABLE IF NOT EXISTS crop (
    c_cropkey       DECIMAL(4,0) PRIMARY KEY,
    c_name          VARCHAR(100) NOT NULL,
    c_scientific    VARCHAR(128),
    c_daystomature  DECIMAL(5,0) NOT NULL,
    c_seasonkey     DECIMAL(2,0) NOT NULL,
    c_ph            DECIMAL (4,2) NOT NULL,
    c_germ          DECIMAL (5,2) NOT NULL,  -- Germination rate as a percentage.
    c_water         DECIMAL(5,0),           -- Expected water usage of crop in mm/year
    -- Omitting nutrient use numerics, at least for now.
    c_nutrientuse   VARCHAR(125),
    FOREIGN KEY (c_seasonkey) REFERENCES season(s_seasonkey)
);

CREATE TABLE IF NOT EXISTS season (
    s_seasonkey     DECIMAL(2,0) PRIMARY KEY,
    s_name          VARCHAR(8) NOT NULL,
    s_startdate     DATE NOT NULL,
    s_enddate       DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS maintenance (
    m_maintenancekey    DECIMAL(4,0) PRIMARY KEY,
    m_category          VARCHAR(30) NOT NULL,
    m_name              VARCHAR(30) NOT NULL,
    m_activeingredient  VARCHAR(80) NOT NULL,
    m_notes             VARCHAR(250)
);

CREATE TABLE IF NOT EXISTS fieldcrop (
    fldc_fieldkey   DECIMAL(12,0) NOT NULL,
    fldc_cropkey    DECIMAL(4,0) NOT NULL,
    fldc_begindate  DATE NOT NULL,
    fldc_enddate    DATE NOT NULL,
    fldc_yield      DECIMAL(6,2) NOT NULL,
    FOREIGN KEY (fldc_fieldkey) REFERENCES field(fld_fieldkey),
    FOREIGN KEY (fldc_cropkey) REFERENCES crop(c_cropkey)
);

CREATE TABLE IF NOT EXISTS fieldmaintenance (
    fldm_fieldkey           DECIMAL(12,0) NOT NULL,
    fldm_maintenancekey     DECIMAL(4,0) NOT NULL,
    fldm_concentration      DECIMAL(5,2) NOT NULL,
    fldm_amount             DECIMAL(5,2),      -- Amount may be unkown, but we should always know the concentration.
    fldm_begindate          DATE NOT NULL,
    fldm_enddate            DATE NOT NULL,
    FOREIGN KEY (fldm_fieldkey) REFERENCES field(fld_fieldkey),
    FOREIGN KEY (fldm_maintenancekey) REFERENCES maintenance(m_maintenancekey)
);