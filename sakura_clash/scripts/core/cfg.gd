class_name Cfg
extends RefCounted
## Global constants: arena geometry, pixel scale, timing.

## Size of one "art pixel" in world units. Actors and effects are rendered at
## 1/PX resolution and upscaled, which gives the chunky pixel-art look.
const PX := 3

const WORLD_W := 1672.0
const WORLD_H := 941.0
## Feet level of fighters standing on the stone terrace of the background.
const FLOOR_Y := 846.0
## Invisible shrine barrier ("kekkai") that bounds the arena.
const WALL_L := 34.0
const WALL_R := 1638.0
const CEIL_Y := 26.0

## Size of the low resolution pixel viewports (WORLD / PX, rounded up).
const PV_W := 558
const PV_H := 314

const ROUND_TIME := 99.0
const ROUNDS_TO_WIN := 2

## Input windows (seconds).
const BUFFER_TIME := 0.15
const DOUBLE_TAP := 0.24
const PARRY_WINDOW := 0.15
const PERFECT_DODGE_WINDOW := 0.16

## Ki (super meter).
const KI_MAX := 100.0
const RUSH_CANCEL_COST := 20.0

const LANTERNS := [Vector2(115, 518), Vector2(1594, 514), Vector2(368, 500), Vector2(466, 500)]
