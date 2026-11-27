"""총기 4종을 코드로 모델링해 GLB로 내보낸다.

blender -b --python build_weapons.py -- <out_dir> [--preview <png_dir>]

AI 메시는 각진 면이 뭉개지므로 총기는 단면 돌출 + 베벨 + 면적 가중 노멀로 직접 만든다.
좌표: 총구가 +Y, 위가 +Z, 폭이 X (GLB로 내보내면 Godot에서 총구가 -Z, 위가 +Y).
원점은 방아쇠 위 총열 축 근처. 부품은 몸통(body), 탄창(mag), 움직이는 부품(action)으로 나눈다.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

MATERIALS = {
    "metal": ((0.085, 0.09, 0.1), 0.85, 0.38),
    "steel": ((0.2, 0.21, 0.22), 0.9, 0.3),
    "polymer": ((0.035, 0.037, 0.04), 0.0, 0.62),
    "rubber": ((0.02, 0.02, 0.02), 0.0, 0.9),
    "olive": ((0.16, 0.19, 0.11), 0.0, 0.7),
    "tan": ((0.42, 0.34, 0.22), 0.0, 0.7),
    "glass": ((0.02, 0.05, 0.08), 0.6, 0.08),
    "brass": ((0.75, 0.55, 0.2), 1.0, 0.3),
}


def material(name):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    color, metallic, rough = MATERIALS[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    return mat


class Gun:
    """부품을 그룹(body/mag/action)별로 모았다가 마지막에 합친다."""

    def __init__(self, name):
        self.name = name
        self.parts = {"body": [], "mag": [], "action": []}
        self.muzzle = Vector((0, 0.7, 0))

    def _finish(self, bm, mat, group, bevel, smooth=False):
        mesh = bpy.data.meshes.new("part")
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new("part", mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(material(mat))
        if bevel > 0:
            mod = obj.modifiers.new("bevel", "BEVEL")
            mod.width = bevel
            mod.segments = 2
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(40)
            mod.harden_normals = False
        obj["smooth"] = smooth
        self.parts[group].append(obj)
        return obj

    def profile(self, pts, width, mat, group="body", x=0.0, bevel=0.0015):
        """옆모습 다각형 (y, z)을 폭 방향으로 돌출한다."""
        bm = bmesh.new()
        half = width / 2
        left = [bm.verts.new((x - half, y, z)) for y, z in pts]
        right = [bm.verts.new((x + half, y, z)) for y, z in pts]
        bm.faces.new(left)
        bm.faces.new(list(reversed(right)))
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((left[j], left[i], right[i], right[j]))
        return self._finish(bm, mat, group, bevel)

    def box(self, y0, y1, z0, z1, width, mat, group="body", x=0.0, bevel=0.0012):
        return self.profile([(y0, z0), (y1, z0), (y1, z1), (y0, z1)], width, mat, group, x, bevel)

    def tube(self, y0, y1, radius, mat, group="body", z=0.0, x=0.0, seg=16, r1=None, bevel=0.0):
        """Y축 방향 원통. r1을 주면 끝이 다른 굵기(원뿔대)."""
        bm = bmesh.new()
        r1 = radius if r1 is None else r1
        a, b = [], []
        for i in range(seg):
            t = 2 * math.pi * i / seg
            c, s = math.cos(t), math.sin(t)
            a.append(bm.verts.new((x + c * radius, y0, z + s * radius)))
            b.append(bm.verts.new((x + c * r1, y1, z + s * r1)))
        bm.faces.new(list(reversed(a)))
        bm.faces.new(b)
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i]))
        return self._finish(bm, mat, group, bevel, smooth=True)

    def pin(self, y, z, radius, width, mat="steel", group="body", seg=10):
        """X축 방향 핀/버튼(좌우로 관통)."""
        bm = bmesh.new()
        a, b = [], []
        for i in range(seg):
            t = 2 * math.pi * i / seg
            c, s = math.cos(t), math.sin(t)
            a.append(bm.verts.new((-width / 2, y + c * radius, z + s * radius)))
            b.append(bm.verts.new((width / 2, y + c * radius, z + s * radius)))
        bm.faces.new(a)
        bm.faces.new(list(reversed(b)))
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[j], a[i], b[i], b[j]))
        return self._finish(bm, mat, group, 0.0, smooth=True)

    def rail(self, y0, y1, z, width=0.021, mat="metal"):
        """피카티니 레일: 바닥판 위에 홈이 있는 이빨을 늘어놓는다."""
        self.box(y0, y1, z, z + 0.004, width * 0.75, mat, bevel=0.0)
        y = y0 + 0.003
        while y + 0.0055 < y1:
            self.box(y, y + 0.0055, z + 0.004, z + 0.0085, width, mat, bevel=0.0006)
            y += 0.0105

    def build(self):
        result = {}
        for group, objs in self.parts.items():
            if not objs:
                continue
            for obj in objs:
                bpy.ops.object.select_all(action="DESELECT")
                obj.select_set(True)
                bpy.context.view_layer.objects.active = obj
                for mod in list(obj.modifiers):
                    bpy.ops.object.modifier_apply(modifier=mod.name)
                angle = math.radians(60 if obj["smooth"] else 32)
                bpy.ops.object.shade_smooth_by_angle(angle=angle)
            bpy.ops.object.select_all(action="DESELECT")
            for obj in objs:
                obj.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            if len(objs) > 1:
                bpy.ops.object.join()
            joined = bpy.context.view_layer.objects.active
            joined.name = group
            joined.data.name = f"{self.name}_{group}"
            mod = joined.modifiers.new("weighted", "WEIGHTED_NORMAL")
            mod.keep_sharp = True
            bpy.ops.object.modifier_apply(modifier=mod.name)
            result[group] = joined
        root = bpy.data.objects.new(self.name, None)
        bpy.context.scene.collection.objects.link(root)
        for obj in result.values():
            obj.parent = root
        muzzle = bpy.data.objects.new("muzzle", None)
        muzzle.location = self.muzzle
        muzzle.parent = root
        bpy.context.scene.collection.objects.link(muzzle)
        return root


def curved_mag(g, y_top, z_top, length, depth, width, curve, mat="metal", steps=7):
    """앞으로 휘는 탄창. 위쪽 중심(y_top, z_top)에서 아래로 내려가며 앞으로 휜다."""
    front, back = [], []
    for i in range(steps + 1):
        t = i / steps
        z = z_top - length * t
        shift = curve * t * t
        front.append((y_top + depth / 2 + shift, z + (depth * 0.25 * t)))
        back.append((y_top - depth / 2 + shift, z))
    g.profile(back + list(reversed(front)), width, mat, "mag", bevel=0.002)
    # 탄창 옆면 보강 리브
    for k in (0.3, 0.55, 0.8):
        z = z_top - length * k
        s = curve * k * k
        g.box(y_top - depth * 0.3 + s, y_top + depth * 0.3 + s, z - 0.004, z + 0.004,
              width + 0.002, mat, "mag", bevel=0.0008)


def trigger_group(g, y, z, guard_len=0.075, mat="polymer"):
    g.box(y - 0.004, y + guard_len, z - 0.045, z - 0.04, 0.012, mat, bevel=0.001)
    g.profile([(y + guard_len - 0.006, z - 0.045), (y + guard_len, z - 0.045),
               (y + guard_len + 0.012, z), (y + guard_len + 0.006, z)], 0.012, mat, bevel=0.001)
    g.profile([(y + 0.024, z), (y + 0.031, z), (y + 0.036, z - 0.022), (y + 0.03, z - 0.028),
               (y + 0.028, z - 0.012)], 0.006, "steel", bevel=0.0008)


def grip(g, y, z, mat="polymer", length=0.115, rake=0.035):
    g.profile([(y - 0.022, z), (y + 0.024, z), (y + 0.018 - rake * 0.3, z - length * 0.5),
               (y + 0.008 - rake, z - length), (y - 0.04 - rake, z - length * 0.95),
               (y - 0.036 - rake * 0.5, z - length * 0.45)], 0.03, mat, bevel=0.004)


def iron_sights(g, y_rear, y_front, z):
    g.box(y_rear, y_rear + 0.02, z, z + 0.014, 0.022, "metal", bevel=0.001)
    g.box(y_rear + 0.004, y_rear + 0.016, z + 0.014, z + 0.03, 0.004, "metal", x=0.008, bevel=0.0006)
    g.box(y_rear + 0.004, y_rear + 0.016, z + 0.014, z + 0.03, 0.004, "metal", x=-0.008, bevel=0.0006)
    g.box(y_front, y_front + 0.016, z, z + 0.012, 0.02, "metal", bevel=0.001)
    g.box(y_front + 0.005, y_front + 0.011, z + 0.012, z + 0.03, 0.003, "metal", bevel=0.0004)
    for side in (-1, 1):
        g.profile([(y_front, z + 0.012), (y_front + 0.016, z + 0.012), (y_front + 0.012, z + 0.034),
                   (y_front + 0.004, z + 0.034)], 0.0025, "metal", x=side * 0.009, bevel=0.0004)


def build_rifle():
    g = Gun("rifle_vk7")
    # 상부 리시버와 레일
    g.profile([(-0.1, 0.0), (0.2, 0.0), (0.2, 0.044), (-0.085, 0.044), (-0.1, 0.03)], 0.046, "metal")
    g.rail(-0.08, 0.2, 0.044)
    # 하부 리시버 (탄창 삽입구 포함)
    g.profile([(-0.1, 0.002), (0.19, 0.002), (0.19, -0.03), (0.165, -0.058), (0.075, -0.058),
               (0.07, -0.04), (-0.1, -0.04)], 0.042, "metal")
    g.box(0.078, 0.162, -0.066, -0.05, 0.046, "metal", bevel=0.002)
    # 배출구, 노리쇠, 탄피 막이
    g.box(0.06, 0.135, 0.008, 0.03, 0.004, "steel", "action", x=0.0225, bevel=0.0006)
    g.profile([(0.035, 0.004), (0.055, 0.004), (0.06, 0.02), (0.05, 0.034), (0.035, 0.034)],
              0.008, "metal", x=0.024, bevel=0.001)
    # 장전 손잡이, 조정간, 핀
    g.box(-0.108, -0.088, 0.024, 0.036, 0.05, "metal", "action", bevel=0.002)
    g.pin(-0.03, -0.012, 0.007, 0.05, "steel")
    g.box(-0.045, -0.025, -0.014, -0.01, 0.05, "steel", bevel=0.0006)
    for y in (0.06, 0.175):
        g.pin(y, -0.02, 0.004, 0.044, "steel")
    g.box(0.1, 0.125, -0.03, -0.015, 0.047, "steel", bevel=0.001)
    # 총열 덮개
    g.profile([(0.2, -0.026), (0.455, -0.022), (0.455, 0.03), (0.44, 0.044), (0.2, 0.044)],
              0.044, "polymer", bevel=0.004)
    g.rail(0.205, 0.44, 0.044)
    for i in range(6):
        y = 0.225 + i * 0.036
        for side in (-1, 1):
            g.profile([(y, -0.004), (y + 0.022, -0.004), (y + 0.026, 0.006), (y + 0.022, 0.016),
                       (y, 0.016), (y - 0.004, 0.006)], 0.003, "metal", x=side * 0.0215,
                      bevel=0.0008)
    g.box(0.22, 0.43, -0.03, -0.022, 0.03, "polymer", bevel=0.002)
    # 총열, 가스 블록, 소염기
    g.tube(0.44, 0.665, 0.009, "steel", z=0.012)
    g.box(0.5, 0.53, -0.004, 0.034, 0.03, "metal", bevel=0.003)
    g.tube(0.2, 0.5, 0.005, "steel", z=0.033, seg=8)
    g.tube(0.655, 0.72, 0.0125, "metal", z=0.012, bevel=0.001)
    for y in (0.672, 0.688, 0.704):
        g.box(y, y + 0.007, 0.004, 0.02, 0.028, "rubber", bevel=0.0)
    # 가늠자, 가늠쇠
    iron_sights(g, -0.07, 0.415, 0.0525)
    # 손잡이, 방아쇠, 탄창
    grip(g, -0.055, -0.04)
    trigger_group(g, -0.03, -0.04)
    curved_mag(g, 0.12, -0.05, 0.19, 0.062, 0.026, 0.045)
    # 개머리판
    g.tube(-0.3, -0.1, 0.014, "metal", z=0.016)
    g.profile([(-0.37, 0.04), (-0.2, 0.04), (-0.185, 0.02), (-0.19, -0.005), (-0.255, -0.02),
               (-0.3, -0.085), (-0.37, -0.09)], 0.04, "polymer", bevel=0.004)
    g.box(-0.382, -0.368, -0.094, 0.044, 0.044, "rubber", bevel=0.004)
    g.muzzle = Vector((0, 0.725, 0.012))
    return g.build()


def build_smg():
    g = Gun("smg_kestrel")
    # 각진 상자형 리시버
    g.profile([(-0.13, -0.005), (0.2, -0.005), (0.2, 0.03), (0.185, 0.046), (-0.115, 0.046),
               (-0.13, 0.034)], 0.044, "metal", bevel=0.003)
    g.rail(-0.09, 0.17, 0.046)
    g.profile([(-0.12, -0.003), (0.13, -0.003), (0.13, -0.05), (0.085, -0.055), (0.07, -0.038),
               (-0.12, -0.038)], 0.04, "polymer", bevel=0.003)
    # 배출구, 장전 손잡이(왼쪽)
    g.box(0.03, 0.1, 0.012, 0.032, 0.004, "steel", "action", x=0.0215, bevel=0.0006)
    g.tube(0.12, 0.145, 0.006, "steel", "action", z=0.03, x=-0.03, seg=10)
    g.box(0.126, 0.139, 0.026, 0.034, 0.016, "steel", "action", x=-0.024, bevel=0.0006)
    g.box(0.02, 0.17, 0.027, 0.033, 0.003, "rubber", x=-0.0215, bevel=0.0)
    # 짧은 총열 덮개와 총열
    g.profile([(0.2, -0.012), (0.31, -0.012), (0.325, 0.0), (0.325, 0.034), (0.2, 0.04)],
              0.04, "polymer", bevel=0.004)
    for i in range(3):
        y = 0.215 + i * 0.033
        for side in (-1, 1):
            g.box(y, y + 0.02, 0.006, 0.02, 0.003, "metal", x=side * 0.0195, bevel=0.0008)
    g.tube(0.32, 0.385, 0.0085, "steel", z=0.014)
    g.tube(0.375, 0.41, 0.012, "metal", z=0.014, bevel=0.001)
    g.box(0.24, 0.3, -0.03, -0.012, 0.024, "polymer", bevel=0.004)
    iron_sights(g, -0.08, 0.15, 0.0545)
    # 손잡이, 방아쇠, 곧은 탄창(방아쇠 앞)
    grip(g, -0.07, -0.038, length=0.105, rake=0.025)
    trigger_group(g, -0.045, -0.038, guard_len=0.07)
    g.box(0.09, 0.126, -0.075, -0.045, 0.034, "polymer", bevel=0.002)
    g.profile([(0.093, -0.06), (0.123, -0.06), (0.129, -0.2), (0.099, -0.202)], 0.024,
              "metal", "mag", bevel=0.002)
    g.box(0.095, 0.132, -0.212, -0.198, 0.028, "polymer", "mag", bevel=0.002)
    # 접이식 골격 개머리판
    for side in (-1, 1):
        g.box(-0.34, -0.12, 0.022, 0.032, 0.006, "metal", x=side * 0.017, bevel=0.001)
    g.profile([(-0.36, 0.04), (-0.335, 0.04), (-0.335, -0.07), (-0.36, -0.075)], 0.042,
              "polymer", bevel=0.004)
    g.box(-0.34, -0.3, -0.03, -0.022, 0.03, "metal", bevel=0.001)
    g.pin(-0.125, 0.027, 0.008, 0.046, "steel")
    g.muzzle = Vector((0, 0.415, 0.014))
    return g.build()


def build_shotgun():
    g = Gun("shotgun_m90")
    # 리시버
    g.profile([(-0.12, -0.03), (0.14, -0.03), (0.15, -0.015), (0.15, 0.032), (0.13, 0.04),
               (-0.1, 0.04), (-0.12, 0.02)], 0.042, "metal", bevel=0.004)
    g.box(0.0, 0.085, 0.005, 0.026, 0.004, "steel", "action", x=0.0205, bevel=0.0006)
    g.box(0.01, 0.12, -0.034, -0.026, 0.03, "steel", bevel=0.001)
    g.box(-0.09, 0.7, 0.031, 0.036, 0.008, "metal", bevel=0.0008)
    g.box(-0.09, 0.12, 0.036, 0.044, 0.012, "metal", bevel=0.001)
    # 굵은 총열과 관형 탄창
    g.tube(0.15, 0.71, 0.0125, "steel", z=0.02)
    g.tube(0.15, 0.62, 0.0125, "metal", z=-0.012)
    g.tube(0.615, 0.635, 0.0145, "steel", z=-0.012, bevel=0.001)
    g.box(0.585, 0.605, -0.02, 0.03, 0.02, "metal", bevel=0.002)
    g.tube(0.7, 0.72, 0.014, "metal", z=0.02, bevel=0.001)
    g.box(0.688, 0.698, 0.036, 0.05, 0.005, "brass", bevel=0.0008)
    # 펌프 손잡이 (움직이는 부품)
    g.tube(0.28, 0.47, 0.024, "polymer", "action", z=-0.012, seg=12)
    for i in range(8):
        y = 0.292 + i * 0.022
        g.tube(y, y + 0.009, 0.0262, "polymer", "action", z=-0.012, seg=12)
    for side in (-1, 1):
        g.box(0.15, 0.3, -0.016, -0.008, 0.003, "steel", "action", x=side * 0.014, bevel=0.0)
    # 손잡이, 방아쇠, 고정 개머리판
    grip(g, -0.075, -0.03, length=0.11, rake=0.04)
    trigger_group(g, -0.05, -0.03, guard_len=0.07, mat="metal")
    g.profile([(-0.12, 0.03), (-0.1, 0.035), (-0.2, 0.03), (-0.4, 0.022), (-0.4, -0.1),
               (-0.37, -0.105), (-0.2, -0.04), (-0.12, -0.028)][::1], 0.038, "polymer", bevel=0.005)
    g.box(-0.414, -0.398, -0.108, 0.026, 0.042, "rubber", bevel=0.004)
    g.muzzle = Vector((0, 0.725, 0.02))
    return g.build()


def build_sniper():
    g = Gun("sniper_lr12")
    # 섀시와 리시버
    g.tube(-0.11, 0.2, 0.021, "metal", z=0.012, seg=14)
    g.profile([(-0.13, 0.0), (0.2, 0.0), (0.46, -0.008), (0.46, -0.04), (0.2, -0.05),
               (0.14, -0.05), (0.13, -0.04), (-0.13, -0.04)], 0.046, "olive", bevel=0.004)
    g.profile([(0.2, -0.004), (0.46, -0.008), (0.46, 0.014), (0.2, 0.016)], 0.05, "olive",
              bevel=0.003)
    # 노리쇠와 손잡이 (움직이는 부품)
    g.tube(-0.135, -0.105, 0.016, "steel", "action", z=0.012, seg=12)
    g.box(0.02, 0.1, 0.004, 0.022, 0.004, "steel", "action", x=0.021, bevel=0.0006)
    bolt = g.tube(-0.01, 0.045, 0.005, "steel", "action", seg=8)
    bolt.rotation_euler = (0, 0, -math.pi / 2)
    bolt.location = (0.022, -0.06, -0.01)
    knob = g.tube(-0.012, 0.012, 0.011, "polymer", "action", seg=10, bevel=0.002)
    knob.rotation_euler = (0, 0, -math.pi / 2)
    knob.location = (0.075, -0.06, -0.016)
    # 길고 무거운 총열, 홈, 소염기
    g.tube(0.2, 0.3, 0.015, "steel", z=0.012, r1=0.0125)
    g.tube(0.3, 0.83, 0.0125, "steel", z=0.012, r1=0.0105)
    for k in range(6):
        t = math.pi * 2 * k / 6
        flute = g.box(0.33, 0.72, -0.0015, 0.0015, 0.004, "metal", bevel=0.0)
        flute.rotation_euler = (0, t, 0)
        flute.location = (math.sin(t) * 0.0118, 0, 0.012 + math.cos(t) * 0.0118)
    g.box(0.83, 0.9, -0.002, 0.026, 0.03, "metal", bevel=0.003)
    for y in (0.842, 0.862, 0.882):
        g.box(y, y + 0.009, 0.004, 0.02, 0.032, "rubber", bevel=0.0)
    # 조준경: 레일, 링, 경통, 대물/접안 렌즈, 조절 손잡이
    g.rail(-0.08, 0.2, 0.033)
    for y in (0.0, 0.115):
        g.box(y, y + 0.022, 0.0415, 0.062, 0.03, "metal", bevel=0.002)
        g.tube(y, y + 0.022, 0.0205, "metal", z=0.075, seg=14, bevel=0.001)
    g.tube(-0.06, 0.2, 0.0165, "metal", z=0.075, seg=14)
    g.tube(0.2, 0.25, 0.0165, "metal", z=0.075, r1=0.028, seg=16)
    g.tube(0.25, 0.33, 0.028, "metal", z=0.075, seg=16, bevel=0.001)
    g.tube(0.322, 0.326, 0.0255, "glass", z=0.075, seg=16)
    g.tube(-0.1, -0.06, 0.021, "metal", z=0.075, r1=0.0165, seg=16)
    g.tube(-0.135, -0.1, 0.021, "rubber", z=0.075, seg=16, bevel=0.001)
    g.tube(-0.128, -0.124, 0.0185, "glass", z=0.075, seg=16)
    top = g.tube(0.0, 0.022, 0.011, "metal", seg=12, bevel=0.001)
    top.rotation_euler = (math.pi / 2, 0, 0)
    top.location = (0, 0.07, 0.09)
    side = g.tube(0.0, 0.022, 0.011, "metal", seg=12, bevel=0.001)
    side.rotation_euler = (0, 0, -math.pi / 2)
    side.location = (0.015, 0.07, 0.075)
    # 손잡이, 방아쇠, 상자 탄창
    grip(g, -0.085, -0.04, mat="olive", length=0.115, rake=0.03)
    trigger_group(g, -0.06, -0.04, guard_len=0.07, mat="metal")
    g.profile([(0.035, -0.045), (0.125, -0.045), (0.128, -0.115), (0.04, -0.12)], 0.03,
              "metal", "mag", bevel=0.003)
    # 조절식 개머리판과 볼 받침
    g.box(-0.22, -0.125, -0.03, 0.0, 0.03, "metal", bevel=0.002)
    g.profile([(-0.44, 0.03), (-0.22, 0.03), (-0.205, 0.0), (-0.22, -0.035), (-0.33, -0.05),
               (-0.36, -0.11), (-0.44, -0.115)], 0.042, "olive", bevel=0.005)
    g.box(-0.37, -0.24, 0.03, 0.052, 0.036, "polymer", bevel=0.005)
    for y in (-0.34, -0.27):
        g.tube(y, y + 0.006, 0.004, "steel", z=0.02, seg=8)
    g.box(-0.456, -0.438, -0.118, 0.034, 0.046, "rubber", bevel=0.004)
    # 접은 양각대
    g.box(0.4, 0.44, -0.056, -0.04, 0.036, "metal", bevel=0.002)
    for sx in (-1, 1):
        g.tube(0.2, 0.42, 0.005, "metal", z=-0.058, x=sx * 0.013, seg=8)
        g.tube(0.185, 0.205, 0.0065, "rubber", z=-0.058, x=sx * 0.013, seg=8)
    g.muzzle = Vector((0, 0.905, 0.012))
    return g.build()


BUILDERS = {
    "rifle_vk7": build_rifle,
    "smg_kestrel": build_smg,
    "shotgun_m90": build_shotgun,
    "sniper_lr12": build_sniper,
}


def preview(root, path):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 640
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.57, 0.6, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.2
    scene.world = world
    pts = [o.matrix_world @ Vector(c) for o in root.children if o.type == "MESH" for c in o.bound_box]
    lo = Vector((min(p[i] for p in pts) for i in range(3)))
    hi = Vector((max(p[i] for p in pts) for i in range(3)))
    center = (lo + hi) / 2
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 85
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = center + Vector((1.0, 0.35, 0.3)).normalized() * (hi - lo).length * 2.1
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    for rot, energy in (((50, 0, 100), 4.0), ((60, 0, -60), 1.5)):
        light = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        light.data.energy = energy
        light.rotation_euler = tuple(math.radians(r) for r in rot)
        scene.collection.objects.link(light)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    out_dir = args[0]
    png_dir = args[args.index("--preview") + 1] if "--preview" in args else ""
    os.makedirs(out_dir, exist_ok=True)
    for name, builder in BUILDERS.items():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        root = builder()
        tris = 0
        for obj in root.children:
            if obj.type == "MESH":
                obj.data.calc_loop_triangles()
                tris += len(obj.data.loop_triangles)
        bpy.ops.object.select_all(action="SELECT")
        path = os.path.join(out_dir, name + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                                  export_yup=True, export_apply=True)
        print(f"WEAPON {name} tris={tris} bytes={os.path.getsize(path)}")
        if png_dir:
            os.makedirs(png_dir, exist_ok=True)
            preview(root, os.path.join(png_dir, name + ".png"))


main()
