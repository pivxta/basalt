package becs

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

@(private = "file")
Test_A :: struct {
	value: int,
}

@(private = "file")
Test_B :: struct {
	value: int,
}

@(private = "file")
Test_C :: struct {
	value: int,
}

@(private = "file")
Test_D :: struct {
	value: int,
}

@(private = "file")
Test_E :: struct {
	value: int,
}

@(private = "file")
Test_F :: struct {
	value: int,
}

@(private = "file")
Query_Fixture :: struct {
	world:   ^World,
	all:     Entity, // Test_A through Test_F, values 11 to 16
	partial: Entity, // Test_A through Test_E, values 21 to 25
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
	world := create_world()
	defer destroy_world(world)

	entity := spawn(world, Test_Position{1, 2}, Test_Velocity{3, 4})
	testing.expect(t, is_alive(world, entity))

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
	world := create_world()
	defer destroy_world(world)

	entity := spawn(world, Test_Position{1, 2})
	insert_components(world, entity, Test_Position{5, 6})

	position, ok := get_component(world, entity, Test_Position)
	testing.expect(t, ok)
	testing.expect_value(t, position^, Test_Position{5, 6})

	count := 0
	query := query(world, Test_Position)
	for _ in query_next(&query) {
		count += 1
	}
	testing.expect_value(t, count, 1)
}

@(test)
test_remove_component :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	entity := spawn(world, Test_Position{1, 2}, Test_Velocity{3, 4})
	remove_component(world, entity, Test_Velocity)

	testing.expect(t, is_alive(world, entity))
	testing.expect(t, has_component(world, entity, Test_Position))
	testing.expect(t, !has_component(world, entity, Test_Velocity))

	// Removing something that isn't there is a no-op.
	remove_component(world, entity, Test_Velocity)
	remove_component(world, entity, Test_Tag)
}

@(test)
test_despawn_and_stale_entity :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	old := spawn(world, Test_Position{1, 1})
	despawn(world, old)
	testing.expect(t, !is_alive(world, old))

	// A new entity may reuse the old index; the old handle must still see nothing.
	new := spawn(world, Test_Position{2, 2})
	testing.expect(t, is_alive(world, new))
	testing.expect(t, !is_alive(world, old))
	testing.expect(t, !has_component(world, old, Test_Position))

	_, old_ok := get_component(world, old, Test_Position)
	testing.expect(t, !old_ok)

	position, new_ok := get_component(world, new, Test_Position)
	testing.expect(t, new_ok)
	testing.expect_value(t, position^, Test_Position{2, 2})

	// Despawning a dead entity is a no-op.
	despawn(world, old)
}

@(test)
test_despawn_removes_all_components :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	entity := spawn(world, Test_Position{1, 2}, Test_Velocity{3, 4}, Test_Tag{})
	despawn(world, entity)

	count := 0
	query := query(world, Test_Position)
	for _ in query_next(&query) {
		count += 1
	}
	testing.expect_value(t, count, 0)
}

@(test)
test_query_matches_only_entities_with_all_components :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	both := spawn(world, Test_Position{1, 0}, Test_Velocity{10, 0})
	_ = spawn(world, Test_Position{2, 0})
	_ = spawn(world, Test_Velocity{20, 0})

	count := 0
	query := query(world, Test_Position, Test_Velocity)
	for pos, vel, entity in query_next(&query) {
		count += 1
		testing.expect_value(t, entity, both)
		pos.x += vel.x
	}
	testing.expect_value(t, count, 1)
	testing.expect_value(t, world.active_queries, 0)

	// Writes through the query pointers land in the world.
	position, _ := get_component(world, both, Test_Position)
	testing.expect_value(t, position^, Test_Position{11, 0})
}

@(test)
test_query_without_storage_is_empty :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	_ = spawn(world, Test_Position{1, 2})

	count := 0
	query := query(world, Test_Position, Test_Velocity)
	for _ in query_next(&query) {
		count += 1
	}
	testing.expect_value(t, count, 0)
	testing.expect_value(t, world.active_queries, 0)
}

@(test)
test_insert_during_query_is_deferred :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	entity := spawn(world, Test_Position{1, 2})

	query := query(world, Test_Position)
	for _, current_entity in query_next(&query) {
		insert_components(world, current_entity, Test_Velocity{3, 4})
		testing.expect(t, !has_component(world, current_entity, Test_Velocity))
	}

	velocity, ok := get_component(world, entity, Test_Velocity)
	testing.expect(t, ok)
	testing.expect_value(t, velocity^, Test_Velocity{3, 4})
}

@(test)
test_remove_during_query_is_deferred :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	entity := spawn(world, Test_Position{1, 2}, Test_Velocity{3, 4})

	query := query(world, Test_Position)
	for _, current_entity in query_next(&query) {
		remove_component(world, current_entity, Test_Velocity)
		testing.expect(t, has_component(world, current_entity, Test_Velocity))
	}

	testing.expect(t, !has_component(world, entity, Test_Velocity))
}

@(test)
test_despawn_during_query_is_deferred :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	a := spawn(world, Test_Position{1, 0})
	b := spawn(world, Test_Position{2, 0})

	count := 0
	query := query(world, Test_Position)
	for _, current_entity in query_next(&query) {
		count += 1
		despawn(world, current_entity)
		testing.expect(t, is_alive(world, current_entity))
	}

	// Both entities were visited, even though the first one was despawned mid-loop.
	testing.expect_value(t, count, 2)
	testing.expect(t, !is_alive(world, a))
	testing.expect(t, !is_alive(world, b))
}

@(test)
test_spawn_during_query :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	_ = spawn(world, Test_Position{1, 2})

	spawned: Entity
	query := query(world, Test_Position)
	for _ in query_next(&query) {
		spawned = spawn(world, Test_Velocity{5, 6})
		testing.expect(t, is_alive(world, spawned))
		testing.expect(t, !has_component(world, spawned, Test_Velocity))
	}

	velocity, ok := get_component(world, spawned, Test_Velocity)
	testing.expect(t, ok)
	testing.expect_value(t, velocity^, Test_Velocity{5, 6})
}

@(test)
test_early_break_flushes_on_query_end :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	entity := spawn(world, Test_Position{1, 2})

	query := query(world, Test_Position)
	for _, current_entity in query_next(&query) {
		despawn(world, current_entity)
		break
	}

	// The loop never finished, so the despawn is still waiting.
	testing.expect(t, is_alive(world, entity))
	testing.expect_value(t, world.active_queries, 1)

	query_end(&query)
	testing.expect(t, !is_alive(world, entity))
	testing.expect_value(t, world.active_queries, 0)

	// Ending twice is harmless.
	query_end(&query)
	testing.expect_value(t, world.active_queries, 0)
}

@(test)
test_nested_queries_flush_at_outer_end :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	_ = spawn(world, Test_Position{1, 2})
	target := spawn(world, Test_Velocity{3, 4})

	outer := query(world, Test_Position)
	for _ in query_next(&outer) {
		inner := query(world, Test_Velocity)
		for _, current_entity in query_next(&inner) {
			despawn(world, current_entity)
		}

		// The inner query has ended, but the outer one is still running.
		testing.expect(t, is_alive(world, target))
		testing.expect_value(t, world.active_queries, 1)
	}

	testing.expect(t, !is_alive(world, target))
	testing.expect_value(t, world.active_queries, 0)
}

@(test)
test_insert_after_despawn_in_same_query_is_skipped :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	entity := spawn(world, Test_Position{1, 2})

	query := query(world, Test_Position)
	for _, current_entity in query_next(&query) {
		despawn(world, current_entity)
		insert_components(world, current_entity, Test_Velocity{3, 4})
	}

	// Reaching this line means the flush skipped the insert instead of asserting.
	testing.expect(t, !is_alive(world, entity))
	testing.expect(t, !has_component(world, entity, Test_Velocity))
}

@(test)
test_zero_sized_components :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	direct := spawn(world, Test_Position{1, 0}, Test_Tag{})
	deferred := spawn(world, Test_Position{2, 0})
	testing.expect(t, has_component(world, direct, Test_Tag))

	// Only zero-sized components are deferred, so the byte buffer stays empty.
	pos_query := query(world, Test_Position)
	for _, current_entity in query_next(&pos_query) {
		if current_entity == deferred {
			insert_components(world, current_entity, Test_Tag{})
		}
	}
	testing.expect(t, has_component(world, deferred, Test_Tag))

	count := 0
	tag_query := query(world, Test_Position, Test_Tag)
	for _ in query_next(&tag_query) {
		count += 1
	}
	testing.expect_value(t, count, 2)
}

@(test)
test_resources :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	settings_cleanup_calls = 0

	_, missing := get_resource(world, Test_Settings)
	testing.expect(t, !missing)

	insert_resource(world, Test_Settings{1}, test_settings_cleanup)
	settings, ok := get_resource(world, Test_Settings)
	testing.expect(t, ok)
	testing.expect_value(t, settings.value, 1)

	// Replacing a resource cleans up the old one.
	insert_resource(world, Test_Settings{2}, test_settings_cleanup)
	testing.expect_value(t, settings_cleanup_calls, 1)
	settings, ok = get_resource(world, Test_Settings)
	testing.expect(t, ok)
	testing.expect_value(t, settings.value, 2)

	destroy_resource(world, Test_Settings)
	testing.expect_value(t, settings_cleanup_calls, 2)
	_, ok = get_resource(world, Test_Settings)
	testing.expect(t, !ok)
}

@(private = "file")
query_fixture_make :: proc() -> (fixture: Query_Fixture) {
	fixture.world = create_world()
	fixture.all = spawn(
		fixture.world,
		Test_A{11},
		Test_B{12},
		Test_C{13},
		Test_D{14},
		Test_E{15},
		Test_F{16},
	)
	fixture.partial = spawn(
		fixture.world,
		Test_A{21},
		Test_B{22},
		Test_C{23},
		Test_D{24},
		Test_E{25},
	)
	// Only in the Test_F set, so a six-component query has a candidate to skip.
	_ = spawn(fixture.world, Test_F{36})
	return fixture
}

// The first digit of every component value for the entity, or -100 for an unexpected entity.
@(private = "file")
query_fixture_base :: proc(fixture: Query_Fixture, entity: Entity) -> int {
	switch entity {
	case fixture.all:
		return 10
	case fixture.partial:
		return 20
	}
	return -100
}

@(test)
test_query_1 :: proc(t: ^testing.T) {
	fixture := query_fixture_make()
	defer destroy_world(fixture.world)

	count := 0
	query := query(fixture.world, Test_A)
	for a, entity, index in query_next(&query) {
		base := query_fixture_base(fixture, entity)
		testing.expect_value(t, index, count)
		testing.expect_value(t, a.value, base + 1)
		count += 1
	}
	testing.expect_value(t, count, 2)
	testing.expect_value(t, fixture.world.active_queries, 0)
}

@(test)
test_query_2 :: proc(t: ^testing.T) {
	fixture := query_fixture_make()
	defer destroy_world(fixture.world)

	count := 0
	query := query(fixture.world, Test_A, Test_B)
	for a, b, entity, index in query_next(&query) {
		base := query_fixture_base(fixture, entity)
		testing.expect_value(t, index, count)
		testing.expect_value(t, a.value, base + 1)
		testing.expect_value(t, b.value, base + 2)
		count += 1
	}
	testing.expect_value(t, count, 2)
	testing.expect_value(t, fixture.world.active_queries, 0)
}

@(test)
test_query_3 :: proc(t: ^testing.T) {
	fixture := query_fixture_make()
	defer destroy_world(fixture.world)

	count := 0
	query := query(fixture.world, Test_A, Test_B, Test_C)
	for a, b, c, entity, index in query_next(&query) {
		base := query_fixture_base(fixture, entity)
		testing.expect_value(t, index, count)
		testing.expect_value(t, a.value, base + 1)
		testing.expect_value(t, b.value, base + 2)
		testing.expect_value(t, c.value, base + 3)
		count += 1
	}
	testing.expect_value(t, count, 2)
	testing.expect_value(t, fixture.world.active_queries, 0)
}

@(test)
test_query_4 :: proc(t: ^testing.T) {
	fixture := query_fixture_make()
	defer destroy_world(fixture.world)

	count := 0
	query := query(fixture.world, Test_A, Test_B, Test_C, Test_D)
	for a, b, c, d, entity, index in query_next(&query) {
		base := query_fixture_base(fixture, entity)
		testing.expect_value(t, index, count)
		testing.expect_value(t, a.value, base + 1)
		testing.expect_value(t, b.value, base + 2)
		testing.expect_value(t, c.value, base + 3)
		testing.expect_value(t, d.value, base + 4)
		count += 1
	}
	testing.expect_value(t, count, 2)
	testing.expect_value(t, fixture.world.active_queries, 0)
}

@(test)
test_query_5 :: proc(t: ^testing.T) {
	fixture := query_fixture_make()
	defer destroy_world(fixture.world)

	count := 0
	query := query(fixture.world, Test_A, Test_B, Test_C, Test_D, Test_E)
	for a, b, c, d, e, entity, index in query_next(&query) {
		base := query_fixture_base(fixture, entity)
		testing.expect_value(t, index, count)
		testing.expect_value(t, a.value, base + 1)
		testing.expect_value(t, b.value, base + 2)
		testing.expect_value(t, c.value, base + 3)
		testing.expect_value(t, d.value, base + 4)
		testing.expect_value(t, e.value, base + 5)
		count += 1
	}
	testing.expect_value(t, count, 2)
	testing.expect_value(t, fixture.world.active_queries, 0)
}

@(test)
test_query_6 :: proc(t: ^testing.T) {
	fixture := query_fixture_make()
	defer destroy_world(fixture.world)

	count := 0
	query := query(fixture.world, Test_A, Test_B, Test_C, Test_D, Test_E, Test_F)
	for a, b, c, d, e, f, entity, index in query_next(&query) {
		testing.expect_value(t, entity, fixture.all)
		testing.expect_value(t, index, count)
		testing.expect_value(t, a.value, 11)
		testing.expect_value(t, b.value, 12)
		testing.expect_value(t, c.value, 13)
		testing.expect_value(t, d.value, 14)
		testing.expect_value(t, e.value, 15)
		testing.expect_value(t, f.value, 16)
		count += 1
	}
	testing.expect_value(t, count, 1)
	testing.expect_value(t, fixture.world.active_queries, 0)
}

// Runs every query_single arity and expects the same error from all of them.
// When exactly one entity is expected, also checks that it and its values come back.
@(private = "file")
expect_query_single :: proc(
	t: ^testing.T,
	world: ^World,
	expected: Query_Single_Error,
	single: Entity = {},
	loc := #caller_location,
) {
	found := expected != .None_Found

	{
		a, entity, err := query_single(world, Test_A)
		testing.expect_value(t, err, expected, loc = loc)
		testing.expect(t, (a != nil) == found, loc = loc)
		if expected == .None {
			testing.expect_value(t, entity, single, loc = loc)
			testing.expect_value(t, a.value, 11, loc = loc)
		}
	}
	{
		a, b, entity, err := query_single(world, Test_A, Test_B)
		testing.expect_value(t, err, expected, loc = loc)
		testing.expect(t, (a != nil && b != nil) == found, loc = loc)
		if expected == .None {
			testing.expect_value(t, entity, single, loc = loc)
			testing.expect_value(t, b.value, 12, loc = loc)
		}
	}
	{
		a, b, c, entity, err := query_single(world, Test_A, Test_B, Test_C)
		testing.expect_value(t, err, expected, loc = loc)
		testing.expect(t, (a != nil && b != nil && c != nil) == found, loc = loc)
		if expected == .None {
			testing.expect_value(t, entity, single, loc = loc)
			testing.expect_value(t, c.value, 13, loc = loc)
		}
	}
	{
		a, b, c, d, entity, err := query_single(world, Test_A, Test_B, Test_C, Test_D)
		testing.expect_value(t, err, expected, loc = loc)
		testing.expect(t, (a != nil && b != nil && c != nil && d != nil) == found, loc = loc)
		if expected == .None {
			testing.expect_value(t, entity, single, loc = loc)
			testing.expect_value(t, d.value, 14, loc = loc)
		}
	}
	{
		a, b, c, d, e, entity, err := query_single(world, Test_A, Test_B, Test_C, Test_D, Test_E)
		testing.expect_value(t, err, expected, loc = loc)
		testing.expect(
			t,
			(a != nil && b != nil && c != nil && d != nil && e != nil) == found,
			loc = loc,
		)
		if expected == .None {
			testing.expect_value(t, entity, single, loc = loc)
			testing.expect_value(t, e.value, 15, loc = loc)
		}
	}
	{
		a, b, c, d, e, f, entity, err := query_single(
			world,
			Test_A,
			Test_B,
			Test_C,
			Test_D,
			Test_E,
			Test_F,
		)
		testing.expect_value(t, err, expected, loc = loc)
		testing.expect(
			t,
			(a != nil && b != nil && c != nil && d != nil && e != nil && f != nil) == found,
			loc = loc,
		)
		if expected == .None {
			testing.expect_value(t, entity, single, loc = loc)
			testing.expect_value(t, f.value, 16, loc = loc)
		}
	}

	testing.expect_value(t, world.active_queries, 0, loc = loc)
}

@(test)
test_query_single :: proc(t: ^testing.T) {
	world := create_world()
	defer destroy_world(world)

	// Nothing exists yet.
	expect_query_single(t, world, .None_Found)

	// Exactly one entity matches every arity.
	first := spawn(world, Test_A{11}, Test_B{12}, Test_C{13}, Test_D{14}, Test_E{15}, Test_F{16})
	expect_query_single(t, world, .None, first)

	// A second match makes every arity report it, while still returning a result.
	_ = spawn(world, Test_A{21}, Test_B{22}, Test_C{23}, Test_D{24}, Test_E{25}, Test_F{26})
	expect_query_single(t, world, .Multiple_Found)
}
