pico-8 cartridge // http://www.pico-8.com
version 38
__lua__
-- 'jumper' demo build #2
-- by nuno

function clamp(val, min, max)
    if val < min then
        return min
    end
    if val > max then
        return max
    end
    return val
end

function rounddown(val, multiple)
    return val - val % multiple
end

function roundup(val, multiple)
    return rounddown(val + multiple - 0.01, multiple)
end

function aabb(x0,y0,w0,h0,x1,y1,w1,h1)
    local r0 = x0 + w0
    local r1 = x1 + w1
    local b0 = y0 + h0
    local b1 = y1 + h1
    if r0 < x1 or r1 < x0 then
        return false
    end
    if b0 < y1 or b1 < y0 then
        return false
    end
    return true
end

function vlen(v)
    return sqrt(v.x*v.x + v.y*v.y)
end

-- 
dbg = false
dbgstr = ''

-- disable btnp repeating
poke(0x5f5c, 255)


function init_room()
	-- updated by move_room
	room_i = 0
	room_x = 0
	room_y = 0
	-- updated by spawn_room
	room_old = nil -- for restore
	room_num_bads = 0 -- for unlock (bads door)
	room_num_unlit = 0 -- for unlock (lanterns door)
	room_checkpoint = nil -- checkpoint thang
	move_room(4)
end

function move_room(i)
	local r = get_room_xy(i)
	room_i = i
	room_x = r.x
	room_y = r.y
end

function restore_room()
	if room_old == nil then
		return
	end
	for t in all(room_old) do
		mset(t.x,t.y,t.val)
	end
end

function get_room_i(x,y)
	x \= 128
	y \= 128
	return x % 8 + y * 8
end

function get_room_xy(i)
	return {
		x = (i % 8) * 128,
		y = (i \ 8) * 128
	}
end

--function in_room(x,y)
--	if 		x < room_x or x >= room_x+128 or
--			y < room_y or y >= room_y+128 then
--		return false
--	end
--	return true
--end

function update_room()
	-- update room and camera to where player currently is
	local oldi = room_i
	local newi = get_room_i(p.x + p.w/2, p.y + p.h/2)
	move_room(newi)
	camera(room_x, room_y)
	-- spawn the room if it's a new room
	if oldi != newi then
		-- give player a little kick through the door
		if p.alive and not p.spawn then
			local oldxy = get_room_xy(oldi)
			if oldxy.x > room_x then
				p.x -= 12
			elseif oldxy.x < room_x then
				p.x += 12
			end
		end
		-- fade out music and stuff
		if silent_rooms[room_i] then
			music(-1,3000,3)
		elseif start_music_rooms[room_i] then
			start_music()
		end
		fireball = {}
		restore_room()
		spawn_room()
	end
end

-- spawn thangs in current room
-- save room
function spawn_room()
	local rmapx = room_x \ 8
	local rmapy = room_y \ 8
	thang = {}
	max_z = 0
	room_old = {}
	room_num_bads = 0
	room_num_unlit = 0
	for y=rmapy,rmapy+15 do
		for x=rmapx,rmapx+15 do
			local val = mget(x,y)
			add(room_old, {x=x,y=y,val=val})
			if fget(val,4) then
				local t = spawn_thang(val,x*8,y*8)
				max_z = max(t.z, max_z)
				mset(x,y,t.replace)
				if t.bad then
					room_num_bads += 1
				elseif t.i == 82 then
					room_num_unlit += 1
				elseif t.i == 91 then
					room_checkpoint = t
				end
			end
		end
	end
end

do_fade = true -- fade in
fade_timer = 8

function spawn_p_in_curr_room()
	restore_room()
	spawn_room()
	spawn_p(room_checkpoint.x, room_checkpoint.y - 1)
end

snd_p_respawn = 8
snd_p_die = 9
snd_p_jump = 10
snd_p_shoot = 11
snd_p_land = 12
snd_hit = 13
snd_bat_flap = 14
snd_ice_break = 15
snd_frog_croak = 16
snd_frog_jump = 17
snd_knight_jump = 18
snd_knight_swing = 19
snd_knight_die = 20
snd_shooter_shot = 21
snd_archer_invis = 22
snd_wizard_tp = 23

-- TODO token reduction?
-- play the start of the music, overlaps with start_music_rooms
intro_rooms = {[23]=1, [8]=1}
-- silent rooms includes all rooms we want regular music to fade out, and NOT play on respawn (including boss rooms)
silent_rooms = {[4]=1, [15]=1, [16]=1, [17]=1}
-- call start_music() when entering these rooms (i.e. we need one after a silent room to restart music)
start_music_rooms = {[8]=1}

function start_music()
	if silent_rooms[room_i] then
		-- boss music will start from boss monster's code
		return
	elseif intro_rooms[room_i] then
		music(0, 0, 3)
	else
		music(2, 200, 3)
	end
end

function fade_update()
	if fade_timer == 12 then
		spawn_p_in_curr_room()	
	elseif fade_timer > 23 then
		fade_timer = 0
		return false
	end
	fade_timer += 1
	return true
end

function _update()
	update_room()
	update_p()
	for t in all(thang) do
		t:update()
	end
	for p in all(fireball) do
		p:update()
	end
	if do_fade then
		do_fade = fade_update()
	end
end

function _init()
	init_thang_dat()
	init_room()
	spawn_p_in_curr_room()	
end

-->8
-- draw

function draw_thang(t)
	local flp = false
	if t.rght != nil then
		flp = not t.rght
	end
	for k,v in pairs(t.pal) do
		pal(k,v,0)
	end
	spr(t.s+t.fr,t.x,t.y,1,1,flp)
	pal()
end

function draw_shot(t)
	-- tracer
	line(t.x, t.y, t.endx, t.endy, t.trace_color)
	--arrow
	line(t.arrowx, t.arrowy, t.endx, t.endy, t.arrow_color)
end

function draw_wizard(t)
	if t.tping then
		for i=1,15 do
			pal(i,7,0)
		end
		if t.fcnt < 6 then
			draw_thang(t)
			spr(230, t.tp_to.x, t.tp_to.y)
		elseif t.fcnt < 12 then
			spr(229, t.tp_from.x, t.tp_from.y)
			spr(229, t.tp_to.x, t.tp_to.y)
		else
			draw_thang(t)
			spr(230, t.tp_from.x, t.tp_from.y)
		end
		pal()
	else
		draw_thang(t)
	end
end

function draw_archer(t)
	if t.invis then
		local fr = t.invistimer < 12 and 11 - t.invistimer or t.invistimer - 58
		if fr >= 0 then
			for i,k in pairs(t.invis_pal_k) do
				pal(k,t.invis_pal_v[fr\4+1][i],0)
			end
		else
			for i=1,15 do
				pal(i,0,0)
			end
		end
	end
	draw_thang(t)
	pal()
end

function draw_knight(t)
	draw_thang(t)
	-- draw sword
	if t.swrd_draw then
		local xoff = t.rght and 8 or -8
		spr(t.i + t.s_swrd.s + t.swrd_fr,
			t.x + xoff,
			t.y,
			1,1,not t.rght)
	end
end

function draw_smol_thang(f)
	local sx = (f.sfr % 2) * 4
	local sy = (f.sfr \ 2) * 4
	sspr(
		(f.s % 16) * 8 + sx,
		(f.s \ 16) * 8 + sy,
		4,4,
  		f.x,
   		f.y,
   		4,4,
    	f.xflip,
    	f.yflip)
end

function draw_fade(s)
	fillp(s)
	rectfill(room_x,room_y,room_x+128 - 1,room_y+128 - 1,1)
end

function print_in_room(s,x,y,c)
	print(s,room_x+x,room_y+y,c)
end

function _draw()
	cls(0)

	map(0,0,0,0,128,64)

	if room_i == 23 then
		print_in_room('path of', 53, 35, 1)
		print_in_room('path of', 52, 34, 7)
		print_in_room('demo 5', 52, 58, 11)
		print_in_room('⬅️➡️ move\n🅾️ z jump\n❎ x fire', 45, 68, 6)
	elseif room_i == 22 then
		--print_in_room('\npsst!\n      ⬆️\n ❎+⬅️⬇️➡️', 75, 54, 1)
		print_in_room('\npsst!\n❎+⬆️\n❎+⬅️+⬇️', 80, 58, 1)
	end

	-- draw one layer at a time!
	for z=max_z,0,-1 do
		for t in all(thang) do
			if t.z == z then
				t:draw()
			end
		end
	end

	-- player
	draw_thang(p)

	for f in all(fireball) do
		draw_smol_thang(f)
	end

	if do_fade then
		if fade_timer < 4 then
			draw_fade(0b0101101001011010.1)
		elseif fade_timer < 8 then
			draw_fade(0b0000101000001010.1)
		elseif fade_timer < 16 then
			draw_fade(0)
		elseif fade_timer < 20 then
			draw_fade(0b0000101000001010.1)
		elseif fade_timer < 24 then
			draw_fade(0b0101101001011010.1)
		end
		fillp(0)
	end

	if dbg then
		local x = room_x + 8
		print(dbgstr,x,room_y,7)
	end
end
-->8
--thang - entity/actor

thang = {}

-- number of layers to draw
max_z = 0

function init_thang_dat()
	local iceblock = {
		init = init_replace_i,
		update = update_iceblock,
		burn = burn_iceblock
	}
	local door = {
		init = init_replace_i,
		update = update_door,
		draw = no_thang,
		open = true,
		h = 16,
		stops_projs = false
	}
	local enemy = {
		burn = burn_bad,
		burning = false,
		-- coll dimensions
		-- same as player..
		cw = 5.99,
		ch = 6.99,
		cx = 1,
		cy = 1,
		-- hurt box - bigger than player, same as collision box
		hw = 5.99,
		hh = 6.99,
		hx = 1,
		hy = 1,
		bad = true,
		air = true,
		g = 0.3,
		max_vy = 4
	}
	local thrower = {
		update = update_shooter_thrower,
		do_shoot = throw_icepick,
		check_shoot = check_throw_icepick,
		hp = 3,
		shspeed = 8, -- only used by shooter
		shooting = false,
		goingrght = true, -- going to go after throwing
		template = enemy,
		shcount = 0, -- throw/shoot stuff at player
		range = 48, -- only used by thrower
		s_wlk = {s=0, f=2},
		s_sh = {s=2, f=1},
		s_burn = {s=3, f=1},
		s_die = {s=4, f=3},
	}
	local shooter = {}
	for k,v in pairs(thrower) do
		shooter[k] = v
	end
	shooter.do_shoot = shoot_shot
	shooter.check_shoot = check_shoot_shot
	shooter.s_sh = {s=2,f=3}
	shooter.s_burn = {s=5, f=1}
	shooter.s_die = {s=104 - 117, f=3}
thang_dat = {
	[91] = { -- checkpoint
		update = update_checkpoint,
		z = 1,
		stops_projs = false,
	},
	[82] = { -- lantern
		lit = false,
		update = update_lantern,
		burn = burn_lantern,
		replace = 82 + 3,
		z = 1,
		stops_projs = false
	},
	[8] = { -- door - only close, never open
		template = door,
		type = 0,
		s_top = 9,
		s_bot = 25
	},
	[14] = { -- door - close then open when enemies are dead
		template = door,
		type = 1,
		s_top = 109,
		s_bot = 125
	},
	[15] = { -- door - only open when lanterns are lit
		template = door,
		type = 2,
		s_top = 110,
		s_bot = 126
	},
	[86] = iceblock,
	[87] = iceblock,
	[96] = { -- bat
		init = init_bat,
		update = update_bat,
		burn = burn_bat,
		bad = true,
		w = 7,
		h = 6,
		range = 8*8,
		dircount = 0,
		xspeed = 0.5,
		yspeed = 0.4,
		cw = 7,
		ch = 6,
		hw = 7,
		hh = 6,
	},
	[112] = { -- frog
		update = update_frog,
		burn = burn_frog,
		template = enemy,
		jbig_vy = -3.5,
		jbig_vx = 1.2,
		jsmol_vy = -2.5,
		jsmol_vx = 1.5,
		jtiny_vy = -1.0,
		hp = 2,
		angry = false,
		croak = false,
		bounced = false,
		do_smol = true,
		-- coll dimensions
		ch = 4.99,
		cw = 5.99,
		cx = 1,
		cy = 2,
		hx = 1,
		hy = 2,
		hw = 4.99,
		hh = 5.99,
		jcount = 0, -- jump
		s_idle = {s=0, f=2},
		s_jmp = {s=2, f=2},
		s_burn = {s=4, f=1},
		s_die = {s=104 - 112, f=3},
		pal_angry = {
			[11] = 8,	-- main
			[3] = 2,	-- shadow
			[8] = 10	-- eyes
		}
	},
	[192] = { -- knight
		update = update_knight,
		burn = burn_knight,
		draw = draw_knight,
		hp = 5,
		atking = false,
		-- draw sword/sword hitbox present
		swrd_fr = 0,
		swrd_hit = false,
		swrd_draw = false,
		swrd_x_off = 5, -- when attacking left, move sword back this much (same as width...)
		swrd_y = 1,
		swrd_w = 5,
		swrd_h = 4,
		phase = 0, -- stand, walk, jump
		atktimer = 0, -- how long since last attack
		jmptime = 0, -- how long to wait before jumping
		g = 0.2,
		template = enemy,
		atkrange = 11, -- only attack player in this range
		s_idle = {s=0, f=0},
		s_wlk  = {s=1, f=2},
		s_atk  = {s=3, f=3},
		s_jmp  = {s=6, f=3},
		s_fall = {s=9, f=1},
		s_burn = {s=10, f=1},
		s_die  = {s=11, f=3},
		s_swrd = {s=14, f=2},
	},
	[100] = thrower,
	[107] = { -- icepick
		update = update_icepick,
		burn = kill_ice_proj,
		draw = draw_smol_thang,
		w = 4,
		h = 4,
		vx = 1.5,
		vy = -4,
		g = 0.3,
		max_vy = 4,
		sfr = 0,
		xflip = false,
		yflip = false,
		hw = 4,
		hh = 4,
		die_yinc = 0.5,
		s_die_s = 108
	},
	[117] = shooter,
	[123] = { -- shot
		update = update_shot,
		draw = draw_shot,
		stops_projs = false,
	},
	[208] = { -- archer
		update = update_archer,
		burn = burn_archer_wizard,
		draw = draw_archer,
		hp = 5,
		shooting = false,
		shspeed = 6,
		goingrght = true, -- going to go after shooting 
		phase = 0,
		invis = false,
		invistimer = 0,
		template = enemy,
		shcount = 0, -- shoot stuff at player
		s_idle = {s=0, f=1},
		s_wlk = {s=1, f=2},
		s_sh = {s=3, f=3},
		s_jmp = {s=7, f=2},
		s_shair = {s=9, f=3},
		s_burn = {s=12, f=1},
		s_die = {s=13, f=3},
		-- body, legs, skin, hair, bow, (cloak)
		invis_pal_k = {5,2,15,4,9,1},
		-- invisible -> visible
		invis_pal_v = {
			{0, 1, 0, 1, 1, 0},
			{1, 1, 1, 1, 1, 1},
			{1, 2, 5, 2, 13, 1},
		}
	},
	[224] = { -- wizard
		init = init_wizard,
		update = update_wizard,
		burn = burn_archer_wizard,
		draw = draw_wizard,
		z = 2,
		hp = 5,
		air = false, -- never be in air
		template = enemy,
		hover_up = false,
		phase = 0,
		tping = false,
		tp_to = nil,
		tp_from = nil,
		shcount = 0,
		casting = false,
		castu = nil,
		s_idle = {s=0, f=1},
		s_cast = {s=1, f=3},
		s_burn = {s=4, f=1},
		s_die = {s=7, f=4},
	},
	[240] = { -- casting
		update = update_casting,
		timer = 15,
		state = 0, -- 0 = casting, 1 = succeeded, 2 = fizzled
		stops_projs = false,
	},
	[124] = { -- ice ball
		update = update_iceball,
		burn = kill_ice_proj,
		draw = draw_smol_thang,
		speed = 3,
		die_yinc = 0.5,
		s_die_s = 108
	}
}
end

function no_thang(t)
end

function init_replace_i(t)
	t.replace = t.i
end

function update_door(t)
	local num = 1
	num = t.type == 1 and room_num_bads or num
	num = t.type == 2 and room_num_unlit or num
	local mx = t.x\8
	local my = t.y\8
	if t.open then
		if num > 0 then
			if not coll_p(t.x,t.y,t.w,t.h) then
					t.open = false
					mset(mx,my,t.s_top)
					mset(mx,my+1,t.s_bot)
			end
		end
	elseif num <= 0 then
		t.open = true
		mset(mx,my,t.i)
		mset(mx,my+1,0)
	end
end

function update_iceblock(t)
	if not t.alive then
		if loop_anim(t,2,3) then
			del(thang, t)
		end
	end
end

function burn_iceblock(t)
	if t.alive then
		sfx(snd_ice_break)
		t.s = 88
		t.alive = false
		mset(t.x\8,t.y\8,0)
	end
end

function kill_ice_proj(t)
	sfx(snd_ice_break)
	kill_ball(t)
end

function update_icepick(t)
	if do_ball_die(t) then
		return
	end
	-- spin in correct direction
	local xfac = t.xflip and -1 or 1
	-- spin around 'ax'is
	if t.fcnt > 0 and t.fcnt % 2 == 0 then
		local fcnt_to_xy = {
			[2] = {2,1},
			[4] = {-1,2},
			[6] = {-2,-1},
			[8] = {1,-2}
		}
		t.x += fcnt_to_xy[t.fcnt][1] * xfac
		t.y += fcnt_to_xy[t.fcnt][2]
		if t.fcnt == 8 then
			t.fcnt = 0
		end
		t.sfr = (t.sfr + 1) % 4
	end
	t.fcnt += 1
	t.vy += t.g
	t.vy = clamp(t.vy,-t.max_vy,t.max_vy)
	t.x += t.vx
	t.y += t.vy

	if 
			collmap(t.x+3, t.y+2, 1) or
			collmap(t.x+1, t.y+2, 1) then
		kill_ice_proj(t)
	end

	if kill_p_on_coll(t) then
		kill_ice_proj(t)
	end
end

function dist_until_wall(x,y,dir,vert)
	-- x, y are some position in world space
	-- dir can be -1 or 1 only
	-- set vert to true for y direction, otherwise it's x
	-- returns number of tiles until hit a wall or room border
	-- 0 if x,y are on a wall already
	if vert == nil then
		vert = false
	end

	local mx = x\8
	local xinc = vert and 0 or dir
	local my = y\8
	local yinc = vert and dir or 0
	local xroomorig = mx\16
	local yroomorig = my\16
	local tiles = 0
	while true do
		local tile = mget(mx, my)
		if fget(tile, 1) then
			break
		end
		mx += xinc
		my += yinc
		tiles += 1
		if mx\16 != xroomorig then
			break
		end
		if my\16 != yroomorig then
			break
		end
	end
	-- in the wall already
	if tiles == 0 then
		return 0
	end

	local off = vert and y or x
	local fn = dir > 0 and roundup or rounddown
	return (tiles - 1)*8 + dir*(fn(off,8) - off)
end

function do_boss_die(t)
	if not t.alive then
		t.stops_projs = false
		t.s = t.i + t.s_die.s
		if not t.air then
			if play_anim(t, 10, t.s_die.f) then
				room_num_bads = 0
			end
			-- don't want to keep doing physics when dead
			-- this would break if he was on an ice block and you broke it
			return true
		end
	end
	return false
end

function do_bad_die(t)
	-- if dead, play death animation, delete t when done
	-- return true if dead
	if not t.alive then
		t.stops_projs = false
		t.s = t.i + t.s_die.s
		if play_anim(t, 5, t.s_die.f) then
			del(thang, t)
			room_num_bads -= 1
		end
		return true
	end
	return false
end

function check_bad_coll_spikes(t)
	if coll_spikes(t) then
		sfx(snd_hit)
		t.alive = false
		reset_anim_state(t)
		t.s = t.i + t.s_die.s
		return true
	end
	return false
end

function do_bad_burning(t)
	-- if burning, play burn animation
	-- return true if still burning (or now dead), else false

	if not t.burning then
		return false
	end
	t.s = t.i + t.s_burn.s
	if play_anim(t, 6, t.s_burn.f) then
		reset_anim_state(t)
		t.burning = false
		if t.hp <= 0 then
			t.alive = false
			return true
		else
			t.s = t.i
			return false
		end
	end
	return true
end

function update_shot(t)
	if t.fcnt > 10 then
		del(thang, t)
		return
	end
	if t.fcnt < 3 then
		t.trace_color = 7
		t.arrow_color = 7
		if		p.alive and
				hit_p(
					min(t.x, t.endx),	-- left
					min(t.y, t.endy),	-- top
					abs(t.endx - t.x),	-- width
					abs(t.endy - t.y)	-- height
				) then
			kill_p()
		end
	elseif t.fcnt < 5 then
		t.trace_color = 12
	else
		t.trace_color = 1
		t.arrow_color = 12
	end
	if t.fcnt > 6 then
		t.arrow_color = 1
	end
	t.fcnt += 1
end

function throw_icepick(t)
	local xfac = t.rght and 1 or -1
	if play_anim(t, 20, t.s_sh.f) then
		t.shooting = false
		local i = spawn_thang(
					107,
					t.x - 3 * xfac,
					t.y + 4)
		if not t.rght then
			i.xflip = true
			i.vx = -i.vx
		end
		reset_anim_state(t)
	end
end

function face_p(t)
	if p.x < t.x then
		t.rght = false
	else
		t.rght = true
	end
end

function reset_anim_state(t)
	t.fcnt = 0
	t.fr = 0
end

function check_shoot_shot(t)
	local shleft = dist_until_wall(t.x + 4, t.y + 4, -1)
	local shright = dist_until_wall(t.x + 4, t.y + 4, 1)
	if hit_p(t.x + 4 - shleft, t.y, shleft + shright, 8) then
		face_p(t)
		t.shcount = 5
		t.shooting = true
		reset_anim_state(t)
	end
end

function check_throw_icepick(t)
	if vlen{ x = t.x - p.x, y = t.y - p.y } <= t.range then
		face_p(t)
		t.shooting = true
		reset_anim_state(t)
	end
	t.shcount = 30
end

function update_shooter_thrower(t)
	if do_bad_die(t) then
		return
	end

	if do_bad_burning(t) then
		-- t.shooting = false -- shooter keeps shooting
		return
	end

	t.vx = 0

	if t.shooting then
		t.s = t.i + t.s_sh.s
		t:do_shoot()
	-- else we walking
	else
		t.s = t.i + t.s_wlk.s
		-- remember which way we were going
		t.rght = t.goingrght
		if not t.air then
			if t.rght then
				t.vx = 0.75
			else
				t.vx = -0.75
			end
			loop_anim(t,4,t.s_wlk.f)
		end

		if t.shcount <= 0 then
			t:check_shoot()
		else
			t.shcount -= 1
		end
	end

	local phys_result = phys_thang(t, t.air)

	if not t.air and not t.shooting then
		if phys_result.hit_wall or coll_edge_turn_around(t,t.x,t.y + t.h) != 0 then
			t.rght = not t.rght
			t.goingrght = t.rght
		end
	end

	if check_bad_coll_spikes(t) then
		return
	end

	kill_p_on_coll(t)
end

function shoot_shot(t)
	-- 8 shooter
	-- 6 archer
	if play_anim(t, t.shspeed, t.s_sh.f) then
		t.shooting = false
		reset_anim_state(t)
	elseif t.fr == 2 and t.fcnt == 1 then
		sfx(snd_shooter_shot)
		local orig = {
			x = t.rght and t.x + 8 or t.x - 1,
			y = t.y + 3
		}
		local shleft = dist_until_wall(t.x + 4, t.y + 4, -1)
		local shright = dist_until_wall(t.x + 4, t.y + 4, 1)
		local shot = spawn_thang(123, orig.x, orig.y)
		shot.endx = t.x + 4 + (t.rght and shright or -shleft)
		shot.endy = orig.y
		shot.arrowx = t.rght and shot.endx - 5 or shot.endx + 5
		shot.arrowy = orig.y
	end
end

function update_archer(t)

	if do_boss_die(t) then
		return
	end

	local oldburning = t.burning
	if do_bad_burning(t) then
		if not t.alive then
			sfx(snd_knight_die)
			music(-1,0,3)
		end
		return
	-- not burning or dead
	elseif oldburning then
		sfx(snd_archer_invis)
		t.invis = true
		t.stops_projs = false
		t.invistimer = 70
		t.shooting = false
		reset_anim_state(t)
	end

	local oldair = t.air
	if not oldair then
		t.vx = 0
	end

	if t.shooting then
		t.s = t.i + (t.air and t.s_shair.s or t.s_sh.s)
		shoot_shot(t)
	-- else we walking or jumping
	else
		-- idle
		if t.phase == 0 then
			t.s = t.i + t.s_idle.s
			local r = get_room_xy(room_i)
			if p.y > r.y + 16 then
				t.phase = 1
			end
			return
		end
		-- remember which way we were going
		t.rght = t.goingrght
		if not t.air then
			t.s = t.i + t.s_wlk.s
			if coll_edge_turn_around(t,t.x,t.y + t.h) != 0 then
				-- jump! or turn around -- always jump when invis
				if t.invis or rnd(1) < 0.5 then
					sfx(snd_knight_jump)
					t.air = true
					t.vy = -4
				else
					t.rght = not t.rght
				end
			end
			t.vx = t.rght and 1.2 or -1.2
			loop_anim(t,4,t.s_wlk.f)
		end

		-- save which way we're going (we might face a different way when shooting)
		t.goingrght = t.rght
		-- check air again
		if t.air then
			t.s = t.i + t.s_jmp.s
			if t.vy < 0 then
				t.s -= 1
				reset_anim_state(t)
			else
				loop_anim(t,4,t.s_jmp.f)
			end
		end

		if t.invis then
			t.invistimer -= 1
			if t.invistimer == 15 then
				sfx(snd_archer_invis)
			elseif t.invistimer <= 0 then
				t.stops_projs = true
				t.invis = false
			end
		-- don't attack unless visible
		elseif t.shcount <= 0 then
			check_shoot_shot(t)
		else
			t.shcount -= 1
		end
	end

	local oldvx = t.vx
	local phys_result = phys_thang(t, oldair)

	if phys_result.hit_wall then
		if t.air then
			t.vx = -oldvx
		end
		-- oops going other way now
		t.goingrght = not t.goingrght
	end

	if kill_p_on_coll(t) then
		t.invis = false
	end
end

function burn_bad(t)
	if t.alive and not t.burning then
		sfx(snd_hit)
		t.hp -= 1
		reset_anim_state(t)
		t.burning = true
	end
end

function init_wizard(t)
	t.y -= 1
end

function start_tp(t)
	t.tping = true
	t.stops_projs = false
	reset_anim_state(t)
	sfx(snd_wizard_tp)
	-- find tp plat
	local plats = {}
	-- start inside borders
	local rmapx = room_x \ 8 + 2
	local rmapy = room_y \ 8 + 4
	for y=rmapy,rmapy+9 do
		for x=rmapx,rmapx+11 do
			local val = mget(x,y)
			if fget(val,0) and not fget(val,1) then
				local plat = {x = x*8, y = y*8 - t.h}
				if (plat.x != t.x or plat.y != t.y) and vlen{x=plat.x-p.x,y=plat.y-p.y} > 48 then
					add(plats, plat)
				end
			end
		end
	end
	t.tp_to = rnd(plats)
	t.tp_from = {x=t.x,y=t.y}
end

function update_casting(t)
	t.s = t.i
	if t.state == 0 then
		-- casting...
		loop_anim(t,4,3)
	else
		t.s += 2
		if t.state == 2 then
			-- failed
			if loop_anim(t,3,1) then
				t.y += 1
			end
			t.timer -= 1
			if t.timer <= 0 then
				del(thang, t)
			end
		else
			-- succeeded
			if play_anim(t,5,4) then
				t.timer -= 1
				if t.timer % 3 == 0 then
					t.y += 1
				end
				if t.timer <= 0 then
					del(thang, t)
				end
			end
		end
	end
end

function spell_summon_bats(t)
	for xy in all({{0,-6},{8,-6},{0,2}}) do
		local b = spawn_thang(96, t.x+xy[1], t.y+xy[2])	
		b.z = 1
	end
end

function do_ball_die(f)
	if not f.alive then
		f.y += f.die_yinc
		f.fcnt += 1
		if f.fcnt & 1 == 0 then
			f.sfr += 1
		end
		if f.fcnt == 8 then
			del(f.list == nil and thang or f.list, f)
		end
		return true
	end
	return false
end

function update_iceball(f)
	if do_ball_die(f) then
		return
	end

	f.x += f.vx
	f.y += f.vy
	-- hit player
	if aabb(
			p.x + p.hx, p.y + p.hy, p.hw, p.hh,
			f.x + 2,f.y + 2,4,4) then
			kill_p()
			kill_ball(f)
	-- hit blocks
	elseif collmap(f.x+2,  f.y+2, 1) then
		kill_ball(f)
	end
end

function spell_frost_nova(t)
	for i=1,8 do
		local f = spawn_thang(124, t.x+4, t.y-2)
		apply_ball_prop(f, ball_dirs[i])
	end
end

function start_casting(t)
	t.casting = true
	t.spell = rnd({
		{fn = spell_summon_bats, pal = {}, cast_time = 55, recovery = 45},
		{fn = spell_frost_nova, pal = {[8]=7,[2]=12}, cast_time = 45, recovery = 30}
	})
	t.castu = spawn_thang(240, t.x, t.y - 6)	
	t.castu.pal = t.spell.pal
	t.shcount = t.spell.cast_time
end

function update_wizard(t)

	if do_boss_die(t) then
		if t.castu != nil then
			t.castu.state = 2
			reset_anim_state(t.castu)
		end
		return
	end

	local oldburning = t.burning
	if do_bad_burning(t) then
		if not t.alive then
			sfx(snd_knight_die)
			music(-1,0,3)
		end
		return
	elseif oldburning then
		start_tp(t)
		if t.castu != nil then
			t.castu.state = 2
			reset_anim_state(t.castu)
		end
	end	

	face_p(t)

	if t.tping then
		t.s = t.i + t.s_cast.s
		t.fr = 2
		t.fcnt += 1
		if t.fcnt == 9 then
			t.x = t.tp_to.x
			t.y = t.tp_to.y
		elseif t.fcnt == 18 then
			reset_anim_state(t)
			t.tping = false
			t.stops_projs = true
			start_casting(t)
		end

	-- else do some spelly welly
	elseif t.casting then
		t.s = t.i + t.s_cast.s
		loop_anim(t,8,t.s_cast.f)
		-- need to spawn casting here in case interrupted
		t.shcount -= 1
		if t.shcount == 15 then
			t.castu.state = 1
			reset_anim_state(t.castu)
			t.castu = nil
		elseif t.shcount <= 0 then
			t.casting = false
			reset_anim_state(t)
			-- now use shcount for resting
			t.shcount = t.spell.recovery
			t.spell.fn(t)
		end

	-- else we standing or hovering around waving our arms
	else
		-- idle
		if t.phase == 0 then
			t.s = t.i + t.s_idle.s
			if play_anim(t, 20, t.s_idle.f) then
				t.hover_up = not t.hover_up
				local dir = t.hover_up and -1 or 1
				t.y += dir
				reset_anim_state(t)
			end
			local r = get_room_xy(room_i)
			if p.y > r.y + 16 then
				t.phase = 1
				t.y += t.hover_up and 2 or 1
				start_tp(t)
			end
			t.shcount = 0
			return
		end

		t.s = t.i + t.s_cast.s
		t.fr = 0

		t.shcount -= 1
		if t.shcount <= 0 then
			start_tp(t)
		end
	end

	if not t.tping then
		kill_p_on_coll(t)
	end
end


function burn_frog(t)
	if not t.angry then
		burn_bad(t)
	end
end

function update_frog(t)
	if do_bad_die(t) then
		return
	end

	local oldburning = t.burning
	if do_bad_burning(t) then
		return
	elseif oldburning then
		t.angry = true
		t.jcount = 3
		t.pal = t.pal_angry
	end

	local oldair = t.air
	-- not burning and not in the air
	if not t.air then
		t.s = t.i + 0
		t.vx = 0
		t.rght = p.x > t.x and true or false
		local dir = t.rght and 1 or -1
		-- not angry - jump when player charges fireball
		if not t.angry then
			if t.croak then
				-- play full idle anim (croak)
				if play_anim(t, 5, t.s_idle.f) then
					sfx(snd_frog_croak)
					t.croak = false
					t.fr = 0
					t.fcount = 0
				end
			else
				-- just play first frame for a bit
				if play_anim(t, 40, 1) then
					t.croak = true
					t.fr = 0
					t.fcount = 0
				end
			end
			if p.sh then
				sfx(snd_frog_jump)
				t.vy += t.jbig_vy
				t.vx = t.jbig_vx * dir
				t.air = true
			end
		else -- angry - jump rapidly at player
			if t.jcount <= 0 then
				t.angry = false
				t.pal = {}
			else
				t.jcount -= 1
				sfx(snd_frog_jump)
				-- small jump
				if not t.bounced or t.do_smol then
					t.vy += t.jsmol_vy
					t.do_smol = false
				-- big jump if we bounced off a wall
				else
					t.vy += t.jbig_vy
					t.bounced = false
					t.do_smol = true -- always do a small jump after a big one
				end
				t.vx = t.jsmol_vx * dir
				t.air = true
			end
		end
	end

	-- physics - always run because falling could happen e.g. due to ice breaking
	local oldvx = t.vx
	local oldx = t.x
	local oldy = t.y
	local phys_result = phys_thang(t, oldair)
	-- if hit ceiling, redo physics with tiny jump
	if phys_result.ceil_cancel then
		t.vx = oldvx
		t.vy = t.jtiny_vy + t.g
		t.x = oldx
		t.y = oldy
		t.air = true
		phys_result = phys_thang(t, oldair)
	end

	-- bounce off wall
	if phys_result.hit_wall then
		t.rght = not t.rght
		t.vx = -oldvx
		t.bounced = true
	end

	-- air animation
	if t.air then
		t.s = t.i + t.s_jmp.s
		if t.vy > 0 then
			t.fr = 1 -- descend
		else
			t.fr = 0 -- ascend
		end
	end

	-- on landing, reset animation state
	if not t.air and phys_result.landed then
		t.s = t.i + t.s_idle.s
		t.fr = 0
		t.fcnt = rnd({0,10,20,30})
	end

	if check_bad_coll_spikes(t) then
		return
	end

	kill_p_on_coll(t)
end

function kill_p_on_coll(t)
	if p.alive and hit_p(t.x,t.y,t.w,t.h) then
		kill_p()
		return true
	end
	return false
end

function burn_knight(t)
	if t.atking and t.fr > 0 then
		burn_bad(t)
	end
end

function burn_archer_wizard(t)
	if not t.invis and not t.tping then
		burn_bad(t)
	end
end

-- return 0 for not on plat, -1 for left, 1 for right
function p_on_same_plat(t)
	-- not falling or jumping
	if t.air or p.air then
		return 0
	end

	-- either floor tile from t and p are fine
	local tfloor = t.lfloor != nil and t.lfloor or t.rfloor
	local pfloor = p.lfloor != nil and p.lfloor or p.rfloor
	-- on same level
	if pfloor.my != tfloor.my then
		return 0
	end

	local mx = tfloor.mx
	local pmx = pfloor.mx
	local topy = tfloor.my - 1
	local boty = tfloor.my
	local dir = p.x < t.x and -1 or 1

	while mx != pmx do
		local bot = mget(mx, boty)
		if not fget(bot, 0) then
			return 0
		end
		local top = mget(mx, topy)
		if fget(top, 1) then
			return 0
		end
		mx += 1 * dir
	end
	return dir
end

function update_knight(t)

	-- default to sword not being out - saves putting it everywhere
	t.swrd_draw = false
	t.swrd_hit = false

	if do_boss_die(t) then
		return
	end

	local oldatking = t.atking
	local oldburning = t.burning

	if do_bad_burning(t) then
		if not t.alive then
			sfx(snd_knight_die)
			music(-1,0,3)
		end
		return
	elseif oldburning then
		t.atking = false
	end

	-- only conserve vx when airborne, otherwise reset...
	if not t.air then
		t.vx = 0
	end

	local oldair = t.air

	if t.alive and t.atking then
		local anim = t.s_atk
		if t.phase == 2 then
			anim = t.s_jmp
		end
		t.s = t.i + anim.s
		if play_anim(t, 10, anim.f) then
			t.atking = false
			reset_anim_state(t)
		else
			if t.fr > 0 then
				if t.phase == 1 and t.fr == 1 and t.fcnt == 1 then
					sfx(snd_knight_swing)
				end
				local dir = t.rght and 1 or -1
				-- jump!
				if t.phase == 2 and not t.air and t.fr == 1 and t.fcnt == 1 then
					sfx(snd_knight_jump)
					t.vy = -3
					t.vx = 1 * dir
					t.air = true
				end
				t.swrd_draw = true
				t.swrd_fr = t.fr - 1
				-- all frames hit for now, not just first frame
				t.swrd_hit = true
			end
		end
	end

	-- grounded state
	--  phase 0 - idle
	--  phase 1 - walk toward player if on same platform, attack
	--  phase 2 - walk until timer expires, then jump toward player
	-- if atking ended, immediately walk this frame
	if t.alive and not t.air and not t.atking then
		local dir = p_on_same_plat(t)

		if t.phase == 0 then
			t.s = t.i + t.s_idle.s
			reset_anim_state(t)
			-- don't advance phase if p is dead
			if p.alive and dir != 0 then
				t.phase = 1
			end
		end

		if t.phase > 0 then
			t.s = t.i + t.s_wlk.s
			-- follow player if they're on same platform
			if dir != 0 then
				t.rght = dir == 1 and true or false
			end
			if t.rght then
				t.vx = 0.75
			else
				t.vx = -0.75
			end

			loop_anim(t,3,t.s_wlk.f)

			local do_attack = false
			t.atktimer += 1 -- time since last attack
			if t.phase == 1 then
				do_attack = vlen({ x = t.x - p.x, y = t.y - p.y }) <= t.atkrange
			end
			if t.phase == 2 then
				if t.atktimer >= t.jmptime then
					do_attack = true
				end
			end
			if do_attack then
				t.atktimer = 0
				t.atking = true
				reset_anim_state(t)
				face_p(t)
			end
		end
	end

	local oldvx = t.vx
	local phys_result = phys_thang(t, oldair)

	if t.air then
		if phys_result.hit_wall then
			t.rght = not t.rght
			t.vx = -oldvx
		end
	elseif not t.atking then
		if phys_result.hit_wall or coll_edge_turn_around(t,t.x,t.y+t.h) != 0 then
			t.rght = not t.rght
		end
	end

	-- animate falling
	if t.air and not t.atking then
		t.s = t.i + t.s_fall.s
		t.fr = 0
	end

	-- change phase if attack ended for any reason
	-- switch phase after attacking
	if oldatking and not t.atking then
		if t.phase == 1 then
			t.phase = 2
			t.jmptime = 20 + rnd({0,15,30})
		else
			t.phase = 1
		end
	end
	-- change phase if haven't attacked in a while
	if t.phase == 1 and t.atktimer > 60 then
		t.phase = 2
		t.jmptime = 10 + rnd({0,15,30})
	end
		
	-- don't kill p if we're dead! (e.g. falling)
	if t.alive then
		if kill_p_on_coll(t) then
			t.phase = 0
		end
		local swrd_start_x = t.rght and 8 or -t.swrd_x_off
		if t.swrd_hit then
			if hit_p(t.x + swrd_start_x, t.y + t.swrd_y, t.swrd_w, t.swrd_h) then
				kill_p()
				t.phase = 0
			end
		end
	end
end

function burn_bat(b)
	if b.alive then
		sfx(snd_hit)
		b.alive = false
		b.s += 2
		b.vy = 0.6
		b.deadf = 20
	end
end

function loop_anim(t,speed,frames)
	-- t = {
	--   s -- starting frame
	--   fr -- current frame
	--   fcnt -- frame counter
	-- }
	-- return true if looped
	local ret = false
	if t.fcnt >= speed then
		t.fcnt = 0
		t.fr += 1
		if t.fr >= frames then
			ret = true
			t.fr = 0
		end
	end
	t.fcnt += 1
	return ret
end

function play_anim(t,speed,frames)
	-- see loop_anim
	-- this one doesn't loop
	if loop_anim(t,speed,frames) then
		t.fr = frames - 1
		t.fcnt = speed
		return true;
	end
	return false
end

function init_bat(b)
	b.fcnt = rnd({0,1,2,3})
end

function update_bat(b)
	if not b.alive then
		b.stops_projs = false
		b.deadf -= 1
		if b.deadf == 0 then
			del(thang, b)
			room_num_bads -= 1
		end
		loop_anim(b,4,2)
		b.x += b.vx
		b.y += b.vy
		return
	end

	-- b.alive
	if loop_anim(b,4,2) then
		sfx(snd_bat_flap)
	end

	-- move the bat
	local b2p = {x=p.x-b.x,y=p.y-b.y}
	local dist2p = vlen(b2p)
	local in_range = dist2p < b.range and true or false
	local go_to_p = in_range

	-- if collide with something, go in random direction
	if move_hit_wall(b) then
		b.dircount = 0
		-- force pick a random direction
		go_to_p = false
		b.vx = 0
		b.vy = 0
	else
		b.x += b.vx
		b.y += b.vy
	end

	-- pick the direction for next frame
	if b.dircount <= 0 then
		-- go toward player
		if go_to_p then
			b.vx = b2p.x * b.xspeed/dist2p
			b.vy = b2p.y * b.yspeed/dist2p
			b.dircount = 30
		-- pick random direction
		else
			local rndv = {x = rnd(2) - 1, y = rnd(2) - 1}
			local len = vlen(rndv)
			b.vx = rndv.x * b.xspeed/len
			b.vy = rndv.y * b.yspeed/len
			if in_range then
				b.dircount = 20
			else
				b.dircount = 60
			end
		end
	else
		-- otherwise keep going the same way until dircount expires
	end
	b.dircount -= 1

	-- face the right way
	if b.vx > 0 then
		b.rght = true
	else
		b.rght = false
	end

	kill_p_on_coll(b)
end

function burn_lantern(l)
	if not l.lit then
		l.lit = true
		room_num_unlit -= 1
		l.s += 1
	end
end

function update_lantern(l)
	if l.lit then
		loop_anim(l,5,2)
	end
end

function update_checkpoint(t)
	loop_anim(t,5,3)
end

function spawn_thang(i,x,y)
	local t = {
		i = i,
		x = x,
		y = y,
		vx = 0,
		vy = 0,
		alive = true,
		-- collision
		ftw = 0.99,
		ftx = 3,
		cx = 0,
		cy = 0,
		cw = 8,
		ch = 8,
		-- hurtbox
		hx = 0,
		hy = 0,
		hw = 8,
		hh = 8,
		-- animation/drawing
		rght = true,
		z = 0,
		w = 8,
		h = 8,
		s = i,
		fr = 0,
		fcnt = 0,
		-- functions
		draw = draw_thang,
		burn = no_thang,
		-- misc
		stops_projs = true,
		-- replace on map when spawn
		replace = 0,
		-- alt palette
		pal = {},
	}
	-- apply template first
	local template = thang_dat[i].template
	if template != nil then
		for k,v in pairs(template) do
			t[k] = v
		end
	end
	-- overwrite defaults/template with specific stuff
	for k,v in pairs(thang_dat[i]) do
		t[k] = v
	end
	if t.init != nil then
		t:init()
	end
	add(thang,t)
	return t
end

-->8
-- player

p_dat = {
	i = 64, -- base of sprite row
	--  animations - s = offset from spr, f = num frames
	s_wlk =  {s=0, f=2},
	s_sh  =  {s=30, f=2},
	s_jmp =  {s=2, f=5},
	s_die =  {s=7, f=5},
	s_spwn = {s=12, f=4},
	w = 8,
	h = 8,
	--  physics
	--  coll dimensions
	ftw = 2 - 1, -- 1 because we just care about pixel coords
	ftx = 3,
	fty = 8,
	ch = 4,
	cw = 5,
	cx = 1,
	cy = 2,
	-- hurtbox dimensions
	hx = 2,
	hy = 2,
	hw = 3.99,
	hh = 3.99,
	-- physics
	gax = 1, -- ground accel
	iax = 0.2, -- ice accel
	aax = 0.3, -- air accel
	adax = 0.8, -- air decel factor
	gdax = 0.6, -- ground decel factor
	idax = 0.9, -- ice decel factor
	max_vx = 1.4,
	min_vx = 0.01, -- stop threshold
	g_norm = 0.3,
	g_sh = 0.05,
	max_vy_norm = 4,
	max_vy_sh = 1,
	g = 0.3, -- gravity
	max_vy = 4,
	j_vy = -4, -- jump accel
}

function spawn_p(x,y)
	p = {
		x = x,
		y = y,
		rght = not (room_i < 8 or room_i > 15),
		vx = 0,
		vy = 0,
		air = true, -- must start in air!
		onice = false,
		fr = 0, -- displayed frame offset
		fcnt = 0, -- counter for advancing frame
		shcount = 0, -- shoot counter (cooldown)
		sh = false, -- charging fireball
		teeter = false,
		alive = true,
		spawn = true,
	}
	for k,v in pairs(p_dat) do
		p[k] = v
	end
	p.s = p.i + p.s_spwn.s
end

function kill_p()
	sfx(snd_p_die)
	music(-1,800,3)
	p.alive = false
	p.s = p.i + p.s_die.s 
	reset_anim_state(p)
	p.sh = false
end

function hit_p(x,y,w,h)
	return aabb(x,y,w,h,
				p.x+p.hx,p.y+p.hy,
				p.hw,p.hh)
end
function coll_p(x,y,w,h)
	return aabb(x,y,w,h,
				p.x+p.cx,p.y+p.cy,
				p.cw,p.ch)
end

function update_p()
	if p.spawn or not p.alive then
		respawn_update_p()
		return
	end

	-- change direction
	if btnp(⬅️) or
		btn(⬅️) and not btn(➡️) then
		p.rght = false
	elseif btnp(➡️) or
		btn(➡️) and not btn(⬅️) then
		p.rght = true
	end
 
	if not p.sh then
		local ax = 0
		if p.air then
			ax = p.aax
		elseif p.onice then
			ax = p.iax
		else
			ax = p.gax
		end
		if btn(⬅️) and not p.rght then
			-- accel left
			p.vx -= ax
		elseif btn(➡️) and p.rght then
			p.vx += ax
		end
	end
	if p.sh or (not btn(⬅️) and not btn(➡️)) then
		if p.air then
			p.vx *= p.adax
		elseif p.onice then
			p.vx *= p.idax
		else
			p.vx *= p.gdax
		end
	end
	p.vx = clamp(p.vx, -p.max_vx, p.max_vx)
	if abs(p.vx) < p.min_vx then
		p.vx = 0
	end

	-- vy - jump and land
	local oldair = p.air
	local jumped = false
	if btnp(🅾️) and not p.air and not p.sh then
		jumped = true
		p.vy += p.j_vy
		p.air = true
	end
	if p.sh and p.vy > 0 then
		p.max_vy = p.max_vy_sh
		p.g = p.g_sh
	else
		p.max_vy = p.max_vy_norm
		p.g = p.g_norm
	end

	local oldx = p.x
	local oldy = p.y
	local oldvy = p.vy + p.g

	local phys_result = phys_thang(p, oldair)

	if phys_result.fell and not p.onice then
		-- fall off platform only if
		-- holding direction of movement
		-- kill 2 bugs with one hack
		-- here - you slip off ice,
		-- and fall when it's destroyed
		if 		(btn(⬅️) and p.vx < 0) or
				(btn(➡️) and p.vx > 0) then
			-- none
		else
			p.air = false
			p.x = oldx
			p.y = oldy
			p.vy = 0
			p.vx = 0
		end
	end

	-- close to edge?
	p.teeter = not p.air and coll_edge(p,p.x,p.y+p.fty)

	if phys_result.landed then
		sfx(snd_p_land)
	end

	if jumped and not phys_result.ceil_cancel then
		sfx(snd_p_jump)
	end

	if coll_spikes(p) then
		kill_p()
		return
	end

	local oldsh = p.sh
	if btn(❎) then
		if p.shcount == 0 then
			p.sh = true
		end
		if p.sh then
			local ydir = 0
			local xdir = 0
			if btn(⬆️) then
				ydir = -1
			elseif btn(⬇️) then
				ydir = 1
			end
			if btn(⬅️) then
				xdir = -1
			elseif btn(➡️) then
				xdir = 1
			-- default x dir, only if a direction hasn't been buffered,
			-- and only if y dir is 0, to allow straight up and down
			elseif p.shbuf == nil and ydir == 0 then
				if p.rght then
					xdir = 1
				else
					xdir = -1
				end
			end
			if xdir != 0 or ydir != 0 then
				p.shbuf = {x = xdir, y = ydir}
			end
		end
	else -- release - fire
		if p.sh then
			make_fireball(p.shbuf.x, p.shbuf.y)
			p.shcount = 10
			p.shbuf = nil
		end
		p.sh = false
	end
	if p.shcount > 0 then
		p.shcount -= 1
	end

	-- animate
	if p.sh then
		p.s = p.i + p.s_sh.s
		if not oldsh then
			sfx(snd_p_shoot)
			p.fr = 0
			p.fcnt = 0
		end
		if loop_anim(p,3,p.s_sh.f) then
			sfx(snd_p_shoot)
		end

	elseif not p.air then
		-- walk anim
		p.s = p.i + p.s_wlk.s
		-- just landed, or changed dir
		if oldair or btnp(➡️) or btnp(⬅️) then
			p.fr = 0
			p.fcnt = 0
		end
		if abs(p.vx) > 0.5 then
		--if (btn(➡️) or btn(⬅️)) then
			--if stat(46) != 5 then
			--if p.fcnt == 1 and p.fr == 0 then
				--sfx(5,0,0,8)
			--end
			loop_anim(p,3,p.s_wlk.f)
			--	sfx(5,0,0,8)
		elseif p.teeter then
			p.fr = 1
		else
			p.fr = 0
		end

	else --p.air
		p.s = p.i + p.s_jmp.s
		if not oldair then	 
			p.fr = 0
			p.fcnt = 0
			-- fell, not jumped
			if not btn(🅾️) then
				p.fr = 5
			end
		end
	-- jump anim
		if p.fcnt > 2 then
			p.fr += 1
			-- loop last 2 frames
			if p.fr >= p.s_jmp.f then
				p.fr -= 2
			end
			p.fcnt = 0
		end
		p.fcnt += 1
	end
end

function respawn_update_p()
	-- do nothing while fading out/in
	if do_fade then
		return
	end
	if not p.alive then
		if play_anim(p,3,p.s_die.f) then
			-- fade out after death anim
			fade_timer = 0
			do_fade = true
			reset_anim_state(p)
			p.s = 0
		end
	elseif p.spawn then
		if play_anim(p,3,p.s_spwn.f) then
			reset_anim_state(p)
			p.s = p.i + p.s_wlk.s
			p.spawn = false
			start_music()
		elseif p.fr == 0 and p.fcnt == 1 then
			sfx(snd_p_respawn, 3)
		end
	end
end
-->8
-- fireball
fireball = {}
ball_dirs = {
	-- start at xdir = 1, ydir = -1 (up right) 
	-- sfr, vx, vy, xflip, yflip
	{3, 0.7071, -0.7071, false, true},
	{1, 1, 		0, false, false},
	{3, 0.7071, 0.7071, false, false},
	{2, 0, 		1, false, false},
	{3, -0.7071, 0.7071, true, false},
	{1, -1, 	0, true, false},
	{3, -0.7071, -0.7071, true, true},
	{2, 0, -1, false, true}
}
function apply_ball_prop(f,prop)
	f.sfr = prop[1] -- sub-frame
	f.vx = prop[2] * f.speed
	f.vy = prop[3] * f.speed
	f.xflip = prop[4]
	f.yflip = prop[5]
end

function make_fireball(xdir, ydir)
	local f = {
		x = p.x + (p.w - 4)/2,
		y = p.y + (p.h - 4)/2,
		s = 80,
		alive = true,
		speed = 3,
		update = update_fireball,
		fcnt = 0,
		list = fireball,
		die_yinc = -0.5,
		s_die_s = 81
	}
	local prop = nil
	if xdir > 0 then
		prop = ball_dirs[ydir + 2]
	elseif xdir == 0 then
		prop = ball_dirs[ydir == 1 and 4 or 8]
	else
		prop = ball_dirs[-ydir + 6]
	end
	apply_ball_prop(f, prop)
	add(fireball, f)
end

function kill_ball(f)
	f.alive = false
	f.yflip = false
	f.sfr = 0
	f.s = f.s_die_s
	f.fcnt = 0
end

function update_fireball(f)
	if do_ball_die(f) then
		return
	end
	f.x += f.vx
	f.y += f.vy
	-- hit stuff
	for t in all(thang) do
		-- use hurt box if t has one
		if aabb(
				t.x + t.hx, t.y + t.hy, t.hw, t.hh,
				f.x,f.y,4,4) then
			-- todo - is alive the right check?
			if t.burn != nil then
				t:burn()
			end
			if t.stops_projs then
				kill_ball(f)
				return
			end
		end
	end
	-- hit blocks
	-- check two points to make it harder to abuse shooting straight up/down past blocks
	if 
			collmap(f.x+3,  f.y+2, 1) or
			collmap(f.x+1,  f.y+2, 1) then
		kill_ball(f)
	end
end

-->8
-- collision

function collmap(x,y,f)
	local val = mget(x\8,y\8)
	return fget(val,f)
end

function coll_edge_turn_around(t,newx,fty)
	-- t = {
	--   ftx	-- foot x offset
	--   ftw	-- foot width
	--   rght	-- facing right
	-- }
	-- fty = foot y
	-- check if foot is close to edge, and facing off edge
	-- return 1 for right, -1 for left, 0 for not
	local tftxl = newx + t.ftx
	local tftxr = tftxl + t.ftw
	if t.rght then
		if not collmap(tftxr+1,fty,0) then
			return 1
		end
	else
		if not collmap(tftxl-1,fty,0) then
			return -1
		end
	end
	return 0
end

function coll_edge(t,newx,fty)
	-- t = {
	--   ftx -- foot x offset
	--   ftw -- foot width
	-- }
	-- fty = foot y
	-- return true if 1 px from edge
	local tftxl = newx + t.ftx
	local tftxr = tftxl + t.ftw
	if not (collmap(tftxl-1,fty,0) and
			collmap(tftxr+1,fty,0)) then
		return true
	end
	return false
end

function coll_spikes(t)
	local hl = t.x + t.hx
	local hr = hl + t.hw
	local ht = t.y + t.hy
	local hb = ht + t.hh
	if 	collmap(hl,ht,3) or
			collmap(hr,ht,3) or
			collmap(hl,hb,3) or
			collmap(hr,hb,3) then
		return true
	end
	return false
end

function move_hit_wall(t)
	-- t = {
	--	 x  -- coord
	--   y  -- coord
	--   cx -- coll x offset
	--   cw -- coll width
	--   cy -- coll y offset
	--   ch -- coll height
	--   vx -- x vel
	--	 vy -- y vel
	-- }
	-- return true if any corner hit a wall, false otherwise

	local newx = t.x + t.vx
	local newy = t.y + t.vy
	local cl = newx + t.cx
	local cr = cl + t.cw
	local ct = newy + t.cy
	local cb = ct + t.ch

	return 	collmap(cl, ct, 1) or 
			collmap(cr, ct, 1) or
			collmap(cl, cb, 1) or 
			collmap(cr, cb, 1)
end

-->8
-- physics for platformu

function phys_thang(t, oldair)
	-- oldair = false if grounded, or just jumped this frame (air = true and vy < 0)
	-- physics for thangs who obey gravity
	-- apply gravity, do physics, stop them colliding with walls
	-- ground if airborne and hit the ground
	-- make airborne if not grounded or jumping
	-- return {
	--			hit_wall, 	 -- if we hit a wall
	--          ceil_cancel, -- if jump was cancelled by a ceiling
	--			landed,		 -- if t.air went from true to false (false on ceil_cancel)
    -- } 
	local ret = { hit_wall = false, ceil_cancel = false, landed = false, fell = false }

	t.vy += t.g
	t.vy = clamp(t.vy, -t.max_vy, t.max_vy)

	local newx = t.x + t.vx
	local newy = t.y + t.vy

	if t.vy > 0 then
		newy = phys_fall(t,newx,newy)
		if not oldair and t.air then
			ret.fell = true
		end
	else
		newy = phys_jump(t,newx,newy,oldair)
		if t.vy == 0 and not t.air then
			ret.ceil_cancel = true
		end
	end

	local pushx = phys_walls(t,newx,newy)
	ret.hit_wall = pushx != newx
	newx = pushx

	if oldair and not t.air then
		ret.landed = true
	end

	t.x = newx
	t.y = newy

	return ret
end

-- t.vy > 0
function phys_fall(t,newx,newy)

	-- where our feeeeet at?
	local fty = newy + t.h
	local ftxl = newx + t.ftx
	local ftxr = ftxl + t.ftw

	local stand_left = collmap(ftxl,fty,0)
	local stand_right = collmap(ftxr,fty,0)

	-- hit or stay on the ground
	if 	(stand_left or
			 stand_right)
			and
			-- (almost) in the block above platform-only block
			(	t.y < rounddown(newy,8)+3 or
				-- grounded
				not t.air or
				-- feet intersecting a 'full' block
				collmap(ftxl,fty,1) or
				collmap(ftxr,fty,1)
				)
			 then
		newy = rounddown(newy, 8)
		t.vy = 0
		t.air = false
		local lblock = mget(ftxl\8,fty\8)
		local rblock = mget(ftxr\8,fty\8)
		-- save position of which block we're standing on
		t.lfloor = stand_left  and {mx = ftxl \ 8, my = fty \ 8} or nil
		t.rfloor = stand_right and {mx = ftxr \ 8, my = fty \ 8} or nil
		-- are we on ice?
		t.onice = lblock == 86 or lblock == 87 or
				  rblock == 86 or rblock == 87
	else
		t.air = true
	end

	return newy
end

-- t.vy < 0
function phys_jump(t,newx,newy,oldair)
	-- where our head at? offset from cy a little so this always happens before phys_walls
	-- this avoids wall bonking on a flat ceiling
	-- use foot x - this avoids ceiling bonking when next to a wall
	local hdy = newy + t.cy - 0.1
	local hdxl = newx + t.ftx
	local hdxr = hdxl + t.ftw

	-- ceiling
	if 	t.air and (
				collmap(hdxl,hdy,1) or
				collmap(hdxr,hdy,1)) then
		if not oldair then
			t.air = false
			t.vy = 0
		else
			-- just sloow down on ceiling hit
			t.vy = t.vy/10
		end
		newy = t.y + t.vy
	end

	return newy
end

function phys_walls(t,newx,newy)
	local cl = newx + t.cx
	local cr = cl + t.cw
	local ct = newy + t.cy
	local cb = ct + t.ch

	local l_pen = 0
	local r_pen = 0
	if 	collmap(cl, cb, 1) or 
			collmap(cl, ct, 1) then
		l_pen = roundup(cl,8) - cl
	end
	if 	collmap(cr, cb, 1) or 
			collmap(cr, ct, 1) then
		r_pen = cr - rounddown(cr,8)
	end
	
	local oldnewx = newx
	if t.vx < 0 then
		newx += l_pen
	elseif t.vx > 0 then
		newx -= r_pen
	else
		if l_pen > 0 then
			newx += l_pen
		elseif r_pen > 0 then
			newx -= r_pen
		end
	end

	if oldnewx != newx then
		t.vx = 0
	end

	return newx
end

__gfx__
00000000dddddddddddddddddddddddddddddddd05555550000000000555555001111110011111103101001301010110dddddddddddddddd0111111001111110
000000000dddddd00dddddddddddddddddddddd011555151000000001551515501dddd100111111031011110100110330dddddddddddddd00155551001555510
000000000111111001111110000000000111111055151555000000005555551101dddd1001111110010110101001133300000000000000000111111001111110
00000000011001100110011111111111111001101551515111111111551151510111111001dddd10010110131011131001111111111111100000000000000000
00000000010000100100001000000000010000101155511100000000155511510000000001dddd10010111131111001300000000000000000000000000000000
00000000001111000111111001100110011111101515151101100110111115550000000001dddd10010101100101001301100110011001100000000000000000
00000000000000000100001111111111110000101111151111111111151155110000000001dddd10010111103301011000111111111111000000000000000000
00000000000000000100001000000000010000100151111000000000011115100000000001dddd10110110100301011300000000000000000000000000000000
dddddddddddddddddddddddddddddddddddddddddddddddd11111111dddddddd0111111001dddd10010100100101011055555555555555555555555500000000
0dddddddddddddddddddddddddddddd00dddddd00dddddd0001000000dddddd01111111d01dddd10330100103101011005515115551555555515515000000000
01111111111111111111111111111110011111100111111000100000011111101d11d1dd01dddd10333100133301011301001110110011001100110000000000
011ddd11111111111111111111ddd110011dd1100110011000000000011dd110111ddd1d01dddd10013100010101011000000010001001010010010000000000
01ddddd1ddddd1dddd1dd1dd1ddddd1001dddd10010000101111111101dddd101ddddddd01dddd10010110010101011000101101100010101000101000000000
01111111ddddd1ddddd1d1dd11111110011111100111111000000100011111101dd1d1dd01dddd10310110100101011000100000001100001110000000000000
01d1d1d1ddddd1dddddd11dd1d1d1d1001dddd10010000100000010001dddd1011d1dddd011dd110010111100101011000000100000001010001010000000000
01d1d1d111111111111111111d1d1d1001dddd100100001000000000011111100dddddd000111100010111100101011000000000000001000000000000000000
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd100100001000011000dddddddddddddddd00000000010101100101011001010110dddddddd0000000055555555
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd1001000010000001010dddddddddddddd0000000003101011031010110310101100dddddd00000000005115550
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd100100001000100000011111111111111000000000310101133101011331010113011111100000000001001110
01d1d1d111111111111111111d1d1d1001dddd100100001000010000011ddd1111ddd11000000000010101100111011101010111011dd1100000000000100010
01d1d1d1ddddd1ddddddd1dd1d1d1d1001dddd10010000100110001101ddddd11ddddd100000000001010110011101110101011101dddd100000000001001100
01d1d1d1ddddd1ddddddd1dd1d1d1d1001dddd100100001000000001011111111111111000000000013131303101011031013113011111100303003000100000
01d1d1d1ddddd1ddddddd11d1d1d1d1001dddd10010000101001000001d1d1d11d1d1d100030300303310110013131300131331331dd3d133003303300010100
01d1d1d111111111111111111d1d1d1001dddd100100001000010000011111111111111030330033333313133331331333333333331333333033330300000000
01d1d1d1dd1d1ddddd1ddddd1d1d1d1001dddd10010000105151551501d1ddddd1dddd10155555555555555555555555dddddddddddddddd55555551dd1d1ddd
01d1d1d1dd1dd11ddd1ddddd1d1d1d1001dddd10010000101151515501d1ddddd1dddd10d155555111515551155555510dddddddddddddd01555551ddd1dd11d
01d1d1d1dd1dddd1dd1ddddd1d1d1d1001dddd10011001105511555501d1ddddd1dddd10d1111515551115555511151501111111111111105511151ddd1dddd1
01d1d1d111111111111111111d1d1d1001dddd1001011010555555550111111111111110155511115551115555551111011dd111111dd1105555111111111111
011ddd11ddddd1ddddddd1dd11ddd110011dd11001000010115511111ddddd1ddddd1dd1d1555551555151515555555101dddd1dd1dddd1055555551ddddd1dd
dd11111dddddd1dddddd11ddd11111dd01d11d1010111101011115111ddddd1ddddd1dd1d111115511551511115511550111111dd11111101555111dddddd1dd
1dddddddddddd1ddddd1d1dddddddddd1dddddd110000001011511001ddddd1ddddd1dd1111115515511151511551555011dd11dd11dd1101155151dddddd1dd
11111111111111111111111111111111111111111111111100011100111111111111111111111111155551551511111101111111111111101111111111111111
00022200000222000000000000505200000000000022220000222200002220000002000000200020000000000000000000000000000000000000000000000000
002211200022112002222220002222200002220000221120002211200221200000222000002202000020000000020000000000000000000007007000007022a0
0021112000211120222222220022222202212220022111200221112222111200022120002022222000220200002200000000000000072000009a2707700a1127
02211120022111202222222202222222211122250221122202211222221112202211202002212220022220000012200000070a00070292a072199aa0002971a0
02222220022222205222111202222222222222200222222202222220222222202221122002111220002120000001100000a9900000a9899009a889000a922920
02222220022222200222212002222222222222250222222022222220022222220222222000211200000110000000100009989990098888a002988890a922229a
222222002222220052222200002222200222222222222500022225000222205002222250000210000000000000000000000000000098820000a99a2009829890
0050050000055000000000000000000000222000022050000020500000205000002250000000000000000000000000000000000000000000000a000000900500
bbbb0980070a7070ddddddddddddddddddddddddddddddddc77c7ccc0cccccc00070c00000000000000000000000000000000000000700000002e200002e2000
bbbb7a987a99a7a700222200002222000022220000000000cccc777cccc711cc00c070c0000000000000000000000000000007000000000002e11e0000e11e20
bbbb7a98099a0890021001200210012002100120000000001ccccc7c1c7cc1cc0c7ccc000c0c0c0000c000000000070000700000000a000002e71e2002e17e20
bbbb0980008000000210712002a0712002170120000000001ccccccc1ccccc1c10c7c1cc00c700000000700000700a000090aa0000a00700029a7a2222a7a920
077007a0070770a0201001022017a102207aa10200000000c1cccc1cc1cccc1cccccc1c10c00c7c0070c0c0000a990000009900000099a002289a922229a9822
9aa97a98099a099020100102201891022018910200000000c11cc11cc11cc11c11cccc10cccc0c0c0c00000c00988900009889000098890002e88e2002e88e20
8998a9980080000002111120021111200211112000000000ccc11cc00ccc11cc0c1c1cc11c0c1cc1100cc7100d66ddd00dd66dd00dd666d0002ee200002ee200
08800880000000002222222222222222222222220000000001ccc11001ccccc000c101c00c110c100c010c000011110000111100001111000005500000055000
5500050000000000007000700700070000066600000666000006660000ee00000007000000000000000000007ccc000cc7c70c00011111100111111006006000
055055000000000008a707a009a707a0000611600006116000c611600ee7e0000000a70000707000000700000c000ccc0c70c7c7011111100111111006007000
0085800000085800009a0a80008a0a9000661160006611600c6611600ee77e00707aaaa0000aa000070a00000c00700c777c077c015555100155551000706006
00050000055555000008a9000009a80006c66160066c6160cc6661600eee7e900aa999a007a997000000900000c0000cc0c70c00015555100155551060606007
0000000055000550000098000000890006cc6660066cc66005666665088eee0000a9a900009980000000000007007000c00c000c155555511555155107006060
000000005000005000000000000000000566c66506566c6000c6666080eeeee008998900000800000000000000c0c00cc70707001511115115151551006ddd60
00000000000000000000000000000000c06666000c66660000666600090eeee000088000000000000000000000c0ccc00000700715111151151dd1510ddd11d0
0000000000000000000000000000000000500500000550000050050000890090000000000000000000000000ccccc0000c700000151d1d511551d15101111110
0000000000000000000000b0bb00000000000e00000666000006660000066c0000066600000666c00eee080000000000bbbb0c7015111151151d15510dddddd0
000000000000000000000b8b03b000000000e7e0006116c000611600006116c000611cc00061160ce77e008000000000bbbb11c7155115511551155101d11110
00000b0000000b000004bbb300b0000000eeee200061160c006116c00061160c0061160c0061160ce77e008000000000bbbb11c7155555511555555106111600
0000b8b00000b8b0004443b000b400b00000ee000666660c066666c0066566656656666566566665eeeeee90000cccccbbbb0c70015555100155551006060070
00bbbb3000bbbb3000b400b000444b8b0008820066666665066666500066660c0066660c0066660c0eee00800000000001100110015555100155551070060606
04443b0004443b300bb300000004bbb300e880005066660c056666c0006666c000666cc00066660c9eeee08000000000c11c11c7011111100111111060060700
04443b0004443b00b3000000000003b0ee0020000066650c006660c000666c0000666500006665c009999800000000007cc71cc7001dd100001dd10000070060
003bb0b0003bb0b0b0000000000000b000220000005005c000055c00005005000050050000500500009009000000000007700770001111000011110000060060
700042b370a3b350b370a3a35041704150626262626262626262626575507050707050705070705070505050705070505070507050705050705063a3b3a3b3a3
a3a3b350507063706370706370637070a3707070a350635070705070a37063a3707063637063637063707070a3707050a3b3637063b3b3b350b3b350b3b3b3a3
70104250b3a370a350b35070634200425062705070505081626200000065505050620000000062000000630000000050706262000000650000627070b3b3b3b3
a3b3b363756562626262626262006370706362000000000000000062700000a370620000000000630000257575505070b3630000006375657565656370a3a3a3
700042507050b350b350a37062430043706270f7f7f7f700000000000000757070500000000000700000000000700080f000000000c1d1e1000062626350a3b3
a3506275650662626262626200000080e0620000000000000000000000000080f0000000000000000062f20000655070705000500000000075757575505070b3
70004270636250505062636200000080006250000000000000007500000000505000009200070000009200b500006200000000000062000000000062626225a3
70706225756262626262626262b500000000000000920000b50000e20000000000920025e20000000000000000655050a37000000000000000006575657563b3
701043506262626362626262b592000000627000007500000000650000000070706570705070b3b3a350705070507050700000f26200620000f2000000626350
70507050066262626262626200c1d1a3500000c1d1d1d1d1d1d1d1d1e100505070d1d1d1d1e100620000620000006370b3637000000000000000000075656550
700062e0000062626262620041d1d1707050500000650000000000000000655050000000000070a3630000005070007050006200000000000062000000626270
50705070506262626262620000650050a3e100000000000000000000000000a350626200000000920000620000006550b37050000000cedeeefe0000007565a3
70e20000620062000000620042000070b350620000000065000000000075655070000000000000630000000000e000a370000000000000000000000000007050
70700000f06262626262626275256570700000000062929200e20000000000b350700000000000c1d1d1e10000000050b35070000000cfdfefff0000000075b3
70d1d1410000000062000000420070705062006500000075000000008165757050009200929200650000e2e200000070500000000000000000f2000000625070
50000000009262626262627565705050a30000066250a3b3a3b37062626200a370507000629200000000000000000070707000000000000000000000000065a3
700000420000000000000000420000507000000000000000000000000000655070d1d1d1d1d1d150d1d1d1d1d17000a37000000000f200000000000000000050
7000000070637070507050705000007050755070507050b3a3b3a350705065b350c1d1d1d1e162000000000000000050a35000000000000000000000000075b3
505000420000000000000000420070b3500000000000000000000000000075705000000000000070000000000050007050000000000000000000000000000070
50700000000000507063000000000050706262626350627050705063620000b370006200620062259200000000000050500000000000000000000000000000a3
500000420051000000005100425070a370620075000000657500000000000050700700000000005006000700007000a37000f200000000000000000000000050
70500000000000000000000000000070506262626262626262620000626262a35025000000005070500000000000008065000000000000000000000000b500b3
705000430053000c00005300430050b3506262810000000000000000b500007070505070507000700050707050620070700062000000000000f2000000b50050
5062620007000000000000000062625070f2626200006206006262006262f2b370f200006200000000000000b5006200e2650065750000000000000072218250
7070e2c03030303030303030d05070a370f66262000062000062620071000080636262630062506250506300500062b350620000000000000062626250d1d170
70006262620062626200626262620070506262626262626262626262626262a370620000000000000000c1d1d1d1d17050750075657565000000007173138350
b3a350007092705070005092705050a3a370f6f662626262626262624300000062e2000062006292e2000000006270a370f662c1e16262f66262f6f670626280
e00062626262626262626200626250a3700662f26262626262626206f26250b35062620000000000006262626262627070657565756575000065717323228350
70b3a350a350a350b3a370a3a3b3a3a3a3a3a350f6f6f6f6f6f6f6f670b3a3b37050706270925050a3506262e25070b35070f6f6f6f6f650f6f6705063626200
0062626281000062626200507050b3a3a35062626262620062626262625070a370f6f6f6f6f6f6f6f6f6f6f6f6f6f650a3506575659265756571731322128350
70a3b3a3b3a3a3b3a3b3a3a3b3a3a3a3b3b3a3b3a3a3a3a3b3a3b3a3b3a3b3a3a3a3a370a3a350a3a370a3a370a370b3a3b3a3b3a3b3a3a3b3b3a3b3a3a3b3a3
b3a3b3a3b3b3a3b3a3a3b3a3b3a3b3a3b3a3b3a3b3a3b3a3a3b3b3a3b370b3a3a3b3b3a3b3a3b3a3b3a3b3a3b3a370a3b3a3b3b3a3a3b3a3a3b3a3b3a3b3a3b3
0066dd000066dd700066dd70066d700000066dd00066dd000000000000066dd00066dd000066dd70077ee700066dd00000000000000000000000000000000000
00dffd002222fd702222fd7022227000222dffd022dffd000066dd00222dffd022dffd002222fd7088aae7002222d0000066dd00000000000007000000000000
22226d0027a26d6027a26d6027a26000222d66d022d66d002222fd70222d66d022d66d0027a26d608877ee0027a2d0002222fd00000000000070000000000000
27a2ddf02a92d4442a92d4442a924400222dddd022dddd0027a26d70222dddd022dddd002a92d44488eee8802a92d04027a26d00000000004600000040000000
2a92dd442982ddf02982ddf02982f00022fddddd2fdddddf2a92dd6022fddddd2fdddddf2982ddf088eeea002982df462a92dd0000000000f400000046770000
2982556028825500288255002882500022255500225550002982d44422255500225550002882550088999000288250402982dd400022222d0000000040000000
288205700225500002250500022005000205005002500500288255f0022505000250050002205050089009000220050028825f460289a72d0000000000000000
0220057000055000005005000050050000500050050005000225050000505000050005000000505000900900005005000225054052889a2d0000000000000000
00000000000000000000000000444900004440000044409000044400011444901104449000444900004440000044409000777900004440000000000000000000
004440000110044400000444004ff090004ff990004ff0090004ff901111ff091111ff09014ff090014ff990014ff009007aa090004ff0000044400000000000
004ff000111114ff011114ff011550090115500901155009001155091111550911115509111550091115500911155009099ee09001155009004ff00000000000
011550001111115511111155155f555f55f5555f55f5555f01155509011f555f111f555f155f555f55f5555f55f5555f99eeeea0115550090115500000000000
1155500009055559910555901155500911555009115550091115555f01115509001155091115500901155009011550099eeee090155550091155500000000000
11555f000099f990199f990011222090112229901122200911f222090000222900002229011222900112299001122229a98880901f2225f01555500900111100
1199f990002002000002200011200900112002001120029011200209000020900000209000112920001120200011209099980900111202901f222f9001111114
09112229020020000022000002000200020002000200020012002090000002020000020200002020000020200000202009008080012029001112220022111544
0c66000400c6600000c6600000c6600400e770000000000000000000007a70007007070000070000000000000000000001017771010077777a00771010711771
c66f60040c66f6040c66f6400c66f6040e77970000000000000000000766a70a00a5a000a005590000000000000000000111a771110aaaa77100771100aa17a1
cfbf00040cfbf0040cfbf0400cfbf00f0e9c98000007000000000000acfbfaa007ab2a0000a19100000000000000000011017771100771111000771001771771
c6ff60040c6ff6040c6ff640fc6ff6c40e7997800077700000070000ac6f96900a5a59907005159000000000000000001011a7a110aaa10000107a7110aa17a1
c6666004cc6666cffc6666f0cc6666040e7777900777770000777000ac9669907caca590010b91000000000000000000001aaaaa00aa11101100aaa7107a1a71
cc666c04fcc66604ccc666400cc666049ee7778000777000000700000fc996c809a9898000a599000051000000000000001aa1aa00aa11111000aaaa11aa1aa1
ccf6fc040ccc60040ccc60400ccc600400ee7e080007000000000000989c69800088880005000100051b5100000000001019a09a00aa101000109aaa10aa1aa1
0cccc000ccccc004ccccc040ccccc0000eeeee0800000000000000000988880000000000005100501115115000000000100990a9109a1000010999aa919a1a91
000000000000000000000000000000000120012000100200000000000006600000000000000660000066000007eee00000991099119910001109991999991991
00000000000000000000100000000000282102820800100800000000006006006006600060600600660060000e07700000991099919911111109911999911991
00120000000080000800000000182100211001210000000000000000606dd6d06060d6d0060dd6d000ddd6007eee070000899999919919aa1009910199910991
0000000000200100000000200102000010000010000000200000000006d0662006d6662000d6d620dd666d200777e800089889899199199a9919810199819981
000008000010000002000000080000000000000002000000000000000d66d2120d60d2120d6d6212000dd2127ee7898008811118918911999918911118818891
00800100000802000000000002100010002100000000000000000000d0006d200d006d20d0066d20d6d06d20e00e780008810008881881891008811018818810
0002000000000000001008000000822001882100201080000000000000660d00d066d0000060d0000066d0000e7e000088101008881888881008810018818810
000000000000000000000000000000000021100000000010000000000000d000000d0000000d00000ddd00000007ee0008100000800188810000810000810801
__label__
55555555555555555151551505555550515155155555555555555555555555550555555055555555555555550555555055555555555555555555555555555555
11515551155555511151515515515155115151551555555115555551155555511155515115555551155555511155515115555551155555511555555111515551
55111555551115155511555555555511551155555511151555111515551115155515155555111515551115155515155555111515551115155511151555111555
55511155555511115555555555115151555555555555111155551111555511111551515155551111555511111551515155551111555511115555111155511155
55515151555555511155111115551151115511115555555155555551555555511155511155555551555555511155511155555551555555515555555155515151
11551511115511550111151111111555011115111155115511551155115511551515151111551155115511551515151111551155115511551155115511551511
55111515115515550115110015115511011511001155155511551555115515551111151111551555115515551111151111551555115515551155155555111515
15555155151111110001110001111510000111001511111115111111151111110151111015111111151111110151111015111111151111111511111115555155
5555555551515515000000000002220000000000515155150cccccc0c77c7ccc0cccccc0c77c7ccc000000005151551505555550555555555555555555555555
155555511151515500000000002211200000000011515155ccc711cccccc777cccc711cccccc777c000000001151515515515155115155511151555111515551
5511151555115555000000000021112000000000551155551c7cc1cc1ccccc7c1c7cc1cc1ccccc7c000000005511555555555511551115555511155555111555
5555111155555555000000000221112000000000555555551ccccc1c1ccccccc1ccccc1c1ccccccc000000005555555555115151555111555551115555511155
555555511155111100000000022222200000000011551111c1cccc1cc1cccc1cc1cccc1cc1cccc1c000000001155111115551151555151515551515155515151
115511550111151100000000022222200000000001111511c11cc11cc11cc11cc11cc11cc11cc11c000000000111151111111555115515111155151111551511
1155155501151100000000002222220000000000011511000ccc11ccccc11cc00ccc11ccccc11cc0000000000115110015115511551115155511151555111515
15111111000111000000000000500500000000000001110001ccccc001ccc11001ccccc001ccc110000000000001110001111510155551551555515515555155
05555550055555500000000005555550000000000000000000000000000000000cccccc00cccccc0000000000000000005555550055555500555555055555555
1551515511555151000000001155515100000000000000000000000000000000ccc711ccccc711cc000000000000000011555151115551511551515515555551
55555511551515550000000055151555000000000000000000000000000000001c7cc1cc1c7cc1cc000000000000000055151555551515555555551155111515
55115151155151510000000015515151000000000000000000000000000000001ccccc1c1ccccc1c000000000000000015515151155151515511515155551111
1555115111555111000000001155511100000000000000000000000000000000c1cccc1cc1cccc1c000000000000000011555111115551111555115155555551
1111155515151511000000001515151100000000000000000000000000000000c11cc11cc11cc11c000000000000000015151511151515111111155511551155
15115511111115110000000011111511000000000000000000000000000000000ccc11cc0ccc11cc000000000000000011111511111115111511551111551555
011115100151111000000000015111100000000000000000000000000000000001ccccc001ccccc0000000000000000001511110015111100111151015111111
55555555055555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005151551555555555
11515551155151550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001151515515555551
55111555555555110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005511555555111515
55511155551151510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555555555551111
55515151155511510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001155111155555551
11551511111115550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111151111551155
55111515151155110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000115110011551555
15555155011115100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001110015111111
5555555551515515055555500000000000000000000000000000000000000000000000000000000000000000000000000cccccc0000000000000000005555550
155555511151515515515155000000000000000000000000000000000000000000000000000000000000000000000000ccc711cc000000000000000011555151
5511151555115555555555110000000000000000000000000000777077707770707000000770777000000000000000001c7cc1cc000000000000000055151555
5555111155555555551151510000000000000000000000000000717171710711717100007071711100000000000000001ccccc1c000000000000000015515151
555555511155111115551151000000000000000000000000000077717771071077710000717177000000000000000000c1cccc1c000000000000000011555111
115511550111151111111555000000000000000000000000000071117171071071710000717171100000000000000000c11cc11c000000000000000015151511
1155155501151100151155110000000000000000000000000000710071710710717100007701710000000000000000000ccc11cc000000000000000011111511
15111111000111000111151000000000000000000000000000000100010100100101000001100100000000000000000001ccccc0000000000000000001511110
55555555055555500555555000000000000000000000000001017771010077777a007710107117710000000000000000000000000cccccc00000000055555555
1555555115515155115551510000000000000000000000000111a771110aaaa77100771100aa17a1000000000000000000000000ccc711cc0000000011515551
551115155555551155151555000000000000000000000000110177711007711110007710017717710000000000000000000000001c7cc1cc0000000055111555
5555111155115151155151510000000000000000000000001011a7a110aaa10000107a7110aa17a10000000000000000000000001ccccc1c0000000055511155
555555511555115111555111000000000000000000000000001aaaaa00aa11101100aaa7107a1a71000000000000000000000000c1cccc1c0000000055515151
115511551111155515151511000000000000000000000000001aa1aa00aa11111000aaaa11aa1aa1000000000000000000000000c11cc11c0000000011551511
1155155515115511111115110000000000000000000000001019a09a00aa101000109aaa10aa1aa10000000000000000000000000ccc11cc0000000055111515
151111110111151001511110000000000000000000000000100990a9109a1000010999aa919a1a9100000000000000000000000001ccccc00000000015555155
55555555055555500555555000000000000000000000000000991099119910001109991999991991000000000000000000000000000000000000000055555555
15555551115551511551515500000000000000000000000000991099919911111109911999911991000000000000000000000000000000000000000015555551
55111515551515555555551100000000000000000000000000899999919919aa1009910199910991000000000000000000000000000000000000000055111515
555511111551515155115151000000000000000000000000089889899199199a9919810199819981000000000000000000000000000000000000000055551111
55555551115551111555115100000000000000000000000008811118918911999918911118818891000000000000000000000000000000000000000055555551
11551155151515111111155500000000000000000000000008810008881881891008811018818810000000000000000000000000000000000000000011551155
11551555111115111511551100000000000000000000000088101008881888881008810018818810000000000000000000000000000000000000000011551555
15111111015111100111151000000000000000000000000008100000800188810000810000810801000000000000000000000000000000000000000015111111
05555550055555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055555555
15515155155151550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011515551
5555551155555511000000000000000000000000000000000000bb00bbb0bbb00bb00000bbb00000000000000000000000000000000000000000000055111555
5511515155115151000000000000000000000000000000000000b0b0b000bbb0b0b00000b0000000000000000000000000000000000000000000000055511155
1555115115551151000000000000000000000000000000000000b0b0bb00b0b0b0b00000bbb00000000000000000000000000000000000000000000055515151
1111155511111555000000000000000000000000000000000000b0b0b000b0b0b0b0000000b00000000000000000000000000000000000000000000011551511
1511551115115511000000000000000000000000000000000000bbb0bbb0b0b0bb000000bbb00000000000000000000000000000000000000000000055111515
01111510011115100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015555155
55555555055555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cccccc055555555
1151555111555151000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ccc711cc15555551
55111555551515550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c7cc1cc55111515
55511155155151510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ccccc1c55551111
5551515111555111000000000000000000000000000000666660006666600000066600660606066600000000000000000000000000000000c1cccc1c55555551
1155151115151511000000000000000000000000000006660066066006660000066606060606060000000000000000000000000000000000c11cc11c11551155
55111515111115110000000000000000000000000000066000660660006600000606060606060660000000000000000000000000000000000ccc11cc11551555
155551550151111000000000000000000000000000000666006606600666000006060606066606000000000000000000000000000000000001ccccc015111111
05555550000000000000000000000000000000000000006666600066666000000606066000600666000000000000000000000000000000000000000055555555
11555151000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011515551
55151555000000000000000000000000000000000000006666600000066600000666060606660666000000000000000000000000000000000000000055111555
15515151000000000000000000000000000000000000066000660000000600000060060606660606000000000000000000000000000000000000000055511155
11555111000000000000000000000000000000000000066060660000006000000060060606060666000000000000000000000000000000000000000055515151
15151511000000000000000000000000000000000000066000660000060000000060060606060600000000000000000000000000000000000000000011551511
11111511000000000000000000000000000000000000006666600000066600000660006606060600000000000000000000000000000000000000000055111515
01511110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015555155
c77c7ccc000000000000000000000000000000000000006666600000060600000666066606660666000000000000000000000000000000000000000055555555
cccc777c000000000000000000000000000000000000066060660000060600000600006006060600000000000000000000000000000000000000000015555551
1ccccc7c000000000000000000000000000000000000066606660000006000000660006006600660000000000000000000000000000007000000000055111515
1ccccccc00000000000000000000000000000000000006606066000006060000060000600606060000000000000000000000000000700a000000000055551111
c1cccc1c00000000000000000000000000000000000000666660000006060000060006660606066600000000000000000000000000a990000000000055555551
c11cc11c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009889000000000011551155
ccc11cc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d66ddd00000000011551555
01ccc110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000015111111
00000000c77c7ccc00000000c77c7ccc0cccccc000000000000000000000000000000000000000000000000000000000dddddddddddddddddddddddd05555550
00000000cccc777c00000000cccc777cccc711cc000000000000000000000000000000000000000000000000000000000dddddddddddddddddddddd011555151
000000001ccccc7c000000001ccccc7c1c7cc1cc0000000000000000000000000000000000000000000000000000000001111111111111111111111055151555
000000001ccccccc000000001ccccccc1ccccc1c00000000000000000000000000000000000000000000000000000000011ddd111111111111ddd11015515151
00000000c1cccc1c00000000c1cccc1cc1cccc1c0000000000000000000000000000000000000000000000000000000001ddddd1dd1dd1dd1ddddd1011555111
03030030c11cc11c00000000c11cc11cc11cc11c0000000000000000000000000000000000000000000000000000000001111111ddd1d1dd1111111015151511
30033033ccc11cc000000000ccc11cc00ccc11cc0000000000000000000000000000000000000000000000000000000001d1d1d1dddd11dd1d1d1d1011111511
3033330301ccc1100000000001ccc11001ccccc00000000000000000000000000000000000000000000000000000000001111111111111111111111001511110
055555500cccccc0000000000cccccc0c77c7ccc0cccccc0c77c7ccc00000000000000000000000000000000dddddddd01d1dddddd1d1dddd1dddd1005555550
11555151ccc711cc00000000ccc711cccccc777cccc711cccccc777c000000000000000000000000000000000dddddd001d1dddddd1dd11dd1dddd1011555151
551515551c7cc1cc000000001c7cc1cc1ccccc7c1c7cc1cc1ccccc7c000000000000000000000000000000000111111001d1dddddd1dddd1d1dddd1055151555
155151511ccccc1c000000001ccccc1c1ccccccc1ccccc1c1ccccccc00000000000000000000000000000000011dd11001111111111111111111111015515151
11555111c1cccc1c00000000c1cccc1cc1cccc1cc1cccc1cc1cccc1c0000000000000000000000000000000001dddd101ddddd1dddddd1dddddd1dd111555111
15151511c11cc11c00000000c11cc11cc11cc11cc11cc11cc11cc11c00000000000000000000000000000000011111101ddddd1dddddd1dddddd1dd115151511
111115110ccc11cc000000000ccc11ccccc11cc00ccc11ccccc11cc00000000000000000000000000000000001dddd101ddddd1dddddd1dddddd1dd111111511
0151111001ccccc00000000001ccccc001ccc11001ccccc001ccc110000000000000000000000000000000000111111011111111111111111111111101511110
05555550c77c7ccc0cccccc0c77c7ccc0cccccc0c77c7ccc0cccccc00000000000000000c77c7cccdddddddd01d1dddddd1ddddddd1dddddd1dddd1005555550
15515155cccc777cccc711cccccc777cccc711cccccc777cccc711cc0000000000000000cccc777c0dddddd001d1dddddd1ddddddd1dddddd1dddd1011555151
555555111ccccc7c1c7cc1cc1ccccc7c1c7cc1cc1ccccc7c1c7cc1cc00000000000000001ccccc7c0111111001d1dddddd1ddddddd1dddddd1dddd1055151555
551151511ccccccc1ccccc1c1ccccccc1ccccc1c1ccccccc1ccccc1c00000000000000001ccccccc011dd1100111111111111111111111111111111015515151
15551151c1cccc1cc1cccc1cc1cccc1cc1cccc1cc1cccc1cc1cccc1c0000000000000000c1cccc1c01dddd101ddddd1dddddd1ddddddd1dddddd1dd111555111
11111555c11cc11cc11cc11cc11cc11cc11cc11cc11cc11cc11cc11c0000000000000000c11cc11c011111101ddddd1ddddd11ddddddd1dddddd1dd115151511
15115511ccc11cc00ccc11ccccc11cc00ccc11ccccc11cc00ccc11cc0000000000000000ccc11cc001dddd101ddddd1dddd1d1ddddddd11ddddd1dd111111511
0111151001ccc11001ccccc001ccc11001ccccc001ccc11001ccccc0000000000000000001ccc110011111101111111111111111111111111111111101511110
5555555505555550c77c7ccc0cccccc0c77c7ccc00000000c77c7ccc0cccccc0c77c7cccdddddddd01d1dddddd1d1ddddd1ddddddd1dddddd1dddd1005555550
1151555111555151cccc777cccc711cccccc777c00000000cccc777cccc711cccccc777c0dddddd001d1dddddd1dd11ddd1ddddddd1dddddd1dddd1011555151
55111555551515551ccccc7c1c7cc1cc1ccccc7c000000001ccccc7c1c7cc1cc1ccccc7c0111111001d1dddddd1dddd1dd1ddddddd1dddddd1dddd1055151555
55511155155151511ccccccc1ccccc1c1ccccccc000000001ccccccc1ccccc1c1ccccccc011dd110011111111111111111111111111111111111111015515151
5551515111555111c1cccc1cc1cccc1cc1cccc1c00000000c1cccc1cc1cccc1cc1cccc1c01dddd101ddddd1dddddd1ddddddd1ddddddd1dddddd1dd111555111
1155151115151511c11cc11cc11cc11cc11cc11c00000000c11cc11cc11cc11cc11cc11c011111101ddddd1dddddd1ddddddd1ddddddd1dddddd1dd115151511
5511151511111511ccc11cc00ccc11ccccc11cc000303003ccc11cc00ccc11ccccc11cc001dddd101ddddd1dddddd1ddddddd11dddddd1dddddd1dd111111511
155551550151111001ccc11001ccccc001ccc1103033003301ccc11001ccccc001ccc11001111110111111111111111111111111111111111111111101511110
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
15555551115155511555555115555551115155511151555115555551115155511151555115555551115155511555555111515551155555511151555115555551
55111515551115555511151555111515551115555511155555111515551115555511155555111515551115555511151555111555551115155511155555111515
55551111555111555555111155551111555111555551115555551111555111555551115555551111555111555555111155511155555511115551115555551111
55555551555151515555555155555551555151515551515155555551555151515551515155555551555151515555555155515151555555515551515155555551
11551155115515111155115511551155115515111155151111551155115515111155151111551155115515111155115511551511115511551155151111551155
11551555551115151155155511551555551115155511151511551555551115155511151511551555551115151155155555111515115515555511151511551555
15111111155551551511111115111111155551551555515515111111155551551555515515111111155551551511111115555155151111111555515515111111

__gff__
0001010101030003100300000101101003030303030100030303000001010100030303030300000303000000000300010303030303000303030303030303030300000000000000000000000000000000000011010101131300000010000000001000000010000000101010000003030810101010101000000000000000030308
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010001000000000000000000000000000100000000000000000000000000000001000000000000010101000000303030300000000000000000000000003030303
__map__
2121222222222222222121212121212121312121212121212121212121322121212121212121212121212121212121212222222222223816161616161616162121322121212121212121212121212121212121212121212121212121212121211411111111111111121111111111111105050505050505050505050505050505
2116161616161616161616161616162113161616161637213816161616372110380000000000000000000000000000141300000000000000000060000000001014000000000000141700000000000014140000000000000000000000000000142400000000000000000000000000000005002121002100002200212100000005
0e161616161616161616161616161621331616161616161616161616161637200e0000000000000000000000000000242300000000000000000000000000002024000000000000343400000000175b24240000000000000000000000600000242400000000560000005600000000000005002100002121002200210021000005
2116161616161616161616161616162108000000000000000000000000000020000000000000000000000000000000242300000000000000000064000000002024000000000000000000000000001724240060000000600000000000000000242400000000000000000000000000000005002121002100212200210021000005
216400000000000000000000006400210000520000006f006f6f000000000020140303030303030303030303030303242300000000000100000001000000002024000000000000e00000000000000024240000000000000000000000000000242400000000000000000000000000005205002100002100002200210021000005
2156560000000064000000005656002113271111111111111111111111280020240000000000000000000000000000242300000000000000000000000000602024000000000000171400000000000024240000000000000000000000000000242400000000000000000000000056561405002121002100002200212100000005
21000000150056565600150000000021230000007f0018000000180000000020240100640000000000000064000000242300000000000000000000006f00002024000000010000242400000100000024240000000000000000000000006000242400005600000056000000560000002405000000000000000000000000000005
210000003506060606063500000000242300000000000000000000000000002024000000000000000000000000000024230000010000000000000000180000202400006f6f6f6f34346f6f6f6f000024240000000000000000000114000000242400006f6f6f6f6f6f6f6f6f6f6f6f2421210000212100210000002100002200
2100640016161616161616000000002423006f00181616161616161616161620340000005600006417000000570000340800000000000000150000007f00002024010027111111111111111128000124240000000000000014000024000000342400003721212121212121212121212421002100210000212100212100220021
2156560064000015000000006400002423001818141616166f1616166f1616202857575614565756245657561403032700000000000000002500000000000020240000000000001417000000000000242403030303140c0d240c0d24000000273400002500000025000000240000002421002100212100210021002100220021
210000005656002500640000565600242300007f3416166f186f166f186f1620380000002400000024000000240000371300005200000000250000000000002024000000000000242400000000000024240000000024000024000024001400371111111128000025000000240000002421002100210000210021002100220021
21000000000000350056560000000024231800002711111111111111111128203800000024000000240000002400003723030303000000152500000000600020243c3d000000003434000000003c3d242400000000240c0d240c0d24002400370e00002500000025000000240000002421210000212100210000002100002200
2106060606060615060606060606062123000000372121380000003721213830380000002400000024000000240303372300000000000025250000000000002024000000010000000000000100000024340000140024000024000024002400370000002500000025640000240000002405000000000000000000000000000005
2116161616161625161616161616160823000000000000000000000000000000380000002400000024000000240000082300000000000025256000000000000e240000000000000000000000000000240801002400240c0d240c0d240024000e14005625560056255600002400000024050000000000005b0000000000000005
2116521616161635161616161616160033000018000000001800000000000000386f6f6f346f6f6f346f6f6f34520000336f6f6f6f6f6f6f6f6f6f6f6f6f3400346f6f6f6f6f3c11113d6f6f6f6f6f34000000346f347000340070346f340000346f6f6f6f6f6f6f6f6f6f3427122834050000000000006f0000000000000005
1111111111111111111111111111111121121212121212121212122121212121111111121111121112111212111211111212121212111212121212121212121211111111111111111111111111111111111111121111121112111212111211112121212121212121212121212121212121222121212121212121212121210121
23000025001a000b00000a002500002021212121212121212121212121212121212121212121212121212121212121212121212121212121212131212132212121312121212122212121212122322121212122212121212121212121212121212121212121212121212121212121212121212121322121212221213138141614
23000025000a001a00000b002500002013161616161616161616161616161610213222322231381616161616161616372132223222313816161616161616163713162416161616161616161616161610143434341616161616161616240000141316161616005600000000000000005608161616161616161616161616241624
23000025000b000a00001a002500002023161616161616161616161616161630213221213816161616161616161616373816161616161616161616161616163733003400000000000000000000750020245256750000000000000000340052242316161600005600007500000000565600165b16161616161616161616340124
23000025002b001b00000a00250000202316161616161616161616161616160e080016001616000016161616161616373800000000000000000000000000000e080000000000000000000000003c3d20343c113d5600000000000000000017242316160000003c1111121111280056141403030d0000000000000000000e0024
23000025001a000b00001a00250000202300000000000000000000000000000000165b000000000100001600001616373800000075000000000000000000000000005b00000000000000000000000020070000000000002900000000000000242316600000002500000000373856563424000000000000000000000000000124
23000035000b000b00002b00350000202300000000000000000000000002031028030d00000000006400000016001637386f3c11113d6f6f00000000003c1111133c1111113d00176f6f6f000000002007000000001c1e1d1d1e00000018002423000c0d000025006000003c1111121124000000000000000000000000010024
23000014030303030303030314000020230000000000000000000000002500203800000000000000575600010000003721382121212137380000003c3d000037232711121111111111112800000203200700000000000000000000000000002423016f6f6f002500000000250000001024000000000000161600000000000024
23000024001a001a00001b0024000020230000000017006400001700002500203800000c0d00000000000000000000372121212121212138000056000000003723000000000000000000000000251620072664000000140014002e000000753433271111280035000000003500000020240016160000000c0d00001616000024
23000024000a001b00000b0024000020230000003c1111111111113d002500203800000000000000000000000000003721212121212121383c3d0000000000372300007500000000000000000025162007523c3d6f003452341c1e000000570f16161614271112111111113d5656562034000c0d000000000000000c0d000034
23010024001a002b00000b0024000120230000002500000000000025002500203800000100000064000064000000003721212132387f7f7f00000000000000372300003c3d000c030d000c03030303200707070707003c113d000000000000001616162400000000007f7f256000002007000000000000000000000000000005
23000024002b001a00001a002400002023000000250000000000002500250020380000000000565700005718000100373800007f7f000000000000000000003723006f6f6f6f6f6f6f6f6f6f6f6f6f2007262626360000000000000000000014130116240000000000600025000000203a26001c1d1d1e00262600001c1e0007
23000024001b001a00002b00240000202311113d25000000000000250025172038160c0d00000000000000000000000e08000000000000000c0304000000003723002711111111111211111111112820050726000000000000002f00007500242316162416000000000000250015152005262626260000000000260026262605
23000124000b002b00000a00240100303300002525000000006400250025252038161600001600000000000016000000005b00000000000000002400006400372300000000003400000000000000003007260000000000000000000000140024231616341616160000006415152525203b266f6f000000d00000000000266f07
23000024002b000b00000b0024000000080000252500002711111128002525203816161616161616001600161616012711280000000c030d00002400565656373300001700000000000075000000000e0800000000070507000026266f346f3423161616161616160015152525252520076f05076f261c1c1e001c1d1e6f0705
332929342e2a292c292e2b293429000000005b35350027212121212128353530386f6f6f6f6f6f6f6f6f6f6f6f6f6f3711111111286f6f6f6f6f346f6f6f6f371112111111111111286f3c3d6f00000000295b0705070505702605070507050733165b1616161616166f6f6f6f6f6f303b050705056f6f6f6f6f6f6f6f050707
310137213907073b3a073a3e2121212122312222322121212132223122322222212122222222222222212121212121212121222222222222222121212121212121212121312121212121223221393a3b3a3a3a3b3a3b3a3b053b3a3b3a3b3a3b111111111111111111121111111111123b3a3b3b3a3b3a3b3a3b3a3b3a3b3a3b
__sfx__
060400000c0000b000090000500000000000000000000000000000c0000c0000d0000d0000d0000d0000e0000e0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0001000010000
000100000a4301943025430194300f43022430254301e430134300e430124301e430284301f430174300f4301e430244301d430134300c430154302b4302443019430124301243020430234301f4301943012430
00010000204001e4001b4001a4001840016400154001540014400134001340014400144001640017400184001b4001d4001f40022400244002440024400244002440024400254002540025400264002640027400
000100001c25020250252502b2501a2502f25021250282502f2502a2502c25022250302502b250212501d2001d2001d2001c2001e2002020022200242002620027200292002b2002d2002e200312003220034200
900300000b20007200032000320503200002000020000200002000020000200002000020000200002000020034200362000020035200322000020000200332000020000200002000020000200002000020000200
960300001201112010003011300012010120101620012200003000030000300003000030000300003000030034300363000030035300323000030000300333000030000300003000030000300003000030000300
000a000015500115000c5000950005500035000350003500035000350003500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
4e0a00000220004200072000c20010200122000c20007200032002d20000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
4e0a00000223004230072300c23010230122200c21007210032102d20000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
000a000015550115500c5500955005550035500355003540035300352003510005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000100000f130111301213013130141301513016120171201812019110191101a1101b1101b1101d1001d1001d1001d1001c0001e0002000022000240002600027000290002b0002d0002e000310003200034000
000200000891008910099100a9100b9200b9200c9200d9200e93010940109400f9300f9200d9100c9100c9000c900009000090000900009000090000900009000090000900009000090000900009000090000900
900300000b23007220032100321503200002000020000200002000020000200002000020000200002000020034200362000020035200322000020000200332000020000200002000020000200002000020000200
060400000c0500b050090400504000030000200000000000000000c0000c0000d0000d0000d0000d0000e0000e0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0001000010000
480400000f1130e1100b11009113021030010309103031030110300103001031f1031b1031710314103111030d103091030610303103001030010328103221032d10318103121030010300103001030010300103
140200002421329223232031b233222231a2031e213172131d203172131020316213102030a2130f2030920305203092130a20301203272032820328203222032d20318203122030020300203002030020300203
000400001e013230132702327023240131e0131901315013120130f0130d0131f0031b0031700314003110030d003090030600303003000030000328003220032d00318003120030000300003000030000300003
00020000095330d5331053312523145231552317513175131751317513175131d5031e5031750314503115030d503095030650303503005030050328503225032d50318503125030050300503005030050300503
00020000091300d1301013012120141201512017110171101711017110171101d1001e1001710014100111000d100091000610003100001000010028100221002d10018100121000010000100001000010000100
90040000222201e2301925015250102300c21007210032101820014200122000e2000d20000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
1014000015020110300e040100400c0400b0400b0400b0400b0300b0200b010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
040300001e0341703016030110200d0200a02007010040100201000014121040e1040d10400104001040010400104001040010400104001040010400104001040010400104001040010400104001040010400104
500200001e9101d9101d9101c9101b9201a920189301693014920119200f9100d9100a91009910019000c9000c900009000090000900009000090000900009000090000900009000090000900009000090000900
1004000018531125310f5310c5410b5410c5410f541145311c5212152100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011c18000d0200d020000000e0200e020000001002010020000000d0200d020000001202012020000000e0200e020000001002010020000000d0200d025000000000000000000000000000000000000000000000
491c18000d0200d0250d0000d00506000060200e0200e0200e0201002010020100200d0200d02510000100000d0000602009020090250900509020090250d000090000900009000090000b0000b0000b0000b000
0d1c18001e0201e0201c0201e0201e0201e0201e0201e0201e0201e0201e0201e0201e0201e0201a0201702017020170201702017020170201702017020170200000000000000000000000000000000000000000
0d1c18001a0201a0201c0201902019020190201902019020190201902019020190200e0200e0200e0200e0200e0200e0200d0200d0200d0200d0200d0250d0000000000000000000000000000000000000000000
0d1c18001e0201e020230202502025020250202502025020250202502025020250201e0201e0201a0201702017020170201702017020170201702017020170200000000000000000000000000000000000000000
491c18000e0200e0250d0000d0200d025060000d0200d0250e0201002010020100201202012025100000d0200d025060000e0200e025120000b0200b0250d000090000900009000090000b0000b0000b0000b000
011c1b000d0200d020000000e0200e020000001002010020000000d0200d020000001202012020000000e0200e020000001002010020000000d0200d020000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
491c18000b0200b0250b00012020120000d0240b0200b0250b00012022120000d0240b0200b0250b00012020120000d0240b0200b0250b00012020120000d0200000000000000000000000000000000000000000
491c00180b0200b0250b00012020120000d0240b0200b0250b00012022120000d0240b0200b0250b00012020120000d0240b0200b0250b00012020120000d0200000000000000000000000000000000000000000
491c18000b0200b0250b0001002012000090240d0200d0250b0001202212000090240b0200b0250b00010020120000d0240b0200b0250b00012000120000d0200000000000000000000000000000000000000000
491c18000b0200b0250b00012020120000d0240b0200b0250b00012022120000d0240b0200b0250b00012020120000d0240b0200b0250b00012000120000d0000000000000000000000000000000000000000000
551c18001c0001c0001c0001c0201c0201a0201c0201c0201c0201c0201e0001e0001c0001c0001f0001a0001a0001500015000150001e00017000170001e0000000000000000000000000000000000000000000
551c18001c0201c0201f0001a0201a0201f00015020150201e00017020170201e00017000170001f0001a0001a0001500015000150001e00017000170001e0000000000000000000000000000000000000000000
1538180010014100101001010015100051c00515024150201502015025150001500512014120101201012015150051f0050d0240d0200d0200d0251e0051e0050000000000000000000000000000000000000000
1538180010020100251000012020120251000513020130251e00012020120251e0050b0200b0252300010020100251e00013020130251200009020090251e0050000000000000000000000000000000000000000
481c00000b0000b0050b00012000120000d0040b0000b0050b00012002120000d0040b0000b0050b00012000120000d0040b0000b0050b00012000120000d0000000000000000000000000000000000000000000
151c180010024100201002010020100251c00512024120201202012020120251e00513024130201302013020130251f00512024120201202012020120251e0050000000000000000000000000000000000000000
0d1c18002502425020250202502025025250052602426020260202602026025260002802428020280202802028025280002602426020260202602026025260000000000000000000000000000000000000000000
29180000110201102011020110000c0200c0200c0201300011020110200c0200c0200f0200f020130201302011020110000c0200c0000f0201102014020140200c0200c0200f0200f02016020160201b0201b020
29180000110201102011020110000f0200f0200f02013000130201302014020140200f0200f0200f0200f020110201102011020110000f0200f02014020140201602216022160221602216022160221602216022
0118000024720247202472024720277202772027720277202b7202b7202b7202b7202972029720297202972027720277202772027720247202472024720247202a720267202472027720297202c7202b7202b720
0118000024720247202472024720277202772027720277201f7201f7201f7201f7201b7201b7201b7201b72020720207202072020720227202272022720227201f7201d7201f7201d7201f7201d7201f7201f720
111800001802018020180201802014020140201302013020180201b020180201802014020140201302013020110201102011020110200f0200f02014020140201302013020130201302013020130201302013020
010c000018020180201802018020180201802018020180201402014020140201402013020130201300013000135201352013000130000f5200f5200f0000f0001352013520135201352013520135201352013520
010c00001802018020180201802018020180201802018020140201402014020140201302013020130201302018020180201b0201b020180201802018020180201402014020140201402013020130201302013020
010c00001f12020100201200010014120001001f1200010020120001001f1200010014120141201b100161001f1201b10220120191001412019100131201b1051d1221d1221d1221d12220122201222012220122
010c00001f22020200202200020014220002001f2200020020220002001f22000200142200020014020160301b0421b042230001900018040180401b0001b0051a0401a0401a0401a0401a0401a0401a0401a040
011800001353013530135301353018530185301853018530165200a500135200750014520145201452014500145201452018520185201a5201a5201b5201b5201852018500145201450016520165201652016520
01180000135301353013530135301b5301b5301b5301b5301a5200a500165200750018520185201852014500185201852018520185001b5201b5201b5201b5001f5201f5201f520135001d5201d5201d5201d500
481c00000b0000b0050b00012000120000d0040b0000b0050b00012002120000d0040b0000b0050b00012000120000d0040b0000b0050b00012000120000d0000000000000000000000000000000000000000000
ae2800000200002000020000200002000020000200002000040000400004000040000400004000040000400007000070000700007000070000700007000070000500005000050000500005000050000500005000
a02800000e2001320016200152001520015200152001520010200132001620018200182001820018200182001a200182001620015200152001520015200152001620018200162001520015200152001520015200
__music__
00 274b4c44
00 296a4344
01 2d284344
00 2e284344
00 2a694c44
00 1e204c44
00 1e214c44
00 1e224c44
00 1e214c44
02 1f424344
02 5f424344

