"""리깅된 병사(T포즈)에서 아래팔과 손만 잘라 1인칭용 팔 모델을 만든다.

blender -b --python extract_arms.py -- <rigged.glb> <out.glb> [tex_size]

결과: arm_l, arm_r 두 노드. 원점은 손목, 팔꿈치→손 방향이 Godot의 -Z(정면), 손등이 +Y(위).
크기는 키 1.8m 기준으로 맞춘다. 텍스처는 색만 남겨 용량을 줄인다.
손가락 뼈대가 있는 리깅(Varco humanoid-fingers)이면 자르기 전에 손가락을 굽힌다:
오른손은 손잡이를 쥔 모양, 왼손은 총열 덮개를 받친 모양.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HEIGHT = 1.8
CURL_SIGN = float(os.environ.get("CURL_SIGN", "1"))
SLEEVE_STRETCH = 2.4
FINGER_PREFIX = "HandLoRA_Bip01_%s_Finger"
## 손가락 마디별 굽힘 각도(도): [첫 마디, 둘째 마디, 끝 마디]. 0번은 엄지, 1번은 검지.
CURL = {
    "r": {0: (20, 25, 20), 1: (30, 40, 25), 2: (70, 85, 55), 3: (72, 88, 55), 4: (75, 90, 55)},
    "l": {0: (10, 15, 10), 1: (40, 50, 30), 2: (42, 52, 30), 3: (44, 54, 30), 4: (46, 56, 30)},
}


def curl_fingers(armature):
    """손가락 뼈의 로컬 Z축(손바닥과 나란하고 손가락에 수직)을 기준으로 굽힌다."""
    posed = False
    for side, letter in (("l", "L"), ("r", "R")):
        sign = 1.0 if side == "r" else -1.0
        for finger, angles in CURL[side].items():
            for joint, angle in enumerate(angles):
                name = FINGER_PREFIX % letter + str(finger) + ("" if joint == 0 else str(joint))
                bone = armature.pose.bones.get(name)
                if bone is None:
                    continue
                bone.rotation_mode = "XYZ"
                bone.rotation_euler = (0.0, 0.0, math.radians(angle) * sign * CURL_SIGN)
                posed = True
    return posed


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
    curl_fingers(armature)
    bpy.context.view_layer.update()
    posed_mesh = body.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    results = []
    for side, prefix in (("l", "Left"), ("r", "Right")):
        keep = {body.vertex_groups[prefix + "ForeArm"].index, body.vertex_groups[prefix + "Hand"].index}
        fingers = FINGER_PREFIX % prefix[0]
        keep |= {group.index for group in body.vertex_groups if group.name.startswith(fingers)}
        bm = bmesh.new()
        bm.from_mesh(posed_mesh)
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
        # 팔 방향을 +Y(내보내면 -Z)로, 손등(이 T포즈에서는 손바닥이 앞을 봐서 손등이 월드 +Y)을 +Z로.
        up = Vector((0, 1, 0))
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
