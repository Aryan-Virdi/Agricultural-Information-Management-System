# Recommended safe load order
## Load tables in this order so each FK target exists before it’s referenced:
- season
- soiltype
- farmer
- maintenance
- field (depends on farmer and soiltype)
- crop (depends on season)
- soilsample (depends on field)
- fieldcrop (depends on field and crop)
- fieldmaintenance (depends on field and maintenance)
