.mode column
.headers on
.width 20 20 20 20 20 20 20 20 20 20


.print ""
.print "==========================================="
.print "QUERY 1: Soil Component Statistics by Field"
.print "==========================================="

-- Important for analyzing the distribution of the dataset for
-- each field. These statistics inform pattern and variability analyses.

WITH 
mean_components AS (
  SELECT 
    ss_fieldkey AS fieldkey, 
    ROUND(AVG(ss_sand), 2) AS mean_sand, 
    ROUND(AVG(ss_silt), 2) AS mean_silt, 
    ROUND(AVG(ss_clay), 2) AS mean_clay,
    ROUND(AVG(ss_ph), 2)  AS mean_ph,
    COUNT(*) AS n 
  FROM soilsample
  GROUP BY ss_fieldkey
),
squared_diff AS (
  SELECT mc.fieldkey, 
    POWER((mc.mean_sand - sample.ss_sand), 2) AS sand, 
    POWER((mc.mean_silt - sample.ss_silt), 2) AS silt, 
    POWER((mc.mean_clay - sample.ss_clay), 2) AS clay, 
    POWER((mc.mean_ph - sample.ss_ph), 2) AS ph
  FROM soilsample AS sample
  JOIN mean_components AS mc ON sample.ss_fieldkey = mc.fieldkey
),
variance AS (
  SELECT sd.fieldkey, 
    (SUM(sd.sand)/(mc.n - 1)) AS var_sand, 
    (SUM(sd.silt)/(mc.n - 1)) AS var_silt, 
    (SUM(sd.clay)/(mc.n - 1)) AS var_clay,
    (SUM(sd.ph)/(mc.n-1)) AS var_ph
  FROM squared_diff AS sd
  JOIN mean_components AS mc ON sd.fieldkey = mc.fieldkey
  GROUP BY sd.fieldkey
)
SELECT 
    v.fieldkey,
    mean_sand,
    ROUND(SQRT(var_sand), 2) AS std_dev_sand,
    mean_silt,
    ROUND(SQRT(var_silt), 2) AS std_dev_silt, 
    mean_clay,
    ROUND(SQRT(var_clay), 2) AS std_dev_clay,
    mean_ph,
    ROUND(SQRT(var_ph), 2) AS std_dev_ph
FROM variance v
JOIN mean_components AS mc ON v.fieldkey = mc.fieldkey
ORDER BY v.fieldkey;


.print ""
.print "==========================================="
.print "QUERY 2: Total Crop Yields by Farmer/Crop"
.print "==========================================="

-- Informs assessments of food security, agricultural productivity,
-- and economic health.

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


.print ""
.print "==========================================="
.print "QUERY 3: Latest Soil Sample for Field 2"
.print "==========================================="

-- The farmer (or related employee) may only be concerned with the most recent sample
-- if they specifically ordered it, especially after a potential contamination or
-- overapplication event.

SELECT * FROM soilsample
WHERE ss_fieldkey = 2
ORDER BY ss_sampledate DESC
LIMIT 1;


.print ""
.print "==========================================="
.print "QUERY 4: James Holloway's Metals (Last Year)"
.print "==========================================="

-- We may be concerned about metal concentration if we are analyzing the flow of
-- contamination risks, such as fertilizer, spills, or leeching.
-- Spatially, we may also be worried about water contamination from leeching
-- metals.

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


.print ""
.print "==========================================="
.print "QUERY 5: Samples Exceeding Thresholds"
.print "==========================================="

-- Find moments in time where metal concentrations were detected
-- as too large for safe agricultural output.
-- As a historical record it is good for spatial and socioeconomic
-- patterns, and as a current view of the soil it is important
-- for a farmer/manager to immediately address the issue.
-- Below query looks at three metals, specifically.

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
  (ss.ss_lead_ppm   IS NOT NULL AND ss.ss_lead_ppm > 100)
  OR (ss.ss_cadmium_ppm IS NOT NULL AND ss.ss_cadmium_ppm > 0.48)
  OR (ss.ss_arsenic_ppm IS NOT NULL AND ss.ss_arsenic_ppm > 10)
ORDER BY ss.ss_sampledate DESC;


.print ""
.print "==========================================="
.print "QUERY 6: Fields with No Recent Maintenance"
.print "==========================================="

-- Check if a field has NOT used particular inputs (besides water)
-- This information may be used to analyze [relatively] naturally 
-- productive fields, or as we have noticed, analyze which fields
-- who have NOT reported any of their data.

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
  TRIM(f.f_name || ' ' || f.f_surname) AS farmer_name,
  fld.fld_soilkey,
  lm.last_begindate
FROM field fld
LEFT JOIN last_maint lm
  ON fld.fld_fieldkey = lm.fldm_fieldkey
LEFT JOIN farmer f
  ON fld.fld_farmerkey = f.f_farmerkey
WHERE lm.last_begindate IS NULL
   OR lm.last_begindate < date('now', '-3 years')
ORDER BY (lm.last_begindate IS NOT NULL), lm.last_begindate;


.print ""
.print "==========================================="
.print "QUERY 7: Monthly Avg pH (Last 12 Months)"
.print "==========================================="

-- Another statistic, but in a smaller timescale for measuring
-- local, short-term changes.

SELECT
  strftime('%Y-%m', ss.ss_sampledate) AS year_month,
  COUNT(*) AS samples,
  ROUND(AVG(ss.ss_ph), 2) AS avg_ph
FROM soilsample ss
WHERE ss.ss_fieldkey = 2 
  AND ss.ss_sampledate >= date((SELECT MAX(ss.ss_sampledate) AS latest_sample FROM soilsample ss), '-12 months') 
GROUP BY 
    year_month--,
    -- ss_fieldkey
ORDER BY year_month;


.print ""
.print "==========================================="
.print "QUERY 8: Maint. Cost vs Total Yield"
.print "==========================================="

-- Analyze maintenance inputs vs yield patterns.
-- Useful for analyzing economic constraints and
-- potential misuse of inputs.

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
ORDER BY 
      m.fieldkey ASC,
      m.year ASC,
      amount_per_yield_unit DESC NULLS LAST;


.print ""
.print "==========================================="
.print "QUERY 9: Soil Type Mismatch"
.print "==========================================="

-- See which pairs of crops and soils mismatch. This is not
-- necessarily a bad thing due to variance in crop tolerance,
-- but may help further inform pattern matching of crop 
-- performance and their conditions.

SELECT
  fld.fld_fieldkey,
  fld.fld_farmerkey,
  f.f_name || ' ' || f.f_surname AS farmer_name,
  c.c_cropkey,
  c.c_name AS crop_name,
  fld.fld_soilkey AS field_soilkey,
  st_field.st_soil_texture AS field_soil_texture,
  c.c_preferredsoil AS crop_preferred_soil,
  st_pref.st_soil_texture AS crop_preferred_soil_texture
FROM field fld
JOIN fieldcrop fldc 
    ON fld.fld_fieldkey = fldc.fldc_fieldkey
JOIN crop c 
    ON fldc.fldc_cropkey = c.c_cropkey
JOIN farmer f 
    ON fld.fld_farmerkey = f.f_farmerkey
LEFT JOIN soiltype st_field  
    ON fld.fld_soilkey = st_field.st_soilkey
LEFT JOIN soiltype st_pref   
    ON c.c_preferredsoil = st_pref.st_soilkey
GROUP BY
      fld.fld_fieldkey,
      c.c_cropkey
ORDER BY fld.fld_fieldkey;


.print ""
.print "==========================================="
.print "QUERY 10: Avg NPK by Soil Texture"
.print "==========================================="

-- Useful for soil analyses and pattern matching. Useful
-- for generalizations by soil type.

SELECT
  st.st_soil_texture,
  COUNT(ss.ss_samplekey) AS sample_count,
  ROUND(AVG(ss.ss_nitrogen_ppm),2)   AS avg_nitrogen_ppm,
  ROUND(AVG(ss.ss_phosphorus_ppm),2) AS avg_phosphorus_ppm,
  ROUND(AVG(ss.ss_potassium_ppm),2)  AS avg_potassium_ppm,
  ROUND(AVG(ss.ss_cec), 2) AS avg_cec
FROM soilsample ss
JOIN field fld ON ss.ss_fieldkey = fld.fld_fieldkey
JOIN soiltype st ON fld.fld_soilkey = st.st_soilkey
GROUP BY st.st_soil_texture
HAVING COUNT(ss.ss_samplekey) >= 5
ORDER BY st.st_soilkey DESC;


.print ""
.print "================================================"
.print "QUERY 11: Active Crop Fields (as of 2019-03-15) "
.print "================================================"

-- Useful for historical records. May inform historical economic
-- and sociopolitical patterns.

SELECT
      c.c_cropkey,
      c.c_name,
      COUNT(fldc.fldc_fieldkey) AS active_fields
FROM crop c
LEFT JOIN fieldcrop fldc 
      ON c.c_cropkey = fldc.fldc_cropkey
      AND date('2019-03-15') BETWEEN fldc.fldc_begindate AND fldc.fldc_enddate
GROUP BY c.c_cropkey
HAVING (COUNT(DISTINCT fldc.fldc_fieldkey) > 0);


.print ""
.print "==========================================="
.print "QUERY 12: Most Commonly Grown Crop"
.print "==========================================="

-- Somewhat trivial. If combined with spatial data, may
-- further inform socioeconomic trends in the region.
-- Indicates economic viability of crop(s) as well.

SELECT
    c.c_name,
    COUNT(DISTINCT fldc_begindate) AS total_planted
FROM crop c
JOIN fieldcrop fc ON c.c_cropkey = fc.fldc_cropkey
GROUP BY c.c_cropkey
ORDER BY total_planted DESC
LIMIT 1;

-- Query that explicitly shows distinctness of begindate and crops.
-- Returns the same result(s) as the above query would.

-- WITH distinct_plantings AS (
--   SELECT DISTINCT
--     fldc_cropkey,
--     fldc_begindate
--   FROM fieldcrop
-- )
-- SELECT
--   c.c_cropkey,
--   c.c_name AS crop_name,
--   COUNT(*) AS planting_count
-- FROM distinct_plantings dp
-- JOIN crop c ON dp.fldc_cropkey = c.c_cropkey
-- GROUP BY dp.fldc_cropkey, c.c_name
-- ORDER BY planting_count DESC;



.print ""
.print "==========================================="
.print "QUERY 13: Top Producing Farmers by Crop"
.print "==========================================="

-- Analyze economic productivity by farmers for each crop.
-- Identifies the top producers.

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
SELECT total.farmer, total.crop, MAX(total.yield) AS total_yield, total.units FROM total_yields_by_farmer_by_crop total
GROUP BY total.crop;


.print ""
.print "==========================================="
.print "QUERY 14: Farmers Ranked by Avg Yield"
.print "==========================================="

-- Rank farmer productivity

SELECT
  f.f_farmerkey,
  TRIM(f.f_name || ' ' || f.f_surname) AS farmer_name,
  ROUND(AVG(fc.fldc_yield),2) AS avg_yield_per_active_crop,
  COUNT(fc.fldc_fieldkey) AS active_fields_count
FROM farmer f
JOIN field fld ON f.f_farmerkey = fld.fld_farmerkey
JOIN fieldcrop fc ON fld.fld_fieldkey = fc.fldc_fieldkey
GROUP BY f.f_farmerkey
ORDER BY avg_yield_per_active_crop DESC;


.print ""
.print "==========================================="
.print "QUERY 15: Crop vs Field pH Mismatch"
.print "==========================================="

-- See which pairs of crops and field pH mismatch. This is not
-- necessarily a bad thing due to variance in crop tolerance,
-- but may help further inform pattern matching of crop 
-- performance and their conditions.

WITH field_avg AS (
  SELECT fld.fld_fieldkey, AVG(ss.ss_ph) AS avg_ph
  FROM field fld
  JOIN soilsample ss ON fld.fld_fieldkey = ss.ss_fieldkey
  GROUP BY fld.fld_fieldkey
)
SELECT
  fld.fld_fieldkey,
  TRIM(f.f_name || ' ' || f.f_surname) AS farmer_name,
  c.c_cropkey,
  c.c_name,
  ROUND(fa.avg_ph, 2) AS field_avg_ph,
  c.c_ph AS crop_pref_ph,
  ROUND(ABS(fa.avg_ph - c.c_ph), 3) AS ph_diff,
  COUNT(*) AS occurrences
FROM field fld
JOIN fieldcrop fc ON fld.fld_fieldkey = fc.fldc_fieldkey
JOIN crop c ON fc.fldc_cropkey = c.c_cropkey
JOIN farmer f ON fld.fld_farmerkey = f.f_farmerkey
JOIN field_avg fa ON fld.fld_fieldkey = fa.fld_fieldkey
WHERE ABS(fa.avg_ph - c.c_ph) < 6
GROUP BY
  fld.fld_fieldkey,
  farmer_name,
  c.c_cropkey,
  c.c_name,
  field_avg_ph,
  crop_pref_ph
ORDER BY ph_diff DESC;


.print ""
.print "==========================================="
.print "QUERY 16: Total Yield Per Season"
.print "==========================================="

 -- Useful for pattern recognition by season. (Including economic productivity)

SELECT
  s.s_seasonkey,
  s.s_name,
  ROUND(SUM(fc.fldc_yield), 2) AS total_yield,
  COUNT(fc.fldc_fieldkey) AS plantings_count
FROM season s
JOIN crop c ON c.c_preferredseason = s.s_seasonkey
JOIN fieldcrop fc ON fc.fldc_cropkey = c.c_cropkey
GROUP BY s.s_seasonkey, s.s_name
ORDER BY total_yield DESC;

.print ""
.print "==========================================="
.print "QUERY 17: Crop Rotation History"
.print "==========================================="

-- 

WITH crop_history AS (
  SELECT
    fc.fldc_fieldkey,
    fc.fldc_cropkey,
    fc.fldc_enddate,
    ROW_NUMBER() OVER (PARTITION BY fc.fldc_fieldkey ORDER BY fc.fldc_enddate DESC) AS rn
  FROM fieldcrop fc
) 
SELECT 
  current_harvest.fldc_fieldkey,
  current_harvest.fldc_cropkey AS current_cropkey,
  previous_harvest.fldc_cropkey AS previous_cropkey,
  c1.c_name AS current_crop_name,
  c2.c_name AS previous_crop_name
FROM crop_history current_harvest
JOIN crop_history previous_harvest 
  ON current_harvest.fldc_fieldkey = previous_harvest.fldc_fieldkey
JOIN crop c1 
  ON current_harvest.fldc_cropkey = c1.c_cropkey
JOIN crop c2 
  ON previous_harvest.fldc_cropkey = c2.c_cropkey
WHERE current_harvest.rn = 1 
  AND previous_harvest.rn = 2
  AND current_harvest.fldc_cropkey <> previous_harvest.fldc_cropkey;


.print ""
.print "==========================================="
.print "QUERY 18: Fieldcrops Within Season"
.print "==========================================="

SELECT
  fc.*,
  f.f_farmerkey,
  TRIM(f.f_name || ' ' || f.f_surname) AS farmer_name,
  c.c_name AS crop_name
FROM fieldcrop fc
JOIN field fld ON fc.fldc_fieldkey = fld.fld_fieldkey
JOIN farmer f ON fld.fld_farmerkey = f.f_farmerkey
JOIN crop c ON fc.fldc_cropkey = c.c_cropkey
JOIN season s ON s.s_seasonkey = c.c_preferredseason
ORDER BY fc.fldc_begindate;


.print ""
.print "==========================================="
.print "QUERY 19: Avg Yield per Crop per Season"
.print "==========================================="

SELECT
  c.c_cropkey,
  c.c_name,
  s.s_seasonkey,
  s.s_name,
  ROUND(AVG(fc.fldc_yield), 2) AS avg_yield,
  COUNT(fc.fldc_fieldkey) AS observations
FROM fieldcrop fc
JOIN crop c ON fc.fldc_cropkey = c.c_cropkey
JOIN season s ON c.c_preferredseason = s.s_seasonkey
GROUP BY c.c_cropkey, s.s_seasonkey
HAVING observations >= 1
ORDER BY c.c_cropkey, avg_yield DESC;


.print ""
.print "==============================================="
.print "QUERY 20: Nutrients & Organic Matter Per Season"
.print "==============================================="

WITH sample_season AS (
  SELECT
    fld.fld_fieldkey,
    CASE 
        WHEN CAST(strftime('%m', ss.ss_sampledate) AS INT) IN (3, 4, 5) THEN 'Spring'
        WHEN CAST(strftime('%m', ss.ss_sampledate) AS INT) IN (6, 7, 8) THEN 'Summer'
        WHEN CAST(strftime('%m', ss.ss_sampledate) AS INT) IN (9, 10, 11) THEN 'Autumn'
        ELSE 'Winter'
    END AS season_name,
    ss.ss_samplekey,
    ss.ss_sampledate,
    ss.ss_nitrogen_ppm,
    ss.ss_phosphorus_ppm,
    ss.ss_potassium_ppm,
    ss.ss_organicmatter_pct
  FROM soilsample ss
  JOIN field fld ON ss.ss_fieldkey = fld.fld_fieldkey
)
SELECT
  ss.fld_fieldkey                                  AS field_key,
  ss.season_name                                   AS season_name,
  COUNT(ss.ss_samplekey)                           AS sample_count,
  ROUND(AVG(ss.ss_nitrogen_ppm), 2)                AS avg_nitrogen_ppm,
  ROUND(MIN(ss.ss_nitrogen_ppm), 2)                AS min_nitrogen_ppm,
  ROUND(MAX(ss.ss_nitrogen_ppm), 2)                AS max_nitrogen_ppm,
  ROUND(AVG(ss.ss_phosphorus_ppm), 2)              AS avg_phosphorus_ppm,
  ROUND(AVG(ss.ss_potassium_ppm), 2)               AS avg_potassium_ppm,
  ROUND(AVG(ss.ss_organicmatter_pct), 2)           AS avg_organicmatter_pct,
  MIN(ss.ss_sampledate)                            AS first_sample_date,
  MAX(ss.ss_sampledate)                            AS last_sample_date
FROM sample_season ss
GROUP BY ss.fld_fieldkey, ss.season_name
ORDER BY ss.fld_fieldkey, ss.season_name;
