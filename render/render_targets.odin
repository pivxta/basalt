package brender
import "core:container/handle_map"
import "core:slice"
import "core:math"
import "base:runtime"
import vk "vendor:vulkan"

Render_Target_Handle :: distinct handle_map.Handle64

Render_Target_Index :: distinct u32

Render_Target_Sampler :: enum u32 {
	Linear_Clamp,
	Nearest_Clamp,
	Linear_Shadow_Compare,
	Nearest_Shadow_Compare,
}

Render_Target_Error :: Texture_Error

Render_Target_Desc :: struct {
	size_policy:  Size_Policy,
	format:       vk.Format,
	usage:        vk.ImageUsageFlags,
	samples:      Maybe(vk.SampleCountFlags),
	mip_levels:   Maybe(int),
	array_layers: Maybe(int),
}

Render_Target_Usage :: struct {
	base_mip_level:    Maybe(int),
	mip_level_count:   Maybe(int),
	base_array_layer:  Maybe(int),
	array_layer_count: Maybe(int),
	new_state:    Render_Target_Subresource_State,
	discard:      bool,
}

Render_Target_Subresource_State :: struct {
	layout: vk.ImageLayout,
	access: vk.AccessFlags2,
	stage:  vk.PipelineStageFlags2,
}

Size_Policy :: union #no_nil {
	Swapchain_Relative_Size_Policy,
	Fixed_Size_Policy,
}

Swapchain_Relative_Size_Policy :: struct {
	scale: Maybe(f64),
}

Fixed_Size_Policy :: struct {
	size: [2]int,
}

Render_Targets :: struct {
	swapchain_extent: vk.Extent2D,
	textures:         Bindless_Textures,
	samplers:         Bindless_Samplers(Render_Target_Sampler),
	handle_map:       handle_map.Dynamic_Handle_Map(Render_Target_Slot, Render_Target_Handle),
	allocator:        runtime.Allocator,
}

Render_Target_Usage_Batch :: struct {
	usages: [dynamic]Render_Target_Usage_Entry,
	allocator: runtime.Allocator,
}

@(private = "file")
Render_Target_Usage_Entry :: struct {
	target: Render_Target_Handle,
	usages: []Render_Target_Usage,
}

@(private = "file")
Render_Target_Slot :: struct {
	handle: Render_Target_Handle,
	target: Render_Target,
}

@(private = "file")
Render_Target :: union {
	Owned_Render_Target,
	Bound_Render_Target,
}

@(private = "file")
Bound_Render_Target :: struct {
	target: Texture,
	states: []Render_Target_Subresource_State,
}

@(private = "file")
Owned_Render_Target :: struct {
	desc:          Render_Target_Desc,
	states:        []Render_Target_Subresource_State,
	target_handle: Bindless_Handle,
}

@(private = "file")
RENDER_TARGET_SAMPLER_DESCS := [Render_Target_Sampler]Sampler_Desc {
	.Linear_Clamp = {address_mode = .CLAMP_TO_EDGE, filter = .LINEAR},
	.Nearest_Clamp = {address_mode = .CLAMP_TO_EDGE, filter = .NEAREST},
	.Linear_Shadow_Compare = {
		address_mode = .CLAMP_TO_BORDER,
		filter = .LINEAR, 
		compare = .GREATER_OR_EQUAL,
		border_color = .FLOAT_OPAQUE_BLACK,
	},
	.Nearest_Shadow_Compare = {
		address_mode = .CLAMP_TO_BORDER, 
		filter = .NEAREST, 
		compare = .GREATER_OR_EQUAL,
		border_color = .FLOAT_OPAQUE_BLACK,
	},
}

usage_batch_make :: proc(allocator := context.temp_allocator) -> Render_Target_Usage_Batch {
	return {
		usages = make([dynamic]Render_Target_Usage_Entry, allocator),
		allocator = allocator,
	}
}

usage_batch_destroy :: proc(batch: ^Render_Target_Usage_Batch) {
	for usages in batch.usages {
		delete(usages.usages, batch.allocator)
	}
	delete(batch.usages)
	batch^ = {}
}

render_targets_init :: proc(
	targets: ^Render_Targets, 
	device: Device, 
	capacity: int,
	allocator := context.allocator,
) -> (
	result: vk.Result,
) {
	
	sampler_globals := Sampler_Globals { mipmap_mode = .NEAREST }
	bindless_init(&targets.textures, device, capacity) or_return
	bindless_samplers_init(
		&targets.samplers, 
		device, 
		RENDER_TARGET_SAMPLER_DESCS,
		sampler_globals,
	) or_return

	handle_map.dynamic_init(&targets.handle_map, allocator)
	targets.allocator = allocator
	return .SUCCESS
}

render_targets_destroy :: proc(targets: ^Render_Targets, device: Device) {
	iterator := handle_map.iterator_make(&targets.handle_map)
	for slot, _ in handle_map.iterate(&iterator) {
		switch t in slot.target {
		case Owned_Render_Target:
			delete(t.states, targets.allocator)
		case Bound_Render_Target:
			delete(t.states, targets.allocator)
		}
	}
	handle_map.dynamic_destroy(&targets.handle_map)
	bindless_samplers_destroy(&targets.samplers, device)
	bindless_destroy(&targets.textures, device)
}

render_targets_reserve :: proc(targets: ^Render_Targets) -> Render_Target_Handle {
	return handle_map.add(&targets.handle_map, {})
}

render_targets_add :: proc(
	targets: ^Render_Targets, 
	device: Device,
	desc: Render_Target_Desc,
) -> (
	handle: Render_Target_Handle,
	err: Render_Target_Error,
) {
	return handle_map.add(
		&targets.handle_map, 
		{target = create_owned(targets, device, desc) or_return},
	), nil
}

render_targets_replace :: proc(
	targets: ^Render_Targets, 
	device: Device,
	frame_ring: Frame_Ring,
	handle: Render_Target_Handle,
	desc: Render_Target_Desc,
) -> Render_Target_Error {
	if slot, ok := handle_map.get(&targets.handle_map, handle); ok {
		target := create_owned(targets, device, desc) or_return
		defer_free(targets, frame_ring, slot)
		slot.target = target
	}
	return nil
}

render_targets_remove :: proc(
	targets: ^Render_Targets, 
	frame_ring: Frame_Ring,
	handle: Render_Target_Handle,
) {
	if slot, ok := handle_map.get(&targets.handle_map, handle); ok {
		defer_free(targets, frame_ring, slot)
		handle_map.remove(&targets.handle_map, handle)
	}
}

render_targets_resize_swapchain :: proc(
	targets: ^Render_Targets, 
	device: Device,
	frame_ring: Frame_Ring,
	new_extent: vk.Extent2D,
) -> Render_Target_Error {
	targets.swapchain_extent = new_extent

	iterator := handle_map.iterator_make(&targets.handle_map)
	for slot, _ in handle_map.iterate(&iterator) {
		if target, target_ok := slot.target.(Owned_Render_Target); target_ok {
			if _, policy_ok := target.desc.size_policy.(Swapchain_Relative_Size_Policy); policy_ok {
				new_target := create_owned(targets, device, target.desc) or_return
				defer_free(targets, frame_ring, slot)
				slot.target = new_target
			}
		}
	}

	return nil
}

@(private = "file")
defer_free :: proc(targets: ^Render_Targets, frame_ring: Frame_Ring, slot: ^Render_Target_Slot) {
	switch &t in slot.target {
	case Bound_Render_Target:
		delete(t.states, targets.allocator)
	case Owned_Render_Target:
		bindless_remove(&targets.textures, frame_ring, t.target_handle)
		delete(t.states, targets.allocator)
	}
}

@(private = "file")
create_owned :: proc(
	targets: ^Render_Targets, 
	device: Device, 
	desc: Render_Target_Desc,
) -> (
	target: Owned_Render_Target, 
	err: Texture_Error,
) {
	texture: Texture
	texture_init(
		&texture,
		device,
		type = .D2,
		format = desc.format,
		usage = desc.usage | target_required_usage(desc.format),
		extent = target_extent(desc.size_policy, targets.swapchain_extent),
		mip_levels = u32(desc.mip_levels.? or_else 1),
		array_layers = u32(desc.array_layers.? or_else 1),
		samples = desc.samples.? or_else {._1},
	) or_return

	handle, ok := bindless_add(&targets.textures, device, texture)
	if !ok {
		texture_destroy(&texture, device)
		return {}, .No_Bindless_Slots_Left
	}

	states := make(
		[]Render_Target_Subresource_State, 
		texture.mip_levels * texture.array_layers,
		targets.allocator,
	)

	return {
		target_handle = handle,
		states = states,
		desc = desc,
	}, nil
}

@(private = "file")
target_extent :: proc(policy: Size_Policy, swapchain_extent: vk.Extent2D) -> vk.Extent3D {
	switch p in policy {
	case Fixed_Size_Policy:
		return {u32(p.size.x), u32(p.size.y), 1}
	case Swapchain_Relative_Size_Policy:
		scale := p.scale.? or_else 1.0
		return {
			u32(math.round(f64(swapchain_extent.width) * scale)),
			u32(math.round(f64(swapchain_extent.height) * scale)),
			1,
		}
	}
	return {}
}

@(private = "file")
target_required_usage :: proc(format: vk.Format) -> vk.ImageUsageFlags {
	aspect := format_aspect_mask(format)
	usage := vk.ImageUsageFlags{.SAMPLED}
	if .DEPTH in aspect || .STENCIL in aspect {
		usage |= {.DEPTH_STENCIL_ATTACHMENT}
	} else if .COLOR in aspect {
		usage |= {.COLOR_ATTACHMENT}
	}
	return usage
}

render_targets_bind :: proc(
	targets: ^Render_Targets, 
	handle: Render_Target_Handle,
	texture: Texture,
	state: Render_Target_Subresource_State,
) {
	if slot, ok := handle_map.get(&targets.handle_map, handle); ok {
		switch t in slot.target {
		case Owned_Render_Target:
			panic("Cannot bind texture to owned target")
		case Bound_Render_Target:
			delete(t.states, targets.allocator)
		}
		new_target := Bound_Render_Target {
			target = texture,
			states = make(
				[]Render_Target_Subresource_State, 
				texture.mip_levels * texture.array_layers,
				targets.allocator,
			),
		}
		for &new_state in new_target.states {
			new_state = state
		}
		slot.target = new_target
	}
}

render_targets_get_index :: proc(
	targets: ^Render_Targets, 
	handle: Render_Target_Handle,
) -> (Render_Target_Index, bool) {
	if slot, ok := handle_map.get(&targets.handle_map, handle); ok {
		switch t in slot.target {
		case Bound_Render_Target:
			return {}, false
		case Owned_Render_Target:
			return Render_Target_Index(t.target_handle.idx), true
		}
	}
	return {}, false
}

render_targets_get_texture_descriptor_set :: proc(target: ^Render_Targets) -> vk.DescriptorSet {
	return target.textures.descriptor_set
}

render_targets_get_samplers_descriptor_set :: proc(target: ^Render_Targets) -> vk.DescriptorSet {
	return target.samplers.descriptor_set
}

render_targets_get_texture_descriptor_set_layout :: proc(
	target: ^Render_Targets,
) -> vk.DescriptorSetLayout {
	return target.textures.descriptor_set_layout
}

render_targets_get_samplers_descriptor_set_layout :: proc(
	target: ^Render_Targets,
) -> vk.DescriptorSetLayout {
	return target.samplers.descriptor_set_layout
}

usage_batch_add_immediate :: proc(
	batch: ^Render_Target_Usage_Batch,
	targets: ^Render_Targets,
	commands: vk.CommandBuffer,
	handle: Render_Target_Handle,
	usages: []Render_Target_Usage,
) {
	usage_batch_add(batch, handle, usages)
	usage_batch_flush(batch, targets, commands)
}

usage_batch_add :: proc(
	batch: ^Render_Target_Usage_Batch,
	handle: Render_Target_Handle,
	usages: []Render_Target_Usage,
) {
	append(&batch.usages, {
		target = handle,
		usages = slice.clone(usages, batch.allocator),
	})
}

usage_batch_flush :: proc(
	batch: ^Render_Target_Usage_Batch,
	targets: ^Render_Targets, 
	commands: vk.CommandBuffer,
) {
	barriers := make([dynamic]vk.ImageMemoryBarrier2, context.temp_allocator)
	for usage_batch in batch.usages {
		target_slot, slot_ok := handle_map.get(&targets.handle_map, usage_batch.target)
		if !slot_ok {
			continue
		}

		target_array_layers := get_target_array_layer_count(target_slot.target)
		target_states := get_target_states(target_slot.target)
		target_texture, target_texture_ok := get_target_texture(targets, target_slot.target)

		assert(target_texture_ok, "Cannot use target with no texture")
		target_aspect_mask := target_texture.full_view.aspect_mask

		for usage in usage_batch.usages {
			base_mip_level, level_count := resolve_mip_level_range(target_slot.target, usage)
			base_array_layer, layer_count := resolve_array_layer_range(target_slot.target, usage)
			if level_count == 0 || layer_count == 0 {
				continue
			}
			if states_match(
				target_slot.target, 
				base_mip_level, 
				level_count, 
				base_array_layer, 
				layer_count,
			) {
				base_state := target_states[base_array_layer + target_array_layers * base_mip_level]
				append(
					&barriers, 
					{
						sType = .IMAGE_MEMORY_BARRIER_2,
						image = target_texture.handle,
						srcStageMask = base_state.stage,
						srcAccessMask = base_state.access,
						dstStageMask = usage.new_state.stage,
						dstAccessMask = usage.new_state.access,
						oldLayout = .UNDEFINED if usage.discard else base_state.layout,
						newLayout = usage.new_state.layout,
						subresourceRange = vk.ImageSubresourceRange {
							aspectMask = target_aspect_mask,
							baseMipLevel = base_mip_level,
							levelCount = level_count,
							baseArrayLayer = base_array_layer,
							layerCount = layer_count,
						},
					},
				)
				set_states(
					&target_slot.target,
					base_mip_level,
					level_count,
					base_array_layer,
					layer_count,
					usage.new_state,
				)
			} else {
				for mip_level in base_mip_level ..< base_mip_level + level_count {
					if states_match(target_slot.target, mip_level, 1, base_array_layer, layer_count) {
						base_state := target_states[base_array_layer + target_array_layers * mip_level]
						append(
							&barriers, 
							{
								sType = .IMAGE_MEMORY_BARRIER_2,
								image = target_texture.handle,
								srcStageMask = base_state.stage,
								srcAccessMask = base_state.access,
								dstStageMask = usage.new_state.stage,
								dstAccessMask = usage.new_state.access,
								oldLayout = .UNDEFINED if usage.discard else base_state.layout,
								newLayout = usage.new_state.layout,
								subresourceRange = vk.ImageSubresourceRange {
									aspectMask = target_aspect_mask,
									baseMipLevel = mip_level,
									levelCount = 1,
									baseArrayLayer = base_array_layer,
									layerCount = layer_count,
								},
							},
						)
						set_states(
							&target_slot.target,
							mip_level,
							1,
							base_array_layer,
							layer_count,
							usage.new_state,
						)
					} else {
						for array_layer in base_array_layer ..< base_array_layer + layer_count {
							state := &target_states[array_layer + target_array_layers * mip_level]
							append(
								&barriers, 
								{
									sType = .IMAGE_MEMORY_BARRIER_2,
									image = target_texture.handle,
									srcStageMask = state.stage,
									srcAccessMask = state.access,
									dstStageMask = usage.new_state.stage,
									dstAccessMask = usage.new_state.access,
									oldLayout = .UNDEFINED if usage.discard else state.layout,
									newLayout = usage.new_state.layout,
									subresourceRange = vk.ImageSubresourceRange {
										aspectMask = target_aspect_mask,
										baseMipLevel = mip_level,
										levelCount = 1,
										baseArrayLayer = array_layer,
										layerCount = 1,
									},
								},
							)
							state^ = usage.new_state
						}
					}
				}
			}
		}
	}
	for usage_batch in batch.usages {
		delete(usage_batch.usages, batch.allocator)	
	}
	clear(&batch.usages)

	if len(barriers) > 0 {
		dependency_info := vk.DependencyInfo {
			sType = .DEPENDENCY_INFO,
			imageMemoryBarrierCount = u32(len(barriers)),
			pImageMemoryBarriers = raw_data(barriers),
		}
		vk.CmdPipelineBarrier2(commands, &dependency_info)
	}
}

@(private = "file")
states_match :: proc(
	target: Render_Target,
	base_mip_level: u32,
	mip_level_count: u32,
	base_array_layer: u32,
	array_layer_count: u32,
) -> bool {
	assert(mip_level_count != 0)
	assert(array_layer_count != 0)

	states := get_target_states(target)
	mip_levels := get_target_mip_level_count(target)
	array_layers := get_target_array_layer_count(target)
	assert(mip_levels != 0)
	assert(array_layers != 0)
	assert(len(states) == int(mip_levels * array_layers))

	first_state := states[base_array_layer + array_layers * base_mip_level]
	for current_mip_level in base_mip_level ..< base_mip_level + mip_level_count {
		for current_array_layer in base_array_layer ..< base_array_layer + array_layer_count {
			if states[current_array_layer + array_layers * current_mip_level] != first_state {
				return false
			}
		}
	}

	return true
}

@(private = "file")
set_states :: proc(
	target: ^Render_Target,
	base_mip_level: u32,
	mip_level_count: u32,
	base_array_layer: u32,
	array_layer_count: u32,
	state: Render_Target_Subresource_State,
) {
	states := get_target_states(target^)
	mip_levels := get_target_mip_level_count(target^)
	array_layers := get_target_array_layer_count(target^)
	assert(mip_levels != 0)
	assert(array_layers != 0)
	assert(len(states) == int(mip_levels * array_layers))

	for current_mip_level in base_mip_level ..< base_mip_level + mip_level_count {
		for current_array_layer in base_array_layer ..< base_array_layer + array_layer_count {
			states[current_array_layer + array_layers * current_mip_level] = state
		}
	}
}

@(private = "file")
get_target_states :: proc(target: Render_Target) -> []Render_Target_Subresource_State {
	switch t in target {
	case Owned_Render_Target:
		return t.states
	case Bound_Render_Target:
		return t.states
	}
	return nil
}

@(private = "file")
get_target_texture :: proc(targets: ^Render_Targets, target: Render_Target) -> (Texture, bool) {
	switch t in target {
	case Owned_Render_Target:
		return bindless_get(&targets.textures, t.target_handle)
	case Bound_Render_Target:
		return t.target, true
	}
	return {}, false
}

@(private = "file")
resolve_mip_level_range :: proc(target: Render_Target, usage: Render_Target_Usage) -> (
	base: u32, 
	count: u32,
) {
	base = u32(usage.base_mip_level.? or_else 0)
	if c, ok := usage.mip_level_count.?; ok {
		count = u32(c)
	} else {
		target_mip_level_count := get_target_mip_level_count(target)
		assert(target_mip_level_count >= base)
		count = target_mip_level_count - base
	}

	total := get_target_mip_level_count(target)
	assert(base + count <= total)
	return base, count
}

@(private = "file")
resolve_array_layer_range :: proc(target: Render_Target, usage: Render_Target_Usage) -> (
	base: u32, 
	count: u32,
) {
	base = u32(usage.base_array_layer.? or_else 0)
	if c, ok := usage.array_layer_count.?; ok {
		count = u32(c)
	} else {
		target_array_layer_count := get_target_array_layer_count(target)
		assert(target_array_layer_count >= base)
		count = target_array_layer_count - base
	}

	total := get_target_array_layer_count(target)
	assert(base + count <= total)
	return base, count
}

@(private = "file")
get_target_mip_level_count :: proc(target: Render_Target) -> u32 {
	switch t in target {
	case Owned_Render_Target:
		return u32(t.desc.mip_levels.? or_else 1)
	case Bound_Render_Target:
		return t.target.mip_levels
	}
	return 0
}

@(private = "file")
get_target_array_layer_count :: proc(target: Render_Target) -> u32 {
	switch t in target {
	case Owned_Render_Target:
		return u32(t.desc.array_layers.? or_else 1)
	case Bound_Render_Target:
		return t.target.array_layers
	}
	return 0
}
