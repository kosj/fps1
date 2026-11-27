"""메시 품질 진단: blender -b --python analyze.py -- in.glb [out.png]

AI 생성 메시에서 자주 나오는 문제를 숫자로 뽑고, 음영/와이어 미리보기를 렌더한다.
"""
import json
import math
import sys

import bmesh
import bpy
from mathutils import Vector


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load(path):
    if path.endswith((".glb", ".gltf")):
        bpy.ops.import_scene.gltf(filepath=path)
    elif path.endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    elif path.endswith(".obj"):
        bpy.ops.wm.obj_import(filepath=path)
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def stats(objs):
    out = {"objects": len(objs)}
    tris = verts = nonman = boundary = degenerate = sliver = islands = 0
    uv_islands = 0
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    sharp_edges = 0
    edges = 0
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bm.verts.ensure_lookup_table()
        verts += len(bm.verts)
        tris += len(bm.faces)
        edges += len(bm.edges)
        for e in bm.edges:
            n = len(e.link_faces)
            if n == 1:
                boundary += 1
            elif n != 2:
                nonman += 1
            elif e.calc_face_angle(0.0) > math.radians(30):
                sharp_edges += 1
        for f in bm.faces:
            a = f.calc_area()
            if a < 1e-10:
                degenerate += 1
                continue
            longest = max(e.calc_length() for e in f.edges)
            # 정삼각형이면 1, 바늘처럼 길쭉하면 0에 가깝다.
            q = 4 * math.sqrt(3) * a / (3 * longest * longest)
            if q < 0.1:
                sliver += 1
        # 떨어져 있는 조각 수
        seen = set()
        for v in bm.verts:
            if v.index in seen:
                continue
            islands += 1
            stack = [v]
            seen.add(v.index)
            while stack:
                cur = stack.pop()
                for e in cur.link_edges:
                    w = e.other_vert(cur)
                    if w.index not in seen:
                        seen.add(w.index)
                        stack.append(w)
        uv = bm.loops.layers.uv.active
        if uv:
            seams = 0
            for e in bm.edges:
                if len(e.link_loops) == 2:
                    l1, l2 = e.link_loops
                    a1, a2 = l1[uv].uv, l1.link_loop_next[uv].uv
                    b1, b2 = l2[uv].uv, l2.link_loop_next[uv].uv
                    if (a1 - b2).length > 1e-5 or (a2 - b1).length > 1e-5:
                        seams += 1
            out["uv_seam_edges"] = out.get("uv_seam_edges", 0) + seams
        for v in bm.verts:
            w = o.matrix_world @ v.co
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
        bm.free()
    out.update(
        verts=verts, tris=tris, pieces=islands, boundary_edges=boundary,
        non_manifold_edges=nonman, degenerate_tris=degenerate,
        sliver_tris=sliver, sliver_pct=round(100 * sliver / max(tris, 1), 1),
        sharp_edge_pct=round(100 * sharp_edges / max(edges, 1), 1),
        size=[round(hi[i] - lo[i], 3) for i in range(3)],
        materials=sorted({m.name for o in objs for m in o.data.materials if m}),
        images=[(i.name, i.size[0], i.size[1]) for i in bpy.data.images if i.size[0]],
    )
    return out, lo, hi


def render(objs, lo, hi, path, wire):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 700
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.52, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scene.world = world
    center = (lo + hi) / 2
    radius = (hi - lo).length / 2
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    direction = Vector((0.9, -1.4, 0.6)).normalized()
    cam.location = center + direction * radius * 2.6
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.clip_start = radius * 0.01
    cam_data.clip_end = radius * 20
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    scene.collection.objects.link(sun)
    if wire:
        mat = bpy.data.materials.new("wire")
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        w = nt.nodes.new("ShaderNodeWireframe")
        w.inputs[0].default_value = 0.6
        w.use_pixel_size = True
        mix = nt.nodes.new("ShaderNodeMixRGB")
        mix.inputs[1].default_value = (0.75, 0.75, 0.75, 1)
        mix.inputs[2].default_value = (0.02, 0.02, 0.02, 1)
        nt.links.new(w.outputs[0], mix.inputs[0])
        nt.links.new(mix.outputs[0], bsdf.inputs["Base Color"])
        for o in objs:
            o.data.materials.clear()
            o.data.materials.append(mat)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    reset()
    objs = load(args[0])
    result, lo, hi = stats(objs)
    print("MESH_STATS " + json.dumps(result, ensure_ascii=False))
    if len(args) > 1:
        render(objs, lo, hi, args[1] + "_shaded.png", False)
        render(objs, lo, hi, args[1] + "_wire.png", True)


main()
