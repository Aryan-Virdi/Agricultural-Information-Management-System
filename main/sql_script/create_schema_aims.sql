CREATE TABLE IF NOT EXISTS farmer (
    f_farmerkey DECIMAL(9,0) NOT NULL,
    f_fieldkey DECIMAL(12,0) NOT NULL,
    f_firstname VARCHAR(25) NOT NULL,
    f_surname VARCHAR(25) NOT NULL
);

CREATE TABLE IF NOT EXISTS field (
    fld_fieldkey DECIMAL(12,0) NOT NULL,
    fld_farmerkey DECIMAL(9,0) NOT NULL,
    fld_soilkey DECIMAL(3,0)
);

CREATE TABLE IF NOT EXISTS soiltype (
    st_soilkey DECIMAL(3,0) NOT NULL,
    -- Percentages to be expressed as xxx.yy (0.01 precision, scale of 5).
    st_sand_pct DECIMAL(5,2) NOT NULL,
    st_silt_pct DECIMAL(5,2) NOT NULL,
    st_clay_pct DECIMAL(5,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS soilsample (
    ss_samplekey DECIMAL(12,0) NOT NULL,
    ss_fieldkey DECIMAL(12,0) NOT NULL,
    ss_sampledate DATE NOT NULL,
    ss_sand DECIMAL(3,2) NOT NULL,
    ss_silt DECIMAL(3,2) NOT NULL,
    ss_clay DECIMAL(3,2) NOT NULL,
    ss_phvalue DECIMAL(4,2) NOT NULL,
    -- NPK expressed in parts per million with scale of 5 and 0.01 precision (xxxxx.yy)
    ss_nitrogen_ppm DECIMAL(7,2) NOT NULL,
    ss_phosphorus_ppm DECIMAL(7,2) NOT NULL,
    ss_potassium_ppm DECIMAL(7,2) NOT NULL,
    -- Organic matter in percentage
    ss_organicmatter_pct DECIMAL(5,2) NOT NULL,
    ss_cec DECIMAL(6,2) NOT NULL,
    -- Heavy metal contaminants in ppm with 0.001 precision and scale of 8. (xxxxxxxx.yyy).
    ss_lead_ppm DECIMAL(8,3) NOT NULL,
    ss_mercury_ppm DECIMAL(8,3) NOT NULL,
    ss_nickel_ppm DECIMAL(8,3) NOT NULL,
    ss_copper_ppm DECIMAL(8,3) NOT NULL,
    ss_chromium_ppm DECIMAL(8.3) NOT NULL,
    ss_cadmium_ppm DECIMAL(8,3) NOT NULL,
    ss_arsenic_ppm DECIMAL(8,3) NOT NULL,
    ss_zinc_ppm DECIMAL(8,3) NOT NULL,
    -- Reamining notes and comments.
    ss_comment VARCHAR(500)
);