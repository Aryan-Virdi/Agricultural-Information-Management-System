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

-- 5. Which farmers produced the most of each crop. Display kg/ha and bushels/ha separately.

WITH
total_yields_by_farmer_by_crop AS (
    SELECT 
        f.f_name || ' ' || f.f_surname AS farmer, 
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
)
SELECT total.farmer, total.crop, MAX(total.yield), total.units FROM total_yields_by_farmer_by_crop total
GROUP BY total.crop;
-- 5. Samples with contaminants exceeding regulatory thresholds
SELECT
  ss.ss_samplekey,
  ss.ss_sampledate,
  fld.fld_fieldkey,
  f.f_farmerkey,
  f.f_name || ' ' || f.f_surname AS farmer_name,
  ss.ss_lead_ppm,
  ss.ss_cadmium_ppm,
  ss.ss_arsenic_ppm
FROM soilsample ss
JOIN field fld ON ss.ss_fieldkey = fld.fld_fieldkey
JOIN farmer f ON fld.fld_farmerkey = f.f_farmerkey
WHERE
  (ss.ss_lead_ppm   IS NOT NULL AND ss.ss_lead_ppm   > :lead_threshold)
  OR (ss.ss_cadmium_ppm IS NOT NULL AND ss.ss_cadmium_ppm > :cadmium_threshold)
  OR (ss.ss_arsenic_ppm IS NOT NULL AND ss.ss_arsenic_ppm > :arsenic_threshold)
ORDER BY ss.ss_sampledate DESC;


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

-- 7. Monthly average pH for a field over the last 12 months
SELECT
  strftime('%Y-%m', ss.ss_sampledate) AS year_month,
  COUNT(*) AS samples,
  ROUND(AVG(ss.ss_ph), 2) AS avg_ph
FROM soilsample ss
WHERE ss.ss_fieldkey = :fieldkey -- Update with the appropiate FieldKey, applicable only for a specific field
  AND ss.ss_sampledate >= date('now', '-12 months')
GROUP BY year_month
ORDER BY year_month;

-- 8. Yearly maintenance cost vs total yield per field
WITH maint_by_year AS (
  SELECT
    fldm_fieldkey AS fieldkey,
    strftime('%Y', fldm_begindate) AS year,
    SUM(COALESCE(fldm_amount,0)) AS total_maint_amount
  FROM fieldmaintenance
  GROUP BY fldm_fieldkey, year
),
yield_by_year AS (
  SELECT
    fldc_fieldkey AS fieldkey,
    strftime('%Y', fldc_enddate) AS year,
    SUM(COALESCE(fldc_yield,0)) AS total_yield
  FROM fieldcrop
  GROUP BY fldc_fieldkey, year
)
SELECT
  m.fieldkey,
  m.year,
  m.total_maint_amount,
  COALESCE(y.total_yield,0) AS total_yield,
  CASE WHEN COALESCE(y.total_yield,0) = 0 THEN NULL
       ELSE ROUND(m.total_maint_amount / y.total_yield, 6)
  END AS amount_per_yield_unit
FROM maint_by_year m
LEFT JOIN yield_by_year y ON m.fieldkey = y.fieldkey AND m.year = y.year
ORDER BY amount_per_yield_unit DESC NULLS LAST;

-- 9. Active plantings where field soil ≠ crop preferred soil
SELECT
  fld.fld_fieldkey,
  fld.fld_farmerkey,
  f.f_name || ' ' || f.f_surname AS farmer_name,
  c.c_cropkey,
  c.c_name AS crop_name,
  fld.fld_soilkey AS field_soilkey,
  c.c_preferredsoil AS crop_preferred_soil
FROM field fld
JOIN fieldcrop fldc ON fld.fld_fieldkey = fldc.fldc_fieldkey
JOIN crop c ON fldc.fldc_cropkey = c.c_cropkey
JOIN farmer f ON fld.fld_farmerkey = f.f_farmerkey
WHERE date('now') BETWEEN fldc.fldc_begindate AND fldc.fldc_enddate
  AND (fld.fld_soilkey IS NULL OR fld.fld_soilkey <> c.c_preferredsoil)
ORDER BY fld.fld_fieldkey;

-- 10. Average N, P, K by soil texture
-- modify for std deviation
SELECT
  st.st_soil_texture,
  COUNT(ss.ss_samplekey) AS sample_count,
  ROUND(AVG(ss.ss_nitrogen_ppm),2)   AS avg_nitrogen_ppm,
  ROUND(AVG(ss.ss_phosphorus_ppm),2) AS avg_phosphorus_ppm,
  ROUND(AVG(ss.ss_potassium_ppm),2)  AS avg_potassium_ppm
FROM soilsample ss
JOIN field fld ON ss.ss_fieldkey = fld.fld_fieldkey
JOIN soiltype st ON fld.fld_soilkey = st.st_soilkey
GROUP BY st.st_soil_texture
HAVING COUNT(ss.ss_samplekey) >= 5
ORDER BY avg_nitrogen_ppm DESC;

-- 11. List all crops and how many fields are actively growing them
SELECT
    c.c_cropkey,
    c.c_name,
    COUNT(fldc.fldc_fieldkey) AS active_fields
FROM crop c
LEFT JOIN fieldcrop fldc 
    ON c.c_cropkey = fldc.fldc_cropkey
    AND date('now') BETWEEN fldc.fldc_begindate AND fldc.fldc_enddate
GROUP BY c.c_cropkey;

-- 12. Find the most commonly grown crop
SELECT
    c.c_name,
    COUNT(*) AS total_planted
FROM crop c
JOIN fieldcrop fc ON c.c_cropkey = fc.fldc_cropkey
GROUP BY c.c_cropkey
ORDER BY total_planted DESC
LIMIT 1;
