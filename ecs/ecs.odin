package becs
import "base:runtime"
import "core:container/handle_map"
@(require) import "core:mem"

Entity :: handle_map.Handle64

World :: struct {
	resources:      map[typeid]Resource_Entry,
	sparse_sets:    map[typeid]Sparse_Set_Entry,
	handle_map:     handle_map.Dynamic_Handle_Map(Entity_Slot, Entity),
	allocator:      runtime.Allocator,
	active_queries: int,
	command_buffer: Command_Buffer,
}

@(private = "file")
Resource_Entry :: struct {
	resource: rawptr,
	cleanup:  Resource_Cleanup_Proc,
	destroy:  Resource_Destroy_Proc,
}

@(private = "file")
Sparse_Set_Entry :: struct {
	set:     rawptr,
	remove:  Sparse_Set_Remove_Proc,
	destroy: Sparse_Set_Destroy_Proc,
}

@(private = "file")
Entity_Slot :: struct {
	handle: Entity,
}

@(private = "file")
Sparse_Set_Remove_Proc :: #type proc(set: rawptr, entity: Entity)

@(private = "file")
Sparse_Set_Destroy_Proc :: #type proc(set: rawptr)

@(private = "file")
Resource_Cleanup_Proc :: #type proc(resource: rawptr)

@(private = "file")
Resource_Destroy_Proc :: #type proc(resource: rawptr, allocator: runtime.Allocator)

create_world :: proc(allocator := context.allocator) -> (world: ^World) {
	world = new(World, allocator)
	world.allocator = allocator
	world.command_buffer = command_buffer_make(allocator)
	world.resources = make(map[typeid]Resource_Entry, allocator)
	world.sparse_sets = make(map[typeid]Sparse_Set_Entry, allocator)
	handle_map.dynamic_init(&world.handle_map, allocator)
	return world
}

destroy_world :: proc(world: ^World) {
	if world == nil {
		return
	}

	assert(world.active_queries == 0)

	for _, entry in world.resources {
		if entry.cleanup != nil {
			entry.cleanup(entry.resource)
		}
		entry.destroy(entry.resource, world.allocator)
	}

	for _, entry in world.sparse_sets {
		entry.destroy(entry.set)
	}

	delete(world.resources)
	delete(world.sparse_sets)
	handle_map.dynamic_destroy(&world.handle_map)
	command_buffer_destroy(&world.command_buffer)

	free(world, world.allocator)
}

insert_resource :: proc(world: ^World, resource: $R, cleanup: proc(resource: ^R) = nil) {
	assert(world != nil)
	if entry, exists := world.resources[R]; exists {
		if entry.cleanup != nil {
			entry.cleanup(entry.resource)
		}
		entry.destroy(entry.resource, world.allocator)
	}
	world.resources[R] = {
		resource = rawptr(new_clone(resource, world.allocator)),
		cleanup = transmute(Resource_Cleanup_Proc)cleanup,
		destroy = proc(resource: rawptr, allocator: runtime.Allocator) {
			free(cast(^R)resource, allocator)
		},
	}
}

destroy_resource :: proc(world: ^World, $R: typeid) {
	assert(world != nil)
	if entry, exists := world.resources[R]; exists {
		if entry.cleanup != nil {
			entry.cleanup(entry.resource)
		}
		entry.destroy(entry.resource, world.allocator)
	}
	delete_key(&world.resources, R)
}

get_resource :: proc(world: ^World, $R: typeid) -> (^R, bool) {
	assert(world != nil)
	if entry, exists := world.resources[R]; exists {
		return cast(^R)entry.resource, true
	}
	return nil, false
}

is_alive :: proc(world: ^World, entity: Entity) -> bool {
	assert(world != nil)
	return handle_map.is_valid(&world.handle_map, entity)
}

despawn :: proc(world: ^World, entity: Entity) {
	assert(world != nil)
	if world.active_queries == 0 {
		direct_despawn(world, entity)
	} else {
		command_despawn(&world.command_buffer, entity)
	}
}

spawn :: proc {
	spawn_empty,
	spawn_1,
	spawn_2,
	spawn_3,
	spawn_4,
	spawn_5,
	spawn_6,
}

spawn_empty :: proc(world: ^World) -> Entity {
	assert(world != nil)
	return handle_map.add(&world.handle_map, {})
}

spawn_1 :: proc(world: ^World, a: $A) -> Entity {
	assert(world != nil)
	entity := spawn_empty(world)
	insert_components(world, entity, a)
	return entity
}

spawn_2 :: proc(world: ^World, a: $A, b: $B) -> Entity {
	assert(world != nil)
	entity := spawn_empty(world)
	insert_components(world, entity, a, b)
	return entity
}

spawn_3 :: proc(world: ^World, a: $A, b: $B, c: $C) -> Entity {
	assert(world != nil)
	entity := spawn_empty(world)
	insert_components(world, entity, a, b, c)
	return entity
}

spawn_4 :: proc(world: ^World, a: $A, b: $B, c: $C, d: $D) -> Entity {
	assert(world != nil)
	entity := spawn_empty(world)
	insert_components(world, entity, a, b, c, d)
	return entity
}

spawn_5 :: proc(world: ^World, a: $A, b: $B, c: $C, d: $D, e: $E) -> Entity {
	assert(world != nil)
	entity := spawn_empty(world)
	insert_components(world, entity, a, b, c, d, e)
	return entity
}

spawn_6 :: proc(world: ^World, a: $A, b: $B, c: $C, d: $D, e: $E, f: $F) -> Entity {
	assert(world != nil)
	entity := spawn_empty(world)
	insert_components(world, entity, a, b, c, d, e, f)
	return entity
}

insert_components :: proc {
	insert_component,
	insert_components_2,
	insert_components_3,
	insert_components_4,
	insert_components_5,
	insert_components_6,
}

insert_component :: proc(world: ^World, entity: Entity, component: $C) {
	assert(world != nil)
	if world.active_queries == 0 {
		direct_insert_component(world, entity, component)
	} else {
		command_insert_component(&world.command_buffer, entity, component)
	}
}

insert_components_2 :: proc(world: ^World, entity: Entity, a: $A, b: $B) where A != B {
	assert(world != nil)
	insert_component(world, entity, a)
	insert_component(world, entity, b)
}

insert_components_3 :: proc(world: ^World, entity: Entity, a: $A, b: $B, c: $C) where A != B,
	A != C,
	B != C {
	assert(world != nil)
	insert_component(world, entity, a)
	insert_component(world, entity, b)
	insert_component(world, entity, c)
}

insert_components_4 :: proc(
	world: ^World,
	entity: Entity,
	a: $A,
	b: $B,
	c: $C,
	d: $D,
) where A !=
	B,
	A !=
	C,
	A !=
	D,
	B !=
	C,
	B !=
	D,
	C !=
	D {
	assert(world != nil)
	insert_component(world, entity, a)
	insert_component(world, entity, b)
	insert_component(world, entity, c)
	insert_component(world, entity, d)
}

insert_components_5 :: proc(
	world: ^World,
	entity: Entity,
	a: $A,
	b: $B,
	c: $C,
	d: $D,
	e: $E,
) where A !=
	B,
	A !=
	C,
	A !=
	D,
	A !=
	E,
	B !=
	C,
	B !=
	D,
	B !=
	E,
	C !=
	D,
	C !=
	E,
	D !=
	E {
	assert(world != nil)
	insert_component(world, entity, a)
	insert_component(world, entity, b)
	insert_component(world, entity, c)
	insert_component(world, entity, d)
	insert_component(world, entity, e)
}

insert_components_6 :: proc(
	world: ^World,
	entity: Entity,
	a: $A,
	b: $B,
	c: $C,
	d: $D,
	e: $E,
	f: $F,
) where A !=
	B,
	A !=
	C,
	A !=
	D,
	A !=
	E,
	A !=
	F,
	B !=
	C,
	B !=
	D,
	B !=
	E,
	B !=
	F,
	C !=
	D,
	C !=
	E,
	C !=
	F,
	D !=
	E,
	D !=
	F,
	E !=
	F {
	assert(world != nil)
	insert_component(world, entity, a)
	insert_component(world, entity, b)
	insert_component(world, entity, c)
	insert_component(world, entity, d)
	insert_component(world, entity, e)
	insert_component(world, entity, f)
}

remove_component :: proc(world: ^World, entity: Entity, $C: typeid) {
	assert(world != nil)
	if world.active_queries == 0 {
		direct_remove_component(world, entity, C)
	} else {
		command_remove_component(&world.command_buffer, entity, C)
	}
}

get_component :: proc(world: ^World, entity: Entity, $C: typeid) -> (^C, bool) {
	assert(world != nil)
	if entry, exists := world.sparse_sets[C]; exists {
		return sparse_get(cast(^Sparse_Set(C))entry.set, entity)
	}
	return nil, false
}

has_component :: proc(world: ^World, entity: Entity, $C: typeid) -> bool {
	assert(world != nil)
	if entry, exists := world.sparse_sets[C]; exists {
		return sparse_has(cast(^Sparse_Set(C))entry.set, entity)
	}
	return false
}

@(private = "file")
direct_despawn :: proc(world: ^World, entity: Entity) {
	if !is_alive(world, entity) {
		return
	}
	for _, entry in world.sparse_sets {
		entry.remove(entry.set, entity)
	}
	handle_map.remove(&world.handle_map, entity)
}

@(private = "file")
direct_insert_component :: proc(world: ^World, entity: Entity, component: $C) {
	assert(is_alive(world, entity))

	if entry, exists := world.sparse_sets[C]; exists {
		sparse_insert(cast(^Sparse_Set(C))entry.set, entity, component)
		return
	}

	set := sparse_create(C, world.allocator)
	world.sparse_sets[C] = {
		set     = rawptr(set),
		remove  = make_sparse_remove_proc(C),
		destroy = make_sparse_destroy_proc(C),
	}
	sparse_insert(set, entity, component)
}

@(private = "file")
direct_remove_component :: proc(world: ^World, entity: Entity, $C: typeid) {
	if entry, exists := world.sparse_sets[C]; exists {
		sparse_remove(cast(^Sparse_Set(C))entry.set, entity)
	}
}

@(private = "file")
make_sparse_destroy_proc :: proc($C: typeid) -> Sparse_Set_Destroy_Proc {
	return proc(set: rawptr) {
			sparse_destroy(cast(^Sparse_Set(C))set)
		}
}

@(private = "file")
make_sparse_remove_proc :: proc($C: typeid) -> Sparse_Set_Remove_Proc {
	return proc(set: rawptr, entity: Entity) {
			sparse_remove(cast(^Sparse_Set(C))set, entity)
		}
}

Query_Single_Error :: enum {
	None = 0,
	None_Found,
	Multiple_Found,
}

Query_1 :: struct($A: typeid) {
	world:    ^World,
	candidates: []Entity,
	data:     []A,
	iterated: int,
	index:    int,
	ended:    bool,
}

Query_2 :: struct($A, $B: typeid) {
	world:    ^World,
	a:        ^Sparse_Set(A),
	b:        ^Sparse_Set(B),
	candidates: []Entity,
	iterated: int,
	index:    int,
	ended:    bool,
}

Query_3 :: struct($A, $B, $C: typeid) {
	world:    ^World,
	a:        ^Sparse_Set(A),
	b:        ^Sparse_Set(B),
	c:        ^Sparse_Set(C),
	candidates: []Entity,
	iterated: int,
	index:    int,
	ended:    bool,
}

Query_4 :: struct($A, $B, $C, $D: typeid) {
	world:    ^World,
	a:        ^Sparse_Set(A),
	b:        ^Sparse_Set(B),
	c:        ^Sparse_Set(C),
	d:        ^Sparse_Set(D),
	candidates: []Entity,
	iterated: int,
	index:    int,
	ended:    bool,
}

Query_5 :: struct($A, $B, $C, $D, $E: typeid) {
	world:    ^World,
	a:        ^Sparse_Set(A),
	b:        ^Sparse_Set(B),
	c:        ^Sparse_Set(C),
	d:        ^Sparse_Set(D),
	e:        ^Sparse_Set(E),
	candidates: []Entity,
	iterated: int,
	index:    int,
	ended:    bool,
}

Query_6 :: struct($A, $B, $C, $D, $E, $F: typeid) {
	world:    ^World,
	a:        ^Sparse_Set(A),
	b:        ^Sparse_Set(B),
	c:        ^Sparse_Set(C),
	d:        ^Sparse_Set(D),
	e:        ^Sparse_Set(E),
	f:        ^Sparse_Set(F),
	candidates: []Entity,
	iterated: int,
	index:    int,
	ended:    bool,
}

query :: proc {
	query_1,
	query_2,
	query_3,
	query_4,
	query_5,
	query_6,
}

query_single :: proc {
	query_single_1,
	query_single_2,
	query_single_3,
	query_single_4,
	query_single_5,
	query_single_6,
}

query_next :: proc {
	query_1_next,
	query_2_next,
	query_3_next,
	query_4_next,
	query_5_next,
	query_6_next,
}

query_end :: proc {
	query_1_end,
	query_2_end,
	query_3_end,
	query_4_end,
	query_5_end,
	query_6_end,
}

query_1 :: proc(world: ^World, $A: typeid) -> (query: Query_1(A)) {
	assert(world != nil)

	world.active_queries += 1
	query.world = world

	set := get_sparse_set(world, A)
	if set == nil {
		return query
	}

	query.candidates = set.dense[:]
	query.data = set.data[:]
	return query
}

query_2 :: proc(world: ^World, $A, $B: typeid) -> (query: Query_2(A, B)) where A != B {
	assert(world != nil)

	world.active_queries += 1
	query.world = world
	query.a = get_sparse_set(world, A)
	query.b = get_sparse_set(world, B)
	if query.a == nil || query.b == nil {
		return query
	}

	query.candidates = smallest_dense(query.a.dense[:], query.b.dense[:])
	return query
}

query_3 :: proc(world: ^World, $A, $B, $C: typeid) -> (query: Query_3(A, B, C)) where A != B,
	A != C,
	B != C {
	assert(world != nil)

	world.active_queries += 1
	query.world = world
	query.a = get_sparse_set(world, A)
	query.b = get_sparse_set(world, B)
	query.c = get_sparse_set(world, C)
	if query.a == nil || query.b == nil || query.c == nil {
		return query
	}

	query.candidates = smallest_dense(query.a.dense[:], query.b.dense[:], query.c.dense[:])
	return query
}

query_4 :: proc(
	world: ^World,
	$A, $B, $C, $D: typeid,
) -> (
	query: Query_4(A, B, C, D),
) where A !=
	B,
	A !=
	C,
	A !=
	D,
	B !=
	C,
	B !=
	D,
	C !=
	D {
	assert(world != nil)

	world.active_queries += 1
	query.world = world
	query.a = get_sparse_set(world, A)
	query.b = get_sparse_set(world, B)
	query.c = get_sparse_set(world, C)
	query.d = get_sparse_set(world, D)
	if query.a == nil || query.b == nil || query.c == nil || query.d == nil {
		return query
	}

	query.candidates = smallest_dense(
		query.a.dense[:],
		query.b.dense[:],
		query.c.dense[:],
		query.d.dense[:],
	)
	return query
}

query_5 :: proc(
	world: ^World,
	$A, $B, $C, $D, $E: typeid,
) -> (
	query: Query_5(A, B, C, D, E),
) where A !=
	B,
	A !=
	C,
	A !=
	D,
	A !=
	E,
	B !=
	C,
	B !=
	D,
	B !=
	E,
	C !=
	D,
	C !=
	E,
	D !=
	E {
	assert(world != nil)

	world.active_queries += 1
	query.world = world
	query.a = get_sparse_set(world, A)
	query.b = get_sparse_set(world, B)
	query.c = get_sparse_set(world, C)
	query.d = get_sparse_set(world, D)
	query.e = get_sparse_set(world, E)
	if query.a == nil || query.b == nil || query.c == nil || query.d == nil || query.e == nil {
		return query
	}

	query.candidates = smallest_dense(
		query.a.dense[:],
		query.b.dense[:],
		query.c.dense[:],
		query.d.dense[:],
		query.e.dense[:],
	)
	return query
}

query_6 :: proc(
	world: ^World,
	$A, $B, $C, $D, $E, $F: typeid,
) -> (
	query: Query_6(A, B, C, D, E, F),
) where A !=
	B,
	A !=
	C,
	A !=
	D,
	A !=
	E,
	A !=
	F,
	B !=
	C,
	B !=
	D,
	B !=
	E,
	B !=
	F,
	C !=
	D,
	C !=
	E,
	C !=
	F,
	D !=
	E,
	D !=
	F,
	E !=
	F {
	assert(world != nil)

	world.active_queries += 1
	query.world = world
	query.a = get_sparse_set(world, A)
	query.b = get_sparse_set(world, B)
	query.c = get_sparse_set(world, C)
	query.d = get_sparse_set(world, D)
	query.e = get_sparse_set(world, E)
	query.f = get_sparse_set(world, F)
	if query.a == nil ||
	   query.b == nil ||
	   query.c == nil ||
	   query.d == nil ||
	   query.e == nil ||
	   query.f == nil {
		return query
	}

	query.candidates = smallest_dense(
		query.a.dense[:],
		query.b.dense[:],
		query.c.dense[:],
		query.d.dense[:],
		query.e.dense[:],
		query.f.dense[:],
	)
	return query
}

query_single_1 :: proc(
	world: ^World,
	$A: typeid,
) -> (
	^A,
	Entity,
	Query_Single_Error,
) {
	query := query(world, A)
	defer query_end(&query)

	a, entity, _, found := query_next(&query)
	if !found {
		return nil, {}, .None_Found
	}
	if _, _, _, more := query_next(&query); more {
		return a, entity, .Multiple_Found
	}
	return a, entity, .None
}

query_single_2 :: proc(
	world: ^World,
	$A, $B: typeid,
) -> (
	^A,
	^B,
	Entity,
	Query_Single_Error,
) where A != B {
	query := query(world, A, B)
	defer query_end(&query)

	a, b, entity, _, found := query_next(&query)
	if !found {
		return nil, nil, {}, .None_Found
	}
	if _, _, _, _, more := query_next(&query); more {
		return a, b, entity, .Multiple_Found
	}
	return a, b, entity, .None
}

query_single_3 :: proc(
	world: ^World,
	$A, $B, $C: typeid,
) -> (
	^A,
	^B,
	^C,
	Entity,
	Query_Single_Error,
) where A != B,
	A != C,
	B != C {
	query := query(world, A, B, C)
	defer query_end(&query)

	a, b, c, entity, _, found := query_next(&query)
	if !found {
		return nil, nil, nil, {}, .None_Found
	}
	if _, _, _, _, _, more := query_next(&query); more {
		return a, b, c, entity, .Multiple_Found
	}
	return a, b, c, entity, .None
}

query_single_4 :: proc(
	world: ^World,
	$A, $B, $C, $D: typeid,
) -> (
	^A,
	^B,
	^C,
	^D,
	Entity,
	Query_Single_Error,
) where A != B,
	A != C,
	A != D,
	B != C,
	B != D,
	C != D {
	query := query(world, A, B, C, D)
	defer query_end(&query)

	a, b, c, d, entity, _, found := query_next(&query)
	if !found {
		return nil, nil, nil, nil, {}, .None_Found
	}
	if _, _, _, _, _, _, more := query_next(&query); more {
		return a, b, c, d, entity, .Multiple_Found
	}
	return a, b, c, d, entity, .None
}

query_single_5 :: proc(
	world: ^World,
	$A, $B, $C, $D, $E: typeid,
) -> (
	^A,
	^B,
	^C,
	^D,
	^E,
	Entity,
	Query_Single_Error,
) where A != B,
	A != C,
	A != D,
	A != E,
	B != C,
	B != D,
	B != E,
	C != D,
	C != E,
	D != E {
	query := query(world, A, B, C, D, E)
	defer query_end(&query)

	a, b, c, d, e, entity, _, found := query_next(&query)
	if !found {
		return nil, nil, nil, nil, nil, {}, .None_Found
	}
	if _, _, _, _, _, _, _, more := query_next(&query); more {
		return a, b, c, d, e, entity, .Multiple_Found
	}
	return a, b, c, d, e, entity, .None
}

query_single_6 :: proc(
	world: ^World,
	$A, $B, $C, $D, $E, $F: typeid,
) -> (
	^A,
	^B,
	^C,
	^D,
	^E,
	^F,
	Entity,
	Query_Single_Error,
) where A != B,
	A != C,
	A != D,
	A != E,
	A != F,
	B != C,
	B != D,
	B != E,
	B != F,
	C != D,
	C != E,
	C != F,
	D != E,
	D != F,
	E != F {
	query := query(world, A, B, C, D, E, F)
	defer query_end(&query)

	a, b, c, d, e, f, entity, _, found := query_next(&query)
	if !found {
		return nil, nil, nil, nil, nil, nil, {}, .None_Found
	}
	if _, _, _, _, _, _, _, _, more := query_next(&query); more {
		return a, b, c, d, e, f, entity, .Multiple_Found
	}
	return a, b, c, d, e, f, entity, .None
}

query_1_end :: proc(query: ^Query_1($A)) {
	if query.ended {
		return
	}
	query.world.active_queries -= 1
	query.ended = true
	if query.world.active_queries == 0 {
		command_buffer_flush(&query.world.command_buffer, query.world)
	}
}

query_2_end :: proc(query: ^Query_2($A, $B)) {
	if query.ended {
		return
	}
	query.world.active_queries -= 1
	query.ended = true
	if query.world.active_queries == 0 {
		command_buffer_flush(&query.world.command_buffer, query.world)
	}
}

query_3_end :: proc(query: ^Query_3($A, $B, $C)) {
	if query.ended {
		return
	}
	query.world.active_queries -= 1
	query.ended = true
	if query.world.active_queries == 0 {
		command_buffer_flush(&query.world.command_buffer, query.world)
	}
}

query_4_end :: proc(query: ^Query_4($A, $B, $C, $D)) {
	if query.ended {
		return
	}
	query.world.active_queries -= 1
	query.ended = true
	if query.world.active_queries == 0 {
		command_buffer_flush(&query.world.command_buffer, query.world)
	}
}

query_5_end :: proc(query: ^Query_5($A, $B, $C, $D, $E)) {
	if query.ended {
		return
	}
	query.world.active_queries -= 1
	query.ended = true
	if query.world.active_queries == 0 {
		command_buffer_flush(&query.world.command_buffer, query.world)
	}
}

query_6_end :: proc(query: ^Query_6($A, $B, $C, $D, $E, $F)) {
	if query.ended {
		return
	}
	query.world.active_queries -= 1
	query.ended = true
	if query.world.active_queries == 0 {
		command_buffer_flush(&query.world.command_buffer, query.world)
	}
}

query_1_next :: proc(query: ^Query_1($A)) -> (a: ^A, entity: Entity, index: int, ok: bool) {
	if query.ended {
		return
	}

	if query.index >= len(query.candidates) {
		query_end(query)
		return
	}

	a = &query.data[query.index]
	entity = query.candidates[query.index]
	index = query.iterated
	query.index += 1
	query.iterated += 1
	return a, entity, index, true
}

query_2_next :: proc(query: ^Query_2($A, $B)) -> (
	a: ^A,
	b: ^B,
	entity: Entity,
	index: int, 
	ok: bool,
) {
	if query.ended {
		return
	}

	for query.index < len(query.candidates) {
		entity = query.candidates[query.index]
		query.index += 1

		a = sparse_get(query.a, entity) or_continue
		b = sparse_get(query.b, entity) or_continue
		index = query.iterated
		query.iterated += 1

		ok = true
		return
	}

	query_end(query)
	entity = {}
	a = nil
	b = nil
	return
}

query_3_next :: proc(query: ^Query_3($A, $B, $C)) -> (
	a: ^A,
	b: ^B,
	c: ^C,
	entity: Entity,
	index: int, 
	ok: bool,
) {
	if query.ended {
		return
	}

	for query.index < len(query.candidates) {
		entity = query.candidates[query.index]
		query.index += 1

		a = sparse_get(query.a, entity) or_continue
		b = sparse_get(query.b, entity) or_continue
		c = sparse_get(query.c, entity) or_continue
		index = query.iterated
		query.iterated += 1

		ok = true
		return
	}

	query_end(query)
	entity = {}
	a = nil
	b = nil
	c = nil
	return
}

query_4_next :: proc(
	query: ^Query_4($A, $B, $C, $D),
) -> (
	a: ^A,
	b: ^B,
	c: ^C,
	d: ^D,
	entity: Entity,
	index: int,
	ok: bool,
) {
	if query.ended {
		return
	}

	for query.index < len(query.candidates) {
		entity = query.candidates[query.index]
		query.index += 1

		a = sparse_get(query.a, entity) or_continue
		b = sparse_get(query.b, entity) or_continue
		c = sparse_get(query.c, entity) or_continue
		d = sparse_get(query.d, entity) or_continue
		index = query.iterated
		query.iterated += 1

		ok = true
		return
	}

	query_end(query)
	entity = {}
	a = nil
	b = nil
	c = nil
	d = nil
	return
}

query_5_next :: proc(
	query: ^Query_5($A, $B, $C, $D, $E),
) -> (
	a: ^A,
	b: ^B,
	c: ^C,
	d: ^D,
	e: ^E,
	entity: Entity,
	index: int,
	ok: bool,
) {
	if query.ended {
		return
	}

	for query.index < len(query.candidates) {
		entity = query.candidates[query.index]
		query.index += 1

		a = sparse_get(query.a, entity) or_continue
		b = sparse_get(query.b, entity) or_continue
		c = sparse_get(query.c, entity) or_continue
		d = sparse_get(query.d, entity) or_continue
		e = sparse_get(query.e, entity) or_continue
		index = query.iterated
		query.iterated += 1

		ok = true
		return
	}

	query_end(query)
	entity = {}
	a = nil
	b = nil
	c = nil
	d = nil
	e = nil
	return
}

query_6_next :: proc(
	query: ^Query_6($A, $B, $C, $D, $E, $F),
) -> (
	a: ^A,
	b: ^B,
	c: ^C,
	d: ^D,
	e: ^E,
	f: ^F,
	entity: Entity,
	index: int,
	ok: bool,
) {
	if query.ended {
		return
	}

	for query.index < len(query.candidates) {
		entity = query.candidates[query.index]
		query.index += 1

		a = sparse_get(query.a, entity) or_continue
		b = sparse_get(query.b, entity) or_continue
		c = sparse_get(query.c, entity) or_continue
		d = sparse_get(query.d, entity) or_continue
		e = sparse_get(query.e, entity) or_continue
		f = sparse_get(query.f, entity) or_continue
		index = query.iterated
		query.iterated += 1

		ok = true
		return
	}

	query_end(query)
	entity = {}
	a = nil
	b = nil
	c = nil
	d = nil
	e = nil
	f = nil
	return
}

@(private = "file")
get_sparse_set :: proc(world: ^World, $C: typeid) -> ^Sparse_Set(C) {
	if entry, exists := world.sparse_sets[C]; exists {
		return cast(^Sparse_Set(C))entry.set
	}
	return nil
}

@(private = "file")
smallest_dense :: proc(candidates: ..[]Entity) -> []Entity {
	smallest := candidates[0]
	for candidate in candidates[1:] {
		if len(candidate) < len(smallest) {
			smallest = candidate
		}
	}
	return smallest
}

@(private = "file")
Command_Kind :: enum {
	Despawn,
	Insert_Component,
	Remove_Component,
}

@(private = "file")
Command :: struct {
	kind:   Command_Kind,
	entity: Entity,
	type:   typeid,
	offset: int,
	insert: Command_Insert_Proc,
}

@(private = "file")
Command_Insert_Proc :: #type proc(world: ^World, entity: Entity, component: rawptr)

@(private = "file")
Command_Buffer :: struct {
	commands: [dynamic]Command,
	bytes:    [dynamic]byte,
}

@(private = "file")
command_buffer_make :: proc(allocator := context.allocator) -> (cmd: Command_Buffer) {
	cmd.commands = make([dynamic]Command, allocator)
	cmd.bytes = make([dynamic]byte, allocator)
	return
}

@(private = "file")
command_buffer_destroy :: proc(cmd: ^Command_Buffer) {
	delete(cmd.commands)
	delete(cmd.bytes)
	cmd^ = {}
}

@(private = "file")
command_buffer_is_empty :: proc(cmd: ^Command_Buffer) -> bool {
	return len(cmd.commands) == 0
}

@(private = "file")
command_buffer_clear :: proc(cmd: ^Command_Buffer) {
	clear(&cmd.commands)
	clear(&cmd.bytes)
}

@(private = "file")
command_buffer_flush :: proc(cmd: ^Command_Buffer, world: ^World) {
	for command in cmd.commands {
		switch command.kind {
		case .Despawn:
			despawn(world, command.entity)
		case .Insert_Component:
			if is_alive(world, command.entity) {
				command.insert(world, command.entity, raw_data(cmd.bytes[command.offset:]))
			}
		case .Remove_Component:
			if entry, exists := world.sparse_sets[command.type]; exists {
				entry.remove(entry.set, command.entity)
			}
		}
	}
	command_buffer_clear(cmd)
}

@(private = "file")
command_despawn :: proc(cmd: ^Command_Buffer, entity: Entity) {
	append(&cmd.commands, {kind = .Despawn, entity = entity})
}

@(private = "file")
command_insert_component :: proc(cmd: ^Command_Buffer, entity: Entity, component: $C) {
	when size_of(C) > 0 {
		offset := mem.align_forward_int(len(cmd.bytes), align_of(C))
		resize(&cmd.bytes, offset + size_of(C))
		(^C)(&cmd.bytes[offset])^ = component
	} else {
		offset := 0
	}

	append(&cmd.commands, {
		kind = .Insert_Component,
		type = C,
		entity = entity,
		offset = offset,
		insert = proc(world: ^World, entity: Entity, component: rawptr) {
			when size_of(C) > 0 {
				insert_component(world, entity, (cast(^C)component)^)
			} else {
				insert_component(world, entity, C{})
			}
		},
	})
}

@(private = "file")
command_remove_component :: proc(cmd: ^Command_Buffer, entity: Entity, $C: typeid) {
	append(&cmd.commands, {kind = .Remove_Component, entity = entity, type = C})
}

@(private = "file")
Sparse_Set :: struct($C: typeid) {
	allocator: runtime.Allocator,
	sparse:    [dynamic]int,
	dense:     [dynamic]Entity,
	data:      [dynamic]C,
}

@(private = "file")
sparse_create :: proc($C: typeid, allocator := context.allocator) -> ^Sparse_Set(C) {
	set := new(Sparse_Set(C), allocator)
	set.allocator = allocator
	set.sparse = make([dynamic]int, allocator)
	set.dense = make([dynamic]Entity, allocator)
	set.data = make([dynamic]C, allocator)
	return set
}

@(private = "file")
sparse_destroy :: proc(set: ^Sparse_Set($C)) {
	if set == nil {
		return
	}

	delete(set.sparse)
	delete(set.dense)
	delete(set.data)
	free(set, set.allocator)
}

@(private = "file")
sparse_insert :: proc(set: ^Sparse_Set($C), entity: Entity, component: C) {
	assert(set != nil)
	assert(entity != {})

	if len(set.sparse) <= int(entity.idx) {
		old_len := len(set.sparse)
		new_len := int(entity.idx) + 1
		resize(&set.sparse, new_len)
		for i in old_len ..< new_len {
			set.sparse[i] = -1
		}
	}

	if set.sparse[entity.idx] >= 0 {
		dense_idx := set.sparse[entity.idx]
		assert(set.dense[dense_idx].gen == entity.gen, "Stale entity in sparse set")
		set.data[dense_idx] = component
		return
	}

	dense_idx := len(set.dense)
	append(&set.dense, entity)
	append(&set.data, component)
	set.sparse[entity.idx] = dense_idx
}

@(private = "file")
sparse_remove :: proc(set: ^Sparse_Set($C), entity: Entity) {
	assert(set != nil)
	dense_idx, found := sparse_find(set, entity)
	if !found {
		return
	}

	last := set.dense[len(set.dense) - 1]
	set.sparse[last.idx] = dense_idx
	set.sparse[entity.idx] = -1

	unordered_remove(&set.dense, dense_idx)
	unordered_remove(&set.data, dense_idx)
}

@(private = "file")
sparse_has :: proc(set: ^Sparse_Set($C), entity: Entity) -> bool {
	_, has := sparse_find(set, entity)
	return has
}

@(private = "file")
sparse_get :: proc(set: ^Sparse_Set($C), entity: Entity) -> (component: ^C, has: bool) {
	dense_idx := sparse_find(set, entity) or_return
	return &set.data[dense_idx], true
}

@(private = "file")
sparse_find :: proc(set: ^Sparse_Set($C), entity: Entity) -> (int, bool) {
	assert(set != nil)
	if len(set.sparse) <= int(entity.idx) {
		return 0, false
	}
	dense_idx := set.sparse[entity.idx]
	return dense_idx, dense_idx >= 0 && set.dense[dense_idx] == entity
}
