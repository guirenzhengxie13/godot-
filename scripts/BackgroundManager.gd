class_name BackgroundManager
extends Node3D

signal lighting_settings_changed(settings: Dictionary)
signal render_cost_profile_changed(profile: Dictionary)

@export var hdri_path := ""
@export var use_procedural_blue_sky := true
@export var floor_albedo_path := "res://assets/environment/leafy_grass_diff_1k.jpg"
@export var floor_normal_path := "res://assets/environment/leafy_grass_nor_gl_1k.jpg"
@export var floor_roughness_path := "res://assets/environment/leafy_grass_rough_1k.jpg"
@export var floor_radius := 38.0
@export var floor_height := 0.12
@export var floor_uv_repeat := 10.0
@export var prop_radius := 18.0
@export var grass_detail_inner_radius := 10.2
@export var edge_tree_radius := 24.8
@export var grass_blade_count := 720
@export var grass_blade_inner_radius := 10.4
@export var grass_blade_outer_radius := 26.8
@export var garden_ring_inner_radius := 10.4
@export var garden_ring_outer_radius := 12.3
@export var cover_meadow_layout_enabled := true
@export var target_fps := 60
@export var time_of_day := 10.0
@export var auto_time_cycle_enabled := false
@export var force_cover_meadow_on_start := true
@export var day_length_seconds := 240.0
@export var time_transition_speed := 4.0
@export var board_manager_path: NodePath = ^"../BoardManager"

@export_group("Inner Board Lamps")
@export var inner_lamps_enabled := true
@export var inner_lamp_outset := 1.35
@export var inner_lamp_height := 2.4
@export var inner_lamp_light_height := 2.15
@export var inner_lamp_pole_radius := 0.045
@export var inner_lamp_pole_color := Color(0.18, 0.14, 0.10)
@export var inner_lamp_shade_color := Color(0.12, 0.09, 0.06)
@export var inner_lamp_bulb_radius := 0.105
@export var inner_lamp_energy := 2.8
@export var inner_lamp_range := 10.0
@export var inner_lamp_spot_angle := 62.0
@export var inner_lamp_spot_attenuation := 0.75
@export var inner_lamp_color := Color(1.0, 0.76, 0.46)
@export var inner_lamp_aim_center_blend := 0.55
@export var inner_lamp_aim_height := 0.06
@export var inner_lamp_debug_markers := false

@export_group("Board Glow")
@export var board_glow_spots_enabled := false

const KENNEY_PROP_ROOT := "res://assets/environment/kenney_nature"
const KENNEY_LANDMARK_ROOT := "res://assets/environment/kenney_landmarks"
const DOWNLOADED_MATERIAL_ROOT := "res://assets/environment/downloaded_materials/polyhaven"
const IMPORTED_TREE_ROOT := "res://assets/environment/imported/trees"
const IMPORTED_MUSHROOM_ROOT := "res://assets/environment/imported/mushrooms"
const LIGHTING_PROFILE_PATH := "user://lighting_profile.cfg"
const RENDER_COST_PROFILE_CONFIG_PATH := "user://render_cost_profile.cfg"
const DEFAULT_RENDER_COST_PROFILE_ID := "high"
const RENDER_COST_PROFILE_ORDER := [
	"high",
	"medium",
	"low",
]
const INNER_CORNER_ANCHORS := [
	Vector2i(0, -4),
	Vector2i(4, -4),
	Vector2i(4, 0),
	Vector2i(0, 4),
	Vector2i(-4, 4),
	Vector2i(-4, 0),
]
const COVER_MEADOW_PROP_POINTS := [
	{"kind": "pond", "position": Vector3(-12.8, 0.18, 5.8), "yaw": -18.0, "scale": 1.0},
	{"kind": "bridge", "position": Vector3(-12.2, 0.18, -6.8), "yaw": 28.0, "scale": 0.95},
	{"kind": "pavilion", "position": Vector3(-5.4, 0.18, -12.2), "yaw": -18.0, "scale": 0.78},
	{"kind": "rock_cluster", "position": Vector3(8.8, 0.18, -10.2), "yaw": 14.0, "scale": 0.9},
	{"kind": "rock_cluster", "position": Vector3(12.4, 0.18, 3.8), "yaw": -24.0, "scale": 0.86},
	{"kind": "flower_cluster", "position": Vector3(-10.7, 0.18, 10.1), "yaw": 8.0, "scale": 0.92},
	{"kind": "flower_cluster", "position": Vector3(3.6, 0.18, 12.6), "yaw": -12.0, "scale": 0.86},
	{"kind": "shrub_cluster", "position": Vector3(-11.8, 0.18, 0.2), "yaw": 34.0, "scale": 0.82},
	{"kind": "shrub_cluster", "position": Vector3(12.6, 0.18, -2.6), "yaw": -42.0, "scale": 0.88},
]
const RENDER_COST_PROFILES := {
	"high": {
		"label": "高渲染",
		"summary": "保留当前默认画面，作为 Forward+ 高画质基准。",
		"render_scale": 1.2,
		"msaa_level": 2.0,
		"fxaa_enabled": 1.0,
		"taa_enabled": 0.0,
		"debanding_enabled": 1.0,
		"ssao_intensity_multiplier": 1.0,
		"fog_density_multiplier": 1.0,
		"reflection_intensity_multiplier": 1.0,
		"board_glow_energy_multiplier": 1.0,
		"grass_density_multiplier": 1.0,
		"ground_radial_segments": 128.0,
	},
	"medium": {
		"label": "中渲染",
		"summary": "推荐默认游玩档，降低采样与后期强度但保留棋盘边缘质量。",
		"render_scale": 1.0,
		"msaa_level": 2.0,
		"fxaa_enabled": 1.0,
		"taa_enabled": 0.0,
		"debanding_enabled": 1.0,
		"ssao_intensity_multiplier": 0.65,
		"fog_density_multiplier": 0.85,
		"reflection_intensity_multiplier": 0.75,
		"board_glow_energy_multiplier": 0.65,
		"grass_density_multiplier": 0.65,
		"ground_radial_segments": 96.0,
	},
	"low": {
		"label": "低渲染",
		"summary": "低配电脑、调试和笔记本省电档，仍保持 Forward+。",
		"render_scale": 0.85,
		"msaa_level": 0.0,
		"fxaa_enabled": 1.0,
		"taa_enabled": 0.0,
		"debanding_enabled": 0.0,
		"ssao_intensity_multiplier": 0.25,
		"fog_density_multiplier": 0.55,
		"reflection_intensity_multiplier": 0.35,
		"board_glow_energy_multiplier": 0.25,
		"grass_density_multiplier": 0.35,
		"ground_radial_segments": 64.0,
	},
}
const LIGHT_BUDGETS := {
	"high": {
		"board_fill_count": 4,
		"board_glow_real_light_count": 8,
		"forest_rim_count": 6,
		"mood_light_count": 8,
		"garden_glow_real_light_count": 6,
		"inner_lamp_real_light_count": 6,
	},
	"medium": {
		"board_fill_count": 2,
		"board_glow_real_light_count": 4,
		"forest_rim_count": 3,
		"mood_light_count": 4,
		"garden_glow_real_light_count": 3,
		"inner_lamp_real_light_count": 4,
	},
	"low": {
		"board_fill_count": 1,
		"board_glow_real_light_count": 0,
		"forest_rim_count": 0,
		"mood_light_count": 2,
		"garden_glow_real_light_count": 0,
		"inner_lamp_real_light_count": 2,
	},
}
const TIME_OF_DAY_PRESETS := [
	{"label": "日出", "hour": 5.5},
	{"label": "上午", "hour": 9.0},
	{"label": "正午", "hour": 12.5},
	{"label": "黄昏", "hour": 17.5},
	{"label": "夜晚", "hour": 21.0},
]
const TIME_OF_DAY_KEYFRAMES := [
	{
		"time": 0.0,
		"label": "深夜",
		"sun_energy": 0.0,
		"ambient_energy": 0.28,
		"fill_energy": 0.025,
		"exposure": 0.82,
		"fog_density": 0.010,
		"fog_sky_affect": 0.42,
		"sun_pitch": -72.0,
		"sun_yaw": -160.0,
		"sun_color": Color(0.48, 0.58, 0.86),
		"fill_color": Color(0.32, 0.42, 0.72),
		"sky_top": Color(0.015, 0.025, 0.06),
		"sky_horizon": Color(0.05, 0.07, 0.12),
		"floor_tint": Color(0.22, 0.34, 0.22),
		"board_glow_energy": 0.22,
		"marker_glow_energy": 1.7,
		"firefly_energy": 1.0,
		"mood_light_scale": 1.0,
		"forest_rim_scale": 0.85,
		"inner_lamp_scale": 1.0,
	},
	{
		"time": 5.5,
		"label": "日出",
		"sun_energy": 0.035,
		"ambient_energy": 0.42,
		"fill_energy": 0.035,
		"exposure": 0.88,
		"fog_density": 0.009,
		"fog_sky_affect": 0.36,
		"sun_pitch": -12.0,
		"sun_yaw": -118.0,
		"sun_color": Color(1.0, 0.58, 0.32),
		"fill_color": Color(0.55, 0.62, 0.86),
		"sky_top": Color(0.18, 0.22, 0.42),
		"sky_horizon": Color(1.0, 0.58, 0.34),
		"floor_tint": Color(0.36, 0.48, 0.28),
		"board_glow_energy": 0.16,
		"marker_glow_energy": 0.84,
		"firefly_energy": 0.55,
		"mood_light_scale": 0.65,
		"forest_rim_scale": 0.55,
		"inner_lamp_scale": 0.45,
	},
	{
		"time": 9.0,
		"label": "上午",
		"sun_energy": 0.42,
		"ambient_energy": 0.88,
		"fill_energy": 0.075,
		"exposure": 1.02,
		"fog_density": 0.0008,
		"fog_sky_affect": 0.05,
		"sun_pitch": -34.0,
		"sun_yaw": -132.0,
		"sun_color": Color(1.0, 0.88, 0.66),
		"fill_color": Color(0.86, 0.92, 1.0),
		"sky_top": Color(0.34, 0.58, 0.88),
		"sky_horizon": Color(0.76, 0.88, 0.96),
		"floor_tint": Color(0.70, 0.92, 0.46),
		"board_glow_energy": 0.015,
		"marker_glow_energy": 0.48,
		"firefly_energy": 0.0,
		"mood_light_scale": 0.0,
		"forest_rim_scale": 0.0,
		"inner_lamp_scale": 0.0,
	},
	{
		"time": 12.5,
		"label": "正午",
		"sun_energy": 0.48,
		"ambient_energy": 0.92,
		"fill_energy": 0.06,
		"exposure": 1.0,
		"fog_density": 0.0006,
		"fog_sky_affect": 0.04,
		"sun_pitch": -58.0,
		"sun_yaw": -150.0,
		"sun_color": Color(1.0, 0.96, 0.84),
		"fill_color": Color(0.88, 0.94, 1.0),
		"sky_top": Color(0.28, 0.58, 0.92),
		"sky_horizon": Color(0.78, 0.90, 0.98),
		"floor_tint": Color(0.68, 0.94, 0.48),
		"board_glow_energy": 0.0,
		"marker_glow_energy": 0.45,
		"firefly_energy": 0.0,
		"mood_light_scale": 0.0,
		"forest_rim_scale": 0.0,
		"inner_lamp_scale": 0.0,
	},
	{
		"time": 17.5,
		"label": "黄昏",
		"sun_energy": 0.30,
		"ambient_energy": 0.72,
		"fill_energy": 0.07,
		"exposure": 0.98,
		"fog_density": 0.002,
		"fog_sky_affect": 0.12,
		"sun_pitch": -14.0,
		"sun_yaw": -40.0,
		"sun_color": Color(1.0, 0.58, 0.30),
		"fill_color": Color(0.62, 0.70, 0.95),
		"sky_top": Color(0.32, 0.38, 0.68),
		"sky_horizon": Color(1.0, 0.56, 0.34),
		"floor_tint": Color(0.62, 0.78, 0.38),
		"board_glow_energy": 0.06,
		"marker_glow_energy": 0.66,
		"firefly_energy": 0.10,
		"mood_light_scale": 0.25,
		"forest_rim_scale": 0.15,
		"inner_lamp_scale": 0.25,
	},
	{
		"time": 21.0,
		"label": "夜晚",
		"sun_energy": 0.0,
		"ambient_energy": 0.38,
		"fill_energy": 0.03,
		"exposure": 0.90,
		"fog_density": 0.006,
		"fog_sky_affect": 0.25,
		"sun_pitch": -68.0,
		"sun_yaw": 40.0,
		"sun_color": Color(0.42, 0.52, 0.86),
		"fill_color": Color(0.28, 0.36, 0.72),
		"sky_top": Color(0.015, 0.025, 0.06),
		"sky_horizon": Color(0.04, 0.06, 0.12),
		"floor_tint": Color(0.20, 0.32, 0.22),
		"board_glow_energy": 0.24,
		"marker_glow_energy": 1.9,
		"firefly_energy": 1.0,
		"mood_light_scale": 1.0,
		"forest_rim_scale": 0.85,
		"inner_lamp_scale": 1.0,
	},
	{
		"time": 24.0,
		"label": "深夜",
		"same_as": 0.0,
	},
]
const LIGHTING_PRESET_ORDER := [
	"cover_meadow",
	"performance_clean",
	"quiet_forest",
	"balanced_clear",
	"polished_stone",
	"soft_day",
	"overcast",
	"studio_soft",
	"supersample_mirror",
]
const LIGHTING_PRESETS := {
	"cover_meadow": {
		"label": "封面花园",
		"ambient_energy": 0.82,
		"sun_energy": 0.105,
		"fill_energy": 0.055,
		"reflection_intensity": 0.045,
		"exposure": 0.96,
		"ssao_intensity": 0.38,
		"render_scale": 1.2,
		"msaa_level": 2.0,
		"fxaa_enabled": 1.0,
		"taa_enabled": 0.0,
		"debanding_enabled": 1.0,
		"floor_tint_r": 0.58,
		"floor_tint_g": 0.82,
		"floor_tint_b": 0.42,
		"floor_normal_scale": 0.16,
		"fog_density": 0.0008,
		"fog_sky_affect": 0.04,
		"sun_pitch": -38.0,
		"sun_yaw": -132.0,
		"sun_angular_distance": 12.0,
		"board_fill_scale": 0.75,
		"forest_rim_scale": 0.0,
		"mood_light_scale": 0.0,
		"firefly_energy": 0.0,
		"board_glow_energy": 0.035,
		"marker_glow_energy": 0.58,
	},
	"performance_clean": {
		"label": "性能清爽",
		"ambient_energy": 0.72,
		"sun_energy": 0.06,
		"fill_energy": 0.04,
		"reflection_intensity": 0.035,
		"exposure": 0.9,
		"ssao_intensity": 0.35,
		"render_scale": 0.9,
		"msaa_level": 0.0,
		"fxaa_enabled": 1.0,
		"taa_enabled": 0.0,
		"debanding_enabled": 0.0,
		"floor_tint_r": 0.45,
		"floor_tint_g": 0.66,
		"floor_tint_b": 0.36,
		"floor_normal_scale": 0.22,
		"fog_density": 0.003,
		"fog_sky_affect": 0.18,
		"sun_pitch": -24.0,
		"sun_yaw": -132.0,
		"sun_angular_distance": 18.0,
		"board_fill_scale": 0.9,
		"forest_rim_scale": 0.75,
		"mood_light_scale": 0.7,
		"firefly_energy": 0.45,
		"board_glow_energy": 0.16,
		"marker_glow_energy": 0.78,
	},
	"quiet_forest": {
		"label": "静谧丛林",
		"ambient_energy": 0.66,
		"sun_energy": 0.045,
		"fill_energy": 0.045,
		"reflection_intensity": 0.03,
		"exposure": 0.86,
		"ssao_intensity": 0.72,
		"render_scale": 1.05,
		"msaa_level": 2.0,
		"fxaa_enabled": 1.0,
		"taa_enabled": 0.0,
		"debanding_enabled": 1.0,
		"floor_tint_r": 0.28,
		"floor_tint_g": 0.48,
		"floor_tint_b": 0.24,
		"floor_normal_scale": 0.2,
		"fog_density": 0.008,
		"fog_sky_affect": 0.38,
		"sun_pitch": -22.0,
		"sun_yaw": -142.0,
		"sun_angular_distance": 18.0,
		"board_fill_scale": 0.8,
		"forest_rim_scale": 0.75,
		"mood_light_scale": 0.65,
		"firefly_energy": 0.95,
		"board_glow_energy": 0.14,
		"marker_glow_energy": 0.72,
	},
	"balanced_clear": {
		"label": "均衡清晰",
		"ambient_energy": 0.74,
		"sun_energy": 0.07,
		"fill_energy": 0.05,
		"reflection_intensity": 0.035,
		"exposure": 0.9,
		"ssao_intensity": 0.85,
		"render_scale": 1.1,
		"msaa_level": 2.0,
		"fxaa_enabled": 1.0,
		"taa_enabled": 0.0,
		"debanding_enabled": 0.0,
		"floor_tint_r": 0.56,
		"floor_tint_g": 0.82,
		"floor_tint_b": 0.46,
		"floor_normal_scale": 0.32,
		"fog_density": 0.004,
		"fog_sky_affect": 0.25,
		"sun_pitch": -24.0,
		"sun_yaw": -132.0,
		"sun_angular_distance": 16.0,
		"board_fill_scale": 0.95,
		"forest_rim_scale": 0.8,
		"mood_light_scale": 0.7,
		"firefly_energy": 0.45,
		"board_glow_energy": 0.16,
		"marker_glow_energy": 0.72,
	},
	"polished_stone": {
		"label": "镜面石板",
		"ambient_energy": 0.68,
		"sun_energy": 0.055,
		"fill_energy": 0.05,
		"reflection_intensity": 0.055,
		"exposure": 0.86,
		"ssao_intensity": 0.9,
		"render_scale": 1.25,
		"msaa_level": 2.0,
		"fxaa_enabled": 1.0,
		"taa_enabled": 0.0,
		"debanding_enabled": 1.0,
		"floor_tint_r": 0.48,
		"floor_tint_g": 0.7,
		"floor_tint_b": 0.38,
		"floor_normal_scale": 0.24,
		"fog_density": 0.0045,
		"fog_sky_affect": 0.28,
		"sun_pitch": -22.0,
		"sun_yaw": -148.0,
		"sun_angular_distance": 18.0,
		"board_fill_scale": 0.75,
		"forest_rim_scale": 0.7,
		"mood_light_scale": 0.65,
		"firefly_energy": 0.55,
		"board_glow_energy": 0.12,
		"marker_glow_energy": 0.62,
	},
	"supersample_mirror": {
		"label": "超采样镜面",
		"ambient_energy": 0.66,
		"sun_energy": 0.05,
		"fill_energy": 0.052,
		"reflection_intensity": 0.065,
		"exposure": 0.85,
		"ssao_intensity": 0.8,
		"render_scale": 1.4,
		"msaa_level": 4.0,
		"fxaa_enabled": 1.0,
		"taa_enabled": 0.0,
		"debanding_enabled": 1.0,
		"floor_tint_r": 0.48,
		"floor_tint_g": 0.7,
		"floor_tint_b": 0.38,
		"floor_normal_scale": 0.24,
		"fog_density": 0.0045,
		"fog_sky_affect": 0.28,
		"sun_pitch": -22.0,
		"sun_yaw": -150.0,
		"sun_angular_distance": 18.0,
		"board_fill_scale": 0.75,
		"forest_rim_scale": 0.7,
		"mood_light_scale": 0.65,
		"firefly_energy": 0.55,
		"board_glow_energy": 0.12,
		"marker_glow_energy": 0.62,
	},
	"soft_day": {
		"label": "柔和日光",
		"ambient_energy": 0.74,
		"sun_energy": 0.06,
		"fill_energy": 0.045,
		"reflection_intensity": 0.035,
		"exposure": 0.9,
		"ssao_intensity": 1.05,
		"render_scale": 1.2,
		"board_glow_energy": 0.14,
		"marker_glow_energy": 0.72,
	},
	"balanced": {
		"label": "均衡自然",
		"ambient_energy": 0.72,
		"sun_energy": 0.07,
		"fill_energy": 0.05,
		"reflection_intensity": 0.04,
		"exposure": 0.9,
		"ssao_intensity": 1.25,
		"render_scale": 1.2,
		"board_glow_energy": 0.14,
		"marker_glow_energy": 0.72,
	},
	"overcast": {
		"label": "阴天漫射",
		"ambient_energy": 0.82,
		"sun_energy": 0.02,
		"fill_energy": 0.04,
		"reflection_intensity": 0.02,
		"exposure": 0.88,
		"ssao_intensity": 0.92,
		"render_scale": 1.2,
		"board_glow_energy": 0.18,
		"marker_glow_energy": 0.78,
	},
	"studio_soft": {
		"label": "柔光展示",
		"ambient_energy": 0.74,
		"sun_energy": 0.04,
		"fill_energy": 0.07,
		"reflection_intensity": 0.035,
		"exposure": 0.9,
		"ssao_intensity": 1.08,
		"render_scale": 1.2,
		"board_glow_energy": 0.16,
		"marker_glow_energy": 0.76,
	},
}

var _environment_node: WorldEnvironment
var _environment: Environment
var _procedural_sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _soft_fill: DirectionalLight3D
var _board_fill_lights: Array[OmniLight3D] = []
var _board_glow_spots: Array[Node3D] = []
var _forest_rim_lights: Array[OmniLight3D] = []
var _mood_lights: Array[OmniLight3D] = []
var _reflection_probe: ReflectionProbe
var _floor: MeshInstance3D
var _floor_material: StandardMaterial3D
var _firefly_material: StandardMaterial3D
var _props_root: Node3D
var _grass_blade_layer: MultiMeshInstance3D
var _noise_textures: Dictionary = {}
var _lighting_preset_id := "cover_meadow"
var _lighting_settings: Dictionary = {}
var _render_cost_profile_id := DEFAULT_RENDER_COST_PROFILE_ID
var _render_cost_settings: Dictionary = RENDER_COST_PROFILES[DEFAULT_RENDER_COST_PROFILE_ID].duplicate(true)
var _time_of_day_target := 10.0
var _time_lighting_settings: Dictionary = {}
var _board_manager: Node = null
var _inner_lamps_root: Node3D
var _inner_board_lamps: Array[Node3D] = []
var _inner_lamp_lights: Array[SpotLight3D] = []
var _inner_lamp_bulbs: Array[MeshInstance3D] = []
var _inner_lamp_debug_lines: Array[MeshInstance3D] = []


func _ready() -> void:
	_configure_viewport_quality()
	_build_world_environment()
	_time_of_day_target = wrapf(time_of_day, 0.0, 24.0)
	apply_lighting_preset(_lighting_preset_id)
	_load_render_cost_profile()
	_load_saved_lighting_settings()
	_apply_time_of_day()
	_build_floor()
	_build_grass_blade_layer()
	_build_scene_props()
	_refresh_lighting_nodes()
	call_deferred("_build_inner_board_lamps")
	call_deferred("_apply_cover_meadow_on_start_if_needed")


func _process(delta: float) -> void:
	if auto_time_cycle_enabled:
		time_of_day = wrapf(time_of_day + 24.0 * delta / maxf(day_length_seconds, 1.0), 0.0, 24.0)
		_time_of_day_target = time_of_day
		_apply_time_of_day()
		return

	var diff := _shortest_hour_delta(time_of_day, _time_of_day_target)
	if absf(diff) <= 0.01:
		return
	time_of_day = wrapf(time_of_day + diff * minf(delta * time_transition_speed, 1.0), 0.0, 24.0)
	_apply_time_of_day()


func _configure_viewport_quality() -> void:
	Engine.max_fps = target_fps
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	var viewport := get_viewport()
	_set_property_if_available(viewport, "msaa_3d", Viewport.MSAA_2X)
	_set_property_if_available(viewport, "screen_space_aa", Viewport.SCREEN_SPACE_AA_FXAA)
	_set_property_if_available(viewport, "use_taa", false)
	_set_property_if_available(viewport, "use_debanding", false)
	_set_property_if_available(viewport, "scaling_3d_mode", 0)
	_set_property_if_available(viewport, "scaling_3d_scale", 1.2)


func _build_world_environment() -> void:
	_environment_node = WorldEnvironment.new()
	_environment_node.name = "WorldEnvironment"
	add_child(_environment_node)

	_environment = Environment.new()
	var sky := Sky.new()
	var panorama_texture = load(hdri_path) if not use_procedural_blue_sky else null
	if panorama_texture != null and not use_procedural_blue_sky:
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = panorama_texture
		sky.sky_material = panorama
	else:
		var procedural := ProceduralSkyMaterial.new()
		_procedural_sky_material = procedural
		procedural.sky_top_color = Color(0.16, 0.34, 0.58)
		procedural.sky_horizon_color = Color(0.54, 0.68, 0.74)
		procedural.sky_curve = 0.18
		procedural.sky_energy_multiplier = 0.76
		procedural.ground_bottom_color = Color(0.18, 0.38, 0.16)
		procedural.ground_horizon_color = Color(0.54, 0.78, 0.42)
		sky.sky_material = procedural

	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_energy = 0.58
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.tonemap_exposure = 0.9
	_environment.tonemap_white = 3.0
	_environment.glow_enabled = false
	_environment.ssao_enabled = true
	_environment.ssao_intensity = 1.42
	_environment.ssao_radius = 1.15
	_environment.ssil_enabled = false
	_environment.ssr_enabled = false
	_environment.fog_enabled = true
	_environment.fog_density = 0.004
	_environment.fog_sky_affect = 0.25
	_environment_node.environment = _environment

	_sun = DirectionalLight3D.new()
	_sun.name = "BackgroundSun"
	_sun.light_energy = 0.06
	_sun.light_angular_distance = 16.0
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.018
	_sun.shadow_normal_bias = 0.72
	_sun.shadow_blur = 1.35
	_sun.rotation_degrees = Vector3(-24.0, -132.0, 0.0)
	_set_property_if_available(_sun, "light_specular", 0.03)
	_set_property_if_available(_sun, "directional_shadow_max_distance", 32.0)
	_set_property_if_available(_sun, "directional_shadow_blend_splits", true)
	add_child(_sun)

	_soft_fill = DirectionalLight3D.new()
	_soft_fill.name = "SoftFillLight"
	_soft_fill.light_energy = 0.1
	_soft_fill.light_color = Color(0.78, 0.86, 1.0)
	_soft_fill.rotation_degrees = Vector3(-28.0, 140.0, 0.0)
	_set_property_if_available(_soft_fill, "light_specular", 0.12)
	add_child(_soft_fill)
	_build_board_accent_lights()
	_build_board_glow_spots()
	_build_board_reflection_probe()


func _build_board_accent_lights() -> void:
	_board_fill_lights.clear()
	var placements := [
		Vector3(-6.0, 5.0, -6.0),
		Vector3(6.0, 5.0, -6.0),
		Vector3(6.0, 5.0, 6.0),
		Vector3(-6.0, 5.0, 6.0),
	]
	for index in range(placements.size()):
		var light := OmniLight3D.new()
		light.name = "BoardFill_%d" % index
		light.position = placements[index]
		light.light_color = Color(0.94, 0.96, 1.0)
		light.light_energy = 0.05
		light.omni_range = 11.0
		light.shadow_enabled = false
		light.set_meta("light_group", "board_fill")
		light.set_meta("priority", index)
		_set_property_if_available(light, "light_specular", 0.08)
		add_child(light)
		_board_fill_lights.append(light)


func _build_board_glow_spots() -> void:
	_board_glow_spots.clear()
	if not board_glow_spots_enabled:
		return
	var placements := [
		{"pos": Vector3(-4.8, 0.0, -2.7), "radius": 0.26, "scale": 0.85, "color": Color(0.72, 0.86, 1.0, 0.2)},
		{"pos": Vector3(-2.7, 0.0, -3.9), "radius": 0.18, "scale": 0.55, "color": Color(1.0, 0.86, 0.58, 0.16)},
		{"pos": Vector3(-0.4, 0.0, -4.2), "radius": 0.22, "scale": 0.7, "color": Color(0.72, 0.86, 1.0, 0.18)},
		{"pos": Vector3(2.3, 0.0, -3.6), "radius": 0.2, "scale": 0.58, "color": Color(0.82, 0.92, 1.0, 0.16)},
		{"pos": Vector3(4.8, 0.0, -2.0), "radius": 0.28, "scale": 0.82, "color": Color(1.0, 0.88, 0.62, 0.17)},
		{"pos": Vector3(5.4, 0.0, 0.2), "radius": 0.19, "scale": 0.55, "color": Color(0.68, 0.82, 1.0, 0.16)},
		{"pos": Vector3(4.2, 0.0, 2.4), "radius": 0.25, "scale": 0.76, "color": Color(0.72, 0.86, 1.0, 0.18)},
		{"pos": Vector3(2.2, 0.0, 3.8), "radius": 0.18, "scale": 0.52, "color": Color(1.0, 0.84, 0.52, 0.15)},
		{"pos": Vector3(-0.2, 0.0, 4.1), "radius": 0.23, "scale": 0.68, "color": Color(0.72, 0.86, 1.0, 0.17)},
		{"pos": Vector3(-2.8, 0.0, 3.4), "radius": 0.2, "scale": 0.58, "color": Color(0.82, 0.92, 1.0, 0.15)},
		{"pos": Vector3(-4.7, 0.0, 1.5), "radius": 0.27, "scale": 0.78, "color": Color(1.0, 0.88, 0.62, 0.16)},
		{"pos": Vector3(-5.4, 0.0, -0.5), "radius": 0.18, "scale": 0.5, "color": Color(0.68, 0.82, 1.0, 0.15)},
		{"pos": Vector3(-3.0, 0.0, -0.4), "radius": 0.2, "scale": 0.55, "color": Color(0.74, 0.88, 1.0, 0.15)},
		{"pos": Vector3(-1.5, 0.0, -1.8), "radius": 0.24, "scale": 0.72, "color": Color(1.0, 0.86, 0.58, 0.16)},
		{"pos": Vector3(0.6, 0.0, -1.5), "radius": 0.18, "scale": 0.5, "color": Color(0.72, 0.86, 1.0, 0.14)},
		{"pos": Vector3(2.5, 0.0, -0.6), "radius": 0.22, "scale": 0.65, "color": Color(0.82, 0.92, 1.0, 0.15)},
		{"pos": Vector3(2.0, 0.0, 1.6), "radius": 0.2, "scale": 0.58, "color": Color(1.0, 0.86, 0.58, 0.15)},
		{"pos": Vector3(0.1, 0.0, 2.2), "radius": 0.25, "scale": 0.72, "color": Color(0.72, 0.86, 1.0, 0.16)},
		{"pos": Vector3(-2.0, 0.0, 1.4), "radius": 0.19, "scale": 0.52, "color": Color(0.8, 0.92, 1.0, 0.14)},
	]
	for index in range(placements.size()):
		var placement: Dictionary = placements[index]
		var root := Node3D.new()
		root.name = "BoardGlow_%d" % index
		root.position = placement.get("pos", Vector3.ZERO)
		root.set_meta("energy_scale", float(placement.get("scale", 0.6)))

		var color: Color = placement.get("color", Color(0.72, 0.86, 1.0, 0.16))
		var glow_mesh := MeshInstance3D.new()
		glow_mesh.name = "GlowDot"
		var mesh := CylinderMesh.new()
		var radius := float(placement.get("radius", 0.22))
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = 0.006
		mesh.radial_segments = 32
		glow_mesh.mesh = mesh
		glow_mesh.position.y = 0.078
		glow_mesh.material_override = _create_board_glow_material(color)
		root.add_child(glow_mesh)

		var light := OmniLight3D.new()
		light.name = "GlowLight"
		light.position.y = 0.62
		light.light_color = Color(color.r, color.g, color.b)
		light.light_energy = 0.0
		light.omni_range = 2.2 + radius * 2.2
		light.shadow_enabled = false
		light.set_meta("light_group", "board_glow")
		light.set_meta("priority", index)
		_set_property_if_available(light, "light_specular", 0.015)
		root.add_child(light)

		add_child(root)
		_board_glow_spots.append(root)


func _create_board_glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 0.45
	material.no_depth_test = false
	return material


func _build_board_reflection_probe() -> void:
	_reflection_probe = ReflectionProbe.new()
	_reflection_probe.name = "BoardReflectionProbe"
	_reflection_probe.position = Vector3(0.0, 2.4, 0.0)
	_reflection_probe.size = Vector3(22.0, 9.0, 22.0)
	_reflection_probe.origin_offset = Vector3(0.0, 1.1, 0.0)
	_reflection_probe.intensity = 0.05
	_reflection_probe.max_distance = 22.0
	_reflection_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(_reflection_probe)
	_refresh_lighting_nodes()


func _resolve_board_manager() -> void:
	if board_manager_path != NodePath("") and has_node(board_manager_path):
		_board_manager = get_node(board_manager_path)
		return
	var root := get_parent()
	if root != null and root.has_node("BoardManager"):
		_board_manager = root.get_node("BoardManager")


func _build_inner_board_lamps() -> void:
	_clear_inner_board_lamps()
	if not inner_lamps_enabled:
		return
	_resolve_board_manager()
	if _board_manager == null or not _board_manager.has_method("coord_to_world"):
		push_warning("Inner board lamps skipped: BoardManager not found or coord_to_world missing.")
		return

	_inner_lamps_root = Node3D.new()
	_inner_lamps_root.name = "InnerBoardLamps"
	add_child(_inner_lamps_root)

	for index in range(INNER_CORNER_ANCHORS.size()):
		var anchor_coord: Vector2i = INNER_CORNER_ANCHORS[index]
		var anchor_world: Vector3 = _get_board_coord_global_position(anchor_coord)
		var outward := Vector3(anchor_world.x, 0.0, anchor_world.z)
		if outward.length_squared() < 0.001:
			outward = Vector3.FORWARD
		else:
			outward = outward.normalized()

		var lamp_world := anchor_world + outward * inner_lamp_outset
		var aim_world := lamp_world.lerp(Vector3.ZERO, inner_lamp_aim_center_blend)
		aim_world.y = inner_lamp_aim_height
		var lamp := _create_inner_board_lamp(index, to_local(lamp_world), outward)
		lamp.set_meta("lamp_aim_world", aim_world)
		_inner_lamps_root.add_child(lamp)
		_inner_board_lamps.append(lamp)
		_aim_inner_lamp_light(lamp)

		if inner_lamp_debug_markers:
			_add_inner_lamp_debug_marker(anchor_world, Color(0.35, 0.8, 1.0))
			_add_inner_lamp_debug_marker(lamp_world, Color(1.0, 0.74, 0.22))
			_add_inner_lamp_debug_marker(aim_world, Color(1.0, 0.32, 0.18))

	_refresh_inner_board_lamps()
	_refresh_light_budget()


func _clear_inner_board_lamps() -> void:
	_inner_board_lamps.clear()
	_inner_lamp_lights.clear()
	_inner_lamp_bulbs.clear()
	_inner_lamp_debug_lines.clear()
	if _inner_lamps_root != null:
		_inner_lamps_root.queue_free()
		_inner_lamps_root = null


func _get_board_coord_global_position(coord: Vector2i) -> Vector3:
	var local_position: Vector3 = _board_manager.coord_to_world(coord)
	if _board_manager is Node3D:
		return (_board_manager as Node3D).to_global(local_position)
	return local_position


func _create_inner_board_lamp(index: int, local_position: Vector3, outward: Vector3) -> Node3D:
	var lamp := Node3D.new()
	lamp.name = "InnerLamp_%d" % index
	lamp.position = local_position
	lamp.rotation.y = atan2(outward.x, outward.z)

	var pole := MeshInstance3D.new()
	pole.name = "Pole"
	var pole_mesh := CylinderMesh.new()
	pole_mesh.height = inner_lamp_height
	pole_mesh.top_radius = inner_lamp_pole_radius
	pole_mesh.bottom_radius = inner_lamp_pole_radius
	pole_mesh.radial_segments = 12
	pole.mesh = pole_mesh
	pole.position = Vector3(0.0, inner_lamp_height * 0.5, 0.0)
	pole.material_override = _make_lamp_pole_material()
	lamp.add_child(pole)

	var arm := MeshInstance3D.new()
	arm.name = "Arm"
	var arm_mesh := CylinderMesh.new()
	arm_mesh.height = 0.55
	arm_mesh.top_radius = inner_lamp_pole_radius * 0.65
	arm_mesh.bottom_radius = inner_lamp_pole_radius * 0.65
	arm_mesh.radial_segments = 10
	arm.mesh = arm_mesh
	arm.position = Vector3(0.0, inner_lamp_light_height, -0.23)
	arm.rotation_degrees.x = 90.0
	arm.material_override = _make_lamp_pole_material()
	lamp.add_child(arm)

	var shade := MeshInstance3D.new()
	shade.name = "Shade"
	var shade_mesh := CylinderMesh.new()
	shade_mesh.height = 0.22
	shade_mesh.bottom_radius = 0.24
	shade_mesh.top_radius = 0.11
	shade_mesh.radial_segments = 16
	shade.mesh = shade_mesh
	shade.position = Vector3(0.0, inner_lamp_light_height - 0.03, -0.46)
	shade.rotation_degrees.x = 180.0
	shade.material_override = _make_lamp_shade_material()
	lamp.add_child(shade)

	var bulb := MeshInstance3D.new()
	bulb.name = "Bulb"
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = inner_lamp_bulb_radius
	bulb_mesh.height = inner_lamp_bulb_radius * 2.0
	bulb_mesh.radial_segments = 16
	bulb_mesh.rings = 8
	bulb.mesh = bulb_mesh
	bulb.position = Vector3(0.0, inner_lamp_light_height - 0.12, -0.46)
	bulb.material_override = _make_lamp_bulb_material(0.0)
	lamp.add_child(bulb)
	_inner_lamp_bulbs.append(bulb)

	var light := SpotLight3D.new()
	light.name = "LampLight"
	light.position = bulb.position
	light.light_color = inner_lamp_color
	light.light_energy = 0.0
	light.spot_range = inner_lamp_range
	light.spot_angle = inner_lamp_spot_angle
	light.spot_attenuation = inner_lamp_spot_attenuation
	light.shadow_enabled = false
	light.set_meta("light_group", "inner_lamp")
	light.set_meta("priority", index)
	lamp.add_child(light)
	_inner_lamp_lights.append(light)

	return lamp


func _aim_inner_lamp_light(lamp: Node3D) -> void:
	var light := lamp.get_node_or_null("LampLight") as SpotLight3D
	if light == null:
		return
	var aim_value = lamp.get_meta("lamp_aim_world", Vector3(0.0, inner_lamp_aim_height, 0.0))
	var aim_world: Vector3 = aim_value if aim_value is Vector3 else Vector3(0.0, inner_lamp_aim_height, 0.0)
	light.look_at(aim_world, Vector3.UP)


func _add_inner_lamp_debug_marker(global_position: Vector3, color: Color) -> void:
	if _inner_lamps_root == null:
		return
	var marker := MeshInstance3D.new()
	marker.name = "InnerLampDebugMarker"
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	marker.mesh = mesh
	marker.global_position = global_position + Vector3.UP * 0.08
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.6
	marker.material_override = material
	_inner_lamps_root.add_child(marker)
	_inner_lamp_debug_lines.append(marker)


func _make_lamp_pole_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = inner_lamp_pole_color
	material.roughness = 0.65
	material.metallic = 0.15
	return material


func _make_lamp_shade_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = inner_lamp_shade_color
	material.roughness = 0.75
	material.metallic = 0.05
	return material


func _make_lamp_bulb_material(energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = inner_lamp_color
	material.emission_enabled = true
	material.emission = inner_lamp_color
	material.emission_energy_multiplier = energy
	return material


func get_lighting_presets() -> Array[Dictionary]:
	var presets: Array[Dictionary] = [{
		"id": "custom",
		"label": "自定义",
	}]
	for preset_id in LIGHTING_PRESET_ORDER:
		if not LIGHTING_PRESETS.has(preset_id):
			continue
		var preset: Dictionary = LIGHTING_PRESETS[preset_id]
		presets.append({
			"id": preset_id,
			"label": String(preset.get("label", preset_id)),
		})
	return presets


func get_lighting_settings() -> Dictionary:
	var settings := _lighting_settings.duplicate(true)
	settings["preset_id"] = _lighting_preset_id
	settings["render_cost_profile_id"] = _render_cost_profile_id
	settings["render_scale"] = float(_render_cost_settings.get("render_scale", settings.get("render_scale", 1.2)))
	return settings


func get_render_cost_profiles() -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	for profile_id in RENDER_COST_PROFILE_ORDER:
		if not RENDER_COST_PROFILES.has(profile_id):
			continue
		var profile: Dictionary = RENDER_COST_PROFILES[profile_id]
		profiles.append({
			"id": profile_id,
			"label": String(profile.get("label", profile_id)),
			"summary": String(profile.get("summary", "")),
		})
	return profiles


func get_render_cost_profile() -> Dictionary:
	var profile := {
		"id": _render_cost_profile_id,
		"label": _render_cost_profile_id,
		"summary": "",
	}
	if RENDER_COST_PROFILES.has(_render_cost_profile_id):
		var preset: Dictionary = RENDER_COST_PROFILES[_render_cost_profile_id]
		profile["label"] = String(preset.get("label", _render_cost_profile_id))
		profile["summary"] = String(preset.get("summary", ""))
	for parameter in _get_render_cost_limits().keys():
		profile[parameter] = float(_render_cost_settings.get(parameter, _get_render_cost_default(parameter)))
	return profile


func get_render_cost_profile_id() -> String:
	return _render_cost_profile_id


func get_time_of_day_presets() -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	for preset in TIME_OF_DAY_PRESETS:
		presets.append((preset as Dictionary).duplicate(true))
	return presets


func set_time_of_day(hour: float, immediate := false) -> void:
	_time_of_day_target = wrapf(hour, 0.0, 24.0)
	if immediate:
		time_of_day = _time_of_day_target
		_apply_time_of_day()


func set_auto_time_cycle_enabled(enabled: bool) -> void:
	auto_time_cycle_enabled = enabled
	if enabled:
		_time_of_day_target = time_of_day


func apply_cover_meadow_visual_target() -> void:
	apply_lighting_preset("cover_meadow")
	set_time_of_day(10.0, true)
	set_auto_time_cycle_enabled(false)


func _apply_cover_meadow_on_start_if_needed() -> void:
	if force_cover_meadow_on_start:
		apply_cover_meadow_visual_target()


func apply_lighting_preset(preset_id: String) -> void:
	if not LIGHTING_PRESETS.has(preset_id):
		return
	_lighting_preset_id = preset_id
	_apply_lighting_settings((LIGHTING_PRESETS[preset_id] as Dictionary).duplicate(true))


func apply_render_cost_profile(profile_id: String, persist := true) -> void:
	if not RENDER_COST_PROFILES.has(profile_id):
		push_warning("Unknown render cost profile: %s" % profile_id)
		return
	_render_cost_profile_id = profile_id
	_render_cost_settings = (RENDER_COST_PROFILES[profile_id] as Dictionary).duplicate(true)
	_apply_render_cost_settings()
	if persist:
		_save_render_cost_profile()


func set_lighting_value(parameter: String, value: float) -> void:
	if not _get_lighting_limits().has(parameter):
		return
	var limits: Vector2 = _get_lighting_limits()[parameter]
	_lighting_settings[parameter] = clampf(value, limits.x, limits.y)
	_lighting_preset_id = "custom"
	_refresh_lighting_nodes()
	lighting_settings_changed.emit(get_lighting_settings())


func save_lighting_settings() -> Dictionary:
	var config := ConfigFile.new()
	config.set_value("lighting", "preset_id", _lighting_preset_id)
	for parameter in _get_lighting_limits().keys():
		config.set_value("lighting", parameter, float(_lighting_settings.get(parameter, 0.0)))
	var save_result := config.save(LIGHTING_PROFILE_PATH)
	if save_result != OK:
		return {
			"ok": false,
			"summary": "保存光影配置失败：%d" % save_result,
		}
	return {
		"ok": true,
		"summary": "已保存光影配置，下次启动会自动加载",
	}


func _load_saved_lighting_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var config := ConfigFile.new()
	if config.load(LIGHTING_PROFILE_PATH) != OK:
		return
	var saved: Dictionary = {}
	for parameter in _get_lighting_limits().keys():
		saved[parameter] = float(config.get_value("lighting", parameter, _lighting_settings.get(parameter, _get_lighting_default(parameter))))
	_lighting_preset_id = String(config.get_value("lighting", "preset_id", "custom"))
	_apply_lighting_settings(saved)


func _save_render_cost_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("render_cost", "profile_id", _render_cost_profile_id)
	var save_result := config.save(RENDER_COST_PROFILE_CONFIG_PATH)
	if save_result != OK:
		push_warning("Failed to save render cost profile: %d" % save_result)


func _load_render_cost_profile() -> void:
	if DisplayServer.get_name() == "headless":
		apply_render_cost_profile(DEFAULT_RENDER_COST_PROFILE_ID, false)
		return
	var config := ConfigFile.new()
	if config.load(RENDER_COST_PROFILE_CONFIG_PATH) != OK:
		apply_render_cost_profile(DEFAULT_RENDER_COST_PROFILE_ID, false)
		return
	var profile_id := String(config.get_value("render_cost", "profile_id", DEFAULT_RENDER_COST_PROFILE_ID))
	apply_render_cost_profile(profile_id, false)


func _apply_lighting_settings(settings: Dictionary) -> void:
	for parameter in _get_lighting_limits().keys():
		var limits: Vector2 = _get_lighting_limits()[parameter]
		var default_value := float(_lighting_settings.get(parameter, _get_lighting_default(parameter)))
		_lighting_settings[parameter] = clampf(float(settings.get(parameter, default_value)), limits.x, limits.y)
	_refresh_lighting_nodes()
	lighting_settings_changed.emit(get_lighting_settings())


func _apply_render_cost_settings() -> void:
	for parameter in _get_render_cost_limits().keys():
		if not _render_cost_settings.has(parameter):
			continue
		var limits: Vector2 = _get_render_cost_limits()[parameter]
		_render_cost_settings[parameter] = clampf(float(_render_cost_settings[parameter]), limits.x, limits.y)
	_refresh_lighting_nodes()
	render_cost_profile_changed.emit(get_render_cost_profile())
	lighting_settings_changed.emit(get_lighting_settings())


func _apply_time_of_day() -> void:
	_time_lighting_settings = _sample_time_of_day_settings(time_of_day)
	_refresh_lighting_nodes()


func _sample_time_of_day_settings(hour: float) -> Dictionary:
	var wrapped_hour := wrapf(hour, 0.0, 24.0)
	var previous := _expand_time_keyframe(TIME_OF_DAY_KEYFRAMES[0])
	var next := _expand_time_keyframe(TIME_OF_DAY_KEYFRAMES[0])

	for index in range(TIME_OF_DAY_KEYFRAMES.size() - 1):
		var a := _expand_time_keyframe(TIME_OF_DAY_KEYFRAMES[index])
		var b := _expand_time_keyframe(TIME_OF_DAY_KEYFRAMES[index + 1])
		var start_time := float(a.get("time", 0.0))
		var end_time := float(b.get("time", 24.0))
		if wrapped_hour >= start_time and wrapped_hour <= end_time:
			previous = a
			next = b
			break

	var previous_time := float(previous.get("time", 0.0))
	var next_time := float(next.get("time", previous_time))
	var span := maxf(next_time - previous_time, 0.001)
	var t := clampf((wrapped_hour - previous_time) / span, 0.0, 1.0)
	var result := {}
	for key in previous.keys():
		if key == "same_as":
			continue
		result[key] = previous[key]
	for key in next.keys():
		if key == "same_as":
			continue
		var a_value = previous.get(key, next[key])
		var b_value = next[key]
		if a_value is Color and b_value is Color:
			result[key] = (a_value as Color).lerp(b_value as Color, t)
		elif _is_numeric_variant(a_value) and _is_numeric_variant(b_value):
			result[key] = lerpf(float(a_value), float(b_value), t)
		else:
			result[key] = b_value
	return result


func _expand_time_keyframe(keyframe: Dictionary) -> Dictionary:
	if not keyframe.has("same_as"):
		return keyframe
	var target_time := float(keyframe.get("same_as", 0.0))
	for candidate in TIME_OF_DAY_KEYFRAMES:
		var candidate_dict: Dictionary = candidate
		if not candidate_dict.has("same_as") and is_equal_approx(float(candidate_dict.get("time", -1.0)), target_time):
			var expanded := candidate_dict.duplicate(true)
			expanded["time"] = float(keyframe.get("time", target_time))
			expanded["label"] = String(keyframe.get("label", expanded.get("label", "")))
			return expanded
	return keyframe


func _shortest_hour_delta(from_hour: float, to_hour: float) -> float:
	var diff := wrapf(to_hour - from_hour + 12.0, 0.0, 24.0) - 12.0
	return diff


func _is_numeric_variant(value) -> bool:
	var value_type := typeof(value)
	return value_type == TYPE_FLOAT or value_type == TYPE_INT


func _get_final_lighting_value(key: String, fallback: float) -> float:
	return float(_time_lighting_settings.get(key, _lighting_settings.get(key, fallback)))


func _get_final_lighting_color(key: String, fallback: Color) -> Color:
	var value = _time_lighting_settings.get(key, fallback)
	return value if value is Color else fallback


func _refresh_lighting_nodes() -> void:
	if _environment != null:
		_environment.ambient_light_energy = _get_final_lighting_value("ambient_energy", 0.6)
		_environment.tonemap_exposure = _get_final_lighting_value("exposure", 0.92)
		_environment.ssao_intensity = (
			float(_lighting_settings.get("ssao_intensity", 1.0))
			* float(_render_cost_settings.get("ssao_intensity_multiplier", 1.0))
		)
		_environment.ssao_enabled = _environment.ssao_intensity > 0.01
		_environment.fog_density = (
			_get_final_lighting_value("fog_density", 0.004)
			* float(_render_cost_settings.get("fog_density_multiplier", 1.0))
		)
		_environment.fog_enabled = _environment.fog_density > 0.0001
		_environment.fog_sky_affect = _get_final_lighting_value("fog_sky_affect", 0.25)
	if _sun != null:
		_sun.light_energy = _get_final_lighting_value("sun_energy", 0.4)
		_sun.light_color = _get_final_lighting_color("sun_color", Color(1.0, 0.92, 0.82))
		_sun.light_angular_distance = float(_lighting_settings.get("sun_angular_distance", 8.0))
		_set_property_if_available(_sun, "light_specular", 0.03)
		_sun.rotation_degrees = Vector3(
			_get_final_lighting_value("sun_pitch", -44.0),
			_get_final_lighting_value("sun_yaw", -38.0),
			0.0
		)
	if _soft_fill != null:
		_soft_fill.light_energy = _get_final_lighting_value("fill_energy", 0.03) * 1.2
		_soft_fill.light_color = _get_final_lighting_color("fill_color", Color(0.78, 0.86, 1.0))
		_set_property_if_available(_soft_fill, "light_specular", 0.12)
	for light in _board_fill_lights:
		if light != null:
			light.light_energy = _get_final_lighting_value("fill_energy", 0.03) * float(_lighting_settings.get("board_fill_scale", 1.0))
			_set_property_if_available(light, "light_specular", 0.08)
	for spot in _board_glow_spots:
		if spot == null:
			continue
		var glow_energy := (
			_get_final_lighting_value("board_glow_energy", 0.16)
			* float(_render_cost_settings.get("board_glow_energy_multiplier", 1.0))
		)
		var energy_scale := float(spot.get_meta("energy_scale", 0.6))
		spot.visible = glow_energy > 0.001
		for child in spot.get_children():
			if child is OmniLight3D:
				(child as OmniLight3D).light_energy = glow_energy * energy_scale
			elif child is MeshInstance3D:
				var mesh_instance := child as MeshInstance3D
				var material := mesh_instance.material_override as StandardMaterial3D
				if material != null:
					var alpha := clampf(glow_energy * energy_scale * 0.62, 0.0, 0.22)
					material.albedo_color.a = alpha
					material.emission_energy_multiplier = glow_energy * 1.4
	for light in _forest_rim_lights:
		if light != null:
			light.light_energy = (
				_get_final_lighting_value("fill_energy", 0.03)
				* float(light.get_meta("energy_scale", 2.2))
				* _get_final_lighting_value("forest_rim_scale", 1.0)
			)
	for light in _mood_lights:
		if light != null:
			light.light_energy = float(light.get_meta("base_energy", 0.1)) * _get_final_lighting_value("mood_light_scale", 1.0)
	if _reflection_probe != null:
		_reflection_probe.intensity = (
			float(_lighting_settings.get("reflection_intensity", 0.12))
			* float(_render_cost_settings.get("reflection_intensity_multiplier", 1.0))
		)
	_refresh_floor_mood()
	_refresh_firefly_mood()
	_refresh_marker_glow()
	_refresh_sky_time_settings()
	_refresh_render_cost_scene_detail()
	_refresh_inner_board_lamps()
	_refresh_light_budget()
	var viewport := get_viewport()
	if viewport != null:
		_apply_viewport_render_settings(viewport)
	call_deferred("_refresh_marker_glow")


func _refresh_marker_glow() -> void:
	var glow_energy := _get_final_lighting_value("marker_glow_energy", 0.55)
	for node in get_tree().get_nodes_in_group("view_focus_markers"):
		if node != null and node.has_method("set_marker_glow"):
			node.set_marker_glow(glow_energy)


func _get_lighting_limits() -> Dictionary:
	return {
		"ambient_energy": Vector2(0.2, 1.2),
		"sun_energy": Vector2(0.0, 0.6),
		"fill_energy": Vector2(0.0, 0.2),
		"reflection_intensity": Vector2(0.0, 0.35),
		"exposure": Vector2(0.6, 1.05),
		"ssao_intensity": Vector2(0.0, 2.4),
		"render_scale": Vector2(0.6, 1.4),
		"msaa_level": Vector2(0.0, 4.0),
		"fxaa_enabled": Vector2(0.0, 1.0),
		"taa_enabled": Vector2(0.0, 1.0),
		"debanding_enabled": Vector2(0.0, 1.0),
		"floor_tint_r": Vector2(0.18, 0.8),
		"floor_tint_g": Vector2(0.28, 1.0),
		"floor_tint_b": Vector2(0.16, 0.75),
		"floor_normal_scale": Vector2(0.0, 0.65),
		"fog_density": Vector2(0.0, 0.016),
		"fog_sky_affect": Vector2(0.0, 0.75),
		"sun_pitch": Vector2(-80.0, -18.0),
		"sun_yaw": Vector2(-180.0, 180.0),
		"sun_angular_distance": Vector2(1.0, 18.0),
		"board_fill_scale": Vector2(0.0, 1.2),
		"forest_rim_scale": Vector2(0.0, 1.2),
		"mood_light_scale": Vector2(0.0, 1.2),
		"firefly_energy": Vector2(0.0, 1.2),
		"board_glow_energy": Vector2(0.0, 0.5),
		"marker_glow_energy": Vector2(0.0, 3.0),
	}


func _get_render_cost_limits() -> Dictionary:
	return {
		"render_scale": Vector2(0.6, 1.4),
		"msaa_level": Vector2(0.0, 4.0),
		"fxaa_enabled": Vector2(0.0, 1.0),
		"taa_enabled": Vector2(0.0, 1.0),
		"debanding_enabled": Vector2(0.0, 1.0),
		"ssao_intensity_multiplier": Vector2(0.0, 1.0),
		"fog_density_multiplier": Vector2(0.0, 1.0),
		"reflection_intensity_multiplier": Vector2(0.0, 1.0),
		"board_glow_energy_multiplier": Vector2(0.0, 1.0),
		"grass_density_multiplier": Vector2(0.0, 1.0),
		"ground_radial_segments": Vector2(32.0, 128.0),
	}


func _get_lighting_default(parameter: String) -> float:
	match parameter:
		"ambient_energy":
			return 0.74
		"sun_energy":
			return 0.06
		"fill_energy":
			return 0.045
		"reflection_intensity":
			return 0.035
		"exposure":
			return 0.9
		"ssao_intensity":
			return 1.05
		"render_scale":
			return 1.2
		"msaa_level":
			return 2.0
		"fxaa_enabled":
			return 1.0
		"taa_enabled":
			return 0.0
		"debanding_enabled":
			return 0.0
		"floor_tint_r":
			return 0.64
		"floor_tint_g":
			return 0.94
		"floor_tint_b":
			return 0.58
		"floor_normal_scale":
			return 0.38
		"fog_density":
			return 0.004
		"fog_sky_affect":
			return 0.25
		"sun_pitch":
			return -24.0
		"sun_yaw":
			return -132.0
		"sun_angular_distance":
			return 18.0
		"board_fill_scale":
			return 0.95
		"forest_rim_scale":
			return 0.8
		"mood_light_scale":
			return 0.7
		"firefly_energy":
			return 0.45
		"board_glow_energy":
			return 0.16
		"marker_glow_energy":
			return 0.72
		_:
			return 0.0


func _get_render_cost_default(parameter: String) -> float:
	var defaults: Dictionary = RENDER_COST_PROFILES[DEFAULT_RENDER_COST_PROFILE_ID]
	return float(defaults.get(parameter, 0.0))


func _apply_viewport_render_settings(viewport: Viewport) -> void:
	var msaa_level := int(roundf(float(_render_cost_settings.get("msaa_level", 2.0))))
	var msaa_mode := Viewport.MSAA_DISABLED
	if msaa_level >= 4:
		msaa_mode = Viewport.MSAA_4X
	elif msaa_level >= 2:
		msaa_mode = Viewport.MSAA_2X
	_set_property_if_available(viewport, "msaa_3d", msaa_mode)
	_set_property_if_available(
		viewport,
		"screen_space_aa",
		Viewport.SCREEN_SPACE_AA_FXAA if float(_render_cost_settings.get("fxaa_enabled", 1.0)) >= 0.5 else Viewport.SCREEN_SPACE_AA_DISABLED
	)
	_set_property_if_available(viewport, "use_taa", float(_render_cost_settings.get("taa_enabled", 0.0)) >= 0.5)
	_set_property_if_available(viewport, "use_debanding", float(_render_cost_settings.get("debanding_enabled", 0.0)) >= 0.5)
	_set_property_if_available(viewport, "scaling_3d_scale", float(_render_cost_settings.get("render_scale", 1.2)))


func _refresh_render_cost_scene_detail() -> void:
	if _grass_blade_layer != null and _grass_blade_layer.multimesh != null:
		var ratio := clampf(float(_render_cost_settings.get("grass_density_multiplier", 1.0)), 0.0, 1.0)
		var visible_count := int(roundf(float(grass_blade_count) * ratio))
		_grass_blade_layer.visible = visible_count > 0
		_grass_blade_layer.multimesh.visible_instance_count = visible_count if visible_count < grass_blade_count else -1
	if _floor != null and _floor.mesh is CylinderMesh:
		var floor_mesh := _floor.mesh as CylinderMesh
		var radial_segments := int(roundf(float(_render_cost_settings.get("ground_radial_segments", 128.0))))
		if floor_mesh.radial_segments != radial_segments:
			floor_mesh.radial_segments = radial_segments


func _build_floor() -> void:
	_floor = MeshInstance3D.new()
	_floor.name = "GrassFloor"
	_floor.position = Vector3(0.0, -0.12, 0.0)

	var mesh := CylinderMesh.new()
	mesh.top_radius = floor_radius
	mesh.bottom_radius = floor_radius
	mesh.height = floor_height
	mesh.radial_segments = int(roundf(float(_render_cost_settings.get("ground_radial_segments", 128.0))))
	mesh.rings = 4
	_floor.mesh = mesh
	_floor.material_override = _build_floor_material()
	_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_floor)


func _build_floor_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	_floor_material = material
	material.albedo_color = Color(0.64, 0.94, 0.58)
	material.roughness = 0.84
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	material.normal_scale = 0.38
	material.uv1_scale = Vector3(floor_uv_repeat, floor_uv_repeat, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var albedo = load(floor_albedo_path)
	if albedo != null:
		material.albedo_texture = albedo

	var normal = load(floor_normal_path)
	if normal != null:
		material.normal_enabled = true
		material.normal_texture = normal

	var roughness = load(floor_roughness_path)
	if roughness != null:
		material.roughness_texture = roughness

	return material


func _refresh_floor_mood() -> void:
	if _floor_material == null:
		return
	var floor_tint := _get_final_lighting_color("floor_tint", Color(
		float(_lighting_settings.get("floor_tint_r", 0.64)),
		float(_lighting_settings.get("floor_tint_g", 0.94)),
		float(_lighting_settings.get("floor_tint_b", 0.58))
	))
	_floor_material.albedo_color = floor_tint
	_floor_material.normal_scale = float(_lighting_settings.get("floor_normal_scale", 0.38))


func _refresh_firefly_mood() -> void:
	if _firefly_material == null:
		return
	var energy := _get_final_lighting_value("firefly_energy", 0.45)
	_firefly_material.emission_enabled = energy > 0.01
	_firefly_material.emission_energy_multiplier = energy


func _refresh_inner_board_lamps() -> void:
	if _inner_board_lamps.is_empty():
		return
	var scale := _get_final_lighting_value("inner_lamp_scale", 0.0)
	var final_energy := inner_lamp_energy * scale
	var bulb_energy := clampf(scale * 1.8, 0.0, 2.2)
	for lamp in _inner_board_lamps:
		if is_instance_valid(lamp):
			lamp.visible = inner_lamps_enabled
	for bulb in _inner_lamp_bulbs:
		if not is_instance_valid(bulb):
			continue
		bulb.visible = inner_lamps_enabled
		if bulb.material_override is StandardMaterial3D:
			var material := bulb.material_override as StandardMaterial3D
			material.albedo_color = inner_lamp_color
			material.emission = inner_lamp_color
			material.emission_energy_multiplier = bulb_energy
	for light in _inner_lamp_lights:
		if not is_instance_valid(light):
			continue
		light.light_color = inner_lamp_color
		light.spot_range = inner_lamp_range
		light.spot_angle = inner_lamp_spot_angle
		light.spot_attenuation = inner_lamp_spot_attenuation
		light.shadow_enabled = false
		light.light_energy = final_energy if inner_lamps_enabled else 0.0


func _refresh_sky_time_settings() -> void:
	if _procedural_sky_material == null:
		return
	_procedural_sky_material.sky_top_color = _get_final_lighting_color("sky_top", _procedural_sky_material.sky_top_color)
	_procedural_sky_material.sky_horizon_color = _get_final_lighting_color("sky_horizon", _procedural_sky_material.sky_horizon_color)
	_procedural_sky_material.sky_energy_multiplier = clampf(_get_final_lighting_value("ambient_energy", 0.6) * 0.95, 0.18, 0.9)


func _refresh_light_budget() -> void:
	var budget: Dictionary = LIGHT_BUDGETS.get(_render_cost_profile_id, LIGHT_BUDGETS["high"])
	_apply_light_group_budget(_board_fill_lights, int(budget.get("board_fill_count", 4)))
	_apply_board_glow_light_budget(int(budget.get("board_glow_real_light_count", 8)))
	_apply_light_group_budget(_forest_rim_lights, int(budget.get("forest_rim_count", 6)))
	_apply_mood_light_budget(int(budget.get("mood_light_count", 8)), int(budget.get("garden_glow_real_light_count", 6)))
	_apply_light_budget_to_lamps(_inner_lamp_lights, int(budget.get("inner_lamp_real_light_count", 6)))


func _apply_light_group_budget(lights: Array[OmniLight3D], enabled_count: int) -> void:
	for index in range(lights.size()):
		var light := lights[index]
		if light == null:
			continue
		var enabled := index < enabled_count
		if not enabled:
			light.set_meta("budget_last_energy", light.light_energy)
			light.light_energy = 0.0
		light.visible = enabled


func _apply_board_glow_light_budget(enabled_count: int) -> void:
	var light_index := 0
	for spot in _board_glow_spots:
		if spot == null:
			continue
		for child in spot.get_children():
			if child is OmniLight3D:
				var light := child as OmniLight3D
				var enabled := light_index < enabled_count
				if not enabled:
					light.light_energy = 0.0
				light.visible = enabled
				light_index += 1


func _apply_mood_light_budget(mood_count: int, garden_count: int) -> void:
	var mood_index := 0
	var garden_index := 0
	for light in _mood_lights:
		if light == null:
			continue
		var group := String(light.get_meta("light_group", "mood"))
		var enabled := false
		if group == "garden_glow":
			enabled = garden_index < garden_count
			garden_index += 1
		else:
			enabled = mood_index < mood_count
			mood_index += 1
		if not enabled:
			light.light_energy = 0.0
		light.visible = enabled


func _apply_light_budget_to_lamps(lights: Array[SpotLight3D], active_count: int) -> void:
	for index in range(lights.size()):
		var light := lights[index]
		if not is_instance_valid(light):
			continue
		var enabled := index < active_count and inner_lamps_enabled and light.light_energy > 0.001
		if not enabled:
			light.light_energy = 0.0
		light.visible = enabled


func _build_grass_blade_layer() -> void:
	var layer := MultiMeshInstance3D.new()
	layer.name = "GrassBladeLayer"
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _build_grass_blade_cluster_mesh()
	multimesh.instance_count = grass_blade_count

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260602
	for index in range(grass_blade_count):
		var angle := rng.randf_range(0.0, TAU)
		var radius_lerp := sqrt(rng.randf())
		var radius := lerpf(grass_blade_inner_radius, grass_blade_outer_radius, radius_lerp)
		var position := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var scale_value := rng.randf_range(0.64, 1.1)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		basis = basis.scaled(Vector3(scale_value, rng.randf_range(0.72, 1.16), scale_value))
		multimesh.set_instance_transform(index, Transform3D(basis, position))

	layer.multimesh = multimesh
	_grass_blade_layer = layer
	add_child(layer)


func _build_grass_blade_cluster_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_build_grass_blade_material())
	for angle in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3(-direction.z, 0.0, direction.x) * 0.055
		var center := direction * 0.045
		var left := center - tangent
		var right := center + tangent
		var tip := center + Vector3(direction.x * 0.045, 0.26, direction.z * 0.045)
		_add_grass_vertex(surface, left, Vector2(0.0, 0.0))
		_add_grass_vertex(surface, right, Vector2(1.0, 0.0))
		_add_grass_vertex(surface, tip, Vector2(0.5, 1.0))
	surface.commit(mesh)
	return mesh


func _build_grass_blade_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.52, 0.22)
	material.roughness = 0.96
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _add_grass_vertex(surface: SurfaceTool, vertex: Vector3, uv: Vector2) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(uv)
	surface.add_vertex(vertex)


func _build_scene_props() -> void:
	_props_root = Node3D.new()
	_props_root.name = "BackgroundProps"
	add_child(_props_root)

	var placements := [
		{"asset": "tree_default.obj", "pos": Vector3(-17.0, 0.0, -11.0), "rot": 18.0, "scale": 2.8, "color": Color(0.36, 0.66, 0.3), "material": "leaf", "cast_shadow": true},
		{"asset": "tree_pineRoundA.obj", "pos": Vector3(-20.0, 0.0, 5.5), "rot": -22.0, "scale": 2.7, "color": Color(0.22, 0.52, 0.31), "material": "leaf_dark", "cast_shadow": true},
		{"asset": "tree_fat.obj", "pos": Vector3(18.0, 0.0, -8.5), "rot": 34.0, "scale": 3.0, "color": Color(0.43, 0.65, 0.28), "material": "leaf", "cast_shadow": true},
		{"asset": "tree_default.obj", "pos": Vector3(20.5, 0.0, 7.0), "rot": -48.0, "scale": 2.6, "color": Color(0.32, 0.62, 0.28), "material": "leaf", "cast_shadow": true},
		{"asset": "rock_largeA.obj", "pos": Vector3(-14.0, 0.0, 13.0), "rot": 8.0, "scale": 1.6, "color": Color(0.46, 0.49, 0.45), "material": "rock"},
		{"asset": "rock_smallA.obj", "pos": Vector3(14.5, 0.0, 12.5), "rot": 52.0, "scale": 1.7, "color": Color(0.5, 0.52, 0.48), "material": "rock"},
		{"asset": "plant_bush.obj", "pos": Vector3(-11.0, 0.0, -16.0), "rot": 0.0, "scale": 2.2, "color": Color(0.24, 0.55, 0.25), "material": "leaf_dark"},
		{"asset": "grass_large.obj", "pos": Vector3(11.5, 0.0, -16.5), "rot": -12.0, "scale": 1.8, "color": Color(0.46, 0.71, 0.34), "material": "grass"},
		{"asset": "flower_yellowA.obj", "pos": Vector3(-7.0, 0.0, 17.0), "rot": 28.0, "scale": 1.4, "color": Color(0.92, 0.76, 0.26), "material": "flower"},
		{"asset": "log.obj", "pos": Vector3(7.5, 0.0, 17.5), "rot": -32.0, "scale": 1.5, "color": Color(0.5, 0.32, 0.19), "material": "bark"},
		{"asset": "fence_simple.obj", "pos": Vector3(-22.0, 0.0, -1.0), "rot": 90.0, "scale": 1.8, "color": Color(0.58, 0.39, 0.24), "material": "bark"},
		{"asset": "fence_simple.obj", "pos": Vector3(22.0, 0.0, 1.5), "rot": -90.0, "scale": 1.8, "color": Color(0.58, 0.39, 0.24), "material": "bark"},
	]

	for placement in placements:
		_spawn_prop(placement)
	_build_cover_meadow_layout()
	_build_imported_environment_assets()
	_build_corner_landmarks()
	_build_board_garden_ring()
	_build_garden_water_feature()
	_build_edge_tree_ring()
	_build_forest_rim_lights()
	_build_grass_detail_ring()
	_build_canopy_shadow_layer()
	_build_firefly_layer()


func _build_cover_meadow_layout() -> void:
	if not cover_meadow_layout_enabled:
		return
	var layout_root := Node3D.new()
	layout_root.name = "CoverMeadowLayout"
	_props_root.add_child(layout_root)

	for index in range(COVER_MEADOW_PROP_POINTS.size()):
		var point: Dictionary = COVER_MEADOW_PROP_POINTS[index]
		var kind := String(point.get("kind", "prop"))
		var anchor := Node3D.new()
		anchor.name = "CoverMeadow_%s_%02d" % [kind, index]
		anchor.position = point.get("position", Vector3.ZERO)
		anchor.rotation_degrees.y = float(point.get("yaw", 0.0))
		anchor.scale = Vector3.ONE * float(point.get("scale", 1.0))
		layout_root.add_child(anchor)

		match kind:
			"pond":
				_build_cover_meadow_pond(anchor)
			"bridge":
				_build_cover_meadow_bridge(anchor)
			"pavilion":
				_build_garden_pavilion(anchor)
			"rock_cluster":
				_build_cover_meadow_rock_cluster(anchor)
			"flower_cluster":
				_build_cover_meadow_flower_cluster(anchor)
			"shrub_cluster":
				_build_cover_meadow_shrub_cluster(anchor)
			_:
				_build_cover_meadow_rock_cluster(anchor)


func _add_cover_meadow_ground_patches(parent: Node3D) -> void:
	var material := _build_downloaded_surface_material(
		"aerial_grass_rock_diff_1k.jpg",
		"aerial_grass_rock_nor_gl_1k.jpg",
		"aerial_grass_rock_rough_1k.jpg",
		Color(0.38, 0.62, 0.27),
		"grass"
	)
	var placements := [
		{"pos": Vector3(-12.7, 0.026, 5.6), "scale": Vector3(4.6, 1.0, 3.2), "rot": -18.0},
		{"pos": Vector3(-11.9, 0.026, -6.7), "scale": Vector3(4.4, 1.0, 2.9), "rot": 24.0},
		{"pos": Vector3(10.8, 0.026, -7.0), "scale": Vector3(4.8, 1.0, 3.5), "rot": -12.0},
		{"pos": Vector3(7.9, 0.026, 10.3), "scale": Vector3(5.2, 1.0, 3.1), "rot": 16.0},
	]
	for index in range(placements.size()):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.0
		mesh.bottom_radius = 1.0
		mesh.height = 0.018
		mesh.radial_segments = 28
		var patch := MeshInstance3D.new()
		patch.name = "CoverMeadowGround_%02d" % index
		patch.mesh = mesh
		patch.position = placements[index]["pos"]
		patch.scale = placements[index]["scale"]
		patch.rotation_degrees.y = float(placements[index]["rot"])
		patch.material_override = material
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(patch)


func _build_cover_meadow_pond(parent: Node3D) -> void:
	var bank_mesh := CylinderMesh.new()
	bank_mesh.top_radius = 1.0
	bank_mesh.bottom_radius = 1.0
	bank_mesh.height = 0.045
	bank_mesh.radial_segments = 40
	var bank := MeshInstance3D.new()
	bank.name = "PebbleBank"
	bank.mesh = bank_mesh
	bank.position = Vector3(0.0, -0.135, 0.0)
	bank.scale = Vector3(2.65, 1.0, 1.65)
	bank.material_override = _build_downloaded_surface_material(
		"clean_pebbles_diff_1k.jpg",
		"clean_pebbles_nor_gl_1k.jpg",
		"clean_pebbles_rough_1k.jpg",
		Color(0.54, 0.52, 0.46),
		"rock"
	)
	parent.add_child(bank)

	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 1.0
	water_mesh.bottom_radius = 1.0
	water_mesh.height = 0.028
	water_mesh.radial_segments = 48
	var water := MeshInstance3D.new()
	water.name = "PondWater"
	water.mesh = water_mesh
	water.position = Vector3(0.0, -0.095, 0.0)
	water.scale = Vector3(2.2, 1.0, 1.25)
	water.material_override = _build_water_material()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(water)

	for placement in [
		{"asset": "rock_smallA.obj", "pos": Vector3(-2.15, -0.16, -0.72), "rot": 20.0, "scale": 0.64, "color": Color(0.48, 0.52, 0.48), "material": "rock"},
		{"asset": "rock_smallA.obj", "pos": Vector3(2.0, -0.16, 0.74), "rot": -32.0, "scale": 0.58, "color": Color(0.52, 0.55, 0.5), "material": "rock"},
		{"asset": "plant_bush.obj", "pos": Vector3(-1.8, -0.16, 1.12), "rot": 12.0, "scale": 0.62, "color": Color(0.25, 0.58, 0.25), "material": "leaf"},
		{"asset": "flower_yellowA.obj", "pos": Vector3(1.7, -0.16, -1.05), "rot": -18.0, "scale": 0.48, "color": Color(0.95, 0.68, 0.28), "material": "flower"},
	]:
		_spawn_prop_from_root(KENNEY_PROP_ROOT, placement, parent)


func _build_cover_meadow_bridge(parent: Node3D) -> void:
	_add_water_ribbon(parent, [
		Vector3(-1.95, -0.155, -0.44),
		Vector3(-0.9, -0.155, -0.16),
		Vector3(0.4, -0.155, 0.06),
		Vector3(1.75, -0.155, 0.42),
	], 1.05)
	_build_stone_footbridge(parent, Vector3(0.0, -0.04, 0.0), 0.0)
	for placement in [
		{"asset": "rock_smallA.obj", "pos": Vector3(-1.7, -0.18, 0.55), "rot": -16.0, "scale": 0.72, "color": Color(0.46, 0.51, 0.47), "material": "rock"},
		{"asset": "rock_smallA.obj", "pos": Vector3(1.6, -0.18, -0.55), "rot": 31.0, "scale": 0.64, "color": Color(0.5, 0.54, 0.5), "material": "rock"},
		{"asset": "grass_large.obj", "pos": Vector3(-1.3, -0.18, -0.82), "rot": 18.0, "scale": 0.72, "color": Color(0.36, 0.74, 0.28), "material": "grass"},
		{"asset": "grass_large.obj", "pos": Vector3(1.25, -0.18, 0.8), "rot": -24.0, "scale": 0.68, "color": Color(0.4, 0.72, 0.3), "material": "grass"},
	]:
		_spawn_prop_from_root(KENNEY_PROP_ROOT, placement, parent)


func _build_cover_meadow_rock_cluster(parent: Node3D) -> void:
	var placements := [
		{"asset": "rock_largeA.obj", "pos": Vector3(-0.34, -0.18, 0.1), "rot": 8.0, "scale": 0.96, "color": Color(0.52, 0.56, 0.52), "material": "rock"},
		{"asset": "rock_smallA.obj", "pos": Vector3(0.72, -0.18, -0.35), "rot": -32.0, "scale": 0.72, "color": Color(0.48, 0.53, 0.49), "material": "rock"},
		{"asset": "rock_smallA.obj", "pos": Vector3(0.24, -0.18, 0.72), "rot": 43.0, "scale": 0.58, "color": Color(0.55, 0.58, 0.53), "material": "rock"},
		{"asset": "grass_large.obj", "pos": Vector3(-0.86, -0.18, -0.56), "rot": 22.0, "scale": 0.62, "color": Color(0.36, 0.68, 0.27), "material": "grass"},
	]
	for placement in placements:
		_spawn_prop_from_root(KENNEY_PROP_ROOT, placement, parent)


func _build_cover_meadow_flower_cluster(parent: Node3D) -> void:
	var colors := [
		Color(0.96, 0.74, 0.24),
		Color(0.94, 0.48, 0.56),
		Color(0.72, 0.62, 0.98),
		Color(1.0, 0.86, 0.34),
	]
	for index in range(9):
		var angle := TAU * float(index) / 9.0
		var radius := 0.25 + 0.12 * float(index % 3)
		_spawn_prop_from_root(KENNEY_PROP_ROOT, {
			"asset": "flower_yellowA.obj",
			"pos": Vector3(cos(angle) * radius, -0.18, sin(angle) * radius),
			"rot": rad_to_deg(angle) + 18.0 * float(index % 2),
			"scale": 0.48 + 0.08 * float(index % 3),
			"color": colors[index % colors.size()],
			"material": "flower",
		}, parent)
	for placement in [
		{"asset": "grass_large.obj", "pos": Vector3(-0.52, -0.18, -0.42), "rot": -12.0, "scale": 0.52, "color": Color(0.36, 0.72, 0.28), "material": "grass"},
		{"asset": "grass_large.obj", "pos": Vector3(0.58, -0.18, 0.42), "rot": 27.0, "scale": 0.48, "color": Color(0.42, 0.76, 0.3), "material": "grass"},
	]:
		_spawn_prop_from_root(KENNEY_PROP_ROOT, placement, parent)


func _build_cover_meadow_shrub_cluster(parent: Node3D) -> void:
	var placements := [
		{"asset": "plant_bush.obj", "pos": Vector3(-0.48, -0.18, -0.28), "rot": -18.0, "scale": 0.86, "color": Color(0.24, 0.58, 0.24), "material": "leaf_dark"},
		{"asset": "plant_bush.obj", "pos": Vector3(0.42, -0.18, 0.2), "rot": 28.0, "scale": 0.72, "color": Color(0.28, 0.64, 0.26), "material": "leaf"},
		{"asset": "rock_smallA.obj", "pos": Vector3(0.82, -0.18, -0.45), "rot": 43.0, "scale": 0.42, "color": Color(0.5, 0.54, 0.49), "material": "rock"},
		{"asset": "flower_yellowA.obj", "pos": Vector3(-0.82, -0.18, 0.44), "rot": -8.0, "scale": 0.42, "color": Color(0.94, 0.72, 0.26), "material": "flower"},
	]
	for placement in placements:
		_spawn_prop_from_root(KENNEY_PROP_ROOT, placement, parent)


func _build_imported_environment_assets() -> void:
	var imported_root := Node3D.new()
	imported_root.name = "ImportedEnvironmentAssets"
	_props_root.add_child(imported_root)

	_spawn_prop_from_root(IMPORTED_TREE_ROOT, {
		"name": "ImportedTreeGrove",
		"asset": "low_poly_tree_scene_free.glb",
		"pos": Vector3(-18.2, -0.03, 13.4),
		"rot": -28.0,
		"scale": 0.76,
		"preserve_material": true,
		"cast_shadow": false,
	}, imported_root)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260628
	var reserved_zones := _get_mushroom_reserved_zones()
	var mushroom_positions: Array[Vector3] = []
	var mushroom_resource = load("%s/lowpoly_mushrooms.glb" % IMPORTED_MUSHROOM_ROOT) if ResourceLoader.exists("%s/lowpoly_mushrooms.glb" % IMPORTED_MUSHROOM_ROOT) else null
	if mushroom_resource is PackedScene:
		var mushroom_source := (mushroom_resource as PackedScene).instantiate()
		var mushroom_variants := _find_descendant_by_name(mushroom_source, "RootNode")
		if mushroom_variants != null:
			for index in range(24):
				var position := _get_random_clear_environment_position(rng, 12.4, 16.6, reserved_zones, mushroom_positions)
				mushroom_positions.append(position)
				_spawn_single_imported_mushroom(
					imported_root,
					mushroom_variants,
					"ImportedMushroom_%02d" % index,
					position,
					rng.randf_range(-180.0, 180.0),
					rng.randf_range(0.0058, 0.0094),
					rng.randi_range(0, mushroom_variants.get_child_count() - 1)
				)
		mushroom_source.free()


func _spawn_single_imported_mushroom(parent: Node3D, mushroom_variants: Node, node_name: String, position: Vector3, rotation_y: float, scale_value: float, variant_index: int) -> void:
	if mushroom_variants == null or mushroom_variants.get_child_count() == 0:
		return
	var source_variant := mushroom_variants.get_child(posmod(variant_index, mushroom_variants.get_child_count()))
	var selected := source_variant.duplicate() as Node3D
	if selected == null:
		return

	var wrapper := Node3D.new()
	wrapper.name = node_name
	wrapper.position = position
	wrapper.rotation_degrees.y = rotation_y
	wrapper.scale = Vector3.ONE * scale_value
	parent.add_child(wrapper)

	selected.name = "%s_Model" % node_name
	selected.position = Vector3.ZERO
	wrapper.add_child(selected)
	_set_prop_shadow_mode(selected, false)
	var bounds := _get_node_global_bounds(selected)
	if bounds.size.length_squared() > 0.0:
		wrapper.global_position.y -= bounds.position.y


func _get_random_clear_environment_position(rng: RandomNumberGenerator, min_radius: float, max_radius: float, reserved_zones: Array, placed_positions: Array[Vector3]) -> Vector3:
	for _attempt in range(180):
		var position := _get_random_environment_position(rng, min_radius, max_radius)
		if _is_clear_mushroom_position(position, reserved_zones, placed_positions):
			return position
	return _get_random_environment_position(rng, min_radius, max_radius)


func _is_clear_mushroom_position(position: Vector3, reserved_zones: Array, placed_positions: Array[Vector3]) -> bool:
	var flat_position := Vector2(position.x, position.z)
	for zone in reserved_zones:
		if not zone is Dictionary:
			continue
		var center: Vector2 = zone.get("center", Vector2.ZERO)
		var radius := float(zone.get("radius", 0.0))
		if flat_position.distance_to(center) < radius:
			return false
	for placed in placed_positions:
		if Vector2(placed.x, placed.z).distance_to(flat_position) < 1.25:
			return false
	return true


func _get_mushroom_reserved_zones() -> Array:
	return [
		{"center": Vector2(-18.2, 13.4), "radius": 5.8},
		{"center": Vector2(-17.0, -11.0), "radius": 4.2},
		{"center": Vector2(-20.0, 5.5), "radius": 4.0},
		{"center": Vector2(18.0, -8.5), "radius": 4.5},
		{"center": Vector2(20.5, 7.0), "radius": 4.0},
		{"center": Vector2(-12.8, 5.8), "radius": 4.3},
		{"center": Vector2(-12.2, -6.8), "radius": 3.9},
		{"center": Vector2(-5.4, -12.2), "radius": 4.0},
		{"center": Vector2(8.8, -10.2), "radius": 3.2},
		{"center": Vector2(12.4, 3.8), "radius": 3.3},
		{"center": Vector2(-10.7, 10.1), "radius": 2.8},
		{"center": Vector2(3.6, 12.6), "radius": 2.8},
		{"center": Vector2(-11.8, 0.2), "radius": 2.8},
		{"center": Vector2(12.6, -2.6), "radius": 2.8},
		{"center": Vector2(-10.1, -8.7), "radius": 4.2},
		{"center": Vector2(10.1, -8.8), "radius": 4.0},
		{"center": Vector2(10.0, 9.0), "radius": 4.0},
		{"center": Vector2(-10.0, 9.0), "radius": 4.0},
		{"center": Vector2(-14.0, 13.0), "radius": 2.4},
		{"center": Vector2(14.5, 12.5), "radius": 2.4},
		{"center": Vector2(7.5, 17.5), "radius": 2.0},
	]


func _get_random_environment_position(rng: RandomNumberGenerator, min_radius: float, max_radius: float) -> Vector3:
	var angle := rng.randf_range(0.0, TAU)
	var radius := sqrt(rng.randf_range(min_radius * min_radius, max_radius * max_radius))
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _find_descendant_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_descendant_by_name(child, node_name)
		if found != null:
			return found
	return null


func _get_node_global_bounds(node: Node) -> AABB:
	var has_bounds := false
	var result := AABB()
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			result = mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
			has_bounds = true
	for child in node.get_children():
		var child_bounds := _get_node_global_bounds(child)
		if child_bounds.size.length_squared() <= 0.0:
			continue
		if has_bounds:
			result = result.merge(child_bounds)
		else:
			result = child_bounds
			has_bounds = true
	return result


func _build_corner_landmarks() -> void:
	var north_west := _create_landmark_root("TowerGarden", Vector3(-10.1, 0.0, -8.7), 18.0)
	_build_garden_pavilion(north_west)
	_spawn_landmark(north_west, "rocks-large.obj", Vector3(-2.35, 0.0, 1.55), 22.0, 1.08, Color(0.42, 0.46, 0.43), "rock")
	_spawn_landmark(north_west, "plant_bush.obj", Vector3(2.2, 0.0, 1.45), -18.0, 1.25, Color(0.18, 0.56, 0.2), "leaf_dark", KENNEY_PROP_ROOT)
	_add_landmark_light(north_west, Vector3(0.0, 2.2, 0.0), Color(1.0, 0.66, 0.34), 0.16, 5.4)

	var north_east := _create_landmark_root("RoundFountainGarden", Vector3(10.1, 0.0, -8.8), -14.0)
	_spawn_landmark(north_east, "fountain-round.obj", Vector3.ZERO, 0.0, 1.72, Color(0.53, 0.61, 0.64), "stone")
	_spawn_landmark(north_east, "fountain-center.obj", Vector3.ZERO, 0.0, 1.72, Color(0.62, 0.72, 0.76), "stone")
	_spawn_landmark(north_east, "lantern.obj", Vector3(-1.85, 0.0, 1.65), 18.0, 1.35, Color(0.56, 0.4, 0.22), "bark")
	_spawn_landmark(north_east, "lantern.obj", Vector3(1.85, 0.0, -1.65), -162.0, 1.35, Color(0.56, 0.4, 0.22), "bark")
	_add_landmark_light(north_east, Vector3(0.0, 1.25, 0.0), Color(0.38, 0.72, 1.0), 0.2, 5.4)

	var south_east := _create_landmark_root("LanternCourt", Vector3(10.0, 0.0, 9.0), 28.0)
	for pos in [Vector3(-1.4, 0.0, -1.4), Vector3(1.4, 0.0, -1.4), Vector3(-1.4, 0.0, 1.4), Vector3(1.4, 0.0, 1.4)]:
		_spawn_landmark(south_east, "pillar-stone.obj", pos, 0.0, 1.38, Color(0.56, 0.59, 0.58), "stone")
	for pos in [Vector3(-1.4, 1.55, -1.4), Vector3(1.4, 1.55, -1.4), Vector3(-1.4, 1.55, 1.4), Vector3(1.4, 1.55, 1.4)]:
		_spawn_landmark(south_east, "lantern.obj", pos, 0.0, 0.82, Color(0.67, 0.47, 0.22), "bark")
	_add_landmark_light(south_east, Vector3(0.0, 2.1, 0.0), Color(1.0, 0.72, 0.4), 0.2, 5.6)

	var south_west := _create_landmark_root("SquareFountainGarden", Vector3(-10.0, 0.0, 9.0), -22.0)
	_spawn_landmark(south_west, "fountain-square.obj", Vector3.ZERO, 0.0, 1.62, Color(0.5, 0.58, 0.6), "stone")
	_spawn_landmark(south_west, "fountain-square-detail.obj", Vector3.ZERO, 0.0, 1.62, Color(0.68, 0.75, 0.77), "stone")
	_spawn_landmark(south_west, "fountain-center.obj", Vector3.ZERO, 0.0, 1.62, Color(0.6, 0.7, 0.74), "stone")
	_spawn_landmark(south_west, "hedge-large-curved.obj", Vector3(-1.8, 0.0, -1.8), 0.0, 1.18, Color(0.2, 0.48, 0.22), "leaf_dark")
	_spawn_landmark(south_west, "hedge-large-curved.obj", Vector3(1.8, 0.0, 1.8), 180.0, 1.18, Color(0.2, 0.48, 0.22), "leaf_dark")
	_add_landmark_light(south_west, Vector3(0.0, 1.2, 0.0), Color(0.4, 0.74, 1.0), 0.18, 5.2)


func _build_garden_pavilion(parent: Node3D) -> void:
	var pavilion := Node3D.new()
	pavilion.name = "GardenPavilion"
	parent.add_child(pavilion)
	_add_primitive_mesh(pavilion, "StoneBase", _make_cylinder_mesh(2.35, 2.35, 0.24, 8), Vector3(0.0, 0.12, 0.0), Color(0.54, 0.58, 0.54), "stone")
	for angle in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var column_position := Vector3(cos(angle) * 1.55, 1.3, sin(angle) * 1.55)
		_add_primitive_mesh(pavilion, "WoodColumn", _make_cylinder_mesh(0.12, 0.12, 2.6, 8), column_position, Color(0.42, 0.2, 0.09), "bark")
	_add_primitive_mesh(pavilion, "LowerRoof", _make_cylinder_mesh(0.82, 2.9, 0.7, 8), Vector3(0.0, 2.82, 0.0), Color(0.19, 0.38, 0.28), "leaf_dark")
	_add_primitive_mesh(pavilion, "UpperRoof", _make_cylinder_mesh(0.18, 1.3, 0.58, 8), Vector3(0.0, 3.42, 0.0), Color(0.14, 0.31, 0.23), "leaf_dark")
	_spawn_landmark(parent, "lantern.obj", Vector3(-1.45, 0.22, 1.8), 18.0, 0.92, Color(0.66, 0.42, 0.18), "bark")
	_spawn_landmark(parent, "lantern.obj", Vector3(1.45, 0.22, -1.8), -162.0, 0.92, Color(0.66, 0.42, 0.18), "bark")


func _build_board_garden_ring() -> void:
	var ring := Node3D.new()
	ring.name = "BoardGardenRing"
	_props_root.add_child(ring)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17061
	for corner_index in range(6):
		var angle := TAU * float(corner_index) / 6.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3(-direction.z, 0.0, direction.x)
		var center := direction * rng.randf_range(garden_ring_inner_radius, garden_ring_outer_radius)
		var placements := [
			{"asset": "rock_smallA.obj", "offset": -tangent * 1.0 + direction * 0.08, "scale": rng.randf_range(0.68, 0.96), "color": Color(0.42, 0.47, 0.43), "material": "rock"},
			{"asset": "plant_bush.obj", "offset": tangent * 0.88, "scale": rng.randf_range(0.76, 1.04), "color": Color(0.18, 0.58, 0.2), "material": "leaf_dark"},
			{"asset": "grass_large.obj", "offset": -direction * 0.42 + tangent * 0.12, "scale": rng.randf_range(0.66, 0.94), "color": Color(0.28, 0.72, 0.22), "material": "grass"},
			{"asset": "flower_yellowA.obj", "offset": direction * 0.24 - tangent * 0.28, "scale": rng.randf_range(0.62, 0.84), "color": Color(0.92, 0.76, 0.22), "material": "flower"},
		]
		for placement in placements:
			_spawn_prop_from_root(KENNEY_PROP_ROOT, {
				"asset": placement["asset"],
				"pos": center + placement["offset"],
				"rot": rng.randf_range(0.0, 180.0),
				"scale": placement["scale"],
				"color": placement["color"],
				"material": placement["material"],
			}, ring)

	for index in range(6):
		var angle := TAU * float(index) / 6.0
		var lantern_position := Vector3(cos(angle) * 8.75, 0.0, sin(angle) * 8.75)
		_spawn_prop_from_root(KENNEY_LANDMARK_ROOT, {"asset": "lantern.obj", "pos": lantern_position, "rot": rad_to_deg(-angle) + 90.0, "scale": 0.94, "color": Color(0.62, 0.4, 0.16), "material": "bark"}, ring)
		_add_garden_glow(ring, lantern_position + Vector3.UP * 1.1, Color(1.0, 0.64, 0.3), 0.055, 2.8)


func _build_garden_water_feature() -> void:
	var water_root := Node3D.new()
	water_root.name = "GardenWater"
	_props_root.add_child(water_root)
	var stream_points := [
		Vector3(-13.6, 0.015, -8.2),
		Vector3(-12.5, 0.015, -7.35),
		Vector3(-11.35, 0.015, -6.5),
		Vector3(-10.35, 0.015, -5.8),
		Vector3(-9.35, 0.015, -5.3),
	]
	_add_water_ribbon(water_root, stream_points, 1.28)
	for index in range(stream_points.size()):
		var point: Vector3 = stream_points[index]
		_spawn_prop_from_root(KENNEY_PROP_ROOT, {"asset": "rock_smallA.obj", "pos": point + Vector3(-0.9, 0.0, 0.48), "rot": float(index) * 31.0, "scale": 0.72 + float(index % 2) * 0.24, "color": Color(0.4, 0.46, 0.43), "material": "rock"}, water_root)
		_spawn_prop_from_root(KENNEY_PROP_ROOT, {"asset": "rock_smallA.obj", "pos": point + Vector3(0.85, 0.0, -0.5), "rot": float(index) * -27.0, "scale": 0.66 + float((index + 1) % 2) * 0.2, "color": Color(0.42, 0.48, 0.45), "material": "rock"}, water_root)
	_build_stone_footbridge(water_root, Vector3(-11.45, 0.08, -6.55), -34.0)


func _add_water_ribbon(parent: Node3D, points: Array, width: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_build_water_material())
	for index in range(points.size() - 1):
		var start: Vector3 = points[index]
		var finish: Vector3 = points[index + 1]
		var direction := (finish - start).normalized()
		var tangent := Vector3(-direction.z, 0.0, direction.x) * width * 0.5
		_add_water_vertex(surface, start - tangent, Vector2(0.0, float(index)))
		_add_water_vertex(surface, start + tangent, Vector2(1.0, float(index)))
		_add_water_vertex(surface, finish + tangent, Vector2(1.0, float(index + 1)))
		_add_water_vertex(surface, start - tangent, Vector2(0.0, float(index)))
		_add_water_vertex(surface, finish + tangent, Vector2(1.0, float(index + 1)))
		_add_water_vertex(surface, finish - tangent, Vector2(0.0, float(index + 1)))
	var stream := MeshInstance3D.new()
	stream.name = "StreamRibbon"
	stream.mesh = surface.commit()
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(stream)


func _build_stone_footbridge(parent: Node3D, position: Vector3, rotation_y: float) -> void:
	var bridge := Node3D.new()
	bridge.name = "StoneFootbridge"
	bridge.position = position
	bridge.rotation_degrees.y = rotation_y
	parent.add_child(bridge)
	for index in range(5):
		var step_position := Vector3(float(index - 2) * 0.52, 0.12 + 0.1 * (2.0 - abs(float(index - 2))), 0.0)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.48, 0.18, 1.72)
		_add_primitive_mesh(bridge, "BridgeStone", mesh, step_position, Color(0.53, 0.57, 0.53), "stone")


func _build_water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.58, 0.72, 0.78)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.22
	material.metallic = 0.08
	material.emission_enabled = true
	material.emission = Color(0.04, 0.18, 0.2)
	material.emission_energy_multiplier = 0.28
	return material


func _build_downloaded_surface_material(diffuse_name: String, normal_name: String, roughness_name: String, fallback_color: Color, material_kind: String) -> StandardMaterial3D:
	var material := _build_prop_material(fallback_color, material_kind)
	var diffuse_path := "%s/%s" % [DOWNLOADED_MATERIAL_ROOT, diffuse_name]
	var normal_path := "%s/%s" % [DOWNLOADED_MATERIAL_ROOT, normal_name]
	var roughness_path := "%s/%s" % [DOWNLOADED_MATERIAL_ROOT, roughness_name]
	if ResourceLoader.exists(diffuse_path):
		material.albedo_texture = load(diffuse_path)
		material.albedo_color = fallback_color.lightened(0.08)
	if ResourceLoader.exists(normal_path):
		material.normal_enabled = true
		material.normal_texture = load(normal_path)
		material.normal_scale = 0.16
	if ResourceLoader.exists(roughness_path):
		material.roughness_texture = load(roughness_path)
	return material


func _add_water_vertex(surface: SurfaceTool, vertex: Vector3, uv: Vector2) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(uv)
	surface.add_vertex(vertex)


func _add_primitive_mesh(parent: Node3D, node_name: String, mesh: Mesh, local_position: Vector3, color: Color, material_kind: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _build_prop_material(color, material_kind)
	parent.add_child(instance)


func _make_cylinder_mesh(top_radius: float, bottom_radius: float, mesh_height: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = mesh_height
	mesh.radial_segments = segments
	return mesh


func _add_garden_glow(parent: Node3D, local_position: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.name = "GardenGlow"
	light.position = local_position
	light.light_color = color
	light.light_energy = energy
	light.set_meta("base_energy", energy)
	light.set_meta("light_group", "garden_glow")
	light.set_meta("priority", _mood_lights.size())
	light.omni_range = light_range
	light.shadow_enabled = false
	parent.add_child(light)
	_mood_lights.append(light)


func _create_landmark_root(root_name: String, world_position: Vector3, rotation_y: float) -> Node3D:
	var root := Node3D.new()
	root.name = root_name
	root.position = world_position
	root.rotation_degrees.y = rotation_y
	_props_root.add_child(root)
	return root


func _spawn_landmark(parent: Node3D, asset_name: String, local_position: Vector3, rotation_y: float, scale_value: float, color: Color, material_kind: String, asset_root := KENNEY_LANDMARK_ROOT) -> void:
	_spawn_prop_from_root(asset_root, {
		"asset": asset_name,
		"pos": local_position,
		"rot": rotation_y,
		"scale": scale_value,
		"color": color,
		"material": material_kind,
	}, parent)


func _add_landmark_light(parent: Node3D, local_position: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.name = "LandmarkGlow"
	light.position = local_position
	light.light_color = color
	light.light_energy = energy
	light.set_meta("base_energy", energy)
	light.set_meta("light_group", "mood")
	light.set_meta("priority", _mood_lights.size())
	light.omni_range = light_range
	light.shadow_enabled = false
	parent.add_child(light)
	_mood_lights.append(light)


func _build_edge_tree_ring() -> void:
	var ring := Node3D.new()
	ring.name = "EdgeTreeRing"
	_props_root.add_child(ring)
	var rng := RandomNumberGenerator.new()
	rng.seed = 271828
	var assets := ["tree_default.obj", "tree_pineRoundA.obj", "tree_fat.obj", "tree_default.obj"]
	for layer_index in range(2):
		var tree_count := 24 if layer_index == 0 else 16
		var base_radius := edge_tree_radius if layer_index == 0 else edge_tree_radius - 3.1
		for index in range(tree_count):
			var angle := TAU * (float(index) + float(layer_index) * 0.46) / float(tree_count)
			var radius := base_radius + rng.randf_range(-0.95, 0.95)
			var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			var scale := rng.randf_range(5.6, 7.4) if layer_index == 0 else rng.randf_range(4.2, 5.8)
			_spawn_prop_from_root(KENNEY_PROP_ROOT, {
				"asset": assets[(index + layer_index) % assets.size()],
				"pos": pos,
				"rot": rad_to_deg(-angle) + 90.0 + rng.randf_range(-11.0, 11.0),
				"scale": scale,
				"color": Color(0.16 + 0.035 * float(index % 3), 0.43 + 0.045 * float((index + layer_index) % 3), 0.19),
				"material": "leaf_dark" if (index + layer_index) % 2 == 0 else "leaf",
				"cast_shadow": layer_index == 1 and index % 4 == 0,
			}, ring)


func _build_forest_rim_lights() -> void:
	var root := Node3D.new()
	root.name = "ForestRimLights"
	_props_root.add_child(root)
	_forest_rim_lights.clear()
	for index in range(6):
		var angle := PI / 6.0 + TAU * float(index) / 6.0
		var light := OmniLight3D.new()
		light.name = "ForestRim_%d" % index
		light.position = Vector3(cos(angle) * 17.5, 5.4 + float(index % 2) * 0.9, sin(angle) * 17.5)
		light.light_color = Color(1.0, 0.68, 0.38) if index % 2 == 0 else Color(0.42, 0.62, 0.92)
		light.set_meta("energy_scale", 2.2 if index % 2 == 0 else 1.65)
		light.set_meta("light_group", "forest_rim")
		light.set_meta("priority", index)
		light.omni_range = 10.5
		light.shadow_enabled = false
		root.add_child(light)
		_forest_rim_lights.append(light)


func _build_grass_detail_ring() -> void:
	var grass_assets := ["grass_large.obj", "plant_bush.obj", "flower_yellowA.obj"]
	for index in range(28):
		var angle := TAU * float(index) / 28.0
		var radius := grass_detail_inner_radius + 1.2 + float(index % 5) * 1.05
		var pos := Vector3(cos(angle) * radius, -0.01, sin(angle) * radius)
		_spawn_prop({
			"asset": grass_assets[index % grass_assets.size()],
			"pos": pos,
			"rot": rad_to_deg(angle) + float(index % 5) * 17.0,
			"scale": 0.8 + float(index % 4) * 0.22,
			"color": Color(0.38 + 0.04 * float(index % 3), 0.66 + 0.03 * float(index % 2), 0.27),
			"material": "flower" if index % grass_assets.size() == 2 else "grass",
		})


func _build_canopy_shadow_layer() -> void:
	return


func _build_firefly_layer() -> void:
	var root := Node3D.new()
	root.name = "FireflyGlow"
	_props_root.add_child(root)
	_firefly_material = StandardMaterial3D.new()
	_firefly_material.albedo_color = Color(1.0, 0.8, 0.32)
	_firefly_material.emission_enabled = true
	_firefly_material.emission = Color(1.0, 0.62, 0.18)
	_firefly_material.emission_energy_multiplier = float(_lighting_settings.get("firefly_energy", 0.45))
	_firefly_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_firefly_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_firefly_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mesh := SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.09
	mesh.radial_segments = 8
	mesh.rings = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 90917
	for index in range(34):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(7.4, 16.8)
		var glow := MeshInstance3D.new()
		glow.name = "Firefly_%02d" % index
		glow.mesh = mesh
		glow.position = Vector3(cos(angle) * radius, rng.randf_range(0.42, 1.55), sin(angle) * radius)
		glow.scale = Vector3.ONE * rng.randf_range(0.8, 1.45)
		glow.material_override = _firefly_material
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(glow)


func _spawn_prop(placement: Dictionary) -> void:
	_spawn_prop_from_root(KENNEY_PROP_ROOT, placement, _props_root)


func _spawn_prop_from_root(asset_root: String, placement: Dictionary, parent: Node3D) -> void:
	var path := "%s/%s" % [asset_root, String(placement.get("asset", ""))]
	var resource = load(path) if ResourceLoader.exists(path) else null
	var node: Node3D

	if resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource
		node = mesh_instance
	elif resource is PackedScene:
		node = resource.instantiate() as Node3D
	else:
		node = _build_fallback_prop()

	node.name = String(placement.get("name", String(placement.get("asset", "Prop")).get_basename()))
	node.position = placement.get("pos", Vector3.ZERO)
	node.rotation_degrees = Vector3(0.0, float(placement.get("rot", 0.0)), 0.0)
	var scale_value := float(placement.get("scale", 1.0))
	node.scale = Vector3.ONE * scale_value
	var material_kind := String(placement.get("material", "matte"))
	if not bool(placement.get("preserve_material", false)):
		_apply_prop_material(node, placement.get("color", Color.WHITE), material_kind)
	_set_prop_shadow_mode(node, bool(placement.get("cast_shadow", material_kind not in ["grass", "flower", "leaf", "leaf_dark"])))
	parent.add_child(node)


func _build_fallback_prop() -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh_instance.mesh = mesh
	return mesh_instance


func _apply_prop_material(node: Node, color: Color, material_kind := "matte") -> void:
	var material := _build_prop_material(color, material_kind)

	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material

	for child in node.get_children():
		_apply_prop_material(child, color, material_kind)


func _set_prop_shadow_mode(node: Node, enabled: bool) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if enabled
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
	for child in node.get_children():
		_set_prop_shadow_mode(child, enabled)


func _build_prop_material(color: Color, material_kind: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.74
	material.metallic = 0.0
	material.albedo_texture = _get_noise_texture(material_kind)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	match material_kind:
		"leaf", "leaf_dark", "grass":
			material.roughness = 0.86
		"stone":
			material.roughness = 0.72
			material.normal_enabled = false
		"banner":
			material.roughness = 0.66
		"bark":
			material.roughness = 0.9
		"rock":
			material.roughness = 0.82
		"flower":
			material.roughness = 0.78
		_:
			pass

	return material


func _get_noise_texture(material_kind: String) -> Texture2D:
	if _noise_textures.has(material_kind):
		return _noise_textures[material_kind]

	var noise := FastNoiseLite.new()
	noise.seed = hash(material_kind)
	noise.frequency = 0.085
	if material_kind == "grass":
		noise.frequency = 0.14
	elif material_kind == "bark":
		noise.frequency = 0.05
	elif material_kind == "rock":
		noise.frequency = 0.11

	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.noise = noise
	texture.normalize = true
	_noise_textures[material_kind] = texture
	return texture


func _set_property_if_available(object: Object, property_name: String, value) -> void:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			object.set(property_name, value)
			return
