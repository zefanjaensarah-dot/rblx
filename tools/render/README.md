# Map preview

A rough 3D preview of the built map in a web browser (no textures, text or avatars), to check
layout, colour and detail without opening Studio.

```
cd tools/test
lune run ../render/dump_map.luau ../../StealABox_v5.rbxl map.json
```

Then open `view.html?data=map.json&cam=x,y,z,targetX,targetY,targetZ` (serve the folder, or use a
browser that can read local files). Bosses show up as a pile at the origin: the fake engine
doesn't move welded parts when a model is pivoted.
