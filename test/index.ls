require! '../index': geoconvert, 'MD5': md5

assert = (name, expect, actual) ->
  console.log "TEST #name : expect #expect, got #actual / ", if expect == actual => "PASSED" else "FAILED" 



geoconvert.shp.file.to-geojson \../sample/shp/county.shp
  .then (geodata) -> 
    assert('county.shp to geojson', \be121669b0e1fe6cd2a446deb7e5884a, md5(JSON.stringify(geodata)))
  .catch (e) -> console.log "county.shp : ", e.toString!

geoconvert.shp.file.to-topojson \../sample/shp/town.shp
  .then (topodata) -> 
    assert('town.shp to topojson', \7e55afe96a1c9f8eef21c43a50f9c7c8, md5(JSON.stringify(topodata)))
    hash = {}
    for geom in topodata.objects.default.geometries
      hash[]["#{geom.properties.C_Name}"].push geom
    geomlists = [v for k,v of hash]
    geoconvert.topojson.merge topodata, {default: geomlists}
    assert('town.shp merge', \7b6fd904e7206255d0beaa375b5901b7, md5(JSON.stringify(topodata)))
  .catch (e) -> console.log "town.shp : ", e.toString!

geoconvert.osm.file.to-geojson \../sample/map.osm
  .then (geodata) -> 
    assert('map.osm to geojson', \0063bb9b5df841187820e3d1a61f7077, md5(JSON.stringify(geodata)))
  .catch (e) -> console.log "county.shp : ", e.toString!

geoconvert.osm.file.to-topojson \../sample/map.osm
  .then (topodata) -> 
    assert('map.osm to topojson', \cf837424872961d28a15df15bb1d3e1c, md5(JSON.stringify(topodata)))
  .catch (e) -> console.log "county.shp : ", e.toString!

geoconvert.geojson.file.to-topojson \../sample/osm.geojson
  .then (topodata) -> 
    assert('osm.geojson to topojson', \cf837424872961d28a15df15bb1d3e1c, md5(JSON.stringify(topodata)))
  .catch (e) -> console.log "osm.geojson : ", e.toString!
