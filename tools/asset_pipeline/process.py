"""AI 생성 메시를 게임용으로 다시 만든다.

blender -b --python process.py -- in.glb out.glb [--tris 4000] [--mode hard|organic]
    [--tex 1024] [--height 1.0]

원본은 "하이폴리 조각"으로만 쓰고, 새로 만든 깨끗한 로우폴리에 색/노멀/러프니스를 굽는다.
  1. 정리: 중복 정점 병합, 떠 있는 부스러기 제거, 구멍 메우기, 노멀 방향 통일
  2. 리토폴로지: organic은 QuadriFlow(쿼드), hard는 평면 병합 후 축소(각진 면 유지)
  3. 셰이딩: 각도 기준 샤프 엣지 + 면적 가중 노멀
  4. UV: 조각 수가 적은 새 UV
  5. 베이크: 원본 -> 새 메시 (base color, normal, roughness)
  6. 크기/원점 맞춤 후 GLB 내보내기
"""
import argparse
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector


def parse():
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--tris", type=int, default=4000)
    p.add_argument("--mode", default="hard", choices=["hard", "organic"])
    p.add_argument("--tex", type=int, default=1024)
    p.add_argument("--height", type=float, default=0.0, help="가장 긴 변을 이 길이(m)로")
    p.add_argument("--samples", type=int, default=4)
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:])


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def import_joined(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    activate(meshes[0])
    for m in meshes:
        m.select_set(True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.name = "high"
    return obj


def bounds(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(p[i] for p in pts) for i in range(3)))
    hi = Vector((max(p[i] for p in pts) for i in range(3)))
    return lo, hi


def cleanup(obj, diag):
    """UV 이음매 때문에 갈라진 정점을 붙이고, 작은 부스러기와 구멍을 없앤다."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=diag * 1e-5)
    # 떨어진 조각 중 전체의 2%보다 작은 것은 버린다.
    bm.verts.ensure_lookup_table()
    seen = set()
    groups = []
    for v in bm.verts:
        if v.index in seen:
            continue
        group = [v]
        seen.add(v.index)
        i = 0
        while i < len(group):
            for e in group[i].link_edges:
                w = e.other_vert(group[i])
                if w.index not in seen:
                    seen.add(w.index)
                    group.append(w)
            i += 1
        groups.append(group)
    biggest = max(len(g) for g in groups)
    junk = [v for g in groups if len(g) < biggest * 0.02 for v in g]
    removed = len([g for g in groups if len(g) < biggest * 0.02])
    bmesh.ops.delete(bm, geom=junk, context="VERTS")
    edges = [e for e in bm.edges if len(e.link_faces) == 1]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=64)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=diag * 1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    print(f"PIPE cleanup pieces={len(groups)} removed_junk={removed}")


def tri_count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def retopo_organic(obj, tris):
    activate(obj)
    try:
        result = bpy.ops.object.quadriflow_remesh(
            mode="FACES", target_faces=max(tris // 2, 200),
            use_mesh_symmetry=False, use_preserve_sharp=True,
            use_preserve_boundary=True, smooth_normals=True,
        )
        if "FINISHED" in result and tri_count(obj) > 100:
            print("PIPE retopo=quadriflow")
            return
    except RuntimeError as err:
        print("PIPE quadriflow failed:", err)
    retopo_hard(obj, tris)


def retopo_hard(obj, tris):
    """평평한 면은 큰 면 하나로 합치고, 남은 곡면만 삼각형을 줄인다."""
    activate(obj)
    planar = obj.modifiers.new("planar", "DECIMATE")
    planar.decimate_type = "DISSOLVE"
    planar.angle_limit = math.radians(4.0)
    planar.delimit = {"SHARP"}
    bpy.ops.object.modifier_apply(modifier=planar.name)
    tri = obj.modifiers.new("tri", "TRIANGULATE")
    tri.quad_method = "BEAUTY"
    tri.ngon_method = "BEAUTY"
    bpy.ops.object.modifier_apply(modifier=tri.name)
    now = tri_count(obj)
    if now > tris:
        col = obj.modifiers.new("collapse", "DECIMATE")
        col.decimate_type = "COLLAPSE"
        col.ratio = tris / now
        col.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=col.name)
    print(f"PIPE retopo=planar+collapse tris={tri_count(obj)}")


def shade(obj, mode):
    activate(obj)
    angle = math.radians(35 if mode == "hard" else 60)
    bpy.ops.object.shade_smooth_by_angle(angle=angle, keep_sharp_edges=False)
    if mode == "hard":
        wn = obj.modifiers.new("weighted", "WEIGHTED_NORMAL")
        wn.keep_sharp = True
        wn.weight = 100
        bpy.ops.object.modifier_apply(modifier=wn.name)


def unwrap(obj, mode):
    activate(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    while obj.data.uv_layers:
        obj.data.uv_layers.remove(obj.data.uv_layers[0])
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    limit = math.radians(66 if mode == "hard" else 72)
    bpy.ops.uv.smart_project(angle_limit=limit, island_margin=0.006, area_weight=0.0)
    bpy.ops.uv.pack_islands(margin=0.006, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake_maps(high, low, size, samples, diag, out_dir, stem):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    bake = scene.render.bake
    bake.use_selected_to_active = True
    bake.cage_extrusion = diag * 0.012
    bake.max_ray_distance = diag * 0.05
    bake.margin = 8
    bake.use_clear = True

    mat = bpy.data.materials.new(stem)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    low.data.materials.clear()
    low.data.materials.append(mat)

    def image_node(name, colorspace):
        img = bpy.data.images.new(f"{stem}_{name}", size, size, alpha=False)
        img.colorspace_settings.name = colorspace
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        return node

    nodes = {
        "albedo": image_node("albedo", "sRGB"),
        "normal": image_node("normal", "Non-Color"),
        "rough": image_node("rough", "Non-Color"),
    }
    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low

    def run(kind, node, **kw):
        nt.nodes.active = node
        bpy.ops.object.bake(type=kind, **kw)
        path = os.path.join(out_dir, node.image.name + ".png")
        node.image.filepath_raw = path
        node.image.file_format = "PNG"
        node.image.save()
        print("PIPE baked", kind, path)

    run("DIFFUSE", nodes["albedo"], pass_filter={"COLOR"})
    run("NORMAL", nodes["normal"], normal_space="TANGENT")
    run("ROUGHNESS", nodes["rough"])

    nt.links.new(nodes["albedo"].outputs["Color"], bsdf.inputs["Base Color"])
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nodes["normal"].outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(nodes["rough"].outputs["Color"], bsdf.inputs["Roughness"])


def place(obj, height):
    """가장 긴 변을 height로 맞추고, 바닥 중앙을 원점에 둔다."""
    lo, hi = bounds(obj)
    size = hi - lo
    if height > 0:
        s = height / max(size)
        obj.scale = (s, s, s)
        activate(obj)
        bpy.ops.object.transform_apply(scale=True)
        lo, hi = bounds(obj)
    center = (lo + hi) / 2
    obj.location -= Vector((center.x, center.y, lo.z))
    activate(obj)
    bpy.ops.object.transform_apply(location=True)


def main():
    a = parse()
    stem = os.path.splitext(os.path.basename(a.dst))[0]
    out_dir = os.path.dirname(os.path.abspath(a.dst))
    high = import_joined(a.src)
    lo, hi = bounds(high)
    diag = (hi - lo).length
    print(f"PIPE source tris={tri_count(high)}")

    activate(high)
    bpy.ops.object.duplicate()
    low = bpy.context.view_layer.objects.active
    low.name = stem
    low.data.materials.clear()
    cleanup(low, diag)
    if a.mode == "organic":
        retopo_organic(low, a.tris)
    else:
        retopo_hard(low, a.tris)
    shade(low, a.mode)
    unwrap(low, a.mode)
    bake_maps(high, low, a.tex, a.samples, diag, out_dir, stem)

    bpy.data.objects.remove(high, do_unlink=True)
    place(low, a.height)
    activate(low)
    bpy.ops.export_scene.gltf(
        filepath=a.dst, export_format="GLB", use_selection=True,
        export_image_format="JPEG", export_image_quality=88,
        export_tangents=True, export_yup=True, export_apply=True,
    )
    print(f"PIPE done tris={tri_count(low)} file={os.path.getsize(a.dst)}")


main()
