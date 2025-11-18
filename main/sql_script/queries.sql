-- 1. Soil component statistics by field.

WITH 
mean_components AS (
    SELECT 
        ss_fieldkey AS fieldkey, 
        AVG(ss_sand) AS mean_sand, 
        AVG(ss_silt) AS mean_silt, 
        AVG(ss_clay) AS mean_clay, 
        COUNT(*) AS n 
    FROM soilsample
    GROUP BY ss_fieldkey
),
squared_diff AS (
    SELECT mc.fieldkey, 
        POWER((mc.mean_sand - sample.ss_sand), 2) AS sand, 
        POWER((mc.mean_silt - sample.ss_silt), 2) AS silt, 
        POWER((mc.mean_clay - sample.ss_clay), 2) AS clay 
    FROM soilsample AS sample
    JOIN mean_components AS mc ON sample.ss_fieldkey = mc.fieldkey
),
variance AS (
    SELECT sd.fieldkey, 
        (SUM(sd.sand)/(mc.n - 1)) AS var_sand, 
        (SUM(sd.silt)/(mc.n - 1)) AS var_silt, 
        (SUM(sd.clay)/(mc.n - 1)) AS var_clay 
    FROM squared_diff AS sd
    JOIN mean_components AS mc ON sd.fieldkey = mc.fieldkey
    GROUP BY sd.fieldkey
)
SELECT 
    v.fieldkey,
    mean_sand,
    mean_silt,
    mean_clay,
    SQRT(var_sand) AS std_dev_sand, 
    SQRT(var_silt) AS std_dev_silt, 
    SQRT(var_clay) AS std_dev_clay 
FROM variance v
JOIN mean_components AS mc ON v.fieldkey = mc.fieldkey
ORDER BY v.fieldkey;

-- 2. Total crop yields for each farmer by crop, accounting for units.

SELECT 
    f.f_name AS farmer, 
    c.c_name AS crop, 
    SUM(fldc.fldc_yield) AS yield, 
    fldc.fldc_yield_unit AS units
FROM fieldcrop fldc
JOIN field fld ON fldc.fldc_fieldkey = fld.fld_fieldkey
JOIN crop c ON fldc.fldc_cropkey = c.c_cropkey
JOIN farmer f ON fld.fld_farmerkey = f.f_farmerkey
GROUP BY
    f.f_farmerkey,
    c.c_cropkey,
    units
ORDER BY
    f.f_farmerkey ASC,
    yield ASC;

-- 3. Latest soil sample for a field. Let's say, field 2.

SELECT * FROM soilsample
WHERE ss_fieldkey = 2
ORDER BY ss_sampledate DESC
LIMIT 1;

-- 4. Display James Holloway's field's change in heavy metals presence in the last year's worth of his samples.

WITH 
latest_sample_for_farmer AS (
    SELECT MAX(ss.ss_sampledate) AS latest_sample FROM soilsample ss
    JOIN farmer f ON ss.ss_fieldkey = f.f_fieldkey
    WHERE f.f_name = 'James' AND f.f_surname = 'Holloway'
), 
most_recent_year AS (
        SELECT ss_sampledate AS dates FROM soilsample
        WHERE ss_sampledate >= DATE((SELECT * FROM latest_sample_for_farmer), '-1 year')
    )
SELECT 
    f.f_name || ' ' || f.f_surname AS farmer_name, 
    ss_sampledate AS date,
    ss_lead_ppm AS lead, 
    ss_mercury_ppm AS mercury, 
    ss_nickel_ppm AS nickel, 
    ss_copper_ppm AS copper, 
    ss_chromium_ppm AS chromium, 
    ss_cadmium_ppm AS cadmium, 
    ss_arsenic_ppm AS arsenic, 
    ss_zinc_ppm AS zinc
FROM soilsample
JOIN farmer f ON ss_fieldkey = f.f_fieldkey
WHERE
        f.f_name = 'James' AND f.f_surname = 'Holloway'
    AND ss_sampledate IN (SELECT dates FROM most_recent_year)
ORDER BY ss_sampledate DESC;

-- 5. Samples with contaminants exceeding regulatory thresholds
SELECT
  ss.ss_samplekey,
  ss.ss_sampledate,
  f.f_farmerkey,
  f.f_name AS farmer_name,
  fld.fld_fieldkey,
  ct.ct_name AS contaminant,
  ssc.ssc_concentration,
  ct.ct_reg_threshold,
  ct.ct_threshold_unit
FROM soilsample ss
JOIN soilsample_contaminant ssc ON ss.ss_samplekey = ssc.ssc_samplekey
JOIN contaminant_type ct ON ssc.ssc_contaminantkey = ct.ct_contaminantkey
JOIN field fld ON ss.ss_fieldkey = fld.fld_fieldkey
JOIN farmer f ON fld.fld_farmerkey = f.f_farmerkey
WHERE ct.ct_reg_threshold IS NOT NULL
  AND ssc.ssc_concentration > ct.ct_reg_threshold
ORDER BY ss.ss_sampledate DESC, ssc.ssc_concentration DESC;

-- 6. Fields with no maintenance in the last N years
WITH last_maint AS (
  SELECT
    fldm_fieldkey,
    MAX(fldm_begindate) AS last_begindate
  FROM fieldmaintenance
  GROUP BY fldm_fieldkey
)
SELECT
  fld.fld_fieldkey,
  fld.fld_farmerkey,
  fld.fld_size,
  lm.last_begindate
FROM field fld
LEFT JOIN last_maint lm ON fld.fld_fieldkey = lm.fldm_fieldkey
WHERE lm.last_begindate IS NULL
   OR lm.last_begindate < date('now', '-3 years')
ORDER BY lm.last_begindate NULLS FIRST;
