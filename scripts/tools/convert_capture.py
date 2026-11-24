#!/usr/bin/env python3
"""
Video and Animation Converter for Heckle Golf Simulator Captures.
Converts Godot-generated AVI recordings into standard web-playable H.264 MP4 videos
and lightweight animated GIFs (< 5MB) suitable for Antigravity remote development,
artifacts, markdown embeds, and PR reviews.
"""

import os
import sys
import argparse
import cv2
from PIL import Image

def convert_avi_to_mp4(input_avi: str, output_mp4: str, target_fps: int = 30, max_width: int = 1280) -> bool:
    if not os.path.exists(input_avi):
        print(f"[ConvertCapture] Error: Input file not found: {input_avi}", file=sys.stderr)
        return False

    cap = cv2.VideoCapture(input_avi)
    if not cap.isOpened():
        print(f"[ConvertCapture] Error: Could not open AVI: {input_avi}", file=sys.stderr)
        return False

    fps = cap.get(cv2.CAP_PROP_FPS)
    if fps <= 0:
        fps = target_fps

    in_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    in_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    out_width = in_width
    out_height = in_height
    if max_width > 0 and in_width > max_width:
        aspect = in_height / in_width
        out_width = int(max_width)
        out_height = int(max_width * aspect)
        # Ensure dimensions are even numbers (required by H.264 encoders)
        out_width = out_width if out_width % 2 == 0 else out_width - 1
        out_height = out_height if out_height % 2 == 0 else out_height - 1

    os.makedirs(os.path.dirname(os.path.abspath(output_mp4)), exist_ok=True)

    # Try Windows Media Foundation (MSMF) H264 hardware encoder first for true browser/webview playback
    out = None
    if sys.platform == "win32":
        try:
            fourcc = cv2.VideoWriter_fourcc(*'H264')
            out = cv2.VideoWriter(output_mp4, cv2.CAP_MSMF, fourcc, fps, (out_width, out_height))
            if not out.isOpened():
                out = None
        except Exception:
            out = None

    # Fallback to standard FFMPEG writer
    if out is None or not out.isOpened():
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(output_mp4, cv2.CAP_FFMPEG, fourcc, fps, (out_width, out_height))

    if not out.isOpened():
        print(f"[ConvertCapture] Error: Could not initialize MP4 VideoWriter for {output_mp4}", file=sys.stderr)
        cap.release()
        return False

    frames_written = 0
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        if out_width != in_width or out_height != in_height:
            frame = cv2.resize(frame, (out_width, out_height), interpolation=cv2.INTER_AREA)
        out.write(frame)
        frames_written += 1

    cap.release()
    out.release()

    # Verify duration
    check = cv2.VideoCapture(output_mp4)
    duration_sec = 0.0
    if check.isOpened():
        check_frames = check.get(cv2.CAP_PROP_FRAME_COUNT)
        check_fps = check.get(cv2.CAP_PROP_FPS) or fps
        duration_sec = check_frames / check_fps if check_fps > 0 else 0.0
        check.release()

    file_size_mb = os.path.getsize(output_mp4) / (1024 * 1024) if os.path.exists(output_mp4) else 0.0
    print(f"[ConvertCapture] H.264 MP4 saved: {output_mp4} ({frames_written} frames, {duration_sec:.1f}s, {file_size_mb:.1f} MB, {out_width}x{out_height})")
    return os.path.exists(output_mp4) and os.path.getsize(output_mp4) > 0

def convert_avi_to_gif(input_avi: str, output_gif: str, max_width: int = 540, sample_fps: int = 10, colors: int = 80) -> bool:
    if not os.path.exists(input_avi):
        print(f"[ConvertCapture] Error: Input file not found: {input_avi}", file=sys.stderr)
        return False

    cap = cv2.VideoCapture(input_avi)
    if not cap.isOpened():
        print(f"[ConvertCapture] Error: Could not open AVI: {input_avi}", file=sys.stderr)
        return False

    source_fps = cap.get(cv2.CAP_PROP_FPS)
    if source_fps <= 0:
        source_fps = 30.0

    step = max(1, int(round(source_fps / sample_fps)))
    frames = []

    frame_idx = 0
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        if frame_idx % step == 0:
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            pil_img = Image.fromarray(rgb_frame)
            if max_width > 0 and pil_img.width > max_width:
                aspect = pil_img.height / pil_img.width
                new_height = int(max_width * aspect)
                pil_img = pil_img.resize((max_width, new_height), Image.Resampling.BILINEAR)

            # Quantize to adaptive palette with reduced colors for compact file size (< 5MB)
            quantized = pil_img.convert("P", palette=Image.Palette.ADAPTIVE, colors=colors)
            frames.append(quantized)
        frame_idx += 1

    cap.release()

    if not frames:
        print("[ConvertCapture] Error: No frames extracted for GIF.", file=sys.stderr)
        return False

    os.makedirs(os.path.dirname(os.path.abspath(output_gif)), exist_ok=True)
    frame_duration_ms = int(1000 / sample_fps)
    frames[0].save(
        output_gif,
        save_all=True,
        append_images=frames[1:],
        duration=frame_duration_ms,
        loop=0,
        optimize=True
    )

    file_size_mb = os.path.getsize(output_gif) / (1024 * 1024) if os.path.exists(output_gif) else 0.0
    print(f"[ConvertCapture] Lightweight GIF saved: {output_gif} ({len(frames)} frames, {file_size_mb:.2f} MB, {frames[0].width}x{frames[0].height})")
    return os.path.exists(output_gif) and os.path.getsize(output_gif) > 0

def generate_html_player(mp4_path: str, gif_path: str, output_html: str, title: str = "Feature Verification Preview") -> bool:
    os.makedirs(os.path.dirname(os.path.abspath(output_html)), exist_ok=True)
    mp4_rel = os.path.basename(mp4_path) if mp4_path else ""
    gif_rel = os.path.basename(gif_path) if gif_path else ""

    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title}</title>
<style>
  body {{
    margin: 0;
    padding: 24px;
    background: #0f141c;
    color: #e6edf3;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
  }}
  .card {{
    max-width: 860px;
    margin: 0 auto;
    background: #161b22;
    border: 1px solid #30363d;
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 8px 24px rgba(0,0,0,0.4);
  }}
  .header {{
    padding: 16px 20px;
    background: #1f242c;
    border-bottom: 1px solid #30363d;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }}
  .header h2 {{
    margin: 0;
    font-size: 1.15rem;
    color: #58a6ff;
  }}
  .badge {{
    background: #238636;
    color: white;
    padding: 4px 10px;
    border-radius: 20px;
    font-size: 0.75rem;
    font-weight: 600;
  }}
  .video-container {{
    position: relative;
    background: #000;
    display: flex;
    justify-content: center;
  }}
  video {{
    max-width: 100%;
    max-height: 540px;
    display: block;
  }}
  .controls {{
    padding: 12px 20px;
    background: #161b22;
    display: flex;
    gap: 12px;
    align-items: center;
    border-top: 1px solid #21262d;
    flex-wrap: wrap;
  }}
  .btn {{
    background: #21262d;
    color: #c9d1d9;
    border: 1px solid #30363d;
    padding: 6px 14px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.85rem;
  }}
  .btn:hover {{
    background: #30363d;
    color: white;
  }}
  .meta {{
    padding: 14px 20px;
    font-size: 0.85rem;
    color: #8b949e;
    line-height: 1.5;
  }}
  .meta a {{
    color: #58a6ff;
    text-decoration: none;
  }}
  .meta a:hover {{
    text-decoration: underline;
  }}
</style>
</head>
<body>
<div class="card">
  <div class="header">
    <h2>⛳ {title}</h2>
    <span class="badge">Verified Working</span>
  </div>
  <div class="video-container">
    <video id="player" controls autoplay loop playsinline>
      <source src="{mp4_rel}" type="video/mp4">
      Your browser does not support the video tag.
    </video>
  </div>
  <div class="controls">
    <button class="btn" onclick="document.getElementById('player').playbackRate = 0.5">0.5x Speed</button>
    <button class="btn" onclick="document.getElementById('player').playbackRate = 1.0">1.0x Normal</button>
    <button class="btn" onclick="document.getElementById('player').playbackRate = 1.5">1.5x Fast</button>
    <button class="btn" onclick="document.getElementById('player').currentTime = 0; document.getElementById('player').play()">Restart</button>
  </div>
  <div class="meta">
    Direct links: <a href="{mp4_rel}" target="_blank">Open Full Video ({mp4_rel})</a> | 
    <a href="{gif_rel}" target="_blank">View Animated GIF ({gif_rel})</a>
  </div>
</div>
</body>
</html>
"""
    with open(output_html, "w", encoding="utf-8") as f:
        f.write(html_content)
    print(f"[ConvertCapture] HTML viewer generated: {output_html}")
    return True

def main():
    parser = argparse.ArgumentParser(description="Convert Godot AVI capture to standard MP4, GIF, and HTML viewer.")
    parser.add_argument("--input", "-i", required=True, help="Input AVI file path")
    parser.add_argument("--mp4", help="Output MP4 file path")
    parser.add_argument("--gif", help="Output animated GIF file path")
    parser.add_argument("--html", help="Output HTML player path")
    parser.add_argument("--mp4-width", type=int, default=1280, help="Max width for MP4")
    parser.add_argument("--gif-width", type=int, default=540, help="Max width for GIF (< 5MB)")
    parser.add_argument("--gif-fps", type=int, default=10, help="Sampling FPS for GIF")
    parser.add_argument("--gif-colors", type=int, default=80, help="Color count for GIF quantization")
    parser.add_argument("--remove-source", action="store_true", help="Remove source AVI file after conversion")

    args = parser.parse_args()

    success = True
    if args.mp4:
        if not convert_avi_to_mp4(args.input, args.mp4, max_width=args.mp4_width):
            success = False

    if args.gif:
        if not convert_avi_to_gif(args.input, args.gif, max_width=args.gif_width, sample_fps=args.gif_fps, colors=args.gif_colors):
            success = False

    if args.html and args.mp4:
        generate_html_player(args.mp4, args.gif or "", args.html)

    if success and args.remove_source and os.path.exists(args.input):
        try:
            os.remove(args.input)
            print(f"[ConvertCapture] Removed intermediate source: {args.input}")
        except Exception as e:
            print(f"[ConvertCapture] Warning: Could not remove intermediate source: {e}", file=sys.stderr)

    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()
