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