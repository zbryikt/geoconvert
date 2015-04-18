require! <[fs zlib osmtogeojson topojson shapefile bluebird xmldom coord]>

geoconvert = do
  default-config: do
    "quantization": undefined
    "pre-quantization": 1e6
    "post-quantization": 1e4
    "simplify": 0
    "simplify-proportion": 0
    "coordinate-system": "cartesian"
    "cartesian": false
    "spherical": false
    "force-clockwise": true
    "stitch-poles": true
    "filter": "small-detached"
    "allow-empty": false
    "id-property": null
    "properties": false
    "shapefile-encoding": null
    "ignore-shapefile-properties": false
    "longitude": "longitude"
    "latitude": "latitude"
    "projection": null
    "width": null
    "height": null
    "margin": 0
    "invert": "auto"
    "bbox": false

  options: (config) -> 
    config = ( {} <<< @default-config ) <<< config
    do
      "verbose": false,
      "pre-quantization": +config["pre-quantization"]
      "post-quantization": +config["post-quantization"]
      "coordinate-system": if config.spherical => \spherical else if config.cartesian => \cartesian else \auto
      "stitch-poles": config["stitch-poles"]
      "id": config["id-property"] or (.id)
      "property-transform": config["properties"] or (.properties)
      "minimum-area": config["simplify"]
      "preserve-attached": config["filter"] !== "small"
      "retain-proportion": +config["simplify-proportion"]
      "force-clockwise": false

  twd97-gws84: (data) ->
    if !data.length => return
    if typeof(data.0) == typeof(0) and data.0 > 200 => # normal longitude < 180
      {lat,lng} = coord.to-gws84 data.0, data.1
      [data.0,data.1] = [lng, lat]
    else => for item in data => @twd97-gws84 item

  clockwisify: (data) ->
    if !data.length or !data.0.length => return
    if typeof(data.0.0) == typeof(0) =>
      sum = 0
      for i from 0 til data.length 
        j = ( i + 1 ) % data.length
        sum += ( data[j]0 - data[i]0 ) * ( data[j]1 + data[i]1 )
      if sum < 0 => data.reverse!
    else => for item in data => @clockwisify item

  fixformat: (geodata) ->
    if geodata.type == \FeatureCollection =>
      target = {objects: {default: {geometries: geodata.features}}}
    else => 
      for obj of geodata.objects =>
        bbox = geodata.objects[obj]bbox
        for i from 0 to 2 by 2
          {lat, lng} = coord.to-gws84 bbox[i], bbox[i + 1]
          [bbox[i], bbox[i + 1]] = [lng, lat]
        target = geodata
    for obj of geodata.objects
      for feature in target.objects[obj]geometries =>
        @twd97-gws84 feature.geometry.coordinates # if twd97
        @clockwisify feature.geometry.coordinates # keep coordinate clockwise
    geodata

  osm: do
    file: do
      to-geojson: (filename) -> new bluebird (res, rej) ->
        (e, osmdata) <- fs.read-file filename, _
        if e => return rej e
        osmdata = osmdata.toString!
        geoconvert.osm.to-geojson osmdata 
          .then (geodata) -> res geodata
          .catch (e) -> rej e
      to-topojson: (filename) -> new bluebird (res, rej) ~>
        (e, osmdata) <- fs.read-file filename, _
        if e => return rej e
        osmdata = osmdata.toString!
        geoconvert.osm.to-topojson osmdata
          .then (topodata) -> res topodata
          .catch (e) -> rej e

    to-geojson: (osmdata) -> new bluebird (res, rej) ->
      osm = new xmldom.DOMParser!parseFromString osmdata, \text/xml
      res geoconvert.fixformat osmtogeojson(osm)

    to-topojson: (osmdata) -> new bluebird (res, rej) ~>
      @to-geojson osmdata
        .then (geodata) -> res geoconvert.geojson.to-topojson geodata
        .catch (e) -> rej e

  shp: do
    file: do
      to-geojson: (filename, config = {}) -> new bluebird (res, rej) ->
        (e,c) <- shapefile.read filename, {
          "encoding": config["shapefile-encoding"]
          "ignore-properties": !!config["ignore-shapefile-properties"]
        }, _
        if e => return rej e
        res c
      to-topojson: (filename, config = {}) -> new bluebird (res, rej) ~>
        options = geoconvert.options config
        (c) <- @to-geojson filename, config .then _
        (topodata) <- geoconvert.geojson.to-topojson c, config .then _
        res topodata

  geojson: do
    file: do
      to-topojson: (filename,config = {}) -> new bluebird (res, rej) ~>
        geodata = JSON.parse(fs.read-file-sync filename .toString!)
        geoconvert.geojson.to-topojson geodata, config
          .then (topodata) -> res topodata
          .catch (e) -> rej e
    to-topojson: (geodata, config = {}) -> new bluebird (res, rej) ~>
      options = geoconvert.options config
      object = topojson.topology {default: geodata}, options
      if config.width or config.height =>
        if options["coordinate-system"] !== \cartesian => return rej "width and height require Cartesian coordinates"
        topojson.scale object, config{width, height, margin, invert}
      if +config["simplify"] > 0 or +config["simplify-proportion"] > 0 => topojson.simplify object, options
      if config["force-clockwise"] => topojson.clockwise object, options
      if config["filter"] !== \none => topojson.filter object, options
      if !config["bbox"] => delete object.bbox
      res object

  topojson: do

    merge: (topodata, geometry-list-hash) -> new bluebird (res, rej) ->
      simplify = false
      fill = (a, h) ->
        if typeof(a) == typeof([]) => [fill(item,h) for item in a]
        else h[Math.abs(a)] = 1

      reorder = (a, h) ->
        for idx from 0 til a.length =>
          if typeof(a[idx]) == typeof([]) => 
            a[idx] = reorder a[idx], h
          else 
            a[idx] = (h[Math.abs(a[idx])] - 1) * ( if a[idx] < 0 => -1 else 1 )
        a

      for obj of topodata.objects =>
        topodata.objects[obj]geometries = for k,v of geometry-list-hash[obj]
          ret = topojson.mergeArcs topodata, v.list
          ret.properties = v.properties
          ret

      if simplify =>
        [used, list] = [{}, []]

        for obj of topodata.objects
          for item in topodata.objects[obj]geometries => fill item.arcs, used

        /* this part is to remove unused arc, but somehow not work correctly
        keys = [k for k of used]
        keys.sort!
        count = 1
        for idx in keys => 
          if used[idx] =>
            used[idx] = count
            count++
        for obj of topodata.objects
          for item in topodata.objects[obj]geometries => 
            item.arcs = reorder item.arcs, used

        for idx from 0 til topodata.arcs.length
          if used[idx] => list.push topodata.arcs[idx] 
        */

        for idx from 0 til topodata.arcs.length
          if used[idx] => list.push topodata.arcs[idx] 
          else list.push []

        topodata.arcs = list

      res topodata

module.exports = geoconvert
