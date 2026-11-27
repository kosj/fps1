"""Varco에서 받은 리깅 캐릭터와 동작별 GLB를 하나의 GLB로 합친다.

blender -b --python merge_character.py -- <out.glb> <tex_size> name=file.glb [name=file.glb ...]

Varco의 Animate 결과는 동작마다 메시와 텍스처가 통째로 들어 있어(파일당 12MB) 그대로는 못 쓴다.
첫 파일의 메시·뼈대를 기준으로 삼고 나머지 파일에서는 동작(액션)만 가져온다.
이름이 -loop로 끝나는 동작은 Godot가 반복 재생으로 가져온다. 텍스처는 tex_size로 줄인다.
"""
import os
import sys

import bpy


def import_glb(path):
    before = set(bpy.data.objects)
    actions_before = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=path)
    objects = [o for o in bpy.data.objects if o not in before]
    actions = [a for a in bpy.data.actions if a not in actions_before]
    return objects, actions


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    out, tex_size = args[0], int(args[1])
    clips = [a.split("=", 1) for a in args[2:]]
    bpy.ops.wm.read_factory_settings(use_empty=True)

    armature = None
    kept = []
    for index, (name, path) in enumerate(clips):
        objects, actions = import_glb(path)
        action = actions[0]
        action.name = name
        action.use_fake_user = True
        if index == 0:
            for obj in objects:
                # Varco가 넣는 뼈 모양용 구(Icosphere)는 버린다.
                if obj.type == "MESH" and not obj.find_armature():
                    bpy.data.objects.remove(obj, do_unlink=True)
                    continue
                kept.append(obj)
                if obj.type == "ARMATURE":
                    armature = obj
        else:
            for obj in objects:
                bpy.data.objects.remove(obj, do_unlink=True)
        print(f"CHAR clip {name} frames={action.frame_range[1] - action.frame_range[0]:.0f}")

    # 모든 동작을 NLA 트랙으로 올려야 내보내기에 포함된다.
    armature.animation_data.action = None
    for name, _path in clips:
        track = armature.animation_data.nla_tracks.new()
        track.name = name
        action = bpy.data.actions[name]
        strip = track.strips.new(name, int(action.frame_range[0]), action)
        strip.name = name

    for image in bpy.data.images:
        if image.size[0] > tex_size:
            image.scale(tex_size, tex_size)
    # 지워진 중복 메시가 남긴 고아 데이터 정리
    bpy.ops.outliner.orphans_purge(do_recursive=True)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in kept:
        obj.select_set(True)
        for child in obj.children_recursive:
            child.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", use_selection=True, export_yup=True,
        export_image_format="JPEG", export_image_quality=85,
        export_animations=True, export_animation_mode="NLA_TRACKS",
        export_optimize_animation_size=True, export_force_sampling=True,
        export_skins=True,
    )
    print(f"CHAR done bytes={os.path.getsize(out)}")


main()
