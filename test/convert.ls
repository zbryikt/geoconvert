require! '../index': geoconvert
require! <[fs topojson]>

geoconvert.shp.file.to-topojson \../sample/shp/town.shp, {"shapefile-encoding":"big5"} .then (topodata) ->
  hash = {}

  #fs.write-file-sync \county.topo.json, JSON.stringify(topodata)
  #for geom in topodata.objects.default.geometries
  #  hash[]["#{geom.properties.C_Name}/#{geom.properties.T_Name}"].push geom

  for geom in topodata.objects.default.geometries
    if !hash[geom.properties.C_Name] => 
      hash[geom.properties.C_Name] = {
        properties: {C_Name: geom.properties.C_Name}
        list: []
      }
    hash[geom.properties.C_Name].list.push geom
  geomlists = [v for k,v of hash]

  geoconvert.topojson.merge topodata, {default: geomlists} .then (topodata) -> 
    fs.write-file-sync \output.json, JSON.stringify(topodata)

  #fs.write-file-sync \village.merge.topo.json, JSON.stringify(topodata)
  #fs.write-file-sync \../../dev/topojson/town.merge2.topo.json, JSON.stringify(topodata)
  # fs.write-file-sync \../../dev/topojson/town.topo.json, JSON.stringify(topodata)
