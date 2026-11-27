"""리깅된 병사(T포즈)에서 아래팔과 손만 잘라 1인칭용 팔 모델을 만든다.

blender -b --python extract_arms.py -- <rigged.glb> <out.glb> [tex_size]

결과: arm_l, arm_r 두 노드. 원점은 손목, 팔꿈치→손 방향이 Godot의 -Z(정면), 손등이 +Y(위).
크기는 키 1.8m 기준으로 맞춘다. 텍스처는 색만 남겨 용량을 줄인다.
"""
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HEIGHT = 1.8
SLEEVE_STRETCH = 2.4


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    src, out = args[0], args[1]
    tex = int(args[2]) if len(args) > 2 else 512
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    body = next(o for o in bpy.data.objects if o.type == "MESH" and o.find_armature())
    armature = body.find_armature()
    scale = HEIGHT / body.dimensions.z
    world = body.matrix_world.copy()
    results = []
    for side, prefix in (("l", "Left"), ("r", "Right")):
        keep = {body.vertex_groups[prefix + "ForeArm"].index, body.vertex_groups[prefix + "Hand"].index}
        bm = bmesh.new()
        bm.from_mesh(body.data)
        deform = bm.verts.layers.deform.verify()
        drop = []
        for v in bm.verts:
            weights = v[deform]
            best = max(weights.items(), key=lambda kv: kv[1])[0] if weights else -1
            if best not in keep:
                drop.append(v)
        bmesh.ops.delete(bm, geom=drop, context="VERTS")
        mesh = bpy.data.meshes.new("arm_" + side)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new("arm_" + side, mesh)
        bpy.context.scene.collection.objects.link(obj)
        for mat in body.data.materials:
            obj.data.materials.append(mat)
        mesh.transform(world)
        bones = armature.data.bones
        to_world = armature.matrix_world
        elbow = to_world @ bones[prefix + "ForeArm"].head_local
        wrist = to_world @ bones[prefix + "Hand"].head_local
        axis = (wrist - elbow).normalized()
        # 팔 방향을 +Y(내보내면 -Z)로, 월드 위쪽(T포즈의 손등)을 +Z로 돌린다.
        up = Vector((0, 0, 1))
        side_axis = axis.cross(up).normalized()
        up = side_axis.cross(axis)
        rot = Matrix((side_axis, axis, up)).to_4x4()
        mesh.transform(rot @ Matrix.Translation(-wrist))
        mesh.transform(Matrix.Scale(scale, 4))
        # 소매를 팔꿈치 쪽으로 늘여 잘린 끝이 화면 밖으로 나가게 한다(통 모양이라 늘여도 티가 안 난다).
        for v in mesh.vertices:
            if v.co.y < 0.0:
                v.co.y *= SLEEVE_STRETCH
        for poly in mesh.polygons:
            poly.use_smooth = True
        length = (wrist - elbow).length * scale
        print(f"ARM {side} verts={len(mesh.vertices)} tris={len(mesh.polygons)} forearm={length:.3f} "
              f"dims={[round(d, 3) for d in obj.dimensions]}")
        results.append(obj)
    for image in bpy.data.images:
        if image.size[0] > tex:
            image.scale(tex, tex)
    # 색 텍스처만 남긴다.
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        for name in ("Normal", "Metallic", "Roughness"):
            for link in list(bsdf.inputs[name].links):
                mat.node_tree.links.remove(link)
        bsdf.inputs["Roughness"].default_value = 0.8
        bsdf.inputs["Metallic"].default_value = 0.0
    bpy.ops.object.select_all(action="DESELECT")
    for obj in results:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True,
                              export_yup=True, export_image_format="JPEG",
                              export_image_quality=85, export_skins=False,
                              export_animations=False)
    print(f"ARM done bytes={os.path.getsize(out)}")


main()
