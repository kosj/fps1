"""병사 캐릭터를 관절별 부품으로 모델링해 GLB로 내보낸다.

blender -b --python build_soldier.py -- <out.glb>

스키닝 없이 부품(골반, 몸통, 머리, 위팔/아래팔, 허벅지/정강이)을 관절 위치를 원점으로 하는
노드 계층으로 내보내고, 게임이 노드 회전으로 걷기·앉기·조준 자세를 만든다.
좌표: 정면 +Y, 위 +Z (GLB에서 정면 -Z, 위 +Y). 키 1.8m, 발바닥이 z=0.
재질 슬롯: uniform(팀 색으로 물들임), gear(조끼·헬멧·장갑·군화), visor(고글).
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

COLORS = {
    "uniform": ((0.5, 0.5, 0.48), 0.0, 0.85),
    "gear": ((0.07, 0.075, 0.07), 0.0, 0.7),
    "visor": ((0.03, 0.05, 0.07), 0.6, 0.15),
}


def material(name):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    color, metallic, rough = COLORS[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    return mat


class Part:
    """관절(pivot)을 원점으로 하는 부품. 좌표는 모두 캐릭터 기준 절대 좌표로 준다."""

    def __init__(self, name, pivot, parent=None):
        self.name = name
        self.pivot = Vector(pivot)
        self.parent = parent
        self.bm = bmesh.new()
        self.slots = []

    def block(self, lo, hi, slot, taper=1.0, taper_axis="z-"):
        """상자. taper < 1이면 아래쪽(z-) 또는 앞쪽(y+) 끝을 좁힌다."""
        lo, hi = Vector(lo), Vector(hi)
        center = (lo + hi) / 2
        size = hi - lo
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        for v in verts:
            if taper != 1.0:
                if taper_axis == "z-" and v.co.z < 0:
                    v.co.x *= taper
                    v.co.y *= taper
                elif taper_axis == "z+" and v.co.z > 0:
                    v.co.x *= taper
                    v.co.y *= taper
                elif taper_axis == "y+" and v.co.y > 0:
                    v.co.x *= taper
                    v.co.z *= taper
            v.co = Vector((v.co.x * size.x, v.co.y * size.y, v.co.z * size.z)) + center - self.pivot
        if slot not in self.slots:
            self.slots.append(slot)
        index = self.slots.index(slot)
        for face in {f for v in verts for f in v.link_faces}:
            face.material_index = index

    def finish(self, built):
        mesh = bpy.data.meshes.new(self.name)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(mesh)
        self.bm.free()
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        for slot in self.slots:
            obj.data.materials.append(material(slot))
        bevel = obj.modifiers.new("bevel", "BEVEL")
        bevel.width = 0.012
        bevel.segments = 2
        bevel.limit_method = "ANGLE"
        bevel.angle_limit = math.radians(40)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
        if self.parent is not None:
            obj.parent = built[self.parent.name]
            obj.location = self.pivot - self.parent.pivot
        else:
            obj.location = self.pivot
        built[self.name] = obj
        return obj


def build():
    hips = Part("hips", (0, 0, 0.95))
    hips.block((-0.17, -0.11, 0.86), (0.17, 0.11, 1.02), "uniform")
    hips.block((-0.185, -0.12, 0.96), (0.185, 0.125, 1.02), "gear")
    hips.block((0.15, -0.06, 0.8), (0.215, 0.07, 0.97), "gear")
    hips.block((-0.2, -0.05, 0.84), (-0.16, 0.05, 0.96), "gear")

    torso = Part("torso", (0, 0, 1.02), hips)
    torso.block((-0.19, -0.11, 1.02), (0.19, 0.11, 1.5), "uniform", 0.85)
    torso.block((-0.2, -0.125, 1.1), (0.2, 0.135, 1.46), "gear", 0.92)
    for x in (-0.12, 0.0, 0.12):
        torso.block((x - 0.045, 0.13, 1.1), (x + 0.045, 0.19, 1.26), "gear")
    torso.block((-0.15, -0.23, 1.12), (0.15, -0.12, 1.45), "gear", 0.9, "z+")
    torso.block((-0.06, -0.06, 1.5), (0.06, 0.06, 1.56), "uniform")
    for sx in (-1, 1):
        torso.block((sx * 0.2 - 0.07, -0.09, 1.4), (sx * 0.2 + 0.07, 0.09, 1.51), "uniform")

    head = Part("head", (0, 0, 1.55), torso)
    head.block((-0.085, -0.095, 1.55), (0.085, 0.1, 1.74), "gear", 0.9)
    head.block((-0.105, -0.12, 1.66), (0.105, 0.115, 1.8), "gear", 0.82, "z+")
    head.block((-0.08, 0.085, 1.64), (0.08, 0.12, 1.7), "visor")
    for sx in (-1, 1):
        head.block((sx * 0.1 - 0.02, -0.04, 1.6), (sx * 0.1 + 0.02, 0.03, 1.69), "gear")

    parts = [hips, torso, head]
    for side, sx in (("l", -1), ("r", 1)):
        x = sx * 0.265
        upper = Part(f"arm_{side}_upper", (x, 0, 1.45), torso)
        upper.block((x - 0.055, -0.06, 1.16), (x + 0.055, 0.06, 1.47), "uniform", 0.85)
        lower = Part(f"arm_{side}_lower", (x, 0, 1.17), upper)
        lower.block((x - 0.048, -0.05, 0.92), (x + 0.048, 0.05, 1.18), "uniform", 0.8)
        lower.block((x - 0.055, -0.058, 1.12), (x + 0.055, 0.058, 1.19), "gear")
        lower.block((x - 0.035, -0.05, 0.82), (x + 0.035, 0.05, 0.93), "gear", 0.85)
        lower.block((x - sx * 0.035 - 0.012, 0.01, 0.85), (x - sx * 0.035 + 0.012, 0.06, 0.92),
                    "gear")
        lx = sx * 0.1
        thigh = Part(f"leg_{side}_upper", (lx, 0, 0.92), hips)
        thigh.block((lx - 0.085, -0.095, 0.5), (lx + 0.085, 0.095, 0.94), "uniform", 0.8)
        thigh.block((lx + sx * 0.085 - 0.03, -0.05, 0.62), (lx + sx * 0.085 + 0.03, 0.06, 0.8),
                    "gear")
        shin = Part(f"leg_{side}_lower", (lx, 0, 0.5), thigh)
        shin.block((lx - 0.065, -0.075, 0.14), (lx + 0.065, 0.07, 0.52), "uniform", 0.85)
        shin.block((lx - 0.07, 0.03, 0.42), (lx + 0.07, 0.1, 0.56), "gear")
        shin.block((lx - 0.065, -0.085, 0.0), (lx + 0.065, 0.08, 0.16), "gear")
        shin.block((lx - 0.06, 0.07, 0.0), (lx + 0.06, 0.19, 0.09), "gear", 0.8, "y+")
        parts += [upper, lower, thigh, shin]
    return parts


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    built = {}
    tris = 0
    for part in build():
        obj = part.finish(built)
        obj.data.calc_loop_triangles()
        tris += len(obj.data.loop_triangles)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True)
    print(f"SOLDIER tris={tris} bytes={os.path.getsize(out)} parts={len(built)}")


main()
