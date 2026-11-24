extends RefCounted

# GolfSwingAnalyzer
# Comprehensive golf swing diagnostic engine combining:
# 1. Real launch monitor ballistic benchmarks (Smash Factor, AoA, Face-to-Path, Spin, Launch Angle)
#    tailored by club type according to professional standards (Golf Sim Depot guide).
# 2. In-depth 3D/2D MediaPipe skeleton wireframe kinematics analyzing setup squareness,
#    thoracic & pelvic rotation, X-factor coil, kinematic sequencing, early extension, and arm structure.
# 3. Cross-correlated unified diagnostic ranking that pairs ballistic symptoms with biomechanical root causes.

class_name GolfSwingAnalyzer

# HackMotion YouTube video tutorials & drill references from:
# https://hackmotion.com/launch-monitor-data-explained/
const HM_VIDEOS = {
	"low_point": {
		"id": "SprUtqdpP68",
		"title": "Simple Low Point Drill You Can Do at the Range - Strike It Pure Every Time",
		"url": "https://www.youtube.com/watch?v=SprUtqdpP68",
		"embed": "https://www.youtube.com/embed/SprUtqdpP68"
	},
	"barrier_path": {
		"id": "XklxkK1FsWg",
		"title": "Perfect Your Swing Indoors: Golf Simulator Practice Tips",
		"url": "https://www.youtube.com/watch?v=XklxkK1FsWg",
		"embed": "https://www.youtube.com/embed/XklxkK1FsWg"
	},
	"downswing_sequence": {
		"id": "YQhfe1MOOKg",
		"title": "2 Powerful Downswing Drills for Better Sequence and Clubface Control",
		"url": "https://www.youtube.com/watch?v=YQhfe1MOOKg",
		"embed": "https://www.youtube.com/embed/YQhfe1MOOKg"
	},
	"shaft_lean": {
		"id": "fyi1k63ly_k",
		"title": "2 Biggest Shaft Lean Mistakes (And How to Fix Them!)",
		"url": "https://www.youtube.com/watch?v=fyi1k63ly_k",
		"embed": "https://www.youtube.com/embed/fyi1k63ly_k"
	},
	"one_metric_aoa": {
		"id": "Gy1_w4pB5RE",
		"title": "You Only Need to Fix ONE Metric | Combine TrackMan + HackMotion to Do It",
		"url": "https://www.youtube.com/watch?v=Gy1_w4pB5RE",
		"embed": "https://www.youtube.com/embed/Gy1_w4pB5RE"
	},
	"sim_improvement": {
		"id": "2bbjlF3nDYs",
		"title": "Home Golf Simulator Tips for Better, Faster Improvement",
		"url": "https://www.youtube.com/watch?v=2bbjlF3nDYs",
		"embed": "https://www.youtube.com/embed/2bbjlF3nDYs"
	}
}

const SKILL_LEVEL_NAMES = {
	"mid_handicap": "Mid Handicap (10–19 HCP)",
	"scratch": "Scratch / Low HCP (0–9 HCP)",
	"tour_pro": "Tour Pro (PGA/LPGA Benchmark)",
	"high_handicap": "High Handicap (20+ HCP)"
}

const CLUB_BENCHMARKS = {
	"mid_handicap": {
		"driver": {"name": "Driver", "club_speed_min": 90.0, "club_speed_max": 97.0, "ball_speed_min": 128.0, "ball_speed_max": 140.0, "smash_min": 1.41, "smash_max": 1.46, "aoa_min": -2.5, "aoa_max": 1.5, "vla_min": 12.5, "vla_max": 15.5, "spin_min": 2500.0, "spin_max": 3200.0, "carry_min": 205.0, "carry_max": 230.0, "rollout_min": 15.0, "rollout_max": 24.0, "apex_min": 75.0, "apex_max": 90.0, "land_angle_min": 36.0, "land_angle_max": 41.0},
		"3w": {"name": "3-Wood", "club_speed_min": 85.0, "club_speed_max": 92.0, "ball_speed_min": 122.0, "ball_speed_max": 132.0, "smash_min": 1.41, "smash_max": 1.45, "aoa_min": -2.0, "aoa_max": 0.5, "vla_min": 12.0, "vla_max": 14.8, "spin_min": 3400.0, "spin_max": 4300.0, "carry_min": 185.0, "carry_max": 205.0, "rollout_min": 14.0, "rollout_max": 20.0, "apex_min": 74.0, "apex_max": 88.0, "land_angle_min": 40.0, "land_angle_max": 44.0},
		"5w": {"name": "5-Wood", "club_speed_min": 82.0, "club_speed_max": 88.0, "ball_speed_min": 116.0, "ball_speed_max": 126.0, "smash_min": 1.40, "smash_max": 1.44, "aoa_min": -2.5, "aoa_max": 0.0, "vla_min": 13.0, "vla_max": 16.0, "spin_min": 4000.0, "spin_max": 4900.0, "carry_min": 174.0, "carry_max": 192.0, "rollout_min": 10.0, "rollout_max": 16.0, "apex_min": 74.0, "apex_max": 88.0, "land_angle_min": 42.0, "land_angle_max": 46.0},
		"hybrid": {"name": "Hybrid", "club_speed_min": 79.0, "club_speed_max": 85.0, "ball_speed_min": 112.0, "ball_speed_max": 121.0, "smash_min": 1.39, "smash_max": 1.43, "aoa_min": -3.0, "aoa_max": -0.5, "vla_min": 13.5, "vla_max": 16.5, "spin_min": 4200.0, "spin_max": 5100.0, "carry_min": 165.0, "carry_max": 182.0, "rollout_min": 8.0, "rollout_max": 14.0, "apex_min": 72.0, "apex_max": 86.0, "land_angle_min": 43.0, "land_angle_max": 47.0},
		"4i": {"name": "4-Iron", "club_speed_min": 77.0, "club_speed_max": 83.0, "ball_speed_min": 107.0, "ball_speed_max": 116.0, "smash_min": 1.37, "smash_max": 1.41, "aoa_min": -3.0, "aoa_max": -1.0, "vla_min": 13.0, "vla_max": 15.5, "spin_min": 4200.0, "spin_max": 5100.0, "carry_min": 156.0, "carry_max": 172.0, "rollout_min": 8.0, "rollout_max": 14.0, "apex_min": 70.0, "apex_max": 84.0, "land_angle_min": 43.0, "land_angle_max": 47.0},
		"5i": {"name": "5-Iron", "club_speed_min": 75.0, "club_speed_max": 80.0, "ball_speed_min": 102.0, "ball_speed_max": 111.0, "smash_min": 1.36, "smash_max": 1.40, "aoa_min": -3.2, "aoa_max": -1.2, "vla_min": 14.0, "vla_max": 16.8, "spin_min": 4600.0, "spin_max": 5500.0, "carry_min": 148.0, "carry_max": 162.0, "rollout_min": 6.0, "rollout_max": 12.0, "apex_min": 70.0, "apex_max": 84.0, "land_angle_min": 44.0, "land_angle_max": 48.0},
		"6i": {"name": "6-Iron", "club_speed_min": 73.0, "club_speed_max": 78.0, "ball_speed_min": 97.0, "ball_speed_max": 105.0, "smash_min": 1.34, "smash_max": 1.38, "aoa_min": -3.5, "aoa_max": -1.5, "vla_min": 15.5, "vla_max": 18.5, "spin_min": 5000.0, "spin_max": 6000.0, "carry_min": 138.0, "carry_max": 152.0, "rollout_min": 5.0, "rollout_max": 9.0, "apex_min": 70.0, "apex_max": 84.0, "land_angle_min": 45.0, "land_angle_max": 49.0},
		"7i": {"name": "7-Iron", "club_speed_min": 70.0, "club_speed_max": 76.0, "ball_speed_min": 92.0, "ball_speed_max": 101.0, "smash_min": 1.32, "smash_max": 1.36, "aoa_min": -3.8, "aoa_max": -1.8, "vla_min": 17.5, "vla_max": 20.8, "spin_min": 5400.0, "spin_max": 6400.0, "carry_min": 128.0, "carry_max": 142.0, "rollout_min": 4.0, "rollout_max": 8.0, "apex_min": 70.0, "apex_max": 82.0, "land_angle_min": 46.0, "land_angle_max": 50.0},
		"8i": {"name": "8-Iron", "club_speed_min": 68.0, "club_speed_max": 73.0, "ball_speed_min": 87.0, "ball_speed_max": 95.0, "smash_min": 1.30, "smash_max": 1.34, "aoa_min": -4.0, "aoa_max": -2.0, "vla_min": 19.0, "vla_max": 22.5, "spin_min": 5900.0, "spin_max": 7000.0, "carry_min": 118.0, "carry_max": 131.0, "rollout_min": 3.0, "rollout_max": 6.0, "apex_min": 68.0, "apex_max": 80.0, "land_angle_min": 47.0, "land_angle_max": 51.0},
		"9i": {"name": "9-Iron", "club_speed_min": 65.0, "club_speed_max": 70.0, "ball_speed_min": 81.0, "ball_speed_max": 89.0, "smash_min": 1.26, "smash_max": 1.30, "aoa_min": -4.2, "aoa_max": -2.2, "vla_min": 21.0, "vla_max": 24.8, "spin_min": 6400.0, "spin_max": 7500.0, "carry_min": 108.0, "carry_max": 120.0, "rollout_min": 2.0, "rollout_max": 4.0, "apex_min": 68.0, "apex_max": 80.0, "land_angle_min": 48.0, "land_angle_max": 52.0},
		"pw": {"name": "Pitching Wedge", "club_speed_min": 63.0, "club_speed_max": 68.0, "ball_speed_min": 75.0, "ball_speed_max": 83.0, "smash_min": 1.20, "smash_max": 1.24, "aoa_min": -4.5, "aoa_max": -2.5, "vla_min": 24.0, "vla_max": 28.0, "spin_min": 6800.0, "spin_max": 8000.0, "carry_min": 98.0, "carry_max": 110.0, "rollout_min": 1.0, "rollout_max": 3.0, "apex_min": 66.0, "apex_max": 78.0, "land_angle_min": 49.0, "land_angle_max": 53.0},
		"gw": {"name": "Gap Wedge", "club_speed_min": 60.0, "club_speed_max": 65.0, "ball_speed_min": 69.0, "ball_speed_max": 76.0, "smash_min": 1.16, "smash_max": 1.20, "aoa_min": -4.8, "aoa_max": -2.8, "vla_min": 26.0, "vla_max": 30.5, "spin_min": 7000.0, "spin_max": 8200.0, "carry_min": 86.0, "carry_max": 98.0, "rollout_min": 1.0, "rollout_max": 3.0, "apex_min": 64.0, "apex_max": 76.0, "land_angle_min": 50.0, "land_angle_max": 54.0},
		"sw": {"name": "Sand Wedge", "club_speed_min": 56.0, "club_speed_max": 61.0, "ball_speed_min": 62.0, "ball_speed_max": 69.0, "smash_min": 1.12, "smash_max": 1.16, "aoa_min": -5.0, "aoa_max": -3.0, "vla_min": 29.0, "vla_max": 33.5, "spin_min": 7200.0, "spin_max": 8400.0, "carry_min": 74.0, "carry_max": 84.0, "rollout_min": 0.0, "rollout_max": 2.0, "apex_min": 62.0, "apex_max": 72.0, "land_angle_min": 51.0, "land_angle_max": 55.0},
		"lw": {"name": "Lob Wedge", "club_speed_min": 52.0, "club_speed_max": 57.0, "ball_speed_min": 54.0, "ball_speed_max": 61.0, "smash_min": 1.05, "smash_max": 1.10, "aoa_min": -5.2, "aoa_max": -3.2, "vla_min": 32.0, "vla_max": 37.0, "spin_min": 6800.0, "spin_max": 8000.0, "carry_min": 60.0, "carry_max": 70.0, "rollout_min": 0.0, "rollout_max": 2.0, "apex_min": 58.0, "apex_max": 68.0, "land_angle_min": 52.0, "land_angle_max": 56.0}
	},
	"scratch": {
		"driver": {"name": "Driver", "club_speed_min": 102.0, "club_speed_max": 108.0, "ball_speed_min": 150.0, "ball_speed_max": 160.0, "smash_min": 1.45, "smash_max": 1.49, "aoa_min": -1.0, "aoa_max": 3.0, "vla_min": 11.5, "vla_max": 14.5, "spin_min": 2300.0, "spin_max": 2800.0, "carry_min": 245.0, "carry_max": 265.0, "rollout_min": 18.0, "rollout_max": 26.0, "apex_min": 85.0, "apex_max": 100.0, "land_angle_min": 37.0, "land_angle_max": 41.0},
		"3w": {"name": "3-Wood", "club_speed_min": 96.0, "club_speed_max": 102.0, "ball_speed_min": 142.0, "ball_speed_max": 150.0, "smash_min": 1.45, "smash_max": 1.48, "aoa_min": -2.5, "aoa_max": -0.5, "vla_min": 11.0, "vla_max": 13.5, "spin_min": 3500.0, "spin_max": 4200.0, "carry_min": 218.0, "carry_max": 235.0, "rollout_min": 14.0, "rollout_max": 20.0, "apex_min": 82.0, "apex_max": 95.0, "land_angle_min": 41.0, "land_angle_max": 45.0},
		"5w": {"name": "5-Wood", "club_speed_min": 92.0, "club_speed_max": 98.0, "ball_speed_min": 135.0, "ball_speed_max": 143.0, "smash_min": 1.44, "smash_max": 1.47, "aoa_min": -3.0, "aoa_max": -1.0, "vla_min": 12.5, "vla_max": 15.0, "spin_min": 4100.0, "spin_max": 4800.0, "carry_min": 205.0, "carry_max": 220.0, "rollout_min": 10.0, "rollout_max": 15.0, "apex_min": 84.0, "apex_max": 96.0, "land_angle_min": 43.0, "land_angle_max": 47.0},
		"hybrid": {"name": "Hybrid", "club_speed_min": 89.0, "club_speed_max": 95.0, "ball_speed_min": 130.0, "ball_speed_max": 138.0, "smash_min": 1.43, "smash_max": 1.46, "aoa_min": -3.5, "aoa_max": -1.5, "vla_min": 13.0, "vla_max": 15.5, "spin_min": 4400.0, "spin_max": 5100.0, "carry_min": 196.0, "carry_max": 210.0, "rollout_min": 8.0, "rollout_max": 13.0, "apex_min": 82.0, "apex_max": 94.0, "land_angle_min": 44.0, "land_angle_max": 48.0},
		"4i": {"name": "4-Iron", "club_speed_min": 86.0, "club_speed_max": 92.0, "ball_speed_min": 123.0, "ball_speed_max": 131.0, "smash_min": 1.40, "smash_max": 1.44, "aoa_min": -3.8, "aoa_max": -1.8, "vla_min": 12.0, "vla_max": 14.5, "spin_min": 4500.0, "spin_max": 5300.0, "carry_min": 185.0, "carry_max": 198.0, "rollout_min": 8.0, "rollout_max": 13.0, "apex_min": 80.0, "apex_max": 92.0, "land_angle_min": 44.0, "land_angle_max": 48.0},
		"5i": {"name": "5-Iron", "club_speed_min": 84.0, "club_speed_max": 89.0, "ball_speed_min": 118.0, "ball_speed_max": 126.0, "smash_min": 1.39, "smash_max": 1.43, "aoa_min": -4.0, "aoa_max": -2.0, "vla_min": 13.0, "vla_max": 15.5, "spin_min": 5000.0, "spin_max": 5800.0, "carry_min": 175.0, "carry_max": 187.0, "rollout_min": 6.0, "rollout_max": 10.0, "apex_min": 80.0, "apex_max": 92.0, "land_angle_min": 45.0, "land_angle_max": 49.0},
		"6i": {"name": "6-Iron", "club_speed_min": 81.0, "club_speed_max": 86.0, "ball_speed_min": 113.0, "ball_speed_max": 120.0, "smash_min": 1.38, "smash_max": 1.41, "aoa_min": -4.2, "aoa_max": -2.2, "vla_min": 14.5, "vla_max": 17.0, "spin_min": 5700.0, "spin_max": 6500.0, "carry_min": 165.0, "carry_max": 176.0, "rollout_min": 5.0, "rollout_max": 8.0, "apex_min": 82.0, "apex_max": 94.0, "land_angle_min": 46.5, "land_angle_max": 50.5},
		"7i": {"name": "7-Iron", "club_speed_min": 79.0, "club_speed_max": 84.0, "ball_speed_min": 108.0, "ball_speed_max": 115.0, "smash_min": 1.35, "smash_max": 1.39, "aoa_min": -4.5, "aoa_max": -2.5, "vla_min": 16.5, "vla_max": 19.0, "spin_min": 6300.0, "spin_max": 7100.0, "carry_min": 155.0, "carry_max": 166.0, "rollout_min": 3.0, "rollout_max": 6.0, "apex_min": 82.0, "apex_max": 94.0, "land_angle_min": 48.0, "land_angle_max": 52.0},
		"8i": {"name": "8-Iron", "club_speed_min": 76.0, "club_speed_max": 81.0, "ball_speed_min": 102.0, "ball_speed_max": 109.0, "smash_min": 1.33, "smash_max": 1.37, "aoa_min": -4.8, "aoa_max": -2.8, "vla_min": 18.0, "vla_max": 21.0, "spin_min": 7100.0, "spin_max": 7900.0, "carry_min": 144.0, "carry_max": 155.0, "rollout_min": 2.0, "rollout_max": 5.0, "apex_min": 82.0, "apex_max": 92.0, "land_angle_min": 49.0, "land_angle_max": 53.0},
		"9i": {"name": "9-Iron", "club_speed_min": 74.0, "club_speed_max": 78.0, "ball_speed_min": 96.0, "ball_speed_max": 102.0, "smash_min": 1.29, "smash_max": 1.33, "aoa_min": -5.0, "aoa_max": -3.0, "vla_min": 20.0, "vla_max": 23.0, "spin_min": 7700.0, "spin_max": 8600.0, "carry_min": 133.0, "carry_max": 144.0, "rollout_min": 1.0, "rollout_max": 3.0, "apex_min": 80.0, "apex_max": 92.0, "land_angle_min": 50.0, "land_angle_max": 54.0},
		"pw": {"name": "Pitching Wedge", "club_speed_min": 71.0, "club_speed_max": 76.0, "ball_speed_min": 89.0, "ball_speed_max": 95.0, "smash_min": 1.22, "smash_max": 1.26, "aoa_min": -5.2, "aoa_max": -3.2, "vla_min": 23.5, "vla_max": 27.0, "spin_min": 8200.0, "spin_max": 9200.0, "carry_min": 122.0, "carry_max": 132.0, "rollout_min": 0.0, "rollout_max": 2.0, "apex_min": 78.0, "apex_max": 90.0, "land_angle_min": 51.0, "land_angle_max": 55.0},
		"gw": {"name": "Gap Wedge", "club_speed_min": 68.0, "club_speed_max": 73.0, "ball_speed_min": 82.0, "ball_speed_max": 88.0, "smash_min": 1.19, "smash_max": 1.23, "aoa_min": -5.5, "aoa_max": -3.5, "vla_min": 25.5, "vla_max": 29.5, "spin_min": 8500.0, "spin_max": 9500.0, "carry_min": 108.0, "carry_max": 118.0, "rollout_min": 0.0, "rollout_max": 2.0, "apex_min": 76.0, "apex_max": 88.0, "land_angle_min": 52.0, "land_angle_max": 56.0},
		"sw": {"name": "Sand Wedge", "club_speed_min": 64.0, "club_speed_max": 69.0, "ball_speed_min": 74.0, "ball_speed_max": 80.0, "smash_min": 1.15, "smash_max": 1.19, "aoa_min": -5.8, "aoa_max": -3.8, "vla_min": 28.5, "vla_max": 32.5, "spin_min": 8700.0, "spin_max": 9700.0, "carry_min": 92.0, "carry_max": 102.0, "rollout_min": 0.0, "rollout_max": 1.0, "apex_min": 72.0, "apex_max": 84.0, "land_angle_min": 53.0, "land_angle_max": 57.0},
		"lw": {"name": "Lob Wedge", "club_speed_min": 59.0, "club_speed_max": 64.0, "ball_speed_min": 64.0, "ball_speed_max": 70.0, "smash_min": 1.09, "smash_max": 1.13, "aoa_min": -6.0, "aoa_max": -4.0, "vla_min": 31.5, "vla_max": 36.0, "spin_min": 8200.0, "spin_max": 9200.0, "carry_min": 74.0, "carry_max": 84.0, "rollout_min": 0.0, "rollout_max": 1.0, "apex_min": 68.0, "apex_max": 78.0, "land_angle_min": 54.0, "land_angle_max": 58.0}
	},
	"tour_pro": {
		"driver": {"name": "Driver", "club_speed_min": 112.0, "club_speed_max": 118.0, "ball_speed_min": 167.0, "ball_speed_max": 174.0, "smash_min": 1.46, "smash_max": 1.50, "aoa_min": -2.0, "aoa_max": 2.5, "vla_min": 10.0, "vla_max": 13.0, "spin_min": 2200.0, "spin_max": 2700.0, "carry_min": 275.0, "carry_max": 295.0, "rollout_min": 18.0, "rollout_max": 28.0, "apex_min": 95.0, "apex_max": 110.0, "land_angle_min": 37.0, "land_angle_max": 42.0},
		"3w": {"name": "3-Wood", "club_speed_min": 105.0, "club_speed_max": 111.0, "ball_speed_min": 156.0, "ball_speed_max": 163.0, "smash_min": 1.46, "smash_max": 1.50, "aoa_min": -3.5, "aoa_max": -1.5, "vla_min": 10.0, "vla_max": 12.5, "spin_min": 3300.0, "spin_max": 4000.0, "carry_min": 240.0, "carry_max": 258.0, "rollout_min": 15.0, "rollout_max": 22.0, "apex_min": 90.0, "apex_max": 102.0, "land_angle_min": 42.0, "land_angle_max": 46.0},
		"5w": {"name": "5-Wood", "club_speed_min": 101.0, "club_speed_max": 107.0, "ball_speed_min": 149.0, "ball_speed_max": 156.0, "smash_min": 1.45, "smash_max": 1.49, "aoa_min": -4.0, "aoa_max": -2.0, "vla_min": 11.5, "vla_max": 14.0, "spin_min": 4000.0, "spin_max": 4700.0, "carry_min": 228.0, "carry_max": 244.0, "rollout_min": 10.0, "rollout_max": 16.0, "apex_min": 92.0, "apex_max": 104.0, "land_angle_min": 45.0, "land_angle_max": 49.0},
		"hybrid": {"name": "Hybrid", "club_speed_min": 98.0, "club_speed_max": 104.0, "ball_speed_min": 143.0, "ball_speed_max": 150.0, "smash_min": 1.44, "smash_max": 1.48, "aoa_min": -4.5, "aoa_max": -2.5, "vla_min": 12.0, "vla_max": 14.5, "spin_min": 4200.0, "spin_max": 5000.0, "carry_min": 220.0, "carry_max": 235.0, "rollout_min": 8.0, "rollout_max": 14.0, "apex_min": 90.0, "apex_max": 100.0, "land_angle_min": 45.0, "land_angle_max": 50.0},
		"4i": {"name": "4-Iron", "club_speed_min": 94.0, "club_speed_max": 99.0, "ball_speed_min": 135.0, "ball_speed_max": 142.0, "smash_min": 1.42, "smash_max": 1.46, "aoa_min": -4.5, "aoa_max": -2.5, "vla_min": 10.5, "vla_max": 13.0, "spin_min": 4400.0, "spin_max": 5200.0, "carry_min": 202.0, "carry_max": 216.0, "rollout_min": 8.0, "rollout_max": 14.0, "apex_min": 88.0, "apex_max": 98.0, "land_angle_min": 45.0, "land_angle_max": 49.0},
		"5i": {"name": "5-Iron", "club_speed_min": 91.0, "club_speed_max": 96.0, "ball_speed_min": 131.0, "ball_speed_max": 137.0, "smash_min": 1.41, "smash_max": 1.45, "aoa_min": -4.8, "aoa_max": -2.8, "vla_min": 11.5, "vla_max": 14.0, "spin_min": 4900.0, "spin_max": 5700.0, "carry_min": 192.0, "carry_max": 205.0, "rollout_min": 6.0, "rollout_max": 12.0, "apex_min": 90.0, "apex_max": 100.0, "land_angle_min": 46.0, "land_angle_max": 50.0},
		"6i": {"name": "6-Iron", "club_speed_min": 89.0, "club_speed_max": 94.0, "ball_speed_min": 126.0, "ball_speed_max": 132.0, "smash_min": 1.39, "smash_max": 1.43, "aoa_min": -5.0, "aoa_max": -3.0, "vla_min": 13.0, "vla_max": 15.5, "spin_min": 5800.0, "spin_max": 6600.0, "carry_min": 182.0, "carry_max": 194.0, "rollout_min": 5.0, "rollout_max": 10.0, "apex_min": 90.0, "apex_max": 100.0, "land_angle_min": 48.0, "land_angle_max": 52.0},
		"7i": {"name": "7-Iron", "club_speed_min": 87.0, "club_speed_max": 92.0, "ball_speed_min": 120.0, "ball_speed_max": 126.0, "smash_min": 1.36, "smash_max": 1.40, "aoa_min": -5.2, "aoa_max": -3.2, "vla_min": 15.0, "vla_max": 17.5, "spin_min": 6600.0, "spin_max": 7500.0, "carry_min": 170.0, "carry_max": 182.0, "rollout_min": 3.0, "rollout_max": 7.0, "apex_min": 92.0, "apex_max": 102.0, "land_angle_min": 49.0, "land_angle_max": 53.0},
		"8i": {"name": "8-Iron", "club_speed_min": 84.0, "club_speed_max": 89.0, "ball_speed_min": 114.0, "ball_speed_max": 120.0, "smash_min": 1.34, "smash_max": 1.38, "aoa_min": -5.5, "aoa_max": -3.5, "vla_min": 17.0, "vla_max": 19.5, "spin_min": 7600.0, "spin_max": 8500.0, "carry_min": 158.0, "carry_max": 170.0, "rollout_min": 2.0, "rollout_max": 5.0, "apex_min": 90.0, "apex_max": 100.0, "land_angle_min": 50.0, "land_angle_max": 54.0},
		"9i": {"name": "9-Iron", "club_speed_min": 82.0, "club_speed_max": 87.0, "ball_speed_min": 108.0, "ball_speed_max": 114.0, "smash_min": 1.30, "smash_max": 1.34, "aoa_min": -5.8, "aoa_max": -3.8, "vla_min": 19.0, "vla_max": 22.0, "spin_min": 8300.0, "spin_max": 9200.0, "carry_min": 146.0, "carry_max": 158.0, "rollout_min": 1.0, "rollout_max": 4.0, "apex_min": 88.0, "apex_max": 98.0, "land_angle_min": 51.0, "land_angle_max": 55.0},
		"pw": {"name": "Pitching Wedge", "club_speed_min": 80.0, "club_speed_max": 85.0, "ball_speed_min": 100.0, "ball_speed_max": 106.0, "smash_min": 1.23, "smash_max": 1.28, "aoa_min": -6.0, "aoa_max": -4.0, "vla_min": 22.5, "vla_max": 26.0, "spin_min": 8800.0, "spin_max": 9800.0, "carry_min": 136.0, "carry_max": 146.0, "rollout_min": 0.0, "rollout_max": 2.0, "apex_min": 88.0, "apex_max": 96.0, "land_angle_min": 52.0, "land_angle_max": 56.0},
		"gw": {"name": "Gap Wedge", "club_speed_min": 76.0, "club_speed_max": 81.0, "ball_speed_min": 93.0, "ball_speed_max": 99.0, "smash_min": 1.21, "smash_max": 1.25, "aoa_min": -6.2, "aoa_max": -4.2, "vla_min": 24.5, "vla_max": 28.5, "spin_min": 9100.0, "spin_max": 10100.0, "carry_min": 120.0, "carry_max": 130.0, "rollout_min": 0.0, "rollout_max": 2.0, "apex_min": 84.0, "apex_max": 92.0, "land_angle_min": 53.0, "land_angle_max": 57.0},
		"sw": {"name": "Sand Wedge", "club_speed_min": 71.0, "club_speed_max": 76.0, "ball_speed_min": 84.0, "ball_speed_max": 90.0, "smash_min": 1.17, "smash_max": 1.21, "aoa_min": -6.5, "aoa_max": -4.5, "vla_min": 27.5, "vla_max": 31.5, "spin_min": 9400.0, "spin_max": 10400.0, "carry_min": 102.0, "carry_max": 112.0, "rollout_min": 0.0, "rollout_max": 1.0, "apex_min": 78.0, "apex_max": 86.0, "land_angle_min": 54.0, "land_angle_max": 58.0},
		"lw": {"name": "Lob Wedge", "club_speed_min": 65.0, "club_speed_max": 70.0, "ball_speed_min": 73.0, "ball_speed_max": 79.0, "smash_min": 1.11, "smash_max": 1.15, "aoa_min": -6.8, "aoa_max": -4.8, "vla_min": 30.5, "vla_max": 35.0, "spin_min": 9000.0, "spin_max": 10000.0, "carry_min": 82.0, "carry_max": 92.0, "rollout_min": 0.0, "rollout_max": 1.0, "apex_min": 72.0, "apex_max": 80.0, "land_angle_min": 55.0, "land_angle_max": 60.0}
	},
	"high_handicap": {
		"driver": {"name": "Driver", "club_speed_min": 78.0, "club_speed_max": 86.0, "ball_speed_min": 106.0, "ball_speed_max": 120.0, "smash_min": 1.34, "smash_max": 1.40, "aoa_min": -3.5, "aoa_max": 1.0, "vla_min": 13.5, "vla_max": 17.0, "spin_min": 2900.0, "spin_max": 3800.0, "carry_min": 165.0, "carry_max": 192.0, "rollout_min": 12.0, "rollout_max": 20.0, "apex_min": 60.0, "apex_max": 75.0, "land_angle_min": 35.0, "land_angle_max": 40.0},
		"3w": {"name": "3-Wood", "club_speed_min": 74.0, "club_speed_max": 81.0, "ball_speed_min": 100.0, "ball_speed_max": 111.0, "smash_min": 1.34, "smash_max": 1.39, "aoa_min": -2.5, "aoa_max": 1.0, "vla_min": 13.0, "vla_max": 16.5, "spin_min": 3600.0, "spin_max": 4700.0, "carry_min": 150.0, "carry_max": 170.0, "rollout_min": 12.0, "rollout_max": 18.0, "apex_min": 60.0, "apex_max": 74.0, "land_angle_min": 38.0, "land_angle_max": 43.0},
		"5w": {"name": "5-Wood", "club_speed_min": 71.0, "club_speed_max": 77.0, "ball_speed_min": 95.0, "ball_speed_max": 105.0, "smash_min": 1.33, "smash_max": 1.38, "aoa_min": -2.5, "aoa_max": 0.5, "vla_min": 14.0, "vla_max": 17.5, "spin_min": 4000.0, "spin_max": 5100.0, "carry_min": 140.0, "carry_max": 158.0, "rollout_min": 10.0, "rollout_max": 15.0, "apex_min": 60.0, "apex_max": 74.0, "land_angle_min": 40.0, "land_angle_max": 45.0},
		"hybrid": {"name": "Hybrid", "club_speed_min": 68.0, "club_speed_max": 74.0, "ball_speed_min": 90.0, "ball_speed_max": 100.0, "smash_min": 1.32, "smash_max": 1.37, "aoa_min": -2.8, "aoa_max": 0.0, "vla_min": 14.5, "vla_max": 18.0, "spin_min": 4100.0, "spin_max": 5200.0, "carry_min": 132.0, "carry_max": 148.0, "rollout_min": 8.0, "rollout_max": 13.0, "apex_min": 58.0, "apex_max": 72.0, "land_angle_min": 41.0, "land_angle_max": 46.0},
		"4i": {"name": "4-Iron", "club_speed_min": 66.0, "club_speed_max": 72.0, "ball_speed_min": 86.0, "ball_speed_max": 95.0, "smash_min": 1.30, "smash_max": 1.35, "aoa_min": -2.5, "aoa_max": 0.0, "vla_min": 14.0, "vla_max": 17.0, "spin_min": 4000.0, "spin_max": 5000.0, "carry_min": 124.0, "carry_max": 138.0, "rollout_min": 8.0, "rollout_max": 14.0, "apex_min": 56.0, "apex_max": 70.0, "land_angle_min": 41.0, "land_angle_max": 45.0},
		"5i": {"name": "5-Iron", "club_speed_min": 64.0, "club_speed_max": 69.0, "ball_speed_min": 82.0, "ball_speed_max": 90.0, "smash_min": 1.29, "smash_max": 1.34, "aoa_min": -2.8, "aoa_max": -0.2, "vla_min": 15.0, "vla_max": 18.0, "spin_min": 4200.0, "spin_max": 5200.0, "carry_min": 116.0, "carry_max": 130.0, "rollout_min": 6.0, "rollout_max": 12.0, "apex_min": 56.0, "apex_max": 70.0, "land_angle_min": 42.0, "land_angle_max": 46.0},
		"6i": {"name": "6-Iron", "club_speed_min": 62.0, "club_speed_max": 67.0, "ball_speed_min": 78.0, "ball_speed_max": 86.0, "smash_min": 1.28, "smash_max": 1.33, "aoa_min": -3.0, "aoa_max": -0.5, "vla_min": 16.5, "vla_max": 19.5, "spin_min": 4500.0, "spin_max": 5600.0, "carry_min": 108.0, "carry_max": 121.0, "rollout_min": 5.0, "rollout_max": 9.0, "apex_min": 56.0, "apex_max": 70.0, "land_angle_min": 43.0, "land_angle_max": 47.0},
		"7i": {"name": "7-Iron", "club_speed_min": 59.0, "club_speed_max": 65.0, "ball_speed_min": 74.0, "ball_speed_max": 82.0, "smash_min": 1.26, "smash_max": 1.31, "aoa_min": -3.2, "aoa_max": -0.8, "vla_min": 18.5, "vla_max": 22.0, "spin_min": 4800.0, "spin_max": 5900.0, "carry_min": 98.0, "carry_max": 112.0, "rollout_min": 4.0, "rollout_max": 8.0, "apex_min": 56.0, "apex_max": 68.0, "land_angle_min": 44.0, "land_angle_max": 48.0},
		"8i": {"name": "8-Iron", "club_speed_min": 57.0, "club_speed_max": 62.0, "ball_speed_min": 70.0, "ball_speed_max": 77.0, "smash_min": 1.24, "smash_max": 1.29, "aoa_min": -3.5, "aoa_max": -1.0, "vla_min": 20.0, "vla_max": 23.5, "spin_min": 5200.0, "spin_max": 6300.0, "carry_min": 88.0, "carry_max": 101.0, "rollout_min": 3.0, "rollout_max": 6.0, "apex_min": 54.0, "apex_max": 66.0, "land_angle_min": 45.0, "land_angle_max": 49.0},
		"9i": {"name": "9-Iron", "club_speed_min": 54.0, "club_speed_max": 59.0, "ball_speed_min": 65.0, "ball_speed_max": 72.0, "smash_min": 1.21, "smash_max": 1.26, "aoa_min": -3.8, "aoa_max": -1.2, "vla_min": 22.0, "vla_max": 26.0, "spin_min": 5500.0, "spin_max": 6600.0, "carry_min": 78.0, "carry_max": 90.0, "rollout_min": 2.0, "rollout_max": 5.0, "apex_min": 54.0, "apex_max": 66.0, "land_angle_min": 46.0, "land_angle_max": 50.0},
		"pw": {"name": "Pitching Wedge", "club_speed_min": 52.0, "club_speed_max": 57.0, "ball_speed_min": 60.0, "ball_speed_max": 67.0, "smash_min": 1.16, "smash_max": 1.21, "aoa_min": -4.0, "aoa_max": -1.5, "vla_min": 25.0, "vla_max": 29.5, "spin_min": 5800.0, "spin_max": 7000.0, "carry_min": 68.0, "carry_max": 80.0, "rollout_min": 1.0, "rollout_max": 3.0, "apex_min": 52.0, "apex_max": 64.0, "land_angle_min": 47.0, "land_angle_max": 51.0},
		"gw": {"name": "Gap Wedge", "club_speed_min": 49.0, "club_speed_max": 54.0, "ball_speed_min": 55.0, "ball_speed_max": 61.0, "smash_min": 1.12, "smash_max": 1.17, "aoa_min": -4.2, "aoa_max": -1.8, "vla_min": 27.0, "vla_max": 32.0, "spin_min": 5900.0, "spin_max": 7100.0, "carry_min": 58.0, "carry_max": 70.0, "rollout_min": 1.0, "rollout_max": 3.0, "apex_min": 50.0, "apex_max": 62.0, "land_angle_min": 48.0, "land_angle_max": 52.0},
		"sw": {"name": "Sand Wedge", "club_speed_min": 46.0, "club_speed_max": 51.0, "ball_speed_min": 49.0, "ball_speed_max": 55.0, "smash_min": 1.08, "smash_max": 1.13, "aoa_min": -4.5, "aoa_max": -2.0, "vla_min": 30.0, "vla_max": 35.0, "spin_min": 6000.0, "spin_max": 7200.0, "carry_min": 48.0, "carry_max": 60.0, "rollout_min": 0.0, "rollout_max": 2.0, "apex_min": 48.0, "apex_max": 58.0, "land_angle_min": 49.0, "land_angle_max": 53.0},
		"lw": {"name": "Lob Wedge", "club_speed_min": 43.0, "club_speed_max": 48.0, "ball_speed_min": 43.0, "ball_speed_max": 49.0, "smash_min": 1.02, "smash_max": 1.07, "aoa_min": -4.5, "aoa_max": -2.0, "vla_min": 33.0, "vla_max": 39.0, "spin_min": 5600.0, "spin_max": 6800.0, "carry_min": 38.0, "carry_max": 48.0, "rollout_min": 0.0, "rollout_max": 2.0, "apex_min": 46.0, "apex_max": 56.0, "land_angle_min": 50.0, "land_angle_max": 54.0}
	}
}

static func _classify_club_discrete(club_name: String) -> String:
	var c = club_name.to_lower().strip_edges()
	if "putt" in c or c == "pt":
		return "putter"
	if c in ["dr", "1w", "driver"] or "driver" in c:
		return "driver"
	if c in ["3w", "3-wood", "3 wood"]:
		return "3w"
	if c in ["5w", "5-wood", "5 wood", "4w", "7w"] or "wood" in c or "fw" in c:
		return "5w"
	if c in ["2h", "3h", "4h", "5h", "hybrid", "rescue"] or "hybrid" in c:
		return "hybrid"
	if c in ["3i", "4i", "3-iron", "4-iron", "3 iron", "4 iron"]:
		return "4i"
	if c in ["5i", "5-iron", "5 iron"]:
		return "5i"
	if c in ["6i", "6-iron", "6 iron"]:
		return "6i"
	if c in ["7i", "7-iron", "7 iron"]:
		return "7i"
	if c in ["8i", "8-iron", "8 iron"]:
		return "8i"
	if c in ["9i", "9-iron", "9 iron"]:
		return "9i"
	if c in ["pw", "pitching", "pitching wedge"]:
		return "pw"
	if c in ["gw", "aw", "gap", "approach", "gap wedge", "approach wedge", "50", "52"]:
		return "gw"
	if c in ["sw", "sand", "sand wedge", "54", "56"]:
		return "sw"
	if c in ["lw", "lob", "lob wedge", "58", "60"]:
		return "lw"
	if "wedge" in c:
		return "pw"
	if "iron" in c:
		return "7i"
	return "driver"

static func normalize_skill_level(skill_level: String) -> String:
	var key := skill_level.strip_edges().to_lower()
	match key:
		"beginner", "high_handicap":
			return "high_handicap"
		"low_handicap", "scratch":
			return "scratch"
		"tour_pro", "pro":
			return "tour_pro"
		_:
			return "mid_handicap"

static func _get_spin_loft_bounds(club_key: String) -> Vector2:
	match club_key:
		"driver": return Vector2(10.0, 14.5)
		"3w": return Vector2(13.0, 17.5)
		"5w": return Vector2(16.0, 20.5)
		"hybrid": return Vector2(18.0, 22.5)
		"4i": return Vector2(20.0, 24.5)
		"5i": return Vector2(22.0, 26.5)
		"6i": return Vector2(24.0, 28.5)
		"7i": return Vector2(26.0, 30.5)
		"8i": return Vector2(28.0, 33.0)
		"9i": return Vector2(31.0, 36.0)
		"pw": return Vector2(34.0, 40.0)
		"gw": return Vector2(38.0, 44.0)
		"sw": return Vector2(42.0, 48.0)
		"lw": return Vector2(46.0, 52.0)
		_: return Vector2(24.0, 30.0)

static func _resolve_is_lefty(shot_data: Dictionary) -> bool:
	if shot_data.has("is_lefty"):
		return bool(shot_data["is_lefty"])
	if shot_data.has("is_left_handed"):
		return bool(shot_data["is_left_handed"])
	if shot_data.has("handedness"):
		return int(shot_data["handedness"]) == 1
	var p_name := str(shot_data.get("Player", shot_data.get("player", "")))
	if not p_name.is_empty():
		if Engine.has_singleton("MultiplayerManager"):
			var mp = Engine.get_singleton("MultiplayerManager")
			if mp != null and mp.has_method("get_player_handedness"):
				return int(mp.get_player_handedness(p_name)) == 1
		elif Engine.get_main_loop() != null and Engine.get_main_loop().root != null and Engine.get_main_loop().root.has_node("MultiplayerManager"):
			var mp_node = Engine.get_main_loop().root.get_node_or_null("MultiplayerManager")
			if mp_node != null and mp_node.has_method("get_player_handedness"):
				return int(mp_node.get_player_handedness(p_name)) == 1
	return false

static func get_benchmark(club_name: String, skill_level: String = "mid_handicap") -> Dictionary:
	var tier: String = normalize_skill_level(skill_level)
	var club_key: String = _classify_club_discrete(club_name)
	var tier_data: Dictionary = CLUB_BENCHMARKS.get(tier, CLUB_BENCHMARKS["mid_handicap"])
	if tier_data.has(club_key):
		return tier_data[club_key]
	return tier_data.get("driver", {})

static func _build_comparison_table(shot_data: Dictionary, benchmark: Dictionary, _skill_tier: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if benchmark.is_empty():
		return rows

	var club_name := str(shot_data.get("Club", shot_data.get("club", "Driver")))
	var club_key := _classify_club_discrete(club_name)
	var club_speed = _get_float_val(shot_data, ["ClubSpeed"], 0.0)
	var ball_speed = _get_float_val(shot_data, ["Speed", "BallSpeed"], 0.0)
	var smash_factor = _get_float_val(shot_data, ["SmashFactor"], 0.0)
	if smash_factor <= 0.5 and ball_speed > 0.0 and club_speed > 0.0:
		smash_factor = ball_speed / club_speed
	var vla = _get_float_val(shot_data, ["VLA", "VerticalLaunchAngle"], 14.0)
	var total_spin = _get_float_val(shot_data, ["TotalSpin", "BackSpin"], 0.0)
	var raw_aoa = _get_float_val(shot_data, ["AttackAngle", "AngleOfAttack"], 999.0)
	var attack_angle = raw_aoa if (raw_aoa < 900.0 and abs(raw_aoa) >= 0.1) else 999.0
	var dyn_loft = _get_float_val(shot_data, ["DynamicLoft", "dynamic_loft"], 999.0)
	var spin_axis = _get_float_val(shot_data, ["SpinAxis", "SideSpinAxis"], 0.0)
	var carry = _get_float_val(shot_data, ["Carry", "CarryDistance", "Distance"], 0.0)
	var apex = _get_float_val(shot_data, ["Apex", "PeakHeight", "MaxHeight"], 0.0)
	var land_angle = _get_float_val(shot_data, ["DescentAngle", "LandAngle", "LandingAngle"], 0.0)
	var has_fa = shot_data.has("FaceAngle") or shot_data.has("ClubFaceAngle") or shot_data.has("RawFaceAngle")
	var has_cp = shot_data.has("ClubPath") or shot_data.has("Path") or shot_data.has("RawClubPath")
	var face_angle = _get_float_val(shot_data, ["RawFaceAngle", "FaceAngle", "ClubFaceAngle"], 0.0)
	var club_path = _get_float_val(shot_data, ["RawClubPath", "ClubPath", "Path"], 0.0)
	var ftp = _get_float_val(shot_data, ["RawFaceToPath", "FaceToPath"], 999.0)
	if ftp > 900.0 and (has_fa or has_cp):
		ftp = face_angle - club_path

	# 1. Ball Speed
	if ball_speed > 0.0:
		var bs_min = float(benchmark.get("ball_speed_min", 125.0))
		var bs_max = float(benchmark.get("ball_speed_max", 140.0))
		var status = "OPTIMAL"
		if ball_speed < bs_min - 10.0:
			status = "CRITICAL"
		elif ball_speed < bs_min - 4.0:
			status = "SUB-OPTIMAL"
		elif ball_speed > bs_max + 12.0:
			status = "GOOD"
		rows.append({
			"metric": "Ball Speed",
			"player": "%.1f mph" % ball_speed,
			"target": "%.1f – %.1f mph" % [bs_min, bs_max],
			"status": status,
			"note": "Primary governor of total potential distance.",
			"player_num": ball_speed, "target_min": bs_min, "target_max": bs_max,
			"scale_min": maxf(30.0, bs_min - 25.0), "scale_max": bs_max + 25.0, "unit": "mph"
		})

	# 2. Smash Factor
	if smash_factor > 0.5:
		var sm_min = float(benchmark.get("smash_min", 1.40))
		var sm_max = float(benchmark.get("smash_max", 1.48))
		var status = "OPTIMAL"
		if smash_factor < sm_min - 0.07:
			status = "CRITICAL"
		elif smash_factor < sm_min:
			status = "SUB-OPTIMAL"
		elif smash_factor >= sm_min and smash_factor <= sm_max + 0.02:
			status = "OPTIMAL"
		else:
			status = "GOOD"
		rows.append({
			"metric": "Smash Factor",
			"player": "%.2f" % smash_factor,
			"target": "%.2f – %.2f" % [sm_min, sm_max],
			"status": status,
			"note": "Clubface energy transfer and centered sweet-spot compression.",
			"player_num": smash_factor, "target_min": sm_min, "target_max": sm_max,
			"scale_min": maxf(0.85, sm_min - 0.16), "scale_max": minf(1.56, sm_max + 0.05), "unit": ""
		})

	# 3. Dynamic Launch (VLA)
	var vla_min = float(benchmark.get("vla_min", 12.0))
	var vla_max = float(benchmark.get("vla_max", 16.0))
	var vla_status = "OPTIMAL"
	if vla < vla_min - 3.0 or vla > vla_max + 4.0:
		vla_status = "CRITICAL"
	elif vla < vla_min - 1.0 or vla > vla_max + 1.5:
		vla_status = "SUB-OPTIMAL"
	rows.append({
		"metric": "Launch Angle (VLA)",
		"player": "%.1f°" % vla,
		"target": "%.1f° – %.1f°" % [vla_min, vla_max],
		"status": vla_status,
		"note": "Initial vertical takeoff angle off clubface.",
		"player_num": vla, "target_min": vla_min, "target_max": vla_max,
		"scale_min": maxf(0.0, vla_min - 7.0), "scale_max": vla_max + 7.0, "unit": "°"
	})

	# 4. Total Spin
	if total_spin > 0.0:
		var sp_min = float(benchmark.get("spin_min", 2500.0))
		var sp_max = float(benchmark.get("spin_max", 3400.0))
		var sp_status = "OPTIMAL"
		if total_spin < sp_min - 800.0 or total_spin > sp_max + 1200.0:
			sp_status = "CRITICAL"
		elif total_spin < sp_min - 300.0 or total_spin > sp_max + 450.0:
			sp_status = "SUB-OPTIMAL"
		rows.append({
			"metric": "Total Spin",
			"player": "%.0f RPM" % total_spin,
			"target": "%.0f – %.0f RPM" % [sp_min, sp_max],
			"status": sp_status,
			"note": "Aerodynamic lift, wind stability, and green-stopping control.",
			"player_num": total_spin, "target_min": sp_min, "target_max": sp_max,
			"scale_min": maxf(500.0, sp_min - 1400.0), "scale_max": sp_max + 1600.0, "unit": "RPM"
		})

	# 5. Angle of Attack (AoA)
	if attack_angle < 900.0 and abs(attack_angle) >= 0.1:
		var aoa_min = float(benchmark.get("aoa_min", -2.5))
		var aoa_max = float(benchmark.get("aoa_max", 1.5))
		var aoa_status = "OPTIMAL"
		if attack_angle < aoa_min - 2.5 or attack_angle > aoa_max + 2.5:
			aoa_status = "CRITICAL"
		elif attack_angle < aoa_min - 1.0 or attack_angle > aoa_max + 1.0:
			aoa_status = "SUB-OPTIMAL"
		rows.append({
			"metric": "Attack Angle (AoA)",
			"player": "%+.1f°" % attack_angle,
			"target": "%+.1f° to %+.1f°" % [aoa_min, aoa_max],
			"status": aoa_status,
			"note": "Angle of clubhead path moving into the ball.",
			"player_num": attack_angle, "target_min": aoa_min, "target_max": aoa_max,
			"scale_min": aoa_min - 5.0, "scale_max": aoa_max + 5.0, "unit": "°"
		})

	# 5b. Spin Loft (Dynamic Loft - AoA)
	if float(dyn_loft) < 900.0 and float(attack_angle) < 900.0:
		var spin_loft: float = float(dyn_loft) - float(attack_angle)
		var sl_bounds: Vector2 = _get_spin_loft_bounds(club_key)
		var sl_status: String = "OPTIMAL"
		if spin_loft < sl_bounds.x - 3.5 or spin_loft > sl_bounds.y + 4.0:
			sl_status = "CRITICAL"
		elif spin_loft < sl_bounds.x - 1.0 or spin_loft > sl_bounds.y + 1.5:
			sl_status = "SUB-OPTIMAL"
		rows.append({
			"metric": "Spin Loft",
			"player": "%.1f°" % spin_loft,
			"target": "%.1f° – %.1f°" % [sl_bounds.x, sl_bounds.y],
			"status": sl_status,
			"note": "Dynamic Loft minus AoA; governs ball compression and spin generation.",
			"player_num": spin_loft, "target_min": sl_bounds.x, "target_max": sl_bounds.y,
			"scale_min": maxf(4.0, sl_bounds.x - 8.0), "scale_max": sl_bounds.y + 8.0, "unit": "°"
		})

	# 6. Spin Axis / Direction
	var axis_status = "OPTIMAL"
	if abs(spin_axis) > 8.0:
		axis_status = "CRITICAL"
	elif abs(spin_axis) > 3.5:
		axis_status = "SUB-OPTIMAL"
	elif abs(spin_axis) > 2.0:
		axis_status = "GOOD"
	rows.append({
		"metric": "Spin Axis",
		"player": "%+.1f°" % spin_axis,
		"target": "-2.5° to +2.5°",
		"status": axis_status,
		"note": "Tilt of spin vector governing draw or slice curve.",
		"player_num": spin_axis, "target_min": -2.5, "target_max": 2.5,
		"scale_min": -14.0, "scale_max": 14.0, "unit": "°"
	})

	# 6b. Face-to-Path (when directly measured)
	if ftp < 900.0:
		var ftp_status := "OPTIMAL"
		if abs(ftp) > 4.0:
			ftp_status = "CRITICAL"
		elif abs(ftp) > 2.5:
			ftp_status = "SUB-OPTIMAL"
		rows.append({
			"metric": "Face-to-Path",
			"player": "%+.1f°" % ftp,
			"target": "-2.0° to +2.0°",
			"status": ftp_status,
			"note": "Face orientation minus swing path; primary curvature driver.",
			"player_num": ftp, "target_min": -2.0, "target_max": 2.0,
			"scale_min": -8.0, "scale_max": 8.0, "unit": "°"
		})

	# 7. Carry Distance
	if carry > 0.0:
		var c_min = float(benchmark.get("carry_min", 150.0))
		var c_max = float(benchmark.get("carry_max", 175.0))
		var c_status = "OPTIMAL"
		if carry < c_min - 25.0:
			c_status = "CRITICAL"
		elif carry < c_min - 10.0:
			c_status = "SUB-OPTIMAL"
		elif carry >= c_min and carry <= c_max:
			c_status = "OPTIMAL"
		else:
			c_status = "GOOD"
		rows.append({
			"metric": "Carry Distance",
			"player": "%.0f yds" % carry,
			"target": "%.0f – %.0f yds" % [c_min, c_max],
			"status": c_status,
			"note": "Airborne distance traveled before ground contact.",
			"player_num": carry, "target_min": c_min, "target_max": c_max,
			"scale_min": maxf(20.0, c_min - 40.0), "scale_max": c_max + 40.0, "unit": "yds"
		})

	# 8. Apex Height (if available)
	if apex > 0.0:
		var ap_min = float(benchmark.get("apex_min", 70.0))
		var ap_max = float(benchmark.get("apex_max", 90.0))
		var ap_status = "OPTIMAL"
		if apex < ap_min - 20.0 or apex > ap_max + 25.0:
			ap_status = "SUB-OPTIMAL"
		rows.append({
			"metric": "Apex (Max Height)",
			"player": "%.0f ft" % apex,
			"target": "%.0f – %.0f ft" % [ap_min, ap_max],
			"status": ap_status,
			"note": "Peak trajectory altitude.",
			"player_num": apex, "target_min": ap_min, "target_max": ap_max,
			"scale_min": maxf(10.0, ap_min - 30.0), "scale_max": ap_max + 30.0, "unit": "ft"
		})

	# 9. Landing Angle (if available)
	if land_angle > 0.0:
		var la_min = float(benchmark.get("land_angle_min", 40.0))
		var la_max = float(benchmark.get("land_angle_max", 50.0))
		var la_status = "OPTIMAL"
		if land_angle < la_min - 5.0:
			la_status = "SUB-OPTIMAL"
		rows.append({
			"metric": "Landing Angle",
			"player": "%.1f°" % land_angle,
			"target": "%.1f° – %.1f°" % [la_min, la_max],
			"status": la_status,
			"note": "Descent pitch governing release and green holding.",
			"player_num": land_angle, "target_min": la_min, "target_max": la_max,
			"scale_min": maxf(20.0, la_min - 12.0), "scale_max": la_max + 10.0, "unit": "°"
		})

	return rows

static func _build_four_tier_diagnosis(rec: Dictionary, _shot_data: Dictionary, _benchmark: Dictionary) -> Dictionary:
	var player_val = str(rec.get("player_val", ""))
	var bench_val = str(rec.get("benchmark_val", ""))
	var cam_flaw = str(rec.get("camera_flaw", ""))
	var launch_eff = str(rec.get("launch_effect", ""))
	var fix_inst = str(rec.get("fix_instruction", ""))

	var observation = "Measured: %s\nTarget Baseline: %s" % [player_val, bench_val]
	if not cam_flaw.is_empty():
		observation += "\nSensor / Video Observation: " + cam_flaw

	var impact = launch_eff
	if impact.is_empty():
		impact = "Sub-optimal launch conditions reducing carry distance and directional accuracy."

	var cause = cam_flaw
	if cause.is_empty():
		cause = str(rec.get("issue_type", "Club delivery deviation during impact."))

	var prescription = fix_inst
	if prescription.is_empty():
		prescription = "Focus on centered contact, steady head posture, and smooth body sequencing through impact."

	return {
		"observation": observation,
		"impact": impact,
		"cause": cause,
		"prescription": prescription
	}

static func _attach_video_metadata(rec: Dictionary, video_key: String) -> void:
	if HM_VIDEOS.has(video_key):
		var v: Dictionary = HM_VIDEOS[video_key]
		rec["video_url"] = v["url"]
		rec["video_embed_url"] = v["embed"]
		rec["video_title"] = v["title"]
		rec["video_id"] = v["id"]
		rec["_video_key"] = video_key

static func _attach_drill_progression(rec: Dictionary, fallback_video_key: String = "") -> void:
	if rec.has("drill_stages") and typeof(rec["drill_stages"]) == TYPE_ARRAY and not (rec["drill_stages"] as Array).is_empty():
		return
	var issue: String = str(rec.get("issue_type", "")).to_lower()
	var vkey: String = str(rec.get("_video_key", fallback_video_key))

	var stages: Array[Dictionary] = []
	var proof: String = "Launch monitor shows primary target metric moving inside shaded benchmark band."
	var watch_out: String = "Avoid rushing tempo or over-steering on full speed; lock feel at 75% first."
	var grad: String = "Complete 8 of 10 practice shots inside target window before advancing."

	if "smash" in issue or "gear" in issue or "low-face" in issue or "early extension" in issue or vkey == "low_point":
		stages = [
			{"stage": 1, "name": "Slow-Motion Centered Strike", "constraint": "50% speed with foot-spray or two-tee gate around clubhead", "reps": "10 balls · target center face"},
			{"stage": 2, "name": "3/4 Tempo Maintenance", "constraint": "75% speed keeping trail glute back against chair reference", "reps": "10 balls · Smash within -0.03 of target"},
			{"stage": 3, "name": "Full Speed Variable Club", "constraint": "Alternate target clubs under full routine", "reps": "8/10 centered strikes"}
		]
		proof = "Smash Factor increases by +0.03 to +0.06 and face impact cluster tightens within ±6 mm."
		watch_out = "Hanging back to catch ball cleanly -> fat turf strikes or heel pulls."
		grad = "Hold Smash Factor above skill minimum for 8/10 consecutive shots."
	elif "slice" in issue or "fade" in issue or "over-the-top" in issue or vkey == "barrier_path":
		stages = [
			{"stage": 1, "name": "Inside Delivery Pump", "constraint": "60% speed avoiding outside barrier/headcover", "reps": "10 balls · Path neutral/in-to-out"},
			{"stage": 2, "name": "Motorcycle Lead-Wrist Flexion", "constraint": "75% speed bowing lead wrist from P5 to P6", "reps": "10 balls · Spin Axis < +4°"},
			{"stage": 3, "name": "Full-Swing Stock Shape", "constraint": "Target corridor ±15 yds at full speed", "reps": "8/10 balls on target fairway"}
		]
		proof = "Club Path neutralizes toward -1°..+3° and Face-to-Path drops under +2.0°."
		watch_out = "Swinging overly in-to-out with closed face -> block-hooks."
		grad = "Achieve 8/10 shots with Spin Axis under +4°."
	elif "hook" in issue or "draw" in issue or "tempo" in issue or "hips" in issue or "shoulder turn" in issue or vkey == "downswing_sequence":
		stages = [
			{"stage": 1, "name": "Split-Hand & Rhythm Gather", "constraint": "50% punch swings with pause at P4 top", "reps": "10 balls · 3:1 smooth transition"},
			{"stage": 2, "name": "Chest-Through Rotation", "constraint": "75% swings rotating lead hip & sternum together", "reps": "10 balls · Face-to-Path within ±2.0°"},
			{"stage": 3, "name": "Course Dispersion Check", "constraint": "Pick tight target window at full speed", "reps": "8/10 balls inside corridor"}
		]
		proof = "Face-to-Path stabilizes near -1.5° to +1.0° without snap-hook spin spikes."
		watch_out = "Spinning shoulders open too early -> pull-slices."
		grad = "Keep 8/10 shots within -5°..+2° Spin Axis with controlled curvature."
	elif "spin loft" in issue or "spin" in issue or "scoop" in issue or vkey == "shaft_lean":
		stages = [
			{"stage": 1, "name": "9-to-3 Impact Bag Compression", "constraint": "Half-swings gripping firm with hands ahead at impact", "reps": "10 reps · flat/flexed lead wrist"},
			{"stage": 2, "name": "Divot Ahead of Ball", "constraint": "Place alignment rod/towel 3 inches behind ball at 75% speed", "reps": "10 balls · downward AoA"},
			{"stage": 3, "name": "Full Iron Windowing", "constraint": "Match optimal spin loft and carry distance", "reps": "8/10 crisp strikes"}
		]
		proof = "Attack Angle shifts downward (irons) and Spin Loft enters club window."
		watch_out = "Leaning chest too far forward -> steep pulls or heavy digs."
		grad = "Produce 8/10 crisp compressions inside optimal Spin Loft band."
	elif "aoa" in issue or "steep" in issue or "launch" in issue or "descent" in issue or "sway" in issue or vkey == "one_metric_aoa":
		stages = [
			{"stage": 1, "name": "Ball Position & Spine Tilt Check", "constraint": "Verify setup ball position & slight trail shoulder lower", "reps": "10 static + pump rehearsals"},
			{"stage": 2, "name": "Launch Window Gate", "constraint": "Flight balls through target VLA window at 75% speed", "reps": "10 balls · VLA inside target band"},
			{"stage": 3, "name": "Full Trajectory Committal", "constraint": "Full speed sweep/brush matching optimal apex", "reps": "8/10 shots matching launch window"}
		]
		proof = "AoA stabilizes in optimal band and VLA/Descent Angle enter green-holding range."
		watch_out = "Tilting spine excessively backward -> fat turf contact behind ball."
		grad = "Hit 8/10 shots matching target AoA & VLA window."
	else:
		stages = [
			{"stage": 1, "name": "Alignment Rail Setup", "constraint": "Confirm toe line & clubface parallel to target stick", "reps": "10 balls · ±2° HLA"},
			{"stage": 2, "name": "Start-Line Gate", "constraint": "Launch through narrow simulator target corridor", "reps": "10 balls · clean start line"},
			{"stage": 3, "name": "Pressure Random Targets", "constraint": "Switch clubs & targets every ball", "reps": "8/10 within corridor"}
		]
		proof = "Horizontal Launch Angle stays within ±2.0° of intended start line."
		watch_out = "Locking wrists rigidly to steer ball -> lost clubhead speed."
		grad = "Hold 8/10 balls inside start-line gate before adding speed."

	rec["drill_stages"] = stages
	rec["monitor_proof"] = proof
	rec["watch_out_for"] = watch_out
	rec["graduation_target"] = grad

static func _estimate_distance_loss(shot_data: Dictionary, benchmark: Dictionary, smash: float, club_speed: float, total_spin: float, spin_axis: float, carry: float) -> Dictionary:
	var target_smash: float = float(benchmark.get("smash_min", 1.40))
	var smash_loss: float = 0.0
	if smash > 0.5 and smash < target_smash:
		var spd_ref: float = club_speed if club_speed > 10.0 else (carry * 0.42 if carry > 30.0 else 90.0)
		smash_loss = clamp((target_smash - smash) * spd_ref * 1.45, 0.0, 40.0)

	var spin_loss: float = 0.0
	var s_min: float = float(benchmark.get("spin_min", 2000.0))
	var s_max: float = float(benchmark.get("spin_max", 7000.0))
	if total_spin > 200.0:
		if total_spin > s_max + 200.0:
			spin_loss = clamp((total_spin - s_max) / 140.0, 0.0, 22.0)
		elif total_spin < s_min - 200.0 and carry > 100.0:
			spin_loss = clamp((s_min - total_spin) / 220.0, 0.0, 14.0)

	var curve_loss: float = clamp((abs(spin_axis) - 4.0) * 0.75, 0.0, 20.0) if abs(spin_axis) > 4.0 else 0.0
	var total_loss: float = smash_loss + spin_loss + curve_loss
	return {
		"smash_loss_yards": snappedf(smash_loss, 0.1),
		"spin_loss_yards": snappedf(spin_loss, 0.1),
		"curve_loss_yards": snappedf(curve_loss, 0.1),
		"total_lost_yards": snappedf(total_loss, 0.1),
		"summary": ("~%.0f yds recoverable (Contact: %.0f · Spin: %.0f · Curve: %.0f)" % [total_loss, smash_loss, spin_loss, curve_loss]) if total_loss >= 3.0 else "Minimal distance leakage (<3 yds)"
	}

# =============================================================================
# 1. LAUNCH MONITOR BALLISTIC ANALYSIS (PHASE 1 - INSTANT DIAGNOSTICS)
# =============================================================================

## Analyzes launch monitor data immediately while wireframe computes in background.
## Evaluates Smash Factor, Face-to-Path, Gear Effect, Spin Loft, AoA, Spin Rate, Descent Angle, Launch Window, and Club Path.
static func analyze_launch_monitor(shot_data: Dictionary) -> Array[Dictionary]:
	var recs: Array[Dictionary] = []
	if shot_data.is_empty():
		return recs

	var club_name: String = str(shot_data.get("Club", shot_data.get("club", "Driver")))
	var club_cat: String = _classify_club(club_name)
	var is_tee: bool = bool(shot_data.get("is_tee", shot_data.get("lie_type", "") == "teebox"))
	if not shot_data.has("is_tee") and not shot_data.has("lie_type"):
		is_tee = (club_cat == "driver")
	var lie_type: String = str(shot_data.get("lie_type", "teebox" if is_tee else "fairway")).to_lower()
	var club_disp: String = get_club_display_name(club_name)
	var lie_disp: String = "Tee Shot" if is_tee else ("Fairway" if lie_type == "fairway" else lie_type.capitalize())

	# Ball & Club flight metrics
	var ball_speed: float = _get_float_val(shot_data, ["Speed", "BallSpeed"], 0.0)
	var club_speed: float = _get_float_val(shot_data, ["ClubSpeed"], 0.0)
	var smash_factor: float = _get_float_val(shot_data, ["SmashFactor"], 0.0)
	var vla: float = _get_float_val(shot_data, ["VLA", "VerticalLaunchAngle"], 14.0)
	var hla: float = _get_float_val(shot_data, ["HLA", "HorizontalLaunchAngle"], 0.0)
	var total_spin: float = _get_float_val(shot_data, ["TotalSpin", "BackSpin"], 0.0)
	var back_spin: float = _get_float_val(shot_data, ["BackSpin"], 0.0)
	var side_spin: float = _get_float_val(shot_data, ["SideSpin"], 0.0)
	var spin_axis: float = _get_float_val(shot_data, ["SpinAxis", "SideSpinAxis"], 0.0)
	var offline: float = _get_float_val(shot_data, ["Offline", "OfflineDistance", "Side", "SideDistance"], 0.0)
	var dynamic_loft: float = _get_float_val(shot_data, ["DynamicLoft", "DynamicLoftAngle"], 999.0)
	var descent_angle: float = _get_float_val(shot_data, ["DescentAngle", "LandingAngle", "LandAngle"], 999.0)
	var hi: float = _get_float_val(shot_data, ["ImpactHorizontal", "HorizontalImpact", "ImpactX", "FaceImpactHorizontal", "hi"], 999.0)
	var vi: float = _get_float_val(shot_data, ["ImpactVertical", "VerticalImpact", "ImpactY", "FaceImpactVertical", "vi"], 999.0)

	# Derive spin axis from side spin if needed
	if not shot_data.has("SpinAxis") and (abs(side_spin) > 0.0 or abs(back_spin) > 0.0):
		if back_spin > 0.0:
			spin_axis = rad_to_deg(atan2(side_spin, back_spin))
		else:
			spin_axis = clamp(side_spin / 95.0, -25.0, 25.0)

	var raw_aoa: float = _get_float_val(shot_data, ["AttackAngle", "AngleOfAttack"], 999.0)
	var attack_angle: float = raw_aoa if (raw_aoa < 900.0 and abs(raw_aoa) >= 0.1) else 999.0 # 999 indicates not directly provided or dummy
	var spin_loft: float = (dynamic_loft - attack_angle) if (dynamic_loft < 900.0 and attack_angle < 900.0) else 999.0
	var club_path: float = _get_float_val(shot_data, ["ClubPath", "Path"], 0.0)
	var face_angle: float = _get_float_val(shot_data, ["FaceAngle", "ClubFaceAngle"], 0.0)
	var face_to_path: float = _get_float_val(shot_data, ["FaceToPath"], 999.0)
	if face_to_path > 900.0 and (shot_data.has("FaceAngle") or shot_data.has("ClubPath")):
		face_to_path = face_angle - club_path
	elif face_to_path > 900.0:
		# Estimate face to path from spin axis (every degree of face-to-path produces ~2.2° spin axis)
		face_to_path = spin_axis / 2.2

	var carry: float = _get_float_val(shot_data, ["Carry", "CarryDistance", "Distance", "TotalDistance"], 0.0)

	# Estimate smash factor if missing but speeds available
	if smash_factor <= 0.5 and ball_speed > 0.0 and club_speed > 0.0:
		smash_factor = ball_speed / club_speed

	# Player skill tier & handedness retrieval
	var player_name: String = str(shot_data.get("Player", shot_data.get("player", "")))
	var skill_level: String = "mid_handicap"
	if shot_data.has("skill_level") and str(shot_data["skill_level"]) != "":
		skill_level = str(shot_data["skill_level"])
	elif Engine.has_singleton("MultiplayerManager"):
		var mp_mgr = Engine.get_singleton("MultiplayerManager")
		if mp_mgr != null and mp_mgr.has_method("get_player_skill_level"):
			skill_level = mp_mgr.get_player_skill_level(player_name)
	elif Engine.get_main_loop() != null and Engine.get_main_loop().root != null and Engine.get_main_loop().root.has_node("MultiplayerManager"):
		var mp_node = Engine.get_main_loop().root.get_node_or_null("MultiplayerManager")
		if mp_node != null and mp_node.has_method("get_player_skill_level"):
			skill_level = mp_node.get_player_skill_level(player_name)
	skill_level = normalize_skill_level(skill_level)
	var is_lefty: bool = _resolve_is_lefty(shot_data)
	var is_functional_stock: bool = abs(face_to_path) <= 2.8 and abs(spin_axis) <= 9.0 and abs(offline) <= 6.5 and ((hla * spin_axis) < -0.5)

	var skill_disp: String = SKILL_LEVEL_NAMES.get(skill_level, "Mid Handicap (10–19 HCP)")
	var benchmark: Dictionary = get_benchmark(club_name, skill_level)

	# ─── 1. SMASH FACTOR & IMPACT EFFICIENCY (TOP PRIORITY FOR DISTANCE & CONSISTENCY) ───
	if smash_factor > 0.5:
		var target_smash_min: float = float(benchmark.get("smash_min", 1.41))
		var target_smash_max: float = float(benchmark.get("smash_max", 1.46))
		var bench_desc: String = "%.2f–%.2f (%s)" % [target_smash_min, target_smash_max, skill_disp]
		var crit_thresh: float = target_smash_min - 0.06

		var fix_inst = "Focus on centered face contact before swinging faster. Smooth out your transition to find the middle of the clubface."
		var drill_inst = "⛳ Impact Tape / Dry Erase Drill: Spray clubface with dry-shampoo or impact decal; confirm strike is centered on sweet spot."
		if club_cat in ["wood", "hybrid"]:
			fix_inst = "Focus on centered face contact with a smooth sweeping delivery through the turf rather than swinging harder."
			drill_inst = "⛳ Sweet Spot Impact Spray: Spray clubface to confirm ball contact is centered without catching the ground early."
		elif club_cat in ["mid_iron", "long_iron", "wedge"]:
			fix_inst = "Focus on centered face contact and compressing the ball before taking turf."
			drill_inst = "⛳ Strike Decal Drill: Spray clubface to ensure impact is centered in grooves 3 through 6."

		if smash_factor < crit_thresh:
			var yards_lost: int = int((target_smash_min - smash_factor) * (club_speed if club_speed > 0 else 95.0) * 1.5)
			yards_lost = clamp(yards_lost, 12, 35)
			var r = {
				"priority": 1,
				"score": 96,
				"severity": "CRITICAL",
				"category": "STRIKE EFFICIENCY & SMASH",
				"issue_type": "Low Smash Factor",
				"title": "Low %s Smash Factor (%.2f vs %s)" % [club_disp, smash_factor, bench_desc],
				"camera_flaw": "Off-center strike contact detected on %s." % club_disp,
				"launch_effect": "Off-center impact (toe/heel/low) leaking approx %d yards of potential carry." % yards_lost,
				"player_val": "Smash Factor: %.2f | Ball Speed: %.1f mph" % [smash_factor, ball_speed],
				"benchmark_val": "Target: %s" % bench_desc,
				"fix_instruction": "Focus on centered face contact before swinging faster. Smooth out your transition and stabilize the lead wrist through impact.",
				"drill": "⛳ HackMotion Impact Spray & Low Point Drill: Spray clubface with dry-shampoo or impact decal. Rehearse centered contact and ensure lead wrist remains stable through impact rather than scooping early."
			}
			_attach_video_metadata(r, "low_point")
			recs.append(r)
		elif smash_factor < target_smash_min:
			var r = {
				"priority": 2,
				"score": 82,
				"severity": "HIGH",
				"category": "STRIKE EFFICIENCY & SMASH",
				"issue_type": "Sub-Optimal Smash Factor",
				"title": "Sub-Optimal %s Efficiency (%.2f Smash)" % [club_disp, smash_factor],
				"camera_flaw": "Slightly off-center strike contact reducing energy transfer.",
				"launch_effect": "Transfer ratio below optimal %s; ball speed could increase by 4-8 mph with centered contact." % bench_desc,
				"player_val": "Smash Factor: %.2f" % smash_factor,
				"benchmark_val": "Target: %s" % bench_desc,
				"fix_instruction": "Maintain steady head position through the strike and check ball position relative to stance.",
				"drill": "⛳ Gate & Low Point Drill: Place two markers just wider than clubhead; swing cleanly through the gate to groove centered compression."
			}
			_attach_video_metadata(r, "low_point")
			recs.append(r)

	# ─── 2. FACE-TO-PATH, GEAR EFFECT & SPIN AXIS (PRIMARY ACCURACY & CURVATURE GOVERNOR) ───
	var slice_sign: float = -1.0 if is_lefty else 1.0
	var directed_axis: float = spin_axis * slice_sign
	var directed_ftp: float = face_to_path * slice_sign
	var slice_side: String = "left" if is_lefty else "right"
	var hook_side: String = "right" if is_lefty else "left"

	var is_toe_gear_hook: bool = (club_cat in ["driver", "wood", "hybrid"]) and (hi < 900.0 and hi >= 10.0) and directed_axis < -4.0 and abs(face_to_path) <= 2.5
	var is_heel_gear_slice: bool = (club_cat in ["driver", "wood", "hybrid"]) and (hi < 900.0 and hi <= -10.0) and directed_axis > 4.0 and abs(face_to_path) <= 2.5
	var is_low_face_spin: bool = (club_cat == "driver") and (vi < 900.0 and vi <= -8.0) and total_spin > 3000.0

	var is_severe_slice: bool = (not is_heel_gear_slice) and (directed_axis > 8.0 or directed_ftp > 3.5)
	var is_mild_slice: bool = (not is_heel_gear_slice) and (not is_functional_stock) and (directed_axis > 4.0 or directed_ftp > 2.0)
	var is_severe_hook: bool = (not is_toe_gear_hook) and (directed_axis < -8.0 or directed_ftp < -3.5)
	var is_mild_hook: bool = (not is_toe_gear_hook) and (not is_functional_stock) and (directed_axis < -4.0 or directed_ftp < -2.0)

	if is_toe_gear_hook:
		var r = {
			"priority": 1,
			"score": 89,
			"severity": "HIGH",
			"category": "IMPACT & GEAR EFFECT",
			"issue_type": "Toe Gear-Effect Hook",
			"title": "Toe Gear-Effect Draw/Hook (+%.0f mm Toe Strike)" % hi,
			"camera_flaw": "Face-to-Path (%+.1f°) was near neutral, but impact on the toe triggered bulge-and-roll gear effect." % face_to_path,
			"launch_effect": "Toe contact drops ball speed and imparts hook spin toward the %s." % hook_side,
			"player_val": "Face Impact: +%.0f mm Toe | FTP: %+.1f° | Axis: %+.1f°" % [hi, face_to_path, spin_axis],
			"benchmark_val": "Target: Strike within ±6 mm of center | ±2.0° FTP",
			"fix_instruction": "Stand half an inch closer at address or check posture so the club returns to the middle of the face rather than swinging out to the toe.",
			"drill": "⛳ Two-Tee Face Centering Gate: Set tees just outside toe and heel at 50% speed; groove center impact before swinging at full speed."
		}
		_attach_video_metadata(r, "low_point")
		recs.append(r)
	elif is_heel_gear_slice:
		var r = {
			"priority": 1,
			"score": 90,
			"severity": "HIGH",
			"category": "IMPACT & GEAR EFFECT",
			"issue_type": "Heel Gear-Effect Slice",
			"title": "Heel Gear-Effect Fade/Slice (%.0f mm Heel Strike)" % hi,
			"camera_flaw": "Face-to-Path (%+.1f°) was near neutral, but heel impact caused horizontal gear-effect slice spin." % face_to_path,
			"launch_effect": "Heel contact reduces Smash Factor and imparts slice spin curving %s." % slice_side,
			"player_val": "Face Impact: %.0f mm Heel | FTP: %+.1f° | Axis: %+.1f°" % [hi, face_to_path, spin_axis],
			"benchmark_val": "Target: Strike within ±6 mm of center | ±2.0° FTP",
			"fix_instruction": "Give arms slightly more room at address and maintain hip depth instead of lunging the pelvis toward the ball.",
			"drill": "⛳ Outside-Ball Clearance Gate: Place a soft headcover 1 inch outside the toe to keep contact centered instead of drifting to the heel."
		}
		_attach_video_metadata(r, "low_point")
		recs.append(r)

	if is_low_face_spin:
		var r = {
			"priority": 1,
			"score": 88,
			"severity": "HIGH",
			"category": "STRIKE LOCATION & SPIN",
			"issue_type": "Low-Face Driver Spin Spike",
			"title": "Low-Face Driver Strike Spiking Spin (%.0f RPM)" % total_spin,
			"camera_flaw": "Impact registered %.0f mm below horizontal sweet spot, triggering vertical gear-effect backspin." % abs(vi),
			"launch_effect": "Vertical gear effect spikes spin and costs both ball speed and fairway rollout.",
			"player_val": "Vertical Strike: %.0f mm Low | Spin: %.0f RPM" % [vi, total_spin],
			"benchmark_val": "Target: Center-to-Slightly-High Face | 2,000–2,600 RPM",
			"fix_instruction": "Tee half the ball above the driver crown and sweep gently upward (+2° to +4° AoA).",
			"drill": "⛳ High-Tee Upward Sweep Drill: Hit 10 drivers at 75% speed off a slightly higher tee focusing on brushing above center."
		}
		_attach_video_metadata(r, "one_metric_aoa")
		recs.append(r)

	if is_severe_slice:
		var has_retrieved_path: bool = (shot_data.has("ClubPath") or shot_data.has("Path") or shot_data.has("RawClubPath")) and str(shot_data.get("ClubPath", shot_data.get("Path", shot_data.get("RawClubPath", "")))) != "---" and str(shot_data.get("ClubPath", shot_data.get("Path", shot_data.get("RawClubPath", "")))) != "N/A"
		var path_str = ("%.1f° Out-to-In" % abs(club_path)) if (club_path * slice_sign) < 0 else ("%.1f° In-to-Out" % abs(club_path))
		var pv_str = "Spin Axis: %+.1f° | Face-to-Path: %+.1f°" % [spin_axis, face_to_path]
		if has_retrieved_path:
			pv_str += " | Path: %s" % path_str
		var r = {
			"priority": 1,
			"score": 94 + int(abs(spin_axis) * 0.4),
			"severity": "CRITICAL",
			"category": "CLUB FACE & SWING PATH",
			"issue_type": "Slice / Open Face-to-Path",
			"title": "Open Face Relative to Path (%+.1f° Spin Axis Slice)" % spin_axis,
			"camera_flaw": "Clubface delivered open relative to swing path at impact.",
			"launch_effect": "Face-to-Path of %+.1f° creates heavy slice sidespin, curving ball offline %s." % [face_to_path, slice_side],
			"player_val": pv_str,
			"benchmark_val": "Target: -2.0° to +2.0° Face-to-Path | ±3.0° Axis",
			"fix_instruction": "Strengthen lead hand grip slightly. At transition, shallow the club onto an inside delivery path and train lead wrist flexion (flatter wrist) into impact.",
			"drill": "⛳ HackMotion Barrier Drill: Place a second ball or headcover 5 inches outside the ball to block the over-the-top path; pair with the Motorcycle Drill to flex lead wrist and square the face."
		}
		_attach_video_metadata(r, "barrier_path")
		recs.append(r)
	elif is_mild_slice:
		var r = {
			"priority": 2,
			"score": 78,
			"severity": "HIGH",
			"category": "CLUB FACE & SWING PATH",
			"issue_type": "Fade / Open Face",
			"title": "Slightly Open Face-to-Path (%+.1f° Axis Fade)" % spin_axis,
			"camera_flaw": "Face open relative to swing path producing mild fade spin.",
			"launch_effect": "Gentle curve to the %s (%+.1f° spin axis); monitor face angle at impact." % [slice_side, spin_axis],
			"player_val": "Spin Axis: %+.1f° | Face-to-Path: %+.1f°" % [spin_axis, face_to_path],
			"benchmark_val": "Target: ±2.0° Face-to-Path",
			"fix_instruction": "Ensure clubface is square at address and maintain quiet, stable wrists through transition to keep face-to-path neutral.",
			"drill": "⛳ HackMotion Alignment Gate & Barrier Drill: Practice launching ball along target line between alignment rods while keeping swing path within ±2° neutral."
		}
		_attach_video_metadata(r, "barrier_path")
		recs.append(r)
	elif is_severe_hook:
		var r = {
			"priority": 1,
			"score": 92 + int(abs(spin_axis) * 0.4),
			"severity": "CRITICAL",
			"category": "CLUB FACE & SWING PATH",
			"issue_type": "Hook / Closed Face-to-Path",
			"title": "Closed Face Relative to Path (%.1f° Spin Axis Hook)" % spin_axis,
			"camera_flaw": "Clubface closed relative to path, causing rapid curvature %s." % hook_side,
			"launch_effect": "Face-to-Path of %+.1f° produces heavy hook sidespin taking ball %s." % [face_to_path, hook_side],
			"player_val": "Spin Axis: %.1f° | Face-to-Path: %+.1f°" % [spin_axis, face_to_path],
			"benchmark_val": "Target: -2.0° to +2.0° Face-to-Path | ±3.0° Axis",
			"fix_instruction": "Check that grip is not excessively strong. Rotate chest and torso through impact in sequence rather than rolling forearms and flipping hands early.",
			"drill": "⛳ HackMotion Transition & Split-Hand Drill: Use the Transition Drill to train lower-to-upper body sequencing; hold grip with a 3-inch gap to rotate chest through without flipping wrists."
		}
		_attach_video_metadata(r, "downswing_sequence")
		recs.append(r)
	elif is_mild_hook:
		var r = {
			"priority": 3,
			"score": 74,
			"severity": "MEDIUM",
			"category": "CLUB FACE & SWING PATH",
			"issue_type": "Draw / Closed Face",
			"title": "Moderate Draw Curvature (%.1f° Spin Axis)" % spin_axis,
			"camera_flaw": "Face delivered slightly closed relative to path.",
			"launch_effect": "Ball curves %s of intended flight line." % hook_side,
			"player_val": "Spin Axis: %.1f° | Face-to-Path: %+.1f°" % [spin_axis, face_to_path],
			"benchmark_val": "Target: ±2.0° Face-to-Path",
			"fix_instruction": "Keep trail wrist extended slightly longer through impact zone and rotate the torso through to the finish.",
			"drill": "⛳ HackMotion Downswing Sequence Drill: Synchronize upper body rotation with hips through impact to prevent over-rotating the clubface closed."
		}
		_attach_video_metadata(r, "downswing_sequence")
		recs.append(r)

	# ─── 3. ANGLE OF ATTACK (AOA) OPTIMIZATION ───
	if attack_angle < 900.0:
		if club_cat == "driver":
			if is_tee:
				if attack_angle < -1.5:
					var spin_penalty = int(abs(attack_angle - 2.5) * 260)
					var yds_gain = int(abs(attack_angle - 2.5) * 4.5)
					yds_gain = clamp(yds_gain, 12, 28)
					var r = {
						"priority": 2,
						"score": 88,
						"severity": "HIGH",
						"category": "LAUNCH CONDITIONS & AOA",
						"issue_type": "Steep Driver Attack Angle",
						"title": "Negative Driver Attack Angle (%.1f° Downward on Tee)" % attack_angle,
						"camera_flaw": "Hitting down on driver steepens spin and robs carry distance.",
						"launch_effect": "Adds ~%d RPM excessive spin; hitting UP (+1° to +5°) unlocks +%d yds carry." % [spin_penalty, yds_gain],
						"player_val": "AoA: %.1f° | Total Spin: %.0f RPM" % [attack_angle, total_spin],
						"benchmark_val": "Driver Tee Target: +1.0° to +5.0° (Upward)",
						"fix_instruction": "Tee ball forward off inside of lead heel. Tilt spine 6°–10° away from target at address to sweep upward on the teed ball.",
						"drill": "⛳ HackMotion Low Point & Box Drill: Place an empty golf ball box 12 inches in front of tee; sweep upward through the ball without clipping the box to move low point behind ball."
					}
					_attach_video_metadata(r, "one_metric_aoa")
					recs.append(r)
			else:
				# Driver off the deck / turf
				if attack_angle < -3.5:
					var r = {
						"priority": 2,
						"score": 85,
						"severity": "HIGH",
						"category": "LAUNCH CONDITIONS & AOA",
						"issue_type": "Steep Driver Off Turf",
						"title": "Steep Driver Strike Off Turf (%.1f° AoA)" % attack_angle,
						"camera_flaw": "Steep angle of attack digging into turf with driver.",
						"launch_effect": "Off-the-deck driver requires a level sweep; chopping down causes severe distance loss.",
						"player_val": "AoA: %.1f°" % attack_angle,
						"benchmark_val": "Turf Driver Target: -1.0° to +1.0° (Level)",
						"fix_instruction": "Sweep the ball cleanly off the grass with a level shoulder rotation. Do not hit down steeply.",
						"drill": "⛳ HackMotion Level Sweep Drill: Practice clipping the grass blades smoothly with a wide arc without gouging turf."
					}
					_attach_video_metadata(r, "one_metric_aoa")
					recs.append(r)
		elif club_cat == "wood":
			if is_tee:
				# Wood off tee
				if attack_angle < -2.5:
					var r = {
						"priority": 2,
						"score": 84,
						"severity": "HIGH",
						"category": "LAUNCH CONDITIONS & AOA",
						"issue_type": "Steep Wood Tee Shot",
						"title": "Steep Attack Angle on Teed %s (%.1f° Downward)" % [club_disp, attack_angle],
						"camera_flaw": "Chopping down into teed fairway wood.",
						"launch_effect": "Spins up excessively and loses penetration into the wind.",
						"player_val": "AoA: %.1f°" % attack_angle,
						"benchmark_val": "Teed Wood Target: -1.0° to +1.5° (Sweeping)",
						"fix_instruction": "Peg the ball low (only 1/4 of ball above crown). Sweep cleanly through impact with a shallow path.",
						"drill": "⛳ HackMotion Low Peg Sweeper: Push tee into ground until ball is barely floating above grass; sweep through impact with a shallow arc."
					}
					_attach_video_metadata(r, "one_metric_aoa")
					recs.append(r)
			else:
				# Wood off turf / fairway / rough (NO TEE!)
				if attack_angle > 0.8:
					var r = {
						"priority": 2,
						"score": 88,
						"severity": "HIGH",
						"category": "LAUNCH CONDITIONS & AOA",
						"issue_type": "Scooping Wood Off Turf",
						"title": "Scooping %s Off Turf (+%.1f° Upward AoA)" % [club_disp, attack_angle],
						"camera_flaw": "Torso hung back trying to lift the fairway wood off the turf into the air.",
						"launch_effect": "Hitting up on a fairway wood off the turf causes thin, topped, or chunked contact.",
						"player_val": "AoA: %+.1f° (Upward) | VLA: %.1f°" % [attack_angle, vla],
						"benchmark_val": "Optimal Turf Wood: -1.0° to -3.0° (Shallow Brush)",
						"fix_instruction": "Do not try to lift or hit up on the ball. Trust the club's built-in loft! Position ball 1-2 balls inside lead heel and sweep the turf with a wide, level bottom arc.",
						"drill": "⛳ HackMotion Forward Lean & Sweeping Coin Drill: Place a coin 2 inches ahead of ball; maintain slight forward shaft lean and brush coin forward along grass."
					}
					_attach_video_metadata(r, "shaft_lean")
					recs.append(r)
				elif attack_angle < -4.5:
					var r = {
						"priority": 2,
						"score": 85,
						"severity": "HIGH",
						"category": "LAUNCH CONDITIONS & AOA",
						"issue_type": "Steep Wood Off Turf",
						"title": "Steep Strike on %s (%.1f° Downward AoA)" % [club_disp, attack_angle],
						"camera_flaw": "Downswing plane too steep into turf for a fairway wood.",
						"launch_effect": "Digs into the turf, producing excessive spin ballooning and lost rollout.",
						"player_val": "AoA: %.1f° (Steep) | Total Spin: %.0f RPM" % [attack_angle, total_spin],
						"benchmark_val": "Optimal Turf Wood: -1.0° to -3.0° (Shallow Brush)",
						"fix_instruction": "Shallow out your transition. Keep shoulders level and feel the clubhead gliding through the turf rather than chopping into it.",
						"drill": "⛳ HackMotion Low Point Turf Brush: Rehearse wide practice swings skimming the grass blades without disturbing the soil, shifting low point forward."
					}
					_attach_video_metadata(r, "one_metric_aoa")
					recs.append(r)
		elif club_cat == "hybrid":
			if not is_tee and attack_angle > 0.5:
				var r = {
					"priority": 2,
					"score": 85,
					"severity": "HIGH",
					"category": "LAUNCH CONDITIONS & AOA",
					"issue_type": "Scooping Hybrid Off Turf",
					"title": "Scooping Hybrid (+%.1f° Upward AoA)" % attack_angle,
					"camera_flaw": "Trying to lift hybrid off turf instead of hitting down with forward compression.",
					"launch_effect": "Thin contact and loss of compression.",
					"player_val": "AoA: %+.1f°" % attack_angle,
					"benchmark_val": "Hybrid Target: -2.0° to -4.0° (Descending Strike)",
					"fix_instruction": "Treat the hybrid like a 5-iron: maintain forward shaft lean and lead wrist flexion to compress the ball before brushing turf.",
					"drill": "⛳ HackMotion Forward Shaft Lean Drill: Lay a towel 3 inches behind ball; strike ball with hands leading clubhead without touching towel."
				}
				_attach_video_metadata(r, "shaft_lean")
				recs.append(r)
			elif attack_angle < -5.5:
				var r = {
					"priority": 2,
					"score": 82,
					"severity": "HIGH",
					"category": "LAUNCH CONDITIONS & AOA",
					"issue_type": "Steep Hybrid Strike",
					"title": "Steep Hybrid Strike (%.1f° AoA)" % attack_angle,
					"camera_flaw": "Steep downswing angle causing fat contact.",
					"launch_effect": "Excess spin and lost distance.",
					"player_val": "AoA: %.1f°" % attack_angle,
					"benchmark_val": "Hybrid Target: -2.0° to -4.0°",
					"fix_instruction": "Widen your swing arc and shift weight smoothly onto lead side through impact.",
					"drill": "⛳ HackMotion Shallow Sweep Drill: Make rhythm swings focusing on shallow turf interaction and proper low point distance 2-4 inches ahead of ball."
				}
				_attach_video_metadata(r, "one_metric_aoa")
				recs.append(r)
		elif club_cat in ["mid_iron", "long_iron", "wedge"]:
			if attack_angle > 0.5:
				var c_type = "Iron" if club_cat != "wedge" else "Wedge"
				var targ_range = "-3.0° to -5.0°" if club_cat != "wedge" else "-4.0° to -6.5°"
				var r = {
					"priority": 2,
					"score": 85,
					"severity": "HIGH",
					"category": "LAUNCH CONDITIONS & AOA",
					"issue_type": "Scooping / Upward %s AoA" % c_type,
					"title": "Positive Attack Angle on %s (+%.1f° Scooping)" % [c_type, attack_angle],
					"camera_flaw": "Hitting up on iron/wedge leads to thin contact and lost compression.",
					"launch_effect": "Causes thin strikes, inconsistent turf interaction, and insufficient green-stopping spin.",
					"player_val": "AoA: %+.1f° | Launch Angle: %.1f°" % [attack_angle, vla],
					"benchmark_val": "Optimal %s AoA: %s (Downward)" % [c_type, targ_range],
					"fix_instruction": "Position ball center of stance, transfer 60% weight to lead foot at impact, and maintain forward shaft lean to compress the ball.",
					"drill": "⛳ HackMotion Shaft Lean & Towel Drill: Lay a small towel 3 inches behind ball; strike ball crisply with forward shaft lean and flat lead wrist."
				}
				_attach_video_metadata(r, "shaft_lean")
				recs.append(r)

	# ─── 4. SPIN RATE HARMONY (BALLOONING VS KNUCKLEBALL) ───
	if total_spin > 0.0:
		if club_cat == "driver":
			if total_spin > 3000.0:
				var drill_desc = "⛳ HackMotion High Tee & Face Centering Drill: Tee ball up half a ball higher to encourage contact on upper equator of face, optimizing dynamic loft." if is_tee else "⛳ HackMotion Centered Strike Drill: Spray clubface to confirm contact is centered, avoiding low-face strikes."
				var fix_desc = "Strike higher on clubface (above center creates gear effect reducing spin). Ensure driver attack angle is positive." if is_tee else "Sweep cleanly off turf and ensure centered impact to avoid low-face spin multiplication."
				var r = {
					"priority": 3,
					"score": 77,
					"severity": "MEDIUM",
					"category": "SPIN DYNAMICS",
					"issue_type": "Excessive Driver Spin",
					"title": "Excessive Driver Spin (%.0f RPM Ballooning)" % total_spin,
					"camera_flaw": "High spin rate produces steep climb and eliminates fairway rollout.",
					"launch_effect": "Ball balloons into wind, losing 15-25 yards of total distance.",
					"player_val": "Spin: %.0f RPM (Optimal: 2,000–2,600 RPM)" % total_spin,
					"benchmark_val": "Driver Target: 2,000–2,600 RPM",
					"fix_instruction": fix_desc,
					"drill": drill_desc
				}
				_attach_video_metadata(r, "shaft_lean")
				recs.append(r)
			elif total_spin < 1700.0 and ball_speed > 110.0:
				var drill_desc = "⛳ HackMotion Centered Strike Drill: Verify ball rests at center equator on driver face at address; verify ball contact is centered to prevent knuckleball diving." if is_tee else "⛳ Centered Face Strike: Verify ball strikes middle groove on clubface."
				var fix_desc = "Check launch angle and strike height. Slightly lower tee height if hitting too high on face." if is_tee else "Check launch angle and strike height. Avoid hitting high on the crown."
				var r = {
					"priority": 3,
					"score": 70,
					"severity": "MEDIUM",
					"category": "SPIN DYNAMICS",
					"issue_type": "Insufficient Driver Spin",
					"title": "Low Driver Spin Rate (%.0f RPM Knuckleball)" % total_spin,
					"camera_flaw": "Insufficient backspin to maintain aerodynamic lift.",
					"launch_effect": "Ball drops out of sky early, reducing airborne carry.",
					"player_val": "Spin: %.0f RPM" % total_spin,
					"benchmark_val": "Target: 2,000–2,600 RPM",
					"fix_instruction": fix_desc,
					"drill": drill_desc
				}
				_attach_video_metadata(r, "shaft_lean")
				recs.append(r)
		elif club_cat == "wood":
			var wood_min_spin = 2600.0 if is_tee else 3000.0
			var wood_max_spin = 3800.0 if is_tee else 4400.0
			var wood_bench = "2,800–3,600 RPM (Tee Shot)" if is_tee else "3,200–4,200 RPM (Off Turf)"
			if total_spin > wood_max_spin + 400.0:
				var r = {
					"priority": 3,
					"score": 76,
					"severity": "MEDIUM",
					"category": "SPIN DYNAMICS",
					"issue_type": "Excessive Wood Spin",
					"title": "Excessive %s Spin (%.0f RPM Ballooning)" % [club_disp, total_spin],
					"camera_flaw": "Chopping attack angle or low-face contact imparting excessive backspin.",
					"launch_effect": "Shot balloons into the wind and stops dead with zero rollout.",
					"player_val": "Spin: %.0f RPM (%s)" % [total_spin, wood_bench],
					"benchmark_val": "Target: %s" % wood_bench,
					"fix_instruction": "Shallow out your downswing. Level sweeping contact with flat lead wrist creates penetrating ball flight with optimal roll.",
					"drill": "⛳ HackMotion Wide Arc & Shaft Lean Drill: Rehearse level sweeping strikes with controlled shaft lean to eliminate high ballooning spin."
				}
				_attach_video_metadata(r, "shaft_lean")
				recs.append(r)
			elif total_spin < wood_min_spin - 600.0 and ball_speed > 90.0:
				var r = {
					"priority": 3,
					"score": 70,
					"severity": "MEDIUM",
					"category": "SPIN DYNAMICS",
					"issue_type": "Low Wood Spin",
					"title": "Low %s Spin (%.0f RPM Knuckleball)" % [club_disp, total_spin],
					"camera_flaw": "Ball struck too high on crown or severe delofting.",
					"launch_effect": "Ball lacks enough backspin lift and falls prematurely out of the air.",
					"player_val": "Spin: %.0f RPM" % total_spin,
					"benchmark_val": "Target: %s" % wood_bench,
					"fix_instruction": "Catch ball centered on the sweet spot. Avoid forward-pressing shaft excessively at address.",
					"drill": "⛳ HackMotion Face Decal Drill: Verify strike location is centered on sweet spot; avoid excessive forward shaft press at address."
				}
				_attach_video_metadata(r, "shaft_lean")
				recs.append(r)
		elif club_cat == "hybrid":
			if total_spin > 5200.0:
				var r = {
					"priority": 3,
					"score": 74,
					"severity": "MEDIUM",
					"category": "SPIN DYNAMICS",
					"issue_type": "High Hybrid Spin",
					"title": "Excessive Hybrid Spin (%.0f RPM Ballooning)" % total_spin,
					"camera_flaw": "Glancing strike or steep descending blow.",
					"launch_effect": "Shot climbs steeply and loses penetrating carry.",
					"player_val": "Spin: %.0f RPM" % total_spin,
					"benchmark_val": "Target: 3,800–4,800 RPM",
					"fix_instruction": "Smooth out transition to shallow approach path and maintain stable lead wrist through impact.",
					"drill": "⛳ HackMotion Sweeping Mat Drill: Swing with smooth tempo, brushing mat with controlled dynamic loft without digging."
				}
				_attach_video_metadata(r, "shaft_lean")
				recs.append(r)
		elif club_cat in ["mid_iron", "long_iron"]:
			var iron_min_spin: float = float(benchmark.get("spin_min", 4200.0 if club_cat == "long_iron" else 5500.0))
			var iron_max_spin: float = float(benchmark.get("spin_max", 5600.0 if club_cat == "long_iron" else 7200.0))
			if total_spin < (iron_min_spin - 900.0) and total_spin > 900.0:
				var r = {
					"priority": 3,
					"score": 76,
					"severity": "MEDIUM",
					"category": "SPIN DYNAMICS",
					"issue_type": "Low Iron Spin",
					"title": "Low %s Spin (%.0f RPM Won't Hold Green)" % [club_disp, total_spin],
					"camera_flaw": "Insufficient backspin to hold approach shots on firmer greens.",
					"launch_effect": "Ball lands flat and releases off green instead of checking near pitch mark.",
					"player_val": "Spin: %.0f RPM (Target: %.0f–%.0f RPM)" % [total_spin, iron_min_spin, iron_max_spin],
					"benchmark_val": "Target: %.0f–%.0f RPM" % [iron_min_spin, iron_max_spin],
					"fix_instruction": "Hit down cleanly on a dry groove with centered contact rather than sweeping thin or delofting excessively.",
					"drill": "⛳ HackMotion Shaft Lean & Compression Bag Drill: Practice hitting into impact bag with hands leading clubhead cleanly."
				}
				_attach_video_metadata(r, "shaft_lean")
				recs.append(r)
			elif total_spin > (iron_max_spin + 1100.0):
				var r = {
					"priority": 3,
					"score": 72,
					"severity": "MEDIUM",
					"category": "SPIN DYNAMICS",
					"issue_type": "High Iron Spin / Glancing",
					"title": "Excessive %s Spin (%.0f RPM Ballooning)" % [club_disp, total_spin],
					"camera_flaw": "Overly open face or steep chop imparting excess backspin and lost carry.",
					"launch_effect": "Iron shot balloons into wind and finishes 10–15 yards short.",
					"player_val": "Spin: %.0f RPM (Target: %.0f–%.0f RPM)" % [total_spin, iron_min_spin, iron_max_spin],
					"benchmark_val": "Target: %.0f–%.0f RPM" % [iron_min_spin, iron_max_spin],
					"fix_instruction": "Deliver slightly more forward shaft lean and shallow the transition to lower spin loft.",
					"drill": "⛳ 9-to-3 Pitch Punch Compression Drill: Hit controlled 75% swings keeping handle slightly ahead of clubhead."
				}
				_attach_video_metadata(r, "shaft_lean")
				recs.append(r)
		elif club_cat == "wedge":
			var w_min_spin: float = float(benchmark.get("spin_min", 7200.0))
			var w_max_spin: float = float(benchmark.get("spin_max", 9800.0))
			if total_spin < (w_min_spin - 1500.0) and total_spin > 900.0:
				var r = {
					"priority": 3,
					"score": 75,
					"severity": "MEDIUM",
					"category": "SPIN DYNAMICS",
					"issue_type": "Low Wedge Spin",
					"title": "Low %s Spin (%.0f RPM Reduced Bite)" % [club_disp, total_spin],
					"camera_flaw": "High-face thin strike or scooped contact reduced groove friction.",
					"launch_effect": "Wedge releases farther than intended instead of checking on greens.",
					"player_val": "Spin: %.0f RPM (Target: %.0f–%.0f RPM)" % [total_spin, w_min_spin, w_max_spin],
					"benchmark_val": "Target: %.0f–%.0f RPM" % [w_min_spin, w_max_spin],
					"fix_instruction": "Accelerate chest through impact and strike grooves 2–4 cleanly with shallow descending turf brush.",
					"drill": "⛳ Low-Flight Spinner Wedge Drill: Hit 40–60 yd wedges focusing on clean ball-first nip with rotating torso."
				}
				_attach_video_metadata(r, "shaft_lean")
				recs.append(r)

	# ─── 5. LAUNCH ANGLE WINDOW (VLA) ───
	if club_cat == "driver":
		if vla < 9.5 and vla > 3.0:
			var drill_desc = "⛳ HackMotion High Launch Gate: Imagine launching ball over a 15-foot crossbar 30 yards ahead with positive attack angle and proper dynamic loft." if is_tee else "⛳ Sweeping Arc: Rehearse level sweeping strikes without delofting."
			var fix_desc = "Tee ball slightly higher and ensure head stays behind ball through impact." if is_tee else "Check ball position inside lead heel and ensure chest is not leaning forward ahead of ball."
			var r = {
				"priority": 4,
				"score": 69,
				"severity": "MEDIUM",
				"category": "LAUNCH WINDOW",
				"issue_type": "Low Driver Launch",
				"title": "Low Driver Launch Angle (%.1f° vs 11°–14.5° Optimal)" % vla,
				"camera_flaw": "Takeoff trajectory too low to optimize carry flight.",
				"launch_effect": "Limits apex height and carry distance; ball lands prematurely.",
				"player_val": "VLA: %.1f°" % vla,
				"benchmark_val": "Target: 11.0°–14.5°",
				"fix_instruction": fix_desc,
				"drill": drill_desc
			}
			_attach_video_metadata(r, "one_metric_aoa")
			recs.append(r)
		elif vla > 16.5:
			var drill_desc = "⛳ HackMotion Level Peg & Wrist Control Drill: Lower tee height until half the ball is above crown; prevent scooping or hanging back on trail foot." if is_tee else "⛳ Stay Centered: Prevent scooping or hanging back on trail foot."
			var fix_desc = "Check for steep attack angle or ball teed excessively high." if is_tee else "Avoid scooping wrists before impact; keep lead wrist flat through strike."
			var r = {
				"priority": 4,
				"score": 67,
				"severity": "MEDIUM",
				"category": "LAUNCH WINDOW",
				"issue_type": "High Driver Launch / Pop-up",
				"title": "High Driver Launch Trajectory (%.1f° VLA Pop-up)" % vla,
				"camera_flaw": "Excessive vertical launch angle creating steep ballooning apex.",
				"launch_effect": "Loss of forward penetration; susceptible to wind shear.",
				"player_val": "VLA: %.1f°" % vla,
				"benchmark_val": "Target: 11.0°–14.5°",
				"fix_instruction": fix_desc,
				"drill": drill_desc
			}
			_attach_video_metadata(r, "shaft_lean")
			recs.append(r)
	elif club_cat == "wood":
		var min_vla = 9.5 if is_tee else 8.5
		var max_vla = 16.0 if is_tee else 15.0
		var bench_vla = "11.0°–15.0° (Teed Wood)" if is_tee else "10.0°–14.0° (Off Turf)"
		if vla < min_vla and vla > 2.0:
			var r = {
				"priority": 4,
				"score": 71,
				"severity": "MEDIUM",
				"category": "LAUNCH WINDOW",
				"issue_type": "Low Wood Launch",
				"title": "Low Trajectory on %s (%.1f° VLA)" % [club_disp, vla],
				"camera_flaw": "Trajectory too flat off the %s to achieve maximum carry." % ("tee" if is_tee else "turf"),
				"launch_effect": "Ball trajectory cuts off early, costing 15–30 yards of airborne carry.",
				"player_val": "VLA: %.1f° (Optimal: %s)" % [vla, bench_vla],
				"benchmark_val": "Target: %s" % bench_vla,
				"fix_instruction": "Position ball 1-2 balls inside lead heel. Let the natural loft launch the ball—do not lean shaft excessively forward.",
				"drill": "⛳ HackMotion Shallow Sweep Drill: Position ball 1-2 balls inside lead heel and sweep grass smoothly without delofting."
			}
			_attach_video_metadata(r, "one_metric_aoa")
			recs.append(r)
		elif vla > max_vla + 2.0:
			var r = {
				"priority": 4,
				"score": 68,
				"severity": "MEDIUM",
				"category": "LAUNCH WINDOW",
				"issue_type": "High Wood Launch / Scoop",
				"title": "High Ballooning Launch on %s (%.1f° VLA)" % [club_disp, vla],
				"camera_flaw": "Flipping wrists or scooping up on the ball at impact.",
				"launch_effect": "Steep launch angle catches wind and drops straight down with no rollout.",
				"player_val": "VLA: %.1f°" % vla,
				"benchmark_val": "Target: %s" % bench_vla,
				"fix_instruction": "Maintain firm lead wrist through impact. Rotate body through to lead side rather than flipping hands.",
				"drill": "⛳ HackMotion Flat Wrist Punch Drill: Practice short punch shots keeping lead wrist flat and pointing at target to eliminate scooping."
			}
			_attach_video_metadata(r, "shaft_lean")
			recs.append(r)
	elif club_cat in ["long_iron", "mid_iron", "wedge"]:
		var b_vla_min: float = float(benchmark.get("vla_min", 14.0))
		var b_vla_max: float = float(benchmark.get("vla_max", 22.0))
		if vla > 2.0 and vla < (b_vla_min - 3.5):
			var r = {
				"priority": 4,
				"score": 71,
				"severity": "MEDIUM",
				"category": "LAUNCH WINDOW",
				"issue_type": "Low Iron / Wedge Launch",
				"title": "Low Launch Trajectory on %s (%.1f° VLA)" % [club_disp, vla],
				"camera_flaw": "Ball launched lower than optimal approach window.",
				"launch_effect": "Produces flatter descent and excessive rollout on approach shots.",
				"player_val": "VLA: %.1f°" % vla,
				"benchmark_val": "Target: %.1f°–%.1f°" % [b_vla_min, b_vla_max],
				"fix_instruction": "Avoid overly hooding the face or dragging hands too far ahead of a thin strike.",
				"drill": "⛳ Trajectory Gate Drill: Launch shots cleanly over an intermediate target height to restore optimal apex."
			}
			_attach_video_metadata(r, "one_metric_aoa")
			recs.append(r)
		elif vla > (b_vla_max + 4.5):
			var r = {
				"priority": 4,
				"score": 70,
				"severity": "MEDIUM",
				"category": "LAUNCH WINDOW",
				"issue_type": "High Iron / Wedge Scoop",
				"title": "High Scooped Launch on %s (%.1f° VLA)" % [club_disp, vla],
				"camera_flaw": "Excessive dynamic loft added at impact by flipping wrists.",
				"launch_effect": "High weak flight loses distance into any headwind.",
				"player_val": "VLA: %.1f°" % vla,
				"benchmark_val": "Target: %.1f°–%.1f°" % [b_vla_min, b_vla_max],
				"fix_instruction": "Keep pressure forward and hands ahead of clubhead through impact.",
				"drill": "⛳ Shaft Lean Compression Drill: Hit 9-to-3 punches keeping trail palm facing target."
			}
			_attach_video_metadata(r, "shaft_lean")
			recs.append(r)

	# ─── 5B. SPIN LOFT & DESCENT ANGLE (GREEN-HOLDING & COMPRESSION) ───
	if spin_loft < 900.0 and club_cat in ["long_iron", "mid_iron", "wedge", "hybrid"]:
		var sl_bounds: Vector2 = _get_spin_loft_bounds(_classify_club_discrete(club_name))
		if spin_loft > sl_bounds.y + 3.5:
			var r = {
				"priority": 2,
				"score": 81,
				"severity": "HIGH",
				"category": "COMPRESSION & SHAFT LEAN",
				"issue_type": "High Spin Loft / Flipping",
				"title": "High Spin Loft on %s (%.1f° Glancing Blow)" % [club_disp, spin_loft],
				"camera_flaw": "Large gap between dynamic loft (%.1f°) and AoA (%.1f°) indicates flipping/adding loft." % [dynamic_loft, attack_angle],
				"launch_effect": "Energy deflects upward instead of forward, sacrificing 8–18 yds and wind stability.",
				"player_val": "Spin Loft: %.1f°" % spin_loft,
				"benchmark_val": "Target: %.1f°–%.1f° Spin Loft" % [sl_bounds.x, sl_bounds.y],
				"fix_instruction": "Preserve lead wrist flexion and rotate chest through impact rather than casting the clubhead.",
				"drill": "⛳ 9-to-3 Impact Bag & Pump Drill: Stop at P6 with hands forward, then turn torso cleanly through ball."
			}
			_attach_video_metadata(r, "shaft_lean")
			recs.append(r)

	if descent_angle < 900.0 and descent_angle > 5.0 and descent_angle < 38.0 and club_cat in ["long_iron", "mid_iron", "wedge", "hybrid"]:
		var r = {
			"priority": 3,
			"score": 77,
			"severity": "MEDIUM",
			"category": "TRAJECTORY & STOPPING POWER",
			"issue_type": "Low Descent Angle / Won't Hold Green",
			"title": "Shallow Landing Angle on %s (%.1f°)" % [club_disp, descent_angle],
			"camera_flaw": "Ball descends under 38°, limiting greenside stopping power.",
			"launch_effect": "Approach shots tend to bounce and release through greens.",
			"player_val": "Descent Angle: %.1f°" % descent_angle,
			"benchmark_val": "Green-Holding Target: 43.0°–52.0°",
			"fix_instruction": "Optimize speed and launch window with centered groove contact rather than delofted thin bullets.",
			"drill": "⛳ Trajectory Window Ladder Drill: Launch mid-irons cleanly through a higher initial window."
		}
		_attach_video_metadata(r, "one_metric_aoa")
		recs.append(r)

	# ─── 6. SWING PATH & HORIZONTAL LAUNCH DIRECTION (HLA) ───
	if abs(hla) > 3.2 and not is_functional_stock:
		var is_push: bool = (hla < 0.0) if is_lefty else (hla > 0.0)
		var hla_side: String = ("Left" if hla < 0.0 else "Right")
		var dir_str = ("Push " + hla_side) if is_push else ("Pull " + hla_side)
		var r = {
			"priority": 4,
			"score": 65,
			"severity": "MEDIUM",
			"category": "AIM & ALIGNMENT",
			"issue_type": "Launch Direction Deviation",
			"title": "Horizontal Launch Off-Line (%s %+.1f°)" % [dir_str, hla],
			"camera_flaw": "Clubface oriented away from target line at moment of impact.",
			"launch_effect": "Initial takeoff starts %.1f° off center before spin takes effect." % abs(hla),
			"player_val": "HLA: %+.1f° (%s)" % [hla, dir_str],
			"benchmark_val": "Target: -1.5° to +1.5° HLA",
			"fix_instruction": "Verify stance and clubface alignment with target before beginning takeaway.",
			"drill": "⛳ HackMotion Direction Game: Use simulator centerline as visual barrier; hit 10 consecutive shots keeping ball on target side."
		}
		_attach_video_metadata(r, "sim_improvement")
		recs.append(r)

	# If no major flaws, acknowledge solid execution (or Functional Stock Flight)
	if recs.is_empty():
		var is_stock_note: bool = is_functional_stock and abs(spin_axis) > 1.5
		var r = {
			"priority": 1,
			"score": 30,
			"severity": "LOW",
			"category": "BALL FLIGHT MAINTENANCE",
			"issue_type": "Pure Ball Strike",
			"title": ("Functional Stock Curve to Target!" if is_stock_note else "Pro-Grade Ball Launch & Face Control!"),
			"camera_flaw": ("Playable stock curve (HLA %+.1f°, Spin Axis %+.1f°) finished near target." % [hla, spin_axis]) if is_stock_note else "Clean contact and square club delivery.",
			"launch_effect": "Solid smash (%.2f), clean spin axis (%+.1f°), and carry (%.0f yds)." % [smash_factor, spin_axis, carry],
			"player_val": "Smash: %.2f | Spin Axis: %+.1f°" % [smash_factor, spin_axis],
			"benchmark_val": "Pro Benchmark: Matched",
			"fix_instruction": "Commit to your predictable stock shape—avoid chasing dead-zero spin when the ball finishes on target." if is_stock_note else "Maintain consistent tempo, rhythm, and pre-shot visualization.",
			"drill": "⛳ HackMotion Full-Bag Audit & Distance Game: Hit 10 shots with target carry distance scoring 1 point per yard off target; practice consistent routine."
		}
		_attach_video_metadata(r, "sim_improvement")
		recs.append(r)

	recs.sort_custom(func(a, b): return a["score"] > b["score"])
	for idx in range(recs.size()):
		recs[idx]["priority"] = idx + 1

	var comp_table: Array[Dictionary] = _build_comparison_table(shot_data, benchmark, skill_level)
	var loss_breakdown: Dictionary = _estimate_distance_loss(shot_data, benchmark, smash_factor, club_speed, total_spin, spin_axis, carry)
	for r in recs:
		r["skill_level"] = skill_level
		r["skill_level_display"] = skill_disp
		r["comparison_table"] = comp_table
		r["four_tier_diagnosis"] = _build_four_tier_diagnosis(r, shot_data, benchmark)
		r["distance_loss_breakdown"] = loss_breakdown
		_attach_drill_progression(r)

	return recs


# =============================================================================
# 2. SKELETON WIREFRAME SEQUENCE BIOMECHANICS (PHASE 2)
# =============================================================================

## Detects key swing phase frames (Address, Top of Backswing P4, Impact P7)
## from a sequence of recorded frames using biomechanical wrist trajectory analysis.
static func detect_key_phases(recorded_frames: Array) -> Dictionary:
	var def_res: Dictionary = {
		"has_phases": false,
		"top_index": 0,
		"impact_index": 0,
		"orig_top_index": 0,
		"orig_impact_index": 0,
		"top_progress": 0.35,
		"impact_progress": 0.65,
		"valid_frames": []
	}
	if recorded_frames.size() < 4:
		return def_res

	# Extract valid landmark frames and their original indices
	var valid_frames: Array[Dictionary] = []
	var valid_indices: Array[int] = []
	for i in range(recorded_frames.size()):
		var f = recorded_frames[i]
		if not (f is Dictionary):
			continue
		var lms: Dictionary = f.get("landmarks", {})
		if lms.has("left_shoulder") and lms.has("right_shoulder") and lms.has("left_hip") and lms.has("right_hip"):
			valid_frames.append(f)
			valid_indices.append(i)

	if valid_frames.size() < 4:
		return def_res

	var total_f: int = valid_frames.size()
	var addr_count: int = min(4, total_f / 4)

	# Calculate baseline wrist Y from address frames (screen Y: larger = lower, smaller = higher)
	var base_wrist_y: float = 0.0
	var base_wrist_count: int = 0
	for i in range(addr_count):
		var lm = valid_frames[i]["landmarks"]
		var wy: float = -1.0
		if lm.has("left_wrist") and lm.has("right_wrist"):
			wy = (float(lm["left_wrist"].get("y", 0.0)) + float(lm["right_wrist"].get("y", 0.0))) * 0.5
		elif lm.has("left_wrist"):
			wy = float(lm["left_wrist"].get("y", 0.0))
		elif lm.has("right_wrist"):
			wy = float(lm["right_wrist"].get("y", 0.0))
		if wy >= 0.0:
			base_wrist_y += wy
			base_wrist_count += 1
	if base_wrist_count > 0:
		base_wrist_y /= float(base_wrist_count)
	else:
		base_wrist_y = 0.70

	# Extract wrist height signal across all valid frames
	var raw_wrist_y: Array[float] = []
	for i in range(total_f):
		var lm = valid_frames[i]["landmarks"]
		var wy: float = 999.0
		if lm.has("left_wrist"):
			wy = float(lm["left_wrist"].get("y", 999.0))
		if lm.has("right_wrist"):
			wy = min(wy, float(lm["right_wrist"].get("y", 999.0)))
		if wy > 900.0:
			wy = raw_wrist_y[i - 1] if i > 0 else base_wrist_y
		raw_wrist_y.append(wy)

	# 3-frame moving average to smooth MediaPipe jitter
	var smooth_wrist_y: Array[float] = []
	for i in range(total_f):
		var sum_y: float = raw_wrist_y[i]
		var count_y: int = 1
		if i > 0:
			sum_y += raw_wrist_y[i - 1]
			count_y += 1
		if i + 1 < total_f:
			sum_y += raw_wrist_y[i + 1]
			count_y += 1
		smooth_wrist_y.append(sum_y / float(count_y))

	# ─── 1. DETECT TOP OF BACKSWING (P4) ───
	# Apex of backswing: hands reach highest point (lowest screen Y) before reversing downward.
	var top_idx: int = -1
	var best_top_val: float = 999.0
	var p4_search_start: int = max(1, addr_count)
	var p4_search_end: int = clamp(int(total_f * 0.70), p4_search_start + 1, total_f - 2)

	# Pass 1: Local minimum with directional reversal (hands rising before, falling after)
	# and hands significantly above address
	for i in range(p4_search_start, p4_search_end + 1):
		var wy = smooth_wrist_y[i]
		var rising_before = (smooth_wrist_y[i - 1] >= wy)
		var falling_after = (i + 1 < total_f and smooth_wrist_y[i + 1] >= wy)
		if i >= 2 and i + 2 < total_f:
			rising_before = rising_before and (smooth_wrist_y[i - 2] >= smooth_wrist_y[i - 1])
			falling_after = falling_after and (smooth_wrist_y[i + 2] >= smooth_wrist_y[i + 1])
		var hands_raised = (base_wrist_y - wy) > 0.08
		if rising_before and falling_after and hands_raised:
			if wy < best_top_val:
				best_top_val = wy
				top_idx = i

	# Pass 2: Global minimum wrist Y in search window where hands are raised above address
	if top_idx < 1:
		for i in range(p4_search_start, p4_search_end + 1):
			var wy = smooth_wrist_y[i]
			if wy < best_top_val and (base_wrist_y - wy) > 0.05:
				best_top_val = wy
				top_idx = i

	# Pass 3: Fallback
	if top_idx < 1:
		top_idx = clamp(int(total_f * 0.38), 1, total_f - 2)

	# ─── 2. DETECT IMPACT (P7) ───
	# Following top_idx, hands descend (screen Y increases) towards ball/address level,
	# reaching the bottom of the swing arc at ball strike, before rising into follow-through.
	var impact_idx: int = -1
	var max_downswing_wrist_y: float = -1.0
	var min_dist_to_base: float = 999.0
	var impact_search_end: int = clamp(int(total_f * 0.85), top_idx + 1, total_f - 1)

	# Pass 1: Local maximum of wrist Y (lowest hands / bottom of swing arc) on downswing
	# where hands were descending before and begin rising after
	for i in range(top_idx + 1, impact_search_end):
		var wy = smooth_wrist_y[i]
		if wy > smooth_wrist_y[top_idx] + 0.08:
			var descending_before = (smooth_wrist_y[i - 1] <= wy)
			var rising_after = (i + 1 < total_f and smooth_wrist_y[i + 1] <= wy)
			if descending_before and rising_after:
				if wy > max_downswing_wrist_y:
					max_downswing_wrist_y = wy
					impact_idx = i

	# Pass 2: Return to address baseline height on downswing
	if impact_idx < 0:
		for i in range(top_idx + 1, impact_search_end + 1):
			var wy = smooth_wrist_y[i]
			var dist = abs(wy - base_wrist_y)
			if dist < min_dist_to_base:
				min_dist_to_base = dist
				impact_idx = i

	# Pass 3: Maximum wrist Y on downswing
	if impact_idx < 0:
		for i in range(top_idx + 1, impact_search_end + 1):
			var wy = smooth_wrist_y[i]
			if wy > max_downswing_wrist_y:
				max_downswing_wrist_y = wy
				impact_idx = i

	# Pass 4: Fallback
	if impact_idx < 0:
		impact_idx = clamp(int(total_f * 0.60), top_idx + 1, total_f - 1)

	var orig_top = valid_indices[top_idx] if top_idx < valid_indices.size() else top_idx
	var orig_imp = valid_indices[impact_idx] if impact_idx < valid_indices.size() else impact_idx
	var total_orig = max(1, recorded_frames.size() - 1)

	return {
		"has_phases": true,
		"top_index": top_idx,
		"impact_index": impact_idx,
		"orig_top_index": orig_top,
		"orig_impact_index": orig_imp,
		"top_progress": float(orig_top) / float(total_orig),
		"impact_progress": float(orig_imp) / float(total_orig),
		"valid_frames": valid_frames
	}


## Analyzes the full frame sequence of landmarks to detect:
## - Address (P1): Shoulder tilt, shoulder & hip squareness/alignment
## - Top of Backswing (P4): Shoulder rotation, hip rotation, X-Factor coil, lateral sway, reverse spine tilt
## - Downswing Transition: Kinematic sequencing (hips clearing vs shoulder cast)
## - Impact (P7): Spine angle retention (early extension), hip clearance angle, shoulder alignment, lead arm structure
## Returns a detailed biomechanical dictionary.
static func analyze_skeleton_sequence(recorded_frames: Array[Dictionary], fallback_telemetry: Dictionary = {}, is_lefty: bool = false) -> Dictionary:
	var result: Dictionary = {
		"has_valid_data": false,
		"is_lefty": is_lefty,
		"camera_view": "face_on",
		"frame_count": 0,
		"swing_tempo_ratio": 0.0,
		"head_vertical_drift": 0.0,
		"address_shoulder_tilt": 0.0,
		"address_shoulder_hip_alignment": 0.0, # degrees open/closed at setup
		"top_shoulder_turn": 0.0,
		"top_hip_turn": 0.0,
		"top_x_factor": 0.0,
		"top_hip_sway": 0.0,
		"top_reverse_spine_tilt": 0.0,
		"transition_shoulder_cast": false,
		"impact_spine_loss": 0.0,
		"impact_early_extension": 0.0,
		"impact_hip_clearance": 0.0, # degrees hips are open at impact
		"impact_chicken_wing": false,
		"lead_elbow_angle": 180.0,
		"top_frame_index": 0,
		"impact_frame_index": 0,
		"top_frame_progress": 0.35,
		"impact_frame_progress": 0.65,
		"flaws_detected": []
	}

	if recorded_frames.is_empty():
		if fallback_telemetry.get("has_valid_telemetry", false):
			result["has_valid_data"] = true
			result["top_shoulder_turn"] = fallback_telemetry.get("shoulder_turn", 0.0)
			result["impact_early_extension"] = fallback_telemetry.get("early_extension", 0.0)
			result["top_hip_sway"] = fallback_telemetry.get("hip_sway", 0.0)
			var m_spine = fallback_telemetry.get("spine_angle", 35.0)
			result["impact_spine_loss"] = max(0.0, 35.0 - m_spine)
		return result

	var phases = detect_key_phases(recorded_frames)
	if not phases.get("has_phases", false):
		return result

	var valid_frames: Array[Dictionary] = phases["valid_frames"]
	var top_idx: int = phases["top_index"]
	var impact_idx: int = phases["impact_index"]

	result["has_valid_data"] = true
	result["top_frame_index"] = phases["orig_top_index"]
	result["impact_frame_index"] = phases["orig_impact_index"]
	result["top_frame_progress"] = phases["top_progress"]
	result["impact_frame_progress"] = phases["impact_progress"]
	var total_f = valid_frames.size()
	result["frame_count"] = total_f

	# ─── 1. ADDRESS PHASE (P1) ───
	var addr_count: int = min(4, max(1, total_f / 4))
	var base_ls := Vector2.ZERO
	var base_rs := Vector2.ZERO
	var base_lh := Vector2.ZERO
	var base_rh := Vector2.ZERO
	var base_nose := Vector2.ZERO
	var nose_addr_count: int = 0

	for i in range(addr_count):
		var lm = valid_frames[i]["landmarks"]
		base_ls += Vector2(float(lm["left_shoulder"].get("x", 0)), float(lm["left_shoulder"].get("y", 0)))
		base_rs += Vector2(float(lm["right_shoulder"].get("x", 0)), float(lm["right_shoulder"].get("y", 0)))
		base_lh += Vector2(float(lm["left_hip"].get("x", 0)), float(lm["left_hip"].get("y", 0)))
		base_rh += Vector2(float(lm["right_hip"].get("x", 0)), float(lm["right_hip"].get("y", 0)))
		if lm.has("nose"):
			base_nose += Vector2(float(lm["nose"].get("x", 0)), float(lm["nose"].get("y", 0)))
			nose_addr_count += 1

	base_ls /= float(addr_count)
	base_rs /= float(addr_count)
	base_lh /= float(addr_count)
	base_rh /= float(addr_count)
	if nose_addr_count > 0:
		base_nose /= float(nose_addr_count)

	var base_s_mid = (base_ls + base_rs) * 0.5
	var base_h_mid = (base_lh + base_rh) * 0.5
	var torso_scale: float = max(0.01, base_s_mid.distance_to(base_h_mid))
	var base_shoulder_width: float = max(0.01, base_ls.distance_to(base_rs))
	var base_hip_width: float = max(0.01, base_lh.distance_to(base_rh))

	# Camera View Auto-Detection: DTL shows shoulders stacked nearly on top of each other vertically
	var sw_ratio: float = base_shoulder_width / torso_scale
	result["camera_view"] = "dtl" if sw_ratio < 0.28 else "face_on"

	# Tempo Ratio (Backswing frames : Downswing frames)
	if total_f >= 12 and impact_idx > top_idx and top_idx > addr_count:
		var bs_frames: float = float(max(1, top_idx - addr_count + 1))
		var ds_frames: float = float(max(1, impact_idx - top_idx))
		result["swing_tempo_ratio"] = bs_frames / ds_frames

	# Address Shoulder Tilt: Trail shoulder lower than lead shoulder
	# In screen coords, Y increases downward.
	var trail_minus_lead_y: float = (base_ls.y - base_rs.y) if is_lefty else (base_rs.y - base_ls.y)
	var shoulder_tilt_rad: float = atan2(trail_minus_lead_y, max(0.001, abs(base_rs.x - base_ls.x)))
	var addr_shoulder_tilt_deg: float = rad_to_deg(shoulder_tilt_rad)
	result["address_shoulder_tilt"] = addr_shoulder_tilt_deg

	# Address Shoulder vs Hip Squareness:
	var s_angle = rad_to_deg(atan2(base_rs.y - base_ls.y, base_rs.x - base_ls.x))
	var h_angle = rad_to_deg(atan2(base_rh.y - base_lh.y, base_rh.x - base_lh.x))
	var align_diff: float = s_angle - h_angle
	result["address_shoulder_hip_alignment"] = align_diff

	var base_spine_vec = base_s_mid - base_h_mid
	var base_spine_angle = rad_to_deg(atan2(abs(base_spine_vec.x), -base_spine_vec.y))

	# ─── 2. DETECT KEY SWING FRAMES (P4 TOP & P7 IMPACT) ───
	# Determined dynamically via detect_key_phases above

	# ─── 3. TOP OF BACKSWING (P4) KINEMATICS ───
	var top_lm = valid_frames[top_idx]["landmarks"]
	var top_ls = Vector2(float(top_lm["left_shoulder"].get("x", 0)), float(top_lm["left_shoulder"].get("y", 0)))
	var top_rs = Vector2(float(top_lm["right_shoulder"].get("x", 0)), float(top_lm["right_shoulder"].get("y", 0)))
	var top_lh = Vector2(float(top_lm["left_hip"].get("x", 0)), float(top_lm["left_hip"].get("y", 0)))
	var top_rh = Vector2(float(top_lm["right_hip"].get("x", 0)), float(top_lm["right_hip"].get("y", 0)))

	var top_sw: float = top_ls.distance_to(top_rs)
	var top_hw: float = top_lh.distance_to(top_rh)
	var top_s_mid = (top_ls + top_rs) * 0.5
	var top_h_mid = (top_lh + top_rh) * 0.5

	# Shoulder turn from cosine foreshortening + z
	var s_ratio = clamp(top_sw / base_shoulder_width, 0.0, 1.0)
	var top_s_turn = rad_to_deg(acos(s_ratio))
	if top_lm["left_shoulder"].has("z") and top_lm["right_shoulder"].has("z"):
		var dz = abs(float(top_lm["left_shoulder"]["z"]) - float(top_lm["right_shoulder"]["z"]))
		var z_turn = rad_to_deg(atan2(dz, max(0.001, top_sw)))
		if z_turn > top_s_turn and z_turn < 120.0:
			top_s_turn = z_turn
	result["top_shoulder_turn"] = top_s_turn

	# Hip turn
	var h_ratio = clamp(top_hw / base_hip_width, 0.0, 1.0)
	var top_h_turn = rad_to_deg(acos(h_ratio))
	result["top_hip_turn"] = top_h_turn

	# X-Factor (Shoulder-Hip Separation)
	var x_factor = max(0.0, top_s_turn - top_h_turn)
	result["top_x_factor"] = x_factor

	# Lateral Hip Sway at Top (negative = away from target for RH, flipped for LH)
	var raw_sway: float = ((top_h_mid.x - base_h_mid.x) / torso_scale) * 10.0
	result["top_hip_sway"] = -raw_sway if is_lefty else raw_sway

	# Reverse Spine Angle at Top
	var top_spine_vec = top_s_mid - top_h_mid
	var raw_top_tilt: float = rad_to_deg(atan2(top_spine_vec.x - base_spine_vec.x, -top_spine_vec.y))
	result["top_reverse_spine_tilt"] = -raw_top_tilt if is_lefty else raw_top_tilt

	# ─── 4. TRANSITION SEQUENCING (P4 -> P6) ───
	var shoulders_uncoiled_first: bool = false
	if top_idx + 2 < impact_idx:
		var mid_t_idx = top_idx + 1
		var mid_lm = valid_frames[mid_t_idx]["landmarks"]
		var mid_ls = Vector2(float(mid_lm["left_shoulder"].get("x", 0)), float(mid_lm["left_shoulder"].get("y", 0)))
		var mid_rs = Vector2(float(mid_lm["right_shoulder"].get("x", 0)), float(mid_lm["right_shoulder"].get("y", 0)))
		var mid_lh = Vector2(float(mid_lm["left_hip"].get("x", 0)), float(mid_lm["left_hip"].get("y", 0)))
		var mid_rh = Vector2(float(mid_lm["right_hip"].get("x", 0)), float(mid_lm["right_hip"].get("y", 0)))
		var mid_sw = mid_ls.distance_to(mid_rs)
		var mid_hw = mid_lh.distance_to(mid_rh)
		if (mid_sw - top_sw) > 0.02 and (mid_hw - top_hw) <= 0.005:
			shoulders_uncoiled_first = true
	result["transition_shoulder_cast"] = shoulders_uncoiled_first

	# ─── 5. IMPACT POSTURE & CLEARANCE (P7) ───
	var imp_lm = valid_frames[impact_idx]["landmarks"]
	var imp_ls = Vector2(float(imp_lm["left_shoulder"].get("x", 0)), float(imp_lm["left_shoulder"].get("y", 0)))
	var imp_rs = Vector2(float(imp_lm["right_shoulder"].get("x", 0)), float(imp_lm["right_shoulder"].get("y", 0)))
	var imp_lh = Vector2(float(imp_lm["left_hip"].get("x", 0)), float(imp_lm["left_hip"].get("y", 0)))
	var imp_rh = Vector2(float(imp_lm["right_hip"].get("x", 0)), float(imp_lm["right_hip"].get("y", 0)))
	var imp_s_mid = (imp_ls + imp_rs) * 0.5
	var imp_h_mid = (imp_lh + imp_rh) * 0.5

	# Head Vertical Drift (Dip positive, Lift negative)
	if nose_addr_count > 0 and imp_lm.has("nose"):
		var imp_nose = Vector2(float(imp_lm["nose"].get("x", 0)), float(imp_lm["nose"].get("y", 0)))
		result["head_vertical_drift"] = ((imp_nose.y - base_nose.y) / torso_scale) * 10.0

	# Early Extension (Pelvic thrust forward / spine angle rise)
	var imp_spine_vec = imp_s_mid - imp_h_mid
	var imp_spine_angle = rad_to_deg(atan2(abs(imp_spine_vec.x), -imp_spine_vec.y))
	var spine_loss = max(0.0, base_spine_angle - imp_spine_angle)
	result["impact_spine_loss"] = spine_loss

	var pelvic_thrust = ((base_h_mid.y - imp_h_mid.y) / torso_scale) * 10.0
	result["impact_early_extension"] = pelvic_thrust

	# Hip Clearance at Impact
	var imp_hw = imp_lh.distance_to(imp_rh)
	var imp_h_ratio = clamp(imp_hw / base_hip_width, 0.0, 1.0)
	var hip_clearance_deg = rad_to_deg(acos(imp_h_ratio))
	result["impact_hip_clearance"] = hip_clearance_deg

	# Lead Arm Chicken Wing Check (Left arm for RH, Right arm for LH)
	var lead_s_key: String = "right_shoulder" if is_lefty else "left_shoulder"
	var lead_e_key: String = "right_elbow" if is_lefty else "left_elbow"
	var lead_w_key: String = "right_wrist" if is_lefty else "left_wrist"
	if imp_lm.has(lead_s_key) and imp_lm.has(lead_e_key) and imp_lm.has(lead_w_key):
		var le_s = Vector2(float(imp_lm[lead_s_key].get("x", 0)), float(imp_lm[lead_s_key].get("y", 0)))
		var le_e = Vector2(float(imp_lm[lead_e_key].get("x", 0)), float(imp_lm[lead_e_key].get("y", 0)))
		var le_w = Vector2(float(imp_lm[lead_w_key].get("x", 0)), float(imp_lm[lead_w_key].get("y", 0)))
		var v1 = (le_s - le_e).normalized()
		var v2 = (le_w - le_e).normalized()
		var elbow_angle = rad_to_deg(acos(clamp(v1.dot(v2), -1.0, 1.0)))
		result["lead_elbow_angle"] = elbow_angle
		if elbow_angle < 152.0:
			result["impact_chicken_wing"] = true

	return result


# =============================================================================
# 3. CROSS-CORRELATION & UNIFIED RANKING (PHASE 3)
# =============================================================================

## Combines launch monitor metrics with deep skeleton kinematics into a single
## ranked, prioritized list of swing recommendations.
static func analyze_shot_unified(shot_data: Dictionary, skeleton: Dictionary) -> Array[Dictionary]:
	var final_recs: Array[Dictionary] = []
	var lm_recs = analyze_launch_monitor(shot_data)

	if not skeleton.get("has_valid_data", false):
		return lm_recs

	var club_name: String = str(shot_data.get("Club", shot_data.get("club", "Driver")))
	var club_cat: String = _classify_club(club_name)
	var is_tee: bool = bool(shot_data.get("is_tee", shot_data.get("lie_type", "") == "teebox"))
	if not shot_data.has("is_tee") and not shot_data.has("lie_type"):
		is_tee = (club_cat == "driver")
	var club_disp: String = get_club_display_name(club_name)
	var is_lefty: bool = _resolve_is_lefty(shot_data)
	var slice_sign: float = -1.0 if is_lefty else 1.0
	var is_dtl: bool = str(skeleton.get("camera_view", "face_on")) == "dtl"

	var spine_loss: float = skeleton.get("impact_spine_loss", 0.0)
	var early_ext: float = skeleton.get("impact_early_extension", 0.0)
	var s_turn: float = skeleton.get("top_shoulder_turn", 85.0)
	var x_factor: float = skeleton.get("top_x_factor", 45.0)
	var hip_sway: float = skeleton.get("top_hip_sway", 0.0)
	var shoulder_tilt: float = skeleton.get("address_shoulder_tilt", 8.0)
	var shoulder_align: float = skeleton.get("address_shoulder_hip_alignment", 0.0)
	var shoulder_cast: bool = skeleton.get("transition_shoulder_cast", false)
	var hip_clearance: float = skeleton.get("impact_hip_clearance", 35.0)
	var chicken_wing: bool = skeleton.get("impact_chicken_wing", false)
	var tempo_ratio: float = float(skeleton.get("swing_tempo_ratio", 0.0))
	var head_drift: float = float(skeleton.get("head_vertical_drift", 0.0))
	var frame_count: int = int(skeleton.get("frame_count", 0))

	var spin_axis: float = _get_float_val(shot_data, ["SpinAxis", "SideSpinAxis"], 0.0)
	var directed_axis: float = spin_axis * slice_sign
	var ball_speed: float = _get_float_val(shot_data, ["Speed", "BallSpeed"], 0.0)
	var club_speed: float = _get_float_val(shot_data, ["ClubSpeed"], 0.0)
	var smash: float = _get_float_val(shot_data, ["SmashFactor"], 0.0)
	if smash <= 0.5 and ball_speed > 0.0 and club_speed > 0.0:
		smash = ball_speed / club_speed
	var has_smash_data: bool = smash > 0.5
	var raw_aoa: float = _get_float_val(shot_data, ["AttackAngle", "AngleOfAttack"], 999.0)
	var aoa: float = raw_aoa if (raw_aoa < 900.0 and abs(raw_aoa) >= 0.1) else 999.0
	var total_spin: float = _get_float_val(shot_data, ["TotalSpin", "BackSpin"], 0.0)
	var carry: float = _get_float_val(shot_data, ["Carry", "CarryDistance"], 0.0)

	var player_name: String = str(shot_data.get("Player", shot_data.get("player", "")))
	var skill_level: String = "mid_handicap"
	if shot_data.has("skill_level") and str(shot_data["skill_level"]) != "":
		skill_level = str(shot_data["skill_level"])
	elif Engine.has_singleton("MultiplayerManager"):
		var mp_mgr = Engine.get_singleton("MultiplayerManager")
		if mp_mgr != null and mp_mgr.has_method("get_player_skill_level"):
			skill_level = mp_mgr.get_player_skill_level(player_name)
	elif Engine.get_main_loop() != null and Engine.get_main_loop().root != null and Engine.get_main_loop().root.has_node("MultiplayerManager"):
		var mp_node = Engine.get_main_loop().root.get_node_or_null("MultiplayerManager")
		if mp_node != null and mp_node.has_method("get_player_skill_level"):
			skill_level = mp_node.get_player_skill_level(player_name)
	skill_level = normalize_skill_level(skill_level)
	var skill_disp: String = SKILL_LEVEL_NAMES.get(skill_level, "Mid Handicap (10–19 HCP)")
	var benchmark: Dictionary = get_benchmark(club_name, skill_level)
	var loss_breakdown: Dictionary = _estimate_distance_loss(shot_data, benchmark, smash, club_speed, total_spin, spin_axis, carry)

	var used_lm_types: Array[String] = []

	# ─── CORRELATION 1: SMASH FACTOR LOSS + EARLY EXTENSION ───
	var has_smash_issue: bool = has_smash_data and ((club_cat == "driver" and smash < 1.42) or (club_cat in ["wood", "hybrid"] and smash < 1.35) or (club_cat in ["mid_iron", "long_iron"] and smash < 1.30))
	var has_posture_loss: bool = early_ext > 1.8 or spine_loss > 6.0

	if has_smash_issue and has_posture_loss:
		used_lm_types.append("Low Smash Factor")
		used_lm_types.append("Sub-Optimal Smash Factor")
		var r = {
			"priority": 1,
			"score": 98,
			"severity": "CRITICAL",
			"category": "POSTURE & STRIKE EFFICIENCY",
			"issue_type": "Early Extension Contact Loss",
			"title": "Early Extension Causing Off-Center Strike (%.2f Smash)" % smash,
			"camera_flaw": "Hips thrust %.1f units toward ball, losing %.1f° of address spine inclination into impact." % [early_ext, spine_loss],
			"launch_effect": "Standing up out of posture pulls sweet spot off ball center, leaking 15–30 yards.",
			"player_val": "Spine Angle Lost: %.1f° | Smash: %.2f" % [spine_loss, smash],
			"benchmark_val": "Pro Benchmark: < 3.0° Spine Loss | 1.48+ Smash",
			"fix_instruction": "Keep trail glute pressed back against an imaginary chair through the entire transition and impact zone.",
			"drill": "⛳ HackMotion Low Point & Chair Drill: Touch lead hip to a chair behind you at address; keep hips in contact with chair until after impact to stabilize low point and smash factor."
		}
		_attach_video_metadata(r, "low_point")
		final_recs.append(r)
	elif has_posture_loss:
		var r = {
			"priority": 2,
			"score": 86,
			"severity": "HIGH",
			"category": "BIOMECHANICS & POSTURE",
			"issue_type": "Early Extension",
			"title": "Early Extension (%.1f° Posture Inclination Lost)" % spine_loss,
			"camera_flaw": "Camera detected torso rising %.1f° out of address posture before strike." % spine_loss,
			"launch_effect": "Forces hands to flip to reach the ball, destabilizing face angle control.",
			"player_val": "Spine Loss: %.1f° | Forward Thrust: %.1f" % [spine_loss, early_ext],
			"benchmark_val": "Benchmark: Retain Address Posture (35° Spine)",
			"fix_instruction": "Stay down through the shot. Feel your chest looking down at the turf until the ball is airborne.",
			"drill": "⛳ Head-on-Wall Drill: Place forehead lightly against a soft cushion on a wall; rehearse slow-motion turn without lifting head."
		}
		_attach_video_metadata(r, "sim_improvement")
		final_recs.append(r)

	# ─── CORRELATION 2: SLICE / OPEN FACE + OVER-THE-TOP SEQUENCE & SETUP ───
	var has_slice: bool = directed_axis > 5.0
	var has_ott_body: bool = shoulder_cast or shoulder_align > 5.0 or chicken_wing

	if has_slice and has_ott_body:
		used_lm_types.append("Slice / Open Face-to-Path")
		used_lm_types.append("Fade / Open Face")
		var cause_desc: String = ""
		if shoulder_cast:
			cause_desc += "Shoulders uncoiled ahead of hips on downswing. "
		if shoulder_align > 5.0:
			cause_desc += "Shoulders were %.1f° open at address setup. " % shoulder_align
		if chicken_wing:
			cause_desc += "Lead elbow collapsed to %.0f° (chicken wing). " % skeleton.get("lead_elbow_angle", 145.0)

		var r = {
			"priority": 1,
			"score": 97,
			"severity": "CRITICAL",
			"category": "SWING PLANE & KINEMATICS",
			"issue_type": "Over-the-Top Slice",
			"title": "Over-The-Top Downswing (%+.1f° Spin Axis Slice)" % spin_axis,
			"camera_flaw": cause_desc.strip_edges(),
			"launch_effect": "Forces club onto out-to-in steep path with open face relative to path.",
			"player_val": "Spin Axis: %+.1f° | Shoulder Setup: %+.1f°" % [spin_axis, shoulder_align],
			"benchmark_val": "Target: -2° to +2° Path | Square Shoulders",
			"fix_instruction": "Square shoulders parallel to target line at setup. Start downswing by shifting weight onto lead heel, letting arms drop inside.",
			"drill": "⛳ HackMotion Barrier & Armpit Glove Drill: Place a barrier 5 inches outside ball and glove under trail armpit; hit balls keeping path inside-to-out."
		}
		_attach_video_metadata(r, "barrier_path")
		final_recs.append(r)

	# ─── CORRELATION 3: DRIVER STEEP AOA + FLAT ADDRESS SHOULDERS (FACE-ON ONLY) ───
	if not is_dtl and club_cat == "driver" and is_tee and aoa < -1.0 and aoa > -20.0 and aoa < 900.0:
		if shoulder_tilt < 4.0:
			used_lm_types.append("Steep Driver Attack Angle")
			var yds_recov = int(abs(aoa - 3.0) * 4.2)
			yds_recov = clamp(yds_recov, 14, 28)
			var r = {
				"priority": 2,
				"score": 89,
				"severity": "HIGH",
				"category": "SETUP & LAUNCH OPTIMIZATION",
				"issue_type": "Level Shoulders Causing Steep Driver Strike",
				"title": "Flat Setup Tilting Driver AoA (%.1f° Downward on Tee)" % aoa,
				"camera_flaw": "Shoulder tilt at address was only %.1f° (ideal: 8°–12° secondary spine tilt)." % shoulder_tilt,
				"launch_effect": "Prevents sweeping upward on ball; causes downward strike that kills ~%d yards." % yds_recov,
				"player_val": "Address Shoulder Tilt: %.1f° | AoA: %.1f°" % [shoulder_tilt, aoa],
				"benchmark_val": "Target: 8.0°–12.0° Tilt | +2.0° to +5.0° AoA",
				"fix_instruction": "At address, bump lead hip slightly toward target so spine tilts 8° away from target. Trail shoulder must sit lower than lead shoulder to hit upward on the teed ball.",
				"drill": "⛳ HackMotion Zipper Tilt Drill: Hold club vertically against sternum; tilt upper body away from target until shaft points at inside of trail knee."
			}
			_attach_video_metadata(r, "one_metric_aoa")
			final_recs.append(r)
	elif club_cat == "wood" and not is_tee and ((aoa < 900.0 and aoa > 0.8) or spine_loss > 4.5):
		used_lm_types.append("Scooping Wood Off Turf")
		var pv_txt = "Spine Loss: %.1f°" % spine_loss
		var bench_txt = "Target: Retain Address Posture (< 3.0° Spine Loss)"
		if aoa < 900.0:
			pv_txt = "Spine Loss: %.1f° | AoA: %+.1f°" % [spine_loss, aoa]
			bench_txt = "Target: Retain Address Posture | -1.0° to -3.0° AoA"
		var r = {
			"priority": 2,
			"score": 90,
			"severity": "HIGH",
			"category": "SETUP & FAIRWAY TURF SWEEP",
			"issue_type": "Hanging Back On Fairway Wood",
			"title": "Hanging Back on %s (%.1f° Spine Loss)" % [club_disp, spine_loss],
			"camera_flaw": "Body tilted backward and torso rose %.1f° out of posture trying to lift ball off turf." % spine_loss,
			"launch_effect": "Causes low-point to fall behind the ball, resulting in fat or topped fairway wood shots.",
			"player_val": pv_txt,
			"benchmark_val": bench_txt,
			"fix_instruction": "Shift weight onto lead side during downswing. Keep your chest facing down toward the turf through impact and sweep the grass.",
			"drill": "⛳ HackMotion Step-Through Drill: Step your trail foot forward toward target after striking fairway wood to ensure weight shifts fully onto lead side."
		}
		_attach_video_metadata(r, "one_metric_aoa")
		final_recs.append(r)

	# ─── CORRELATION 4: RESTRICTED SHOULDER TURN & POWER LEAK (FACE-ON ONLY) ───
	if not is_dtl and s_turn < 75.0:
		used_lm_types.append("Low Ball Speed")
		var r = {
			"priority": 3,
			"score": 79,
			"severity": "MEDIUM",
			"category": "POWER & ROTATIONAL COIL",
			"issue_type": "Restricted Shoulder Turn",
			"title": "Restricted Shoulder Rotation (%.1f° vs 90° Benchmark)" % s_turn,
			"camera_flaw": "Camera measured only %.1f° of shoulder turn at top of backswing (X-Factor: %.1f°)." % [s_turn, x_factor],
			"launch_effect": "Shortens swing radius and limits coil energy, reducing potential ball speed.",
			"player_val": "Shoulder Turn: %.1f° | X-Factor: %.1f°" % [s_turn, x_factor],
			"benchmark_val": "Pro Benchmark: 90.0° Turn | 45.0° X-Factor",
			"fix_instruction": "Allow your lead heel to float slightly if needed, and focus on turning your lead shoulder fully behind the ball.",
			"drill": "⛳ HackMotion Cross-Arm Coil Drill: Cross arms across shoulders and rotate until shaft points down toward ball line to build transition power."
		}
		_attach_video_metadata(r, "downswing_sequence")
		final_recs.append(r)

	# ─── CORRELATION 5: LATERAL HIP SWAY (FACE-ON ONLY) ───
	if not is_dtl and abs(hip_sway) > 3.0:
		var dir_txt = "away from target" if hip_sway < 0 else "toward target"
		var r = {
			"priority": 3,
			"score": 73,
			"severity": "MEDIUM",
			"category": "LOWER BODY STABILITY",
			"issue_type": "Lateral Hip Sway",
			"title": "Lateral Hip Sway (%.1f units %s)" % [abs(hip_sway), dir_txt],
			"camera_flaw": "Hips slid %.1f units laterally %s instead of pivoting within foot foundation." % [abs(hip_sway), dir_txt],
			"launch_effect": "Shifts swing low point unpredictably, causing fat or thin strikes.",
			"player_val": "Hip Sway: %.1f units" % abs(hip_sway),
			"benchmark_val": "Target: Centered Pivot (< 1.5 units sway)",
			"fix_instruction": "Feel pressure on the inside instep of your trail foot. Turn around your spine axis without sliding hips sideways.",
			"drill": "⛳ HackMotion Foot Stability Drill: Place half a tennis ball under outside edge of trail foot during backswing to stabilize low point distance."
		}
		_attach_video_metadata(r, "one_metric_aoa")
		final_recs.append(r)

	# ─── CORRELATION 6: STALLED HIPS AT IMPACT ───
	if not is_dtl and hip_clearance < 18.0 and not has_smash_issue:
		var r = {
			"priority": 4,
			"score": 68,
			"severity": "MEDIUM",
			"category": "IMPACT ROTATION",
			"issue_type": "Stalled Hips at Impact",
			"title": "Hips Square at Impact (Only %.1f° Open)" % hip_clearance,
			"camera_flaw": "Hips stopped turning into impact, leaving pelvis nearly square to target line.",
			"launch_effect": "Forces the hands and arms to take over through impact, making face control erratic.",
			"player_val": "Hip Clearance: %.1f° Open" % hip_clearance,
			"benchmark_val": "Target: 35.0°–45.0° Open at Impact",
			"fix_instruction": "Focus on clearing the lead hip behind you as your first downswing move. Belt buckle should face the target by follow-through.",
			"drill": "⛳ HackMotion Hip Clearance Step Drill: Focus on clearing lead hip 35°–45° open at impact; rehearse step-through finish to let body rotation lead the swing."
		}
		_attach_video_metadata(r, "downswing_sequence")
		final_recs.append(r)

	# ─── CORRELATION 7: RUSHED DOWNSWING TEMPO ───
	if frame_count >= 12 and tempo_ratio > 0.0 and tempo_ratio < 1.85:
		var r = {
			"priority": 3,
			"score": 76,
			"severity": "MEDIUM",
			"category": "TEMPO & RHYTHM",
			"issue_type": "Rushed Downswing Tempo",
			"title": "Hurried Transition Tempo (%.1f:1 vs 3.0:1 Pro)" % tempo_ratio,
			"camera_flaw": "Backswing-to-downswing ratio measured %.1f:1, indicating a rushed transition from the top." % tempo_ratio,
			"launch_effect": "Steepens the shaft prematurely and disrupts kinetic sequencing into impact.",
			"player_val": "Tempo Ratio: %.1f:1" % tempo_ratio,
			"benchmark_val": "Tour Target: ~3.0:1 Backswing:Downswing",
			"fix_instruction": "Give the club a split-second gather at the top before letting hips unwind.",
			"drill": "⛳ 1-2-3 Pause-at-Top Metronome Drill: Count 1-2 to top of backswing, slight pause, swing through on 3."
		}
		_attach_video_metadata(r, "downswing_sequence")
		final_recs.append(r)

	# ─── CORRELATION 8: HEAD POSTURE DIP / LIFT ───
	if abs(head_drift) > 1.8:
		var drift_dir: String = "dipped down" if head_drift > 0.0 else "lifted up"
		var r = {
			"priority": 3,
			"score": 74,
			"severity": "MEDIUM",
			"category": "POSTURE STABILITY",
			"issue_type": "Head Posture Dip / Lift",
			"title": "Head Level Shifted (%.1f units %s)" % [abs(head_drift), drift_dir],
			"camera_flaw": "Head %s %.1f normalized units between address and impact." % [drift_dir, abs(head_drift)],
			"launch_effect": "Changes swing bottom arc mid-swing, producing alternating thin and heavy strikes.",
			"player_val": "Vertical Head Drift: %+.1f units" % head_drift,
			"benchmark_val": "Target: < ±1.2 units vertical head drift",
			"fix_instruction": "Maintain eyes level through the strike while rotating ribs cleanly around a stable spine.",
			"drill": "⛳ Head-Steady Half-Swing Drill: Rehearse 7-iron punch swings keeping head level against a backdrop marker."
		}
		_attach_video_metadata(r, "sim_improvement")
		final_recs.append(r)

	# Add any launch monitor recommendations that weren't subsumed by cross-correlations
	for r in lm_recs:
		var t = str(r.get("issue_type", ""))
		if not t in used_lm_types and t != "Pure Ball Strike" and t != "Functional Stock Flight":
			final_recs.append(r)

	if final_recs.is_empty():
		final_recs = lm_recs

	final_recs.sort_custom(func(a, b): return a["score"] > b["score"])
	for idx in range(final_recs.size()):
		final_recs[idx]["priority"] = idx + 1

	var comp_table: Array[Dictionary] = _build_comparison_table(shot_data, benchmark, skill_level)
	for r in final_recs:
		if not r.has("skill_level"):
			r["skill_level"] = skill_level
			r["skill_level_display"] = skill_disp
		if not r.has("comparison_table"):
			r["comparison_table"] = comp_table
		if not r.has("four_tier_diagnosis"):
			r["four_tier_diagnosis"] = _build_four_tier_diagnosis(r, shot_data, benchmark)
		if not r.has("distance_loss_breakdown"):
			r["distance_loss_breakdown"] = loss_breakdown
		_attach_drill_progression(r)

	return final_recs


# =============================================================================
# 4. BACKWARD COMPATIBILITY & HELPERS
# =============================================================================

## Legacy entry point for compatibility with earlier callers
static func analyze_shot(shot_data: Dictionary, skeleton_telemetry: Dictionary = {}) -> Array[Dictionary]:
	if skeleton_telemetry.get("has_valid_telemetry", false):
		var fake_skel: Dictionary = {
			"has_valid_data": true,
			"address_shoulder_tilt": 8.0,
			"address_shoulder_hip_alignment": 0.0,
			"top_shoulder_turn": _get_float_val(skeleton_telemetry, ["shoulder_turn"], 85.0),
			"top_hip_turn": 40.0,
			"top_x_factor": 45.0,
			"top_hip_sway": _get_float_val(skeleton_telemetry, ["hip_sway"], 0.0),
			"transition_shoulder_cast": false,
			"impact_spine_loss": max(0.0, 35.0 - _get_float_val(skeleton_telemetry, ["spine_angle"], 35.0)),
			"impact_early_extension": _get_float_val(skeleton_telemetry, ["early_extension"], 0.0),
			"impact_hip_clearance": 35.0,
			"impact_chicken_wing": false,
			"lead_elbow_angle": 180.0
		}
		return analyze_shot_unified(shot_data, fake_skel)
	else:
		return analyze_launch_monitor(shot_data)


static func get_club_display_name(club_name: String) -> String:
	var c = club_name.to_lower().strip_edges()
	if c in ["dr", "1w", "driver"] or "driver" in c:
		return "Driver"
	elif c == "3w":
		return "3-Wood"
	elif c == "4w":
		return "4-Wood"
	elif c == "5w":
		return "5-Wood"
	elif c == "7w":
		return "7-Wood"
	elif "wood" in c or c == "fw":
		return "Fairway Wood"
	elif c in ["2h", "3h", "4h", "5h"]:
		return c.to_upper().replace("H", "-Hybrid")
	elif "hybrid" in c or "rescue" in c:
		return "Hybrid"
	elif c in ["1i", "2i", "3i", "4i", "5i", "6i", "7i", "8i", "9i"]:
		return c.to_upper().replace("I", "-Iron")
	elif "iron" in c:
		return club_name.capitalize()
	elif c in ["pw", "pitching"]:
		return "Pitching Wedge"
	elif c in ["gw", "aw", "gap", "approach"]:
		return "Gap Wedge"
	elif c in ["sw", "sand"]:
		return "Sand Wedge"
	elif c in ["lw", "lob"]:
		return "Lob Wedge"
	elif "wedge" in c:
		return "Wedge"
	elif "putt" in c or c == "pt":
		return "Putter"
	return club_name.capitalize() if not club_name.is_empty() else "Driver"


static func _classify_club(club_name: String) -> String:
	var c = club_name.to_lower().strip_edges()
	if "putt" in c or c == "pt":
		return "putter"
	if c in ["dr", "1w", "driver"] or "driver" in c:
		return "driver"
	if c in ["3w", "4w", "5w", "7w", "wood", "fairway", "fw"] or "wood" in c:
		return "wood"
	if c in ["2h", "3h", "4h", "5h", "hybrid", "rescue"] or "hybrid" in c:
		return "hybrid"
	if c in ["pw", "gw", "sw", "lw", "aw", "pitching", "sand", "gap", "approach", "lob", "wedge"] or "wedge" in c:
		return "wedge"
	if c in ["1i", "2i", "3i", "4i", "5i", "1-iron", "2-iron", "3-iron", "4-iron", "5-iron"]:
		return "long_iron"
	if c in ["6i", "7i", "8i", "9i", "6-iron", "7-iron", "8-iron", "9-iron", "6 iron", "7 iron", "8 iron", "9 iron"] or "iron" in c:
		return "mid_iron"
	return "driver"


static func _get_float_val(dict: Dictionary, keys: Array, default_val: float) -> float:
	for k in keys:
		if dict.has(k):
			var val = dict[k]
			if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
				return float(val)
			elif typeof(val) == TYPE_STRING:
				var s: String = str(val).strip_edges()
				if s == "" or s == "---" or s == "N/A" or s == "n/a" or s.to_lower() == "nan":
					continue
				# Clean string of trailing labels like " In-Out", " Sq", " O", " C", " yd", "°"
				var parts = s.split(" ")
				if parts.size() > 0:
					var num_str = parts[0].replace("+", "").replace("°", "")
					if num_str == "" or num_str == "---" or num_str == "N/A":
						continue
					if num_str.is_valid_float():
						var parsed = float(num_str)
						if not is_nan(parsed):
							return parsed
	return default_val


## Returns detailed diagnostic metadata, causes, drills, and video guide for any issue name
static func get_issue_info(issue_name: String) -> Dictionary:
	var key: String = issue_name.strip_edges()
	var lower: String = key.to_lower()
	var info: Dictionary = {
		"title": key,
		"category": "SWING MECHANICS",
		"severity": "HIGH",
		"camera_flaw": "Swing mechanic deviation detected during shot execution.",
		"launch_effect": "Negatively impacts ball flight accuracy, distance, and consistency.",
		"fix_instruction": "Maintain consistent setup posture, smooth transition sequencing, and stable wrist angles through impact.",
		"drill": "⛳ Gate & Alignment Drill: Set up two alignment sticks or tees to groove neutral swing path and centered clubface contact."
	}
	var video_key: String = "sim_improvement"

	if "low smash" in lower or "sub-optimal smash" in lower or "smash factor" in lower:
		info["category"] = "STRIKE EFFICIENCY & SMASH"
		info["severity"] = "CRITICAL" if "low" in lower else "HIGH"
		info["title"] = "Smash Factor & Strike Efficiency"
		info["camera_flaw"] = "Off-center strike contact (toe/heel/high/low on the face) detected at impact."
		info["launch_effect"] = "Reduces energy transfer from clubhead to ball, leaking 15–35 yards of potential carry distance."
		info["fix_instruction"] = "Focus on centered face contact before swinging faster. Smooth out your transition and stabilize the lead wrist through impact."
		info["drill"] = "⛳ HackMotion Impact Spray & Low Point Drill: Spray clubface with dry-shampoo or impact decal. Rehearse centered contact and ensure lead wrist remains stable through impact rather than scooping early."
		video_key = "low_point"

	elif "early extension contact loss" in lower:
		info["category"] = "POSTURE & STRIKE EFFICIENCY"
		info["severity"] = "CRITICAL"
		info["title"] = "Early Extension Contact Loss"
		info["camera_flaw"] = "Hips thrust forward toward the ball and spine inclination was lost prior to impact."
		info["launch_effect"] = "Standing up out of posture pulls the sweet spot off the ball center, causing severe distance loss and erratic strikes."
		info["fix_instruction"] = "Keep trail glute pressed back against an imaginary wall/chair through transition and impact zone."
		info["drill"] = "⛳ HackMotion Low Point & Chair Drill: Touch lead hip to a chair behind you at address; keep hips in contact with chair until after impact to stabilize low point and smash factor."
		video_key = "low_point"

	elif "early extension" in lower:
		info["category"] = "BIOMECHANICS & POSTURE"
		info["severity"] = "HIGH"
		info["title"] = "Early Extension Posture Loss"
		info["camera_flaw"] = "Torso rises out of address posture inclination before ball strike."
		info["launch_effect"] = "Forces hands to flip to reach the ball, destabilizing face angle control and strike quality."
		info["fix_instruction"] = "Stay down through the shot. Feel your chest looking down at the turf until the ball is airborne."
		info["drill"] = "⛳ Head-on-Wall Drill: Place forehead lightly against a soft cushion on a wall; rehearse slow-motion turn without lifting head."
		video_key = "sim_improvement"

	elif "over-the-top" in lower or "ott" in lower:
		info["category"] = "SWING PLANE & KINEMATICS"
		info["severity"] = "CRITICAL"
		info["title"] = "Over-The-Top Swing Path"
		info["camera_flaw"] = "Shoulders uncoiled ahead of hips on downswing, casting the club outside the target line."
		info["launch_effect"] = "Forces club onto steep out-to-in delivery with open face relative to path, producing heavy slice spin."
		info["fix_instruction"] = "Square shoulders parallel to target line at setup. Start downswing by shifting weight onto lead heel, letting arms drop inside."
		info["drill"] = "⛳ HackMotion Barrier & Armpit Glove Drill: Place a barrier 5 inches outside ball and glove under trail armpit; hit balls keeping path inside-to-out."
		video_key = "barrier_path"

	elif "slice" in lower or "open face-to-path" in lower:
		info["category"] = "CLUB FACE & SWING PATH"
		info["severity"] = "CRITICAL"
		info["title"] = "Slice / Open Face-to-Path"
		info["camera_flaw"] = "Clubface delivered open relative to swing path at impact."
		info["launch_effect"] = "Creates heavy clockwise sidespin, slicing the ball significantly offline to the right."
		info["fix_instruction"] = "Strengthen lead hand grip slightly. At transition, shallow the club onto an inside delivery path and train lead wrist flexion into impact."
		info["drill"] = "⛳ HackMotion Barrier Drill: Place a second ball or headcover 5 inches outside the ball to block the over-the-top path; pair with the Motorcycle Drill to flex lead wrist and square the face."
		video_key = "barrier_path"

	elif "fade" in lower or "open face" in lower:
		info["category"] = "CLUB FACE & SWING PATH"
		info["severity"] = "HIGH"
		info["title"] = "Fade / Slightly Open Face"
		info["camera_flaw"] = "Face delivered slightly open relative to swing path producing fade curvature."
		info["launch_effect"] = "Gentle curve to the right; causes slight distance loss and weak push-fades into crosswinds."
		info["fix_instruction"] = "Ensure clubface is square at address and maintain quiet, stable wrists through transition to keep face-to-path neutral."
		info["drill"] = "⛳ HackMotion Alignment Gate & Barrier Drill: Practice launching ball along target line between alignment rods while keeping swing path within ±2° neutral."
		video_key = "barrier_path"

	elif "hook" in lower or "closed face-to-path" in lower:
		info["category"] = "CLUB FACE & SWING PATH"
		info["severity"] = "CRITICAL"
		info["title"] = "Hook / Closed Face-to-Path"
		info["camera_flaw"] = "Clubface delivered closed relative to swing path, causing rapid leftward curvature."
		info["launch_effect"] = "Produces heavy counter-clockwise sidespin hook taking ball far left of the target."
		info["fix_instruction"] = "Check that grip is not excessively strong. Rotate chest and torso through impact in sequence rather than rolling forearms and flipping hands early."
		info["drill"] = "⛳ HackMotion Transition & Split-Hand Drill: Use the Transition Drill to train lower-to-upper body sequencing; hold grip with a 3-inch gap to rotate chest through without flipping wrists."
		video_key = "downswing_sequence"

	elif "draw" in lower or "closed face" in lower:
		info["category"] = "CLUB FACE & SWING PATH"
		info["severity"] = "MEDIUM"
		info["title"] = "Draw / Closed Face Curvature"
		info["camera_flaw"] = "Face delivered slightly closed relative to path."
		info["launch_effect"] = "Ball draws left of intended flight line; monitor face angle to avoid over-hooking."
		info["fix_instruction"] = "Keep trail wrist extended slightly longer through impact zone and rotate the torso through to the finish."
		info["drill"] = "⛳ HackMotion Downswing Sequence Drill: Synchronize upper body rotation with hips through impact to prevent over-rotating the clubface closed."
		video_key = "downswing_sequence"

	elif "steep driver attack angle" in lower or ("steep" in lower and "driver" in lower and "tee" in lower):
		info["category"] = "LAUNCH CONDITIONS & AOA"
		info["severity"] = "HIGH"
		info["title"] = "Negative Driver Attack Angle"
		info["camera_flaw"] = "Hitting downward on driver off the tee steepens spin and robs carry distance."
		info["launch_effect"] = "Adds 500–1200 RPM excessive backspin; hitting UP (+1° to +5°) unlocks +15 to +30 yards carry."
		info["fix_instruction"] = "Tee ball forward off inside of lead heel. Tilt spine 6°–10° away from target at address to sweep upward on the teed ball."
		info["drill"] = "⛳ HackMotion Low Point & Box Drill: Place an empty golf ball box 12 inches in front of tee; sweep upward through the ball without clipping the box to move low point behind ball."
		video_key = "one_metric_aoa"

	elif "level shoulders causing steep driver strike" in lower:
		info["category"] = "SETUP & LAUNCH OPTIMIZATION"
		info["severity"] = "HIGH"
		info["title"] = "Flat Setup Driver Strike"
		info["camera_flaw"] = "Shoulders were level at address rather than maintaining 8°–12° secondary spine tilt."
		info["launch_effect"] = "Prevents sweeping upward on ball; causes downward strike that robs significant yardage."
		info["fix_instruction"] = "At address, bump lead hip slightly toward target so spine tilts 8° away from target. Trail shoulder must sit lower than lead shoulder to hit upward on teed ball."
		info["drill"] = "⛳ HackMotion Zipper Tilt Drill: Hold club vertically against sternum; tilt upper body away from target until shaft points at inside of trail knee."
		video_key = "one_metric_aoa"

	elif "steep driver off turf" in lower:
		info["category"] = "LAUNCH CONDITIONS & AOA"
		info["severity"] = "HIGH"
		info["title"] = "Steep Driver Off Turf"
		info["camera_flaw"] = "Chopping down into turf with driver off the deck."
		info["launch_effect"] = "Driver off the deck requires a level sweep; chopping down causes severe distance loss and scuffs."
		info["fix_instruction"] = "Sweep the ball cleanly off the grass with a level shoulder rotation. Do not hit down steeply."
		info["drill"] = "⛳ HackMotion Level Sweep Drill: Practice clipping grass blades smoothly with a wide arc without gouging turf."
		video_key = "one_metric_aoa"

	elif "scooping wood" in lower or "hanging back on fairway wood" in lower:
		info["category"] = "SETUP & FAIRWAY TURF SWEEP"
		info["severity"] = "HIGH"
		info["title"] = "Scooping / Hanging Back on Fairway Wood"
		info["camera_flaw"] = "Body tilted backward and torso rose out of posture trying to lift ball off turf."
		info["launch_effect"] = "Causes low-point to fall behind the ball, resulting in thin, topped, or chunked fairway wood shots."
		info["fix_instruction"] = "Shift weight onto lead side during downswing. Keep your chest facing down toward the turf through impact and sweep the grass."
		info["drill"] = "⛳ HackMotion Step-Through & Sweeping Coin Drill: Place a coin 2 inches ahead of ball; maintain slight forward shaft lean and brush coin forward along grass."
		video_key = "shaft_lean"

	elif "steep wood" in lower:
		info["category"] = "LAUNCH CONDITIONS & AOA"
		info["severity"] = "HIGH"
		info["title"] = "Steep Attack Angle on Fairway Wood"
		info["camera_flaw"] = "Downswing plane too steep into turf for a fairway wood."
		info["launch_effect"] = "Digs into the turf, producing excessive spin ballooning and lost rollout."
		info["fix_instruction"] = "Shallow out your transition. Keep shoulders level and feel the clubhead gliding through the turf rather than chopping into it."
		info["drill"] = "⛳ HackMotion Low Point Turf Brush: Rehearse wide practice swings skimming the grass blades without disturbing the soil, shifting low point forward."
		video_key = "one_metric_aoa"

	elif "scooping hybrid" in lower:
		info["category"] = "LAUNCH CONDITIONS & AOA"
		info["severity"] = "HIGH"
		info["title"] = "Scooping Hybrid Off Turf"
		info["camera_flaw"] = "Trying to lift hybrid off turf instead of hitting down with forward compression."
		info["launch_effect"] = "Thin contact, high weak flight, and lost compression."
		info["fix_instruction"] = "Treat the hybrid like a 5-iron: maintain forward shaft lean and lead wrist flexion to compress the ball before brushing turf."
		info["drill"] = "⛳ HackMotion Forward Shaft Lean Drill: Lay a towel 3 inches behind ball; strike ball with hands leading clubhead without touching towel."
		video_key = "shaft_lean"

	elif "steep hybrid" in lower:
		info["category"] = "LAUNCH CONDITIONS & AOA"
		info["severity"] = "HIGH"
		info["title"] = "Steep Hybrid Strike"
		info["camera_flaw"] = "Steep downswing angle causing fat contact or heavy divots."
		info["launch_effect"] = "Excess spin and lost distance."
		info["fix_instruction"] = "Widen your swing arc and shift weight smoothly onto lead side through impact."
		info["drill"] = "⛳ HackMotion Shallow Sweep Drill: Make rhythm swings focusing on shallow turf interaction and proper low point distance 2-4 inches ahead of ball."
		video_key = "one_metric_aoa"

	elif "scooping" in lower or "upward" in lower:
		info["category"] = "LAUNCH CONDITIONS & AOA"
		info["severity"] = "HIGH"
		info["title"] = "Scooping / Upward Iron & Wedge Attack Angle"
		info["camera_flaw"] = "Hitting up on iron/wedge leads to thin contact and lost compression."
		info["launch_effect"] = "Causes thin strikes, inconsistent turf interaction, and insufficient green-stopping spin."
		info["fix_instruction"] = "Position ball center of stance, transfer 60% weight to lead foot at impact, and maintain forward shaft lean to compress the ball."
		info["drill"] = "⛳ HackMotion Shaft Lean & Towel Drill: Lay a small towel 3 inches behind ball; strike ball crisply with forward shaft lean and flat lead wrist."
		video_key = "shaft_lean"

	elif "excessive driver spin" in lower or "excessive wood spin" in lower or "high hybrid spin" in lower:
		info["category"] = "SPIN DYNAMICS"
		info["severity"] = "MEDIUM"
		info["title"] = "Excessive Backspin (Ballooning Flight)"
		info["camera_flaw"] = "High spin rate produces steep climb and eliminates rollout."
		info["launch_effect"] = "Ball balloons into the wind, losing 15–30 yards of total distance."
		info["fix_instruction"] = "Strike higher on clubface and shallow approach path to deliver optimal dynamic loft."
		info["drill"] = "⛳ HackMotion High Tee & Face Centering Drill: Tee ball up half a ball higher to encourage contact on upper equator of face, optimizing dynamic loft."
		video_key = "shaft_lean"

	elif "insufficient driver spin" in lower or "low wood spin" in lower or "low iron spin" in lower or "spin" in lower:
		info["category"] = "SPIN DYNAMICS"
		info["severity"] = "MEDIUM"
		info["title"] = "Low Spin Rate (Knuckleball / Won't Hold Green)"
		info["camera_flaw"] = "Insufficient backspin to maintain aerodynamic lift or hold greens on approach."
		info["launch_effect"] = "Ball drops out of sky early or rolls completely off the green."
		info["fix_instruction"] = "Check launch angle and strike height. Hit down on iron approach shots with forward shaft lean."
		info["drill"] = "⛳ HackMotion Shaft Lean & Compression Bag Drill: Practice hitting into impact bag with hands leading clubhead to deliver optimal dynamic loft."
		video_key = "shaft_lean"

	elif "launch" in lower or "vla" in lower:
		info["category"] = "LAUNCH WINDOW"
		info["severity"] = "MEDIUM"
		info["title"] = "Sub-Optimal Launch Angle Window"
		info["camera_flaw"] = "Vertical launch angle outside optimal trajectory window."
		info["launch_effect"] = "Limits apex height and total carry or causes ballooning pop-ups."
		info["fix_instruction"] = "Adjust ball position and maintain flat lead wrist through impact."
		info["drill"] = "⛳ HackMotion High Launch Gate: Imagine launching ball over a 15-foot crossbar 30 yards ahead with positive attack angle and proper dynamic loft."
		video_key = "one_metric_aoa"

	elif "launch direction" in lower or "direction deviation" in lower or "hla" in lower:
		info["category"] = "AIM & ALIGNMENT"
		info["severity"] = "MEDIUM"
		info["title"] = "Horizontal Launch Direction Deviation (Push / Pull)"
		info["camera_flaw"] = "Clubface oriented away from target line at moment of impact."
		info["launch_effect"] = "Initial takeoff starts off-center before spin takes effect."
		info["fix_instruction"] = "Verify stance and clubface alignment with target before beginning takeaway."
		info["drill"] = "⛳ HackMotion Direction Game: Use simulator centerline as visual barrier; hit 10 consecutive shots keeping ball on target side."
		video_key = "sim_improvement"

	elif "restricted shoulder turn" in lower or "shoulder turn" in lower:
		info["category"] = "POWER & ROTATIONAL COIL"
		info["severity"] = "MEDIUM"
		info["title"] = "Restricted Shoulder Rotation"
		info["camera_flaw"] = "Measured less than 85° of shoulder turn at top of backswing."
		info["launch_effect"] = "Shortens swing radius and limits coil energy, reducing potential ball speed."
		info["fix_instruction"] = "Allow lead heel to float slightly if needed, and focus on turning lead shoulder fully behind the ball."
		info["drill"] = "⛳ HackMotion Cross-Arm Coil Drill: Cross arms across shoulders and rotate until shaft points down toward ball line to build transition power."
		video_key = "downswing_sequence"

	elif "lateral hip sway" in lower or "hip sway" in lower:
		info["category"] = "LOWER BODY STABILITY"
		info["severity"] = "MEDIUM"
		info["title"] = "Lateral Hip Sway"
		info["camera_flaw"] = "Hips slid laterally instead of pivoting within foot foundation."
		info["launch_effect"] = "Shifts swing low point unpredictably, causing fat or thin strikes."
		info["fix_instruction"] = "Feel pressure on inside instep of trail foot. Turn around spine axis without sliding hips sideways."
		info["drill"] = "⛳ HackMotion Foot Stability Drill: Place half a tennis ball under outside edge of trail foot during backswing to stabilize low point distance."
		video_key = "one_metric_aoa"

	elif "stalled hips" in lower or "hip clearance" in lower:
		info["category"] = "IMPACT ROTATION"
		info["severity"] = "MEDIUM"
		info["title"] = "Stalled Hips at Impact"
		info["camera_flaw"] = "Hips stopped turning into impact, leaving pelvis nearly square to target line."
		info["launch_effect"] = "Forces hands and arms to take over through impact, making face control erratic."
		info["fix_instruction"] = "Focus on clearing lead hip behind you as first downswing move. Belt buckle should face target by follow-through."
		info["drill"] = "⛳ HackMotion Hip Clearance Step Drill: Focus on clearing lead hip 35°–45° open at impact; rehearse step-through finish to let body rotation lead swing."
		video_key = "downswing_sequence"

	elif "toe gear" in lower or "toe_gear_hook" in lower:
		info["category"] = "IMPACT & GEAR EFFECT"
		info["severity"] = "HIGH"
		info["title"] = "Toe Gear-Effect Hook"
		info["camera_flaw"] = "Face and path were close to neutral, but strike location shifted onto the toe."
		info["launch_effect"] = "Bulge/roll gear effect imparts draw/hook spin and drops ball speed without an over-closed path."
		info["fix_instruction"] = "Check standing distance to ball (avoid reaching) and spray face to center contact on the middle groove."
		info["drill"] = "⛳ Two-Tee Face Centering Gate: Set tees just outside toe and heel at 50% speed; groove center impact before swinging at full speed."
		video_key = "low_point"

	elif "heel gear" in lower or "heel_gear_slice" in lower:
		info["category"] = "IMPACT & GEAR EFFECT"
		info["severity"] = "HIGH"
		info["title"] = "Heel Gear-Effect Slice"
		info["camera_flaw"] = "Strike contacted the heel side near the hosel even though swing path was near neutral."
		info["launch_effect"] = "Heel gear effect adds slice curvature, loses 10–25 yds, and increases shanks or weak flares."
		info["fix_instruction"] = "Give hands half an inch more room at address and maintain hip depth rather than lunging pelvis toward the ball."
		info["drill"] = "⛳ Inside Approach / Outside-Ball Clearance Drill: Place a soft headcover 1 inch outside the toe to keep path centered instead of lunging into the heel."
		video_key = "low_point"

	elif "low-face" in lower or "low_face_spin" in lower:
		info["category"] = "STRIKE LOCATION & SPIN"
		info["severity"] = "HIGH"
		info["title"] = "Low-Face Driver Spin Spike"
		info["camera_flaw"] = "Strike contact occurred below the horizontal sweet spot on driver face."
		info["launch_effect"] = "Vertical gear effect spikes backspin (+600–1200 RPM) and steals carry/rollout distance."
		info["fix_instruction"] = "Tee half the ball above the driver crown and sweep gently upward (+2° to +4° AoA)."
		info["drill"] = "⛳ High-Tee Upward Sweep Drill: Hit 10 drivers at 75% speed off a higher tee focusing on brushing above the sweet spot."
		video_key = "one_metric_aoa"

	elif "spin loft" in lower or "flipping" in lower or "high_spin_loft" in lower:
		info["category"] = "COMPRESSION & SHAFT LEAN"
		info["severity"] = "HIGH"
		info["title"] = "High Spin Loft / Glancing Strike"
		info["camera_flaw"] = "Dynamic loft exceeded optimal angle relative to attack angle (hands flipping past clubhead)."
		info["launch_effect"] = "Energy transfers upward instead of forward, costing distance and wind stability."
		info["fix_instruction"] = "Preserve slight forward shaft lean and lead wrist flexion through impact with rotating body."
		info["drill"] = "⛳ 9-to-3 Impact Bag & Pump Drill: Stop at P6 with lead wrist bowed/flat, then turn torso cleanly through ball."
		video_key = "shaft_lean"

	elif "descent angle" in lower or "won't hold green" in lower or "low_descent" in lower:
		info["category"] = "TRAJECTORY & STOPPING POWER"
		info["severity"] = "MEDIUM"
		info["title"] = "Shallow Descent Angle (Low Stopping Power)"
		info["camera_flaw"] = "Shot launched or spun too low, producing a shallow landing angle under 38°."
		info["launch_effect"] = "Approach shots bounce and release off greens instead of holding near pitch mark."
		info["fix_instruction"] = "Catch ball centered on grooves with crisp downward blow and natural loft rather than excessively hooded face."
		info["drill"] = "⛳ Trajectory Window Ladder Drill: Hit 6-iron/7-iron shots flighting over an intermediate height gate to restore 43°+ landing angle."
		video_key = "one_metric_aoa"

	elif "tempo" in lower or "rushed_tempo" in lower:
		info["category"] = "TEMPO & RHYTHM"
		info["severity"] = "MEDIUM"
		info["title"] = "Rushed Downswing Tempo"
		info["camera_flaw"] = "Transition from top of backswing to impact was overly hurried (< 1.8:1 ratio)."
		info["launch_effect"] = "Rushing from the top steepens shaft, hurts sequence, and increases dispersion."
		info["fix_instruction"] = "Add a brief, smooth breath/pause at top of backswing before unwinding from the ground up."
		info["drill"] = "⛳ 1-2-3 Pause-at-Top Metronome Drill: Count 1-2 to the top, pause a hairline beat, and swing through on 3."
		video_key = "downswing_sequence"

	elif "head posture" in lower or "head_drift" in lower:
		info["category"] = "POSTURE STABILITY"
		info["severity"] = "MEDIUM"
		info["title"] = "Head Posture Dip / Lift"
		info["camera_flaw"] = "Notable vertical head displacement between address and impact."
		info["launch_effect"] = "Moves swing radius up or down mid-swing, leading to alternating fat and thin strikes."
		info["fix_instruction"] = "Keep eyes level and maintain steady spine inclination until well after impact."
		info["drill"] = "⛳ Head-Steady Centerness Drill: Hit half-wedge and 7-iron shots keeping sternum height steady against backdrop reference."
		video_key = "sim_improvement"

	elif "two-way miss" in lower or "two_way_miss" in lower or "face instability" in lower:
		info["category"] = "DISPERSION & FACE CONTROL"
		info["severity"] = "HIGH"
		info["title"] = "Two-Way Miss / Face Instability"
		info["camera_flaw"] = "Wide swing in both Face-to-Path and Start Direction across shots."
		info["launch_effect"] = "Produces unpredictable misses both left and right, making course alignment difficult."
		info["fix_instruction"] = "Commit to one stock curve (gentle draw or fade), neutralize grip pressure, and train start-line control first."
		info["drill"] = "⛳ 10-Ball Start-Line Gate Drill: Hit 10 balls through a ±2° HLA gate at 80% speed before pushing speed."
		video_key = "sim_improvement"

	elif "fatigue" in lower or "fatigue_drift" in lower:
		info["category"] = "SESSION STAMINA & FOCUS"
		info["severity"] = "MEDIUM"
		info["title"] = "Late-Session Fatigue Drift"
		info["camera_flaw"] = "Late-session Smash Factor and offline accuracy degraded noticeably compared to early shots."
		info["launch_effect"] = "Tired swings lead to rushed tempo, sloppy contact, and ingraining compensatory habits."
		info["fix_instruction"] = "Take a 30-second reset between shots late in practice and stop full-speed swings once smash drops > 0.04."
		info["drill"] = "⛳ Quality-Over-Volume 5-Ball Blocks: Play 5-ball purposeful target blocks with full pre-shot routine rather than rapid-fire raking."
		video_key = "sim_improvement"

	_attach_video_metadata(info, video_key)
	_attach_drill_progression(info, video_key)
	return info


