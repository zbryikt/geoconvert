require! '../index': geoconvert
require! <[fs topojson]>

geoconvert.shp.file.to-topojson \../sample/shp/village.shp .then (topodata) ->
  hash = {}
  for geom in topodata.objects.default.geometries
    hash[]["#{geom.properties.C_Name}"].push geom
  geomlists = [v for k,v of hash]
  geoconvert.topojson.merge topodata, {default: geomlists} .then (topodata) -> 
    fs.write-file-sync \../../dev/topojson/town.topo.json, JSON.stringify(topodata)
