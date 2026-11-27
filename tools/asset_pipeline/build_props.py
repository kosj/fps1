"""맵 엄폐물(컨테이너, 나무 상자)을 크기별로 모델링해 GLB로 내보낸다.

blender -b --python build_props.py -- <out_dir>

충돌은 게임에서 상자 그대로 쓰므로, 모델은 주어진 크기 상자 안에 정확히 들어가야 한다.
크기를 늘려 쓰면 테두리 굵기가 찌그러지므로 맵에서 쓰는 크기마다 따로 만든다.
재질 슬롯 이름(panel, frame)은 게임에서 game/world/surfaces.gd 재질로 바꿔 끼운다.
크기는 Godot 기준 (x, y=높이, z)이다.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

# maps/depot/depot.gd에서 쓰는 크기. 맵에 새 크기를 넣으면 여기에도 추가한다.
SIZES = {
    "container": [(4, 2.5, 1), (2, 2.5, 3), (3, 2.5, 1.5), (2, 2.5, 4)],
    "crate": [(2, 1.2, 2), (3, 1.2, 1.2), (3, 1.2, 1.5)],
}


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.slots = ["panel", "frame"]

    def box(self, lo, hi, slot, matrix=None):
        """Godot 좌표(x, y, z)의 두 모서리로 상자를 더한다."""
        lo, hi = Vector(lo), Vector(hi)
        size = hi - lo
        center = (lo + hi) / 2
        result = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = result["verts"]
        # Godot (x, y, z) -> Blender (x, -z, y)
        bmesh.ops.scale(self.bm, vec=(size.x, size.z, size.y), verts=verts)
        if matrix is not None:
            bmesh.ops.transform(self.bm, matrix=matrix, verts=verts)
        bmesh.ops.translate(self.bm, vec=(center.x, -center.z, center.y), verts=verts)
        index = self.slots.index(slot)
        for face in {f for v in verts for f in v.link_faces}:
            face.material_index = index

    def finish(self, name):
        mesh = bpy.data.meshes.new(name)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(mesh)
        self.bm.free()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        for slot in self.slots:
            mat = bpy.data.materials.get(slot) or bpy.data.materials.new(slot)
            obj.data.materials.append(mat)
        return obj


def container(size):
    """골판 옆면은 텍스처로 표현하고, 형태는 모서리 기둥·위아래 보·문짝 잠금봉으로 만든다."""
    x, y, z = (s / 2 for s in size)
    h = size[1]
    b = Builder()
    post, rail, inset = 0.12, 0.12, 0.045
    b.box((-x + inset, 0.02, -z + inset), (x - inset, h - 0.03, z - inset), "panel")
    for sx in (-1, 1):
        for sz in (-1, 1):
            cx, cz = sx * (x - post / 2), sz * (z - post / 2)
            b.box((cx - post / 2, 0, cz - post / 2), (cx + post / 2, h, cz + post / 2), "frame")
    for level in (0.0, h - rail):
        for sz in (-1, 1):
            cz = sz * (z - 0.04)
            b.box((-x + post, level, cz - 0.04), (x - post, level + rail, cz + 0.04), "frame")
        for sx in (-1, 1):
            cx = sx * (x - 0.04)
            b.box((cx - 0.04, level, -z + post), (cx + 0.04, level + rail, z - post), "frame")
    # 문은 좁은 쪽 한 면에 단다.
    along_x = size[0] <= size[2]
    half_width = x if along_x else z
    face = z if along_x else x
    rods = [-half_width * 0.62, -half_width * 0.18, half_width * 0.18, half_width * 0.62]
    for offset in rods + [0.0]:
        thick = 0.012 if offset == 0.0 else 0.022
        lo = (offset - thick, rail, face - inset)
        hi = (offset + thick, h - rail, face - inset + 0.035)
        if not along_x:
            lo, hi = (lo[2], lo[1], lo[0]), (hi[2], hi[1], hi[0])
        b.box(lo, hi, "frame")
    for level in (h * 0.3, h * 0.55, h * 0.8):
        lo = (-half_width + post, level - 0.02, face - inset)
        hi = (half_width - post, level + 0.02, face - inset + 0.02)
        if not along_x:
            lo, hi = (lo[2], lo[1], lo[0]), (hi[2], hi[1], hi[0])
        b.box(lo, hi, "frame")
    return b


def crate(size):
    """판자 테두리와 대각 보강목이 있는 나무 상자."""
    x, y, z = (s / 2 for s in size)
    h = size[1]
    b = Builder()
    plank, proud = 0.11, 0.03
    b.box((-x + proud, 0.0, -z + proud), (x - proud, h - proud, z - proud), "panel")
    for sx in (-1, 1):
        for sz in (-1, 1):
            cx, cz = sx * (x - plank / 2), sz * (z - plank / 2)
            b.box((cx - plank / 2, 0, cz - plank / 2), (cx + plank / 2, h, cz + plank / 2), "frame")
    for level in (0.0, h - plank):
        for sz in (-1, 1):
            cz = sz * (z - proud / 2)
            b.box((-x + plank, level, cz - proud / 2), (x - plank, level + plank, cz + proud / 2),
                  "frame")
        for sx in (-1, 1):
            cx = sx * (x - proud / 2)
            b.box((cx - proud / 2, level, -z + plank), (cx + proud / 2, level + plank, z - plank),
                  "frame")
    # 윗면 테두리
    for sz in (-1, 1):
        cz = sz * (z - plank / 2)
        b.box((-x + plank, h - proud, cz - plank / 2), (x - plank, h, cz + plank / 2), "frame")
    for sx in (-1, 1):
        cx = sx * (x - plank / 2)
        b.box((cx - plank / 2, h - proud, -z + plank), (cx + plank / 2, h, z - plank), "frame")
    # 옆면 대각 보강목
    inner_h = h - plank * 2
    for sz in (-1, 1):
        span = size[0] - plank * 2
        angle = math.atan2(inner_h, span)
        length = math.hypot(span, inner_h)
        rot = Matrix.Rotation(-angle * sz, 4, "Y")
        cz = sz * (z - proud / 2)
        b.box((-length / 2, h / 2 - plank / 2, cz - proud / 2),
              (length / 2, h / 2 + plank / 2, cz + proud / 2), "frame", None)
        # 방금 만든 상자를 기울인다(상자 중심 기준).
        verts = list(b.bm.verts)[-8:]
        center = Vector((0, -cz, h / 2))
        bmesh.ops.rotate(b.bm, cent=center, matrix=rot, verts=verts)
    for sx in (-1, 1):
        span = size[2] - plank * 2
        angle = math.atan2(inner_h, span)
        length = math.hypot(span, inner_h)
        rot = Matrix.Rotation(angle * sx, 4, "X")
        cx = sx * (x - proud / 2)
        b.box((cx - proud / 2, h / 2 - plank / 2, -length / 2),
              (cx + proud / 2, h / 2 + plank / 2, length / 2), "frame", None)
        verts = list(b.bm.verts)[-8:]
        center = Vector((cx, 0, h / 2))
        bmesh.ops.rotate(b.bm, cent=center, matrix=rot, verts=verts)
    return b


def file_name(kind, size):
    return "%s_%d_%d_%d" % (kind, round(size[0] * 100), round(size[1] * 100), round(size[2] * 100))


def main():
    out_dir = sys.argv[sys.argv.index("--") + 1]
    os.makedirs(out_dir, exist_ok=True)
    makers = {"container": container, "crate": crate}
    for kind, sizes in SIZES.items():
        for size in sizes:
            bpy.ops.wm.read_factory_settings(use_empty=True)
            name = file_name(kind, size)
            obj = makers[kind](size).finish(name)
            # 원점은 상자 중심(게임의 상자 중심과 같게).
            obj.data.transform(Matrix.Translation((0, 0, -size[1] / 2)))
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.shade_flat()
            path = os.path.join(out_dir, name + ".glb")
            bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                                      export_yup=True)
            obj.data.calc_loop_triangles()
            dims = obj.dimensions
            print(f"PROP {name} tris={len(obj.data.loop_triangles)} bytes={os.path.getsize(path)} "
                  f"dims={dims.x:.2f},{dims.z:.2f},{dims.y:.2f}")


main()
