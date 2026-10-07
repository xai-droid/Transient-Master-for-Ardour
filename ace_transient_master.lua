ardour {
	["type"]    = "dsp",
	name        = "ACE Transient Master",
	category    = "Dynamics",
	license     = "MIT",
	author      = "Ardour Community",
	description = [[Shape attack and sustain independently with a dual-envelope detector.]]
}

function dsp_ioconfig ()
	return { { audio_in = -1, audio_out = -1 } }
end

function dsp_params ()
	return
	{
		{ ["type"] = "input", name = "Attack", min = -12, max = 12, default = 0, unit = "dB" },
		{ ["type"] = "input", name = "Sustain", min = -12, max = 12, default = 0, unit = "dB" },
		{ ["type"] = "input", name = "Sensitivity", min = 0.1, max = 4, default = 1, logarithmic = true },
		{ ["type"] = "input", name = "Release", min = 20, max = 500, default = 120, unit = "ms", logarithmic = true },
		{ ["type"] = "input", name = "Mix", min = 0, max = 100, default = 100, unit = "%" },
		{ ["type"] = "input", name = "Output", min = -12, max = 12, default = 0, unit = "dB" },
	}
end

local sample_rate = 48000
local channel_count = 0
local output_channels
local shapers = {}
local audio_type
local displayed_attack
local displayed_sustain
local displayed_sensitivity
local displayed_release
local displayed_mix
local displayed_output
local display_dirty = false
local display_frames = 0

function dsp_init (rate)
	sample_rate = rate
	audio_type = ARDOUR.DataType ("audio")
end

function dsp_configure (ins, outs)
	channel_count = ins:n_audio ()
	assert (channel_count == outs:n_audio ())
	assert (channel_count > 0)
	output_channels = outs
	shapers = {}
	for channel = 1, channel_count do
		shapers[channel] = ARDOUR.DSP.TransientShaper (sample_rate)
	end
end

function dsp_runmap (bufs, in_map, out_map, n_samples, offset)
	ARDOUR.DSP.process_map (bufs, output_channels, in_map, out_map, n_samples, offset)
	local controls = CtrlPorts:array ()
	if controls[1] ~= displayed_attack or controls[2] ~= displayed_sustain
		or controls[3] ~= displayed_sensitivity or controls[4] ~= displayed_release
		or controls[5] ~= displayed_mix or controls[6] ~= displayed_output then
		displayed_attack = controls[1]
		displayed_sustain = controls[2]
		displayed_sensitivity = controls[3]
		displayed_release = controls[4]
		displayed_mix = controls[5]
		displayed_output = controls[6]
		display_dirty = true
	end
	display_frames = display_frames - n_samples
	if display_dirty and display_frames <= 0 then
		self:queue_draw ()
		display_frames = sample_rate / 20
		display_dirty = false
	end

	for channel = 1, channel_count do
		local output_buffer = out_map:get (audio_type, channel - 1)
		if output_buffer ~= ARDOUR.ChanMapping.Invalid then
			local audio = bufs:get_audio (output_buffer)
			shapers[channel]:run (audio:data (offset), n_samples, controls[1], controls[2], controls[3], controls[4], controls[5], controls[6])
		end
	end
end

function render_inline (ctx, w, max_h)
	local controls = CtrlPorts:array ()
	local h = math.min (82, max_h)
	if w < 24 or h < 24 then
		return { w, h }
	end

	ctx:rectangle (0, 0, w, h)
	ctx:set_source_rgba (0.11, 0.12, 0.14, 1.0)
	ctx:fill ()

	local left = 5
	local right = w - 5
	local top = 5
	local bottom = h - 5
	local graph_width = right - left
	local graph_height = bottom - top

	ctx:set_line_width (1.0)
	for db = -18, 18, 6 do
		local y = top + (24 - db) / 48 * graph_height
		if db == 0 then
			ctx:set_source_rgba (0.50, 0.54, 0.58, 0.75)
		else
			ctx:set_source_rgba (0.34, 0.37, 0.40, 0.55)
		end
		ctx:move_to (left, y)
		ctx:line_to (right, y)
		ctx:stroke ()
	end

	local attack_gain = 10 ^ (0.05 * controls[1])
	local sustain_gain = 10 ^ (0.05 * controls[2])
	local output_gain = 10 ^ (0.05 * controls[6])
	local mix = controls[5] / 100
	local sensitivity = controls[3]
	local release_ms = math.max (controls[4], 1)

	ctx:set_source_rgba (0.24, 0.86, 0.72, 1.0)
	ctx:set_line_width (2.0)
	for point = 0, math.floor (graph_width) do
		local x = point / graph_width
		local elapsed_ms = x * 500
		local weight = math.min (1, math.exp (-elapsed_ms / release_ms) * sensitivity)
		local shaped_gain = sustain_gain + weight * (attack_gain - sustain_gain)
		local mixed_gain = 1 + mix * (shaped_gain - 1)
		local gain_db = 20 * math.log (math.max (mixed_gain * output_gain, 0.000001)) / math.log (10)
		gain_db = math.max (-24, math.min (24, gain_db))
		local y = top + (24 - gain_db) / 48 * graph_height
		if point == 0 then
			ctx:move_to (left + point, y)
		else
			ctx:line_to (left + point, y)
		end
	end
	ctx:stroke ()

	return { w, h }
end