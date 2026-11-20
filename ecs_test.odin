package basalt

import "core:testing"

@(private = "file")
Test_Position :: struct {
	x, y: f32,
}

@(private = "file")
Test_Velocity :: struct {
	x, y: f32,
}

@(private = "file")
Test_Tag :: struct {}

@(private = "file")
Test_Settings :: struct {
	value: int,
}

// Only touched by test_resources, so parallel tests don't race on it.
@(private = "file")
settings_cleanup_calls: int

@(private = "file")
test_settings_cleanup :: proc(settings: ^Test_Settings) {
	settings_cleanup_calls += 1
}

@(test)
test_spawn_and_get :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	entity := world_spawn(world, Test_Position{1, 2}, Test_Velocity{3, 4})
	testing.expect(t, world_is_alive(world, entity))

	position, has_position := get_component(world, entity, Test_Position)
	testing.expect(t, has_position)
	testing.expect_value(t, position^, Test_Position{1, 2})

	velocity, has_velocity := get_component(world, entity, Test_Velocity)
	testing.expect(t, has_velocity)
	testing.expect_value(t, velocity^, Test_Velocity{3, 4})

	testing.expect(t, !has_component(world, entity, Test_Tag))
}

@(test)
test_insert_replaces :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	entity := world_spawn(world, Test_Position{1, 2})
	insert_components(world, entity, Test_Position{5, 6})

	position, ok := get_component(world, entity, Test_Position)
	testing.expect(t, ok)
	testing.expect_value(t, position^, Test_Position{5, 6})

	count := 0
	query := world_query(world, Test_Position)
	for _ in query_next(&query) {
		count += 1
	}
	testing.expect_value(t, count, 1)
}

@(test)
test_remove_component :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	entity := world_spawn(world, Test_Position{1, 2}, Test_Velocity{3, 4})
	remove_component(world, entity, Test_Velocity)

	testing.expect(t, world_is_alive(world, entity))
	testing.expect(t, has_component(world, entity, Test_Position))
	testing.expect(t, !has_component(world, entity, Test_Velocity))

	// Removing something that isn't there is a no-op.
	remove_component(world, entity, Test_Velocity)
	remove_component(world, entity, Test_Tag)
}

@(test)
test_despawn_and_stale_entity :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	old := world_spawn(world, Test_Position{1, 1})
	world_despawn(world, old)
	testing.expect(t, !world_is_alive(world, old))

	// A new entity may reuse the old index; the old handle must still see nothing.
	new := world_spawn(world, Test_Position{2, 2})
	testing.expect(t, world_is_alive(world, new))
	testing.expect(t, !world_is_alive(world, old))
	testing.expect(t, !has_component(world, old, Test_Position))

	_, old_ok := get_component(world, old, Test_Position)
	testing.expect(t, !old_ok)

	position, new_ok := get_component(world, new, Test_Position)
	testing.expect(t, new_ok)
	testing.expect_value(t, position^, Test_Position{2, 2})

	// Despawning a dead entity is a no-op.
	world_despawn(world, old)
}

@(test)
test_despawn_removes_all_components :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	entity := world_spawn(world, Test_Position{1, 2}, Test_Velocity{3, 4}, Test_Tag{})
	world_despawn(world, entity)

	count := 0
	query := world_query(world, Test_Position)
	for _ in query_next(&query) {
		count += 1
	}
	testing.expect_value(t, count, 0)
}

@(test)
test_query_matches_only_entities_with_all_components :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	both := world_spawn(world, Test_Position{1, 0}, Test_Velocity{10, 0})
	_ = world_spawn(world, Test_Position{2, 0})
	_ = world_spawn(world, Test_Velocity{20, 0})

	count := 0
	query := world_query(world, Test_Position, Test_Velocity)
	for item in query_next(&query) {
		count += 1
		testing.expect_value(t, item.entity, both)
		item.a.x += item.b.x
	}
	testing.expect_value(t, count, 1)
	testing.expect_value(t, world.active_queries, 0)

	// Writes through the query pointers land in the world.
	position, _ := get_component(world, both, Test_Position)
	testing.expect_value(t, position^, Test_Position{11, 0})
}

@(test)
test_query_without_storage_is_empty :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	_ = world_spawn(world, Test_Position{1, 2})

	count := 0
	query := world_query(world, Test_Position, Test_Velocity)
	for _ in query_next(&query) {
		count += 1
	}
	testing.expect_value(t, count, 0)
	testing.expect_value(t, world.active_queries, 0)
}

@(test)
test_insert_during_query_is_deferred :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	entity := world_spawn(world, Test_Position{1, 2})

	query := world_query(world, Test_Position)
	for item in query_next(&query) {
		insert_components(world, item.entity, Test_Velocity{3, 4})
		testing.expect(t, !has_component(world, item.entity, Test_Velocity))
	}

	velocity, ok := get_component(world, entity, Test_Velocity)
	testing.expect(t, ok)
	testing.expect_value(t, velocity^, Test_Velocity{3, 4})
}

@(test)
test_remove_during_query_is_deferred :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	entity := world_spawn(world, Test_Position{1, 2}, Test_Velocity{3, 4})

	query := world_query(world, Test_Position)
	for item in query_next(&query) {
		remove_component(world, item.entity, Test_Velocity)
		testing.expect(t, has_component(world, item.entity, Test_Velocity))
	}

	testing.expect(t, !has_component(world, entity, Test_Velocity))
}

@(test)
test_despawn_during_query_is_deferred :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	a := world_spawn(world, Test_Position{1, 0})
	b := world_spawn(world, Test_Position{2, 0})

	count := 0
	query := world_query(world, Test_Position)
	for item in query_next(&query) {
		count += 1
		world_despawn(world, item.entity)
		testing.expect(t, world_is_alive(world, item.entity))
	}

	// Both entities were visited, even though the first one was despawned mid-loop.
	testing.expect_value(t, count, 2)
	testing.expect(t, !world_is_alive(world, a))
	testing.expect(t, !world_is_alive(world, b))
}

@(test)
test_spawn_during_query :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	_ = world_spawn(world, Test_Position{1, 2})

	spawned: Entity
	query := world_query(world, Test_Position)
	for _ in query_next(&query) {
		spawned = world_spawn(world, Test_Velocity{5, 6})
		testing.expect(t, world_is_alive(world, spawned))
		testing.expect(t, !has_component(world, spawned, Test_Velocity))
	}

	velocity, ok := get_component(world, spawned, Test_Velocity)
	testing.expect(t, ok)
	testing.expect_value(t, velocity^, Test_Velocity{5, 6})
}

@(test)
test_early_break_flushes_on_query_end :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	entity := world_spawn(world, Test_Position{1, 2})

	query := world_query(world, Test_Position)
	for item in query_next(&query) {
		world_despawn(world, item.entity)
		break
	}

	// The loop never finished, so the despawn is still waiting.
	testing.expect(t, world_is_alive(world, entity))
	testing.expect_value(t, world.active_queries, 1)

	query_end(&query)
	testing.expect(t, !world_is_alive(world, entity))
	testing.expect_value(t, world.active_queries, 0)

	// Ending twice is harmless.
	query_end(&query)
	testing.expect_value(t, world.active_queries, 0)
}

@(test)
test_nested_queries_flush_at_outer_end :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	_ = world_spawn(world, Test_Position{1, 2})
	target := world_spawn(world, Test_Velocity{3, 4})

	outer := world_query(world, Test_Position)
	for _ in query_next(&outer) {
		inner := world_query(world, Test_Velocity)
		for item in query_next(&inner) {
			world_despawn(world, item.entity)
		}

		// The inner query has ended, but the outer one is still running.
		testing.expect(t, world_is_alive(world, target))
		testing.expect_value(t, world.active_queries, 1)
	}

	testing.expect(t, !world_is_alive(world, target))
	testing.expect_value(t, world.active_queries, 0)
}

@(test)
test_insert_after_despawn_in_same_query_is_skipped :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	entity := world_spawn(world, Test_Position{1, 2})

	query := world_query(world, Test_Position)
	for item in query_next(&query) {
		world_despawn(world, item.entity)
		insert_components(world, item.entity, Test_Velocity{3, 4})
	}

	// Reaching this line means the flush skipped the insert instead of asserting.
	testing.expect(t, !world_is_alive(world, entity))
	testing.expect(t, !has_component(world, entity, Test_Velocity))
}

@(test)
test_zero_sized_components :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	direct := world_spawn(world, Test_Position{1, 0}, Test_Tag{})
	deferred := world_spawn(world, Test_Position{2, 0})
	testing.expect(t, has_component(world, direct, Test_Tag))

	// Only zero-sized components are deferred, so the byte buffer stays empty.
	query := world_query(world, Test_Position)
	for item in query_next(&query) {
		if item.entity == deferred {
			insert_components(world, item.entity, Test_Tag{})
		}
	}
	testing.expect(t, has_component(world, deferred, Test_Tag))

	count := 0
	tag_query := world_query(world, Test_Position, Test_Tag)
	for _ in query_next(&tag_query) {
		count += 1
	}
	testing.expect_value(t, count, 2)
}

@(test)
test_resources :: proc(t: ^testing.T) {
	world := world_create()
	defer world_destroy(world)

	settings_cleanup_calls = 0

	_, missing := world_get_resource(world, Test_Settings)
	testing.expect(t, !missing)

	world_insert_resource(world, Test_Settings{1}, test_settings_cleanup)
	settings, ok := world_get_resource(world, Test_Settings)
	testing.expect(t, ok)
	testing.expect_value(t, settings.value, 1)

	// Replacing a resource cleans up the old one.
	world_insert_resource(world, Test_Settings{2}, test_settings_cleanup)
	testing.expect_value(t, settings_cleanup_calls, 1)
	settings, ok = world_get_resource(world, Test_Settings)
	testing.expect(t, ok)
	testing.expect_value(t, settings.value, 2)

	world_destroy_resource(world, Test_Settings)
	testing.expect_value(t, settings_cleanup_calls, 2)
	_, ok = world_get_resource(world, Test_Settings)
	testing.expect(t, !ok)
}
