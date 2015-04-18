require! '../index': geoconvert
require! <[fs topojson]>

geoconvert.shp.file.to-topojson \../sample/shp/village.shp, {"shapefile-encoding":"big5"} .then (topodata) ->
  # example vote-sections
  # vote-sections = {
  #   "大家好": ["6401"]
  # }
  geomlists = for k,blocks of vote-sections => do
    properties: { name: k }
    list: [ (topodata.objects.default.geometries.filter -> RegExp("^#block").exec it.properties.VILLAGE_ID) for block in blocks ].reduce(((a,b) -> a ++ b), [])

  geoconvert.topojson.merge topodata, {default: geomlists} .then (topodata) -> 
    fs.write-file-sync \output.json, JSON.stringify(topodata)
