#!/usr/bin/env python3
"""Render-and-compare loop for the tank art (docs/design/tank-art-pipeline.md).

The concept art is a render too, so we compare like with like: recover the reference's camera
from a handful of landmarks, render the game model from that camera in Godot, and score how
close it is. Not pixel-exact: proportions (landmarks, silhouette), palette (per-material colour)
and detail (edges).

    tools/.venv/Scripts/python tools/compare.py run --ref art/anchors/tank.jpg --label wheel_v1
    tools/.venv/Scripts/python tools/compare.py grid art/anchors/tank.jpg     # helper for marking landmarks
    tools/.venv/Scripts/python tools/compare.py selftest                       # pipeline check on a known render

Reference landmarks live next to the image: art/anchors/tank_landmarks.json
    {"points": {"bolt_tip": [x, y], "helmet_top": [x, y], ...}}   (pixels; any subset of the
    model's LM_* markers, at least 6, not all in one plane)
Each run writes art/compare/runs/<time>_<label>/ (camera.json, renders, report.png, scores.json)
and appends a row to art/compare/history.csv.
"""

import argparse
import csv
import json
import math
import os
import subprocess
import sys
import time

import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUNS = os.path.join(ROOT, "art", "compare", "runs")
HISTORY = os.path.join(ROOT, "art", "compare", "history.csv")


# --- Godot ------------------------------------------------------------------------------------

def godot_path():
    env = os.environ.get("BT_GODOT")
    if env and os.path.exists(env):
        return env
    p = os.path.normpath(os.path.join(ROOT, "..", "Hero-Reader", "third_party", "godot",
                                      "Godot_v4.7-stable_win64_console.exe"))
    if os.path.exists(p):
        return p
    sys.exit("Godot 4.7 not found: set BT_GODOT")


def godot(args, size=(640, 480), headless=False):
    cmd = [godot_path(), "--path", ROOT]
    cmd += ["--headless"] if headless else ["--resolution", "%dx%d" % size]
    cmd += args
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    if r.returncode != 0 or "SCRIPT ERROR" in r.stdout + r.stderr:
        sys.exit("godot failed:\n" + (r.stdout + r.stderr)[-3000:])
    return r.stdout


def godot_import():
    godot(["--import"], headless=True)


def model_landmarks(out_dir, pose=None):
    path = os.path.join(out_dir, "model_landmarks.json")
    godot(["scenes/tank_compare.tscn", "--", "--landmarks", path] + (["--pose", pose] if pose else []))
    return load_json(path)


def render(camera_path, out_dir, pose=None):
    cam = load_json(camera_path)
    args = ["scenes/tank_compare.tscn", "--", "--camera", camera_path, "--out", out_dir]
    if pose:
        args += ["--pose", pose]
    godot(args, size=(int(cam["width"]), int(cam["height"])))


# --- Camera fit -------------------------------------------------------------------------------

def fit_camera(model_lm, ref_points, width, height):
    """solvePnP over a sweep of vertical fields of view; returns the Godot camera and errors."""
    names = [n for n in ref_points if n in model_lm]
    if len(names) < 6:
        sys.exit("need at least 6 landmarks shared with the model, have %d: %s" % (len(names), names))
    obj = np.array([model_lm[n] for n in names], dtype=np.float64)
    img = np.array([ref_points[n] for n in names], dtype=np.float64)

    def solve(fov):
        f = (height / 2.0) / math.tan(math.radians(fov) / 2.0)
        k = np.array([[f, 0, width / 2.0], [0, f, height / 2.0], [0, 0, 1]], dtype=np.float64)
        ok, rvec, tvec = cv2.solvePnP(obj, img, k, None, flags=cv2.SOLVEPNP_SQPNP)
        if not ok:
            return None
        ok, rvec, tvec = cv2.solvePnP(obj, img, k, None, rvec, tvec, True, cv2.SOLVEPNP_ITERATIVE)
        proj, _ = cv2.projectPoints(obj, rvec, tvec, k, None)
        err = np.linalg.norm(proj.reshape(-1, 2) - img, axis=1)
        return float(np.sqrt(np.mean(err ** 2))), rvec, tvec

    best = None
    for fov10 in list(range(100, 701, 10)):
        r = solve(fov10 / 10.0)
        if r and (best is None or r[0] < best[0]):
            best = (r[0], fov10 / 10.0, r[1], r[2])
    for fov10 in range(int(best[1] * 10) - 10, int(best[1] * 10) + 11):
        r = solve(fov10 / 10.0)
        if r and r[0] < best[0]:
            best = (r[0], fov10 / 10.0, r[1], r[2])
    rms, fov, rvec, tvec = best
    rot, _ = cv2.Rodrigues(rvec)
    centre = (-rot.T @ tvec).reshape(3)
    # OpenCV camera: x right, y down, z forward. Godot camera: x right, y up, -z forward.
    basis = [rot[0].tolist(), (-rot[1]).tolist(), (-rot[2]).tolist()]
    return {"width": width, "height": height, "fov_y": fov, "origin": centre.tolist(),
            "basis": basis, "fit_rms_px": rms, "landmarks_used": names}


# --- Scoring ----------------------------------------------------------------------------------

def lab(img_bgr):
    return cv2.cvtColor(img_bgr, cv2.COLOR_BGR2LAB).astype(np.float32) * np.array([100 / 255, 1, 1], np.float32) \
        - np.array([0, 128, 128], np.float32)


def border_color(img_bgr):
    b = np.concatenate([img_bgr[:8].reshape(-1, 3), img_bgr[-8:].reshape(-1, 3),
                        img_bgr[:, :8].reshape(-1, 3), img_bgr[:, -8:].reshape(-1, 3)])
    return np.median(b, axis=0)


def ref_mask(img_bgr, threshold):
    bg = border_color(img_bgr).astype(np.uint8).reshape(1, 1, 3)
    diff = lab(img_bgr) - lab(bg)
    d = np.linalg.norm(diff, axis=2)
    # A soft drop shadow is the background a little darker with the same tint: not tank.
    shadow = (diff[:, :, 0] > -22.0) & (np.linalg.norm(diff[:, :, 1:], axis=2) < 6.0)
    m = ((d > threshold) & ~shadow).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(m)
    keep = np.zeros_like(m)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] > 0.005 * m.size:
            keep[labels == i] = 1
    return keep.astype(bool)


def edges(img_bgr, mask):
    g = cv2.GaussianBlur(cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY), (3, 3), 0)
    e = cv2.Canny(g, 50, 140) > 0
    return e & mask


def chamfer(a, b):
    """Mean distance (px) from edge pixels of a to the nearest edge pixel of b."""
    if not a.any() or not b.any():
        return float("nan")
    dt = cv2.distanceTransform((~b).astype(np.uint8), cv2.DIST_L2, 3)
    return float(dt[a].mean())


def score(ref_path, ref_points, run_dir, label, mask_threshold=20.0):
    ref = cv2.imread(ref_path)
    beauty = cv2.imread(os.path.join(run_dir, "beauty.png"))
    ids = cv2.imread(os.path.join(run_dir, "ids.png"), cv2.IMREAD_UNCHANGED)
    legend = load_json(os.path.join(run_dir, "ids.json"))
    proj = load_json(os.path.join(run_dir, "projected.json"))
    h, w = ref.shape[:2]
    diag = math.hypot(w, h)

    m_ref = ref_mask(ref, mask_threshold)
    m_ren = ids[:, :, 3] > 127
    iou = float((m_ref & m_ren).sum() / max(1, (m_ref | m_ren).sum()))

    lm_err = {}
    for n, p in ref_points.items():
        if n in proj:
            lm_err[n] = math.hypot(proj[n][0] - p[0], proj[n][1] - p[1]) / diag * 100.0
    lm_mean = float(np.mean(list(lm_err.values()))) if lm_err else float("nan")

    lab_ref, lab_ren = lab(ref), lab(beauty)
    colour = {}
    total_area = 0
    weighted = 0.0
    for key, rgb in legend.items():
        target = np.array(rgb[::-1], np.int16)   # BGR
        region = (np.abs(ids[:, :, :3].astype(np.int16) - target).max(axis=2) <= 6) & m_ren
        region = cv2.erode(region.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
        region &= m_ref   # only where the reference has tank too
        area = int(region.sum())
        if area < 30:
            continue
        de = float(np.linalg.norm(lab_ref[region].mean(axis=0) - lab_ren[region].mean(axis=0)))
        colour[key] = {"delta_e": de, "area": area,
                       "ref_rgb": [int(v) for v in ref[region].mean(axis=0)[::-1]],
                       "render_rgb": [int(v) for v in beauty[region].mean(axis=0)[::-1]]}
        total_area += area
        weighted += de * area
    colour_mean = weighted / total_area if total_area else float("nan")

    zone = cv2.dilate((m_ref | m_ren).astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool)
    e_ref, e_ren = edges(ref, zone), edges(beauty, zone)
    edge = (chamfer(e_ren, e_ref) + chamfer(e_ref, e_ren)) / 2.0 / diag * 100.0

    scores = {"label": label, "landmark_err_pct": lm_mean, "silhouette_iou": iou,
              "colour_delta_e": colour_mean, "edge_chamfer_pct": edge,
              "landmarks": lm_err, "colours": colour}
    save_json(os.path.join(run_dir, "scores.json"), scores)
    report(ref, beauty, m_ref, m_ren, e_ref, e_ren, ref_points, proj, scores,
           os.path.join(run_dir, "report.png"))
    return scores


def report(ref, beauty, m_ref, m_ren, e_ref, e_ren, ref_points, proj, s, path):
    h, w = ref.shape[:2]
    blend = cv2.addWeighted(ref, 0.5, beauty, 0.5, 0)
    sil = np.full_like(ref, 30)
    sil[m_ref & ~m_ren] = (60, 60, 230)     # reference only: red
    sil[m_ren & ~m_ref] = (230, 200, 60)    # render only: cyan
    sil[m_ref & m_ren] = (200, 200, 200)
    sil[e_ref] = (0, 0, 255)
    sil[e_ren] = (255, 255, 0)
    for img in (ref, blend):
        for n, p in ref_points.items():
            cv2.circle(img, (int(p[0]), int(p[1])), 6, (40, 200, 40), 2)
    for img in (beauty, blend):
        for n, p in proj.items():
            q = (int(p[0]), int(p[1]))
            cv2.drawMarker(img, q, (200, 40, 200), cv2.MARKER_CROSS, 12, 2)
            if n in ref_points:
                cv2.line(blend, q, (int(ref_points[n][0]), int(ref_points[n][1])), (200, 40, 200), 1)
    top = np.hstack([ref, beauty])
    bottom = np.hstack([blend, sil])
    bar = np.full((60, w * 2, 3), 255, np.uint8)
    text = "%s   landmarks %.2f%%   silhouette IoU %.3f   colour dE %.1f   edges %.2f%%" % (
        s["label"], s["landmark_err_pct"], s["silhouette_iou"], s["colour_delta_e"], s["edge_chamfer_pct"])
    cv2.putText(bar, text, (12, 38), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (20, 20, 20), 2, cv2.LINE_AA)
    cv2.imwrite(path, np.vstack([top, bottom, bar]))


# --- Commands ---------------------------------------------------------------------------------

def load_json(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def save_json(p, data):
    with open(p, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def ref_landmarks(ref):
    p = os.path.splitext(ref)[0] + "_landmarks.json"
    if not os.path.exists(p):
        sys.exit("no landmarks for %s: write %s (see `grid`)" % (ref, p))
    return load_json(p)["points"]


def run(ref, label, points=None, pose=None, do_import=True, refit=True):
    if do_import:
        godot_import()
    if points is None:
        points = ref_landmarks(ref)
        lm_file = os.path.splitext(ref)[0] + "_landmarks.json"
        pose = pose or load_json(lm_file).get("pose")   # the concept's own ballista pose
    run_dir = os.path.join(RUNS, time.strftime("%Y%m%d_%H%M%S") + "_" + label)
    os.makedirs(run_dir, exist_ok=True)
    h, w = cv2.imread(ref).shape[:2]
    model_lm = model_landmarks(run_dir, pose)
    cam = fit_camera(model_lm, points, w, h)
    cam["background"] = [float(c) / 255 for c in border_color(cv2.imread(ref))[::-1]]
    cam_path = os.path.join(run_dir, "camera.json")
    save_json(cam_path, cam)
    render(cam_path, run_dir, pose)
    s = score(ref, points, run_dir, label)
    new = not os.path.exists(HISTORY)
    os.makedirs(os.path.dirname(HISTORY), exist_ok=True)
    with open(HISTORY, "a", newline="", encoding="utf-8") as f:
        wr = csv.writer(f)
        if new:
            wr.writerow(["time", "label", "landmark_err_pct", "silhouette_iou", "colour_delta_e",
                         "edge_chamfer_pct", "fov_y", "fit_rms_px", "run_dir"])
        wr.writerow([time.strftime("%Y-%m-%d %H:%M:%S"), label, "%.3f" % s["landmark_err_pct"],
                     "%.4f" % s["silhouette_iou"], "%.2f" % s["colour_delta_e"],
                     "%.3f" % s["edge_chamfer_pct"], cam["fov_y"], "%.2f" % cam["fit_rms_px"],
                     os.path.relpath(run_dir, ROOT)])
    print(json.dumps({k: s[k] for k in ("landmark_err_pct", "silhouette_iou", "colour_delta_e",
                                        "edge_chamfer_pct")}, indent=2))
    print("camera fov %.1f, fit rms %.2f px" % (cam["fov_y"], cam["fit_rms_px"]))
    print("report", os.path.join(run_dir, "report.png"))
    return s, cam, run_dir


def selftest():
    """Render the model from a known camera, treat that render as the reference, and check that
    the fit recovers the camera and the scores come out near perfect."""
    work = os.path.join(RUNS, "selftest")
    os.makedirs(work, exist_ok=True)
    godot_import()
    eye, target = np.array([-6.5, 4.2, -7.0]), np.array([0.0, 1.1, 0.0])
    fwd = (target - eye) / np.linalg.norm(target - eye)
    right = np.cross(fwd, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    known = {"width": 1024, "height": 768, "fov_y": 30.0, "origin": eye.tolist(),
             "basis": [right.tolist(), up.tolist(), (-fwd).tolist()], "background": [0.88, 0.88, 0.89]}
    ref_dir = os.path.join(work, "reference")
    os.makedirs(ref_dir, exist_ok=True)
    save_json(os.path.join(ref_dir, "camera.json"), known)
    render(os.path.join(ref_dir, "camera.json"), ref_dir)
    points = load_json(os.path.join(ref_dir, "projected.json"))
    s, cam, _ = run(os.path.join(ref_dir, "beauty.png"), "selftest", points=points, do_import=False)
    ok = (abs(cam["fov_y"] - 30.0) < 1.0 and np.linalg.norm(np.array(cam["origin"]) - eye) < 0.2
          and s["landmark_err_pct"] < 0.2 and s["silhouette_iou"] > 0.97 and s["colour_delta_e"] < 2.0)
    print("SELFTEST", "PASSED" if ok else "FAILED", "fov %.2f origin %s" % (cam["fov_y"], np.round(cam["origin"], 2)))
    return 0 if ok else 1


def grid(image, step):
    img = cv2.imread(image)
    out = img.copy()
    for x in range(0, img.shape[1], step):
        cv2.line(out, (x, 0), (x, img.shape[0]), (0, 0, 255) if x % (step * 4) == 0 else (0, 160, 255), 1)
        cv2.putText(out, str(x), (x + 2, 12), cv2.FONT_HERSHEY_SIMPLEX, 0.35, (0, 0, 200), 1)
    for y in range(0, img.shape[0], step):
        cv2.line(out, (0, y), (img.shape[1], y), (0, 0, 255) if y % (step * 4) == 0 else (0, 160, 255), 1)
        cv2.putText(out, str(y), (2, y + 12), cv2.FONT_HERSHEY_SIMPLEX, 0.35, (0, 0, 200), 1)
    path = os.path.join(RUNS, "grid_" + os.path.basename(os.path.splitext(image)[0]) + ".png")
    os.makedirs(RUNS, exist_ok=True)
    cv2.imwrite(path, out)
    print(path)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("--ref", required=True)
    r.add_argument("--label", required=True)
    r.add_argument("--pose", help="ballista yaw_deg,pitch_deg,draw")
    r.add_argument("--no-import", action="store_true")
    sub.add_parser("selftest")
    g = sub.add_parser("grid")
    g.add_argument("image")
    g.add_argument("--step", type=int, default=25)
    a = ap.parse_args()
    if a.cmd == "run":
        run(a.ref, a.label, pose=a.pose, do_import=not a.no_import)
    elif a.cmd == "selftest":
        sys.exit(selftest())
    elif a.cmd == "grid":
        grid(a.image, a.step)


if __name__ == "__main__":
    main()
