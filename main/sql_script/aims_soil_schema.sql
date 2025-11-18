PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS farmer (
    f_farmerkey DECIMAL(9,0) PRIMARY KEY,
    f_fieldkey DECIMAL(12,0) NOT NULL,
    f_name VARCHAR(100) NOT NULL,
);

CREATE TABLE IF NOT EXISTS field (
    fld_fieldkey DECIMAL(12,0) PRIMARY KEY,
    fld_farmerkey DECIMAL(9,0) NOT NULL,
    fld_soilkey DECIMAL(3,0),
    FOREIGN KEY (fld_farmerkey) REFERENCES farmer(f_farmerkey),
    FOREIGN KEY (fld_soilkey) REFERENCES soiltype(st_soilkey)
);

CREATE TABLE IF NOT EXISTS soiltype (
    st_soilkey DECIMAL(3,0) PRIMARY KEY,
    st_texture VARCHAR(50),
    st_sand DECIMAL(5,2),
    st_silt DECIMAL(5,2),
    st_clay DECIMAL(5,2),
    st_loamy DECIMAL(5,2),
    st_chalky DECIMAL(5,2),
    st_peaty DECIMAL(5,2),
);

CREATE TABLE IF NOT EXISTS soilsample (
    ss_samplekey            DECIMAL(12,0) PRIMARY KEY,
    ss_fieldkey             DECIMAL(12,0) NOT NULL,
    ss_soilkey              DECIMAL(3,0),
    ss_sampledate           DATE NOT NULL,
    ss_ph                   DECIMAL(4,2),
    ss_nitrogen_ppm         DECIMAL(9,2),
    ss_phosphorus_ppm       DECIMAL(9,2),
    ss_potassium_ppm DECIMAL(9,2),
    ss_organicmatter_pct DECIMAL(5,2),
    ss_cec DECIMAL(7,2),
    ss_salinity_ec DECIMAL(6,3),
    ss_lead_ppm DECIMAL(8,3) NOT NULL,
    ss_mercury_ppm DECIMAL(8,3) NOT NULL,
    ss_nickel_ppm DECIMAL(8,3) NOT NULL,
    ss_copper_ppm DECIMAL(8,3) NOT NULL,
    ss_chromium_ppm DECIMAL(8,3) NOT NULL,
    ss_cadmium_ppm DECIMAL(8,3) NOT NULL,
    ss_arsenic_ppm DECIMAL(8,3) NOT NULL,
    ss_zinc_ppm DECIMAL(8,3) NOT NULL,
    ss_bulkdensity_g_cm3 DECIMAL(4,3),
    ss_depth_cm INTEGER,
    ss_comment TEXT,
    FOREIGN KEY (ss_fieldkey) REFERENCES field(fld_fieldkey),
    FOREIGN KEY (ss_soilkey) REFERENCES soiltype(st_soilkey)
);

CREATE TABLE IF NOT EXISTS maintenance (
    m_maintenancekey DECIMAL(4,0) PRIMARY KEY,
    m_category VARCHAR(30),
    m_name VARCHAR(100) NOT NULL,
    m_description TEXT,
    m_cost_unit DECIMAL(10,2)
);

CREATE TABLE IF NOT EXISTS fieldmaintenance (
    fldm_fieldkey DECIMAL(12,0) NOT NULL,
    fldm_maintenancekey DECIMAL(4,0)  NOT NULL,
    fldm_begindate DATE NOT NULL,
    fldm_enddate DATE,
    fldm_amount DECIMAL(7,2),
    fldm_amount_unit VARCHAR(16),
    fldm_actual_cost DECIMAL(10,2),
    PRIMARY KEY (fldm_fieldkey, fldm_maintenancekey, fldm_begindate),
    FOREIGN KEY (fldm_fieldkey) REFERENCES field(fld_fieldkey),
    FOREIGN KEY (fldm_maintenancekey) REFERENCES maintenance(m_maintenancekey)
);

CREATE TABLE IF NOT EXISTS season (
    s_seasonkey     DECIMAL(2,0) PRIMARY KEY,
    s_name          VARCHAR(16) NOT NULL,
    s_startdate     DATE,
    s_enddate       DATE
);

CREATE TABLE IF NOT EXISTS crop (
    c_cropkey           DECIMAL(4,0) PRIMARY KEY,
    c_name              VARCHAR(100) NOT NULL,
    c_variety           VARCHAR(50),
    c_daystomature      DECIMAL(5,0),
    c_preferredseason   DECIMAL(2,0),
    c_preferredsoil     DECIMAL(3,0),
    c_ph_preferred      DECIMAL(4,2),
    c_notes             VARCHAR(250),
    FOREIGN KEY (c_preferredseason) REFERENCES season(s_seasonkey),
    FOREIGN KEY (c_preferredsoil) REFERENCES soiltype(st_soilkey)
);

CREATE TABLE IF NOT EXISTS fieldcrop (
    fldc_fieldkey   DECIMAL(12,0) NOT NULL,
    fldc_cropkey    DECIMAL(4,0) NOT NULL,
    fldc_begindate  DATE NOT NULL,
    fldc_expected_harvest DATE,
    fldc_enddate    DATE,
    fldc_yield      DECIMAL(10,2),
    fldc_yield_unit VARCHAR(16),
    PRIMARY KEY (fldc_fieldkey, fldc_cropkey, fldc_begindate),
    FOREIGN KEY (fldc_fieldkey) REFERENCES field(fld_fieldkey),
    FOREIGN KEY (fldc_cropkey) REFERENCES crop(c_cropkey)
);

CREATE TABLE IF NOT EXISTS contaminant_type (
    ct_contaminantkey   DECIMAL(6,0) PRIMARY KEY,
    ct_name             VARCHAR(100) NOT NULL UNIQUE,
    ct_typical_unit     VARCHAR(20) DEFAULT 'ppm',
    ct_reg_threshold    DECIMAL(12,4),
    ct_threshold_unit   VARCHAR(20),
    ct_notes            TEXT
);

CREATE TABLE IF NOT EXISTS soilsample_contaminant (
    ssc_samplekey       DECIMAL(12,0) NOT NULL,
    ssc_contaminantkey  DECIMAL(6,0)  NOT NULL,
    ssc_concentration   DECIMAL(12,4) NOT NULL,
    ssc_detection_limit DECIMAL(12,4),
    ssc_method          VARCHAR(100),
    ssc_unit            VARCHAR(20) DEFAULT 'ppm',
    PRIMARY KEY (ssc_samplekey, ssc_contaminantkey),
    FOREIGN KEY (ssc_samplekey) REFERENCES soilsample(ss_samplekey) ON DELETE CASCADE,
    FOREIGN KEY (ssc_contaminantkey) REFERENCES contaminant_type(ct_contaminantkey)
);
