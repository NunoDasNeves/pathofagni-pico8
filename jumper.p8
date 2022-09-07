pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- 'jumper' demo build #2
-- by nuno

#include util.lua

-- 
dbg = false
dbgstr = ''

-- disable btnp repeating
poke(0x5f5c, 255)

room = {
	i = 0,
	x = 0,
	y = 0,
	sz = 16*8,
	old = nil, -- for restore
	fcnt = 0,
	num_bads = 0, -- for unlock
	max_i = 8*3 - 1
}

-- one lantern per room
-- for now
-- room index+1 -> lit
lantern = {}
curr_lantern = 5

function get_curr_lantern()
	return lantern[curr_lantern]
end

function init_lantern()
	-- todo this properly
	for i=0,room.max_i do
		local l = {}
		local r = get_room_xy(i)
		local rmapx = r.x \ 8
		local rmapy = r.y \ 8
		local rmapr=rmapx+15
		local rmapb=rmapy+15
		for y=rmapy,rmapb do
			for x=rmapx,rmapr do
				local val = mget(x,y)
				if val == 82 then
					l.x = x*8
					l.y = y*8
					l.lit = false
				end
			end
		end
		add(lantern, l)
	end
	-- initial spawn
	lantern[curr_lantern].lit = true
end

function restore_room()
	if room.old == nil then
		return
	end
	for t in all(room.old) do
		mset(t.x,t.y,t.val)
	end
end

function get_room_i(x,y)
	x \= room.sz
	y \= room.sz
	return x % 8 + y * 8
end

function get_room_xy(i)
	return {
		x = (i % 8) * room.sz,
		y = (i \ 8) * room.sz
	}
end

function in_room(x,y)
	if x<room.x or x>room.x+room.sz then
		return false
	end
	if y<room.y or y>room.y+room.sz then
		return false
	end
	return true
end

function move_room(x,y)
	room.i = get_room_i(x,y)
	local r = get_room_xy(room.i)
	room.x = r.x
	room.y = r.y
end

function update_room()
	local oldi = room.i
	local px = p.x + p.w/2
	local py = p.y + p.h/2
	move_room(px,py)
	if oldi != room.i then
		-- give player a little kick through the door
		if p.alive and not p.spawn then
			local oldxy = get_room_xy(oldi)
			local roomxy = get_room_xy(room.i)
			if oldxy.x > roomxy.x then
				p.x -= 12
			elseif oldxy.x < roomxy.x then
				p.x += 12
			end
		end
		camera(room.x, room.y)
		fireball = {}
		restore_room()
		spawn_room()
	end
end

-- spawn thangs in current room
-- save room
function spawn_room()
	local rmapx = room.x \ 8
	local rmapy = room.y \ 8
	local rmapr=rmapx+15
	local rmapb=rmapy+15
	thang = {}
	max_z = 0
	room.old = {}
	room.num_bads = 0
	for y=rmapy,rmapb do
		for x=rmapx,rmapr do
			local val = mget(x,y)
			add(room.old, {x=x,y=y,val=val})
			if fget(val,4) then
				local t = spawn_thang(val,x*8,y*8)
				max_z = max(t.z, max_z)
				mset(x,y,t.replace)
				if t.bad then
					room.num_bads += 1
				end
			end
		end
	end
end

do_fade = true -- fade in
fade_timer = 8

function spawn_p_at_curr_lantern()
	local l = get_curr_lantern()
	spawn_p(l.x,l.y - p_dat.h)
	restore_room()
	spawn_room()
end

function fade_update()
	if fade_timer == 12 then
		spawn_p_at_curr_lantern()	
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
	camera(0,0)
	init_sfx_dat()
	init_thang_dat()
	init_lantern()
	spawn_p_at_curr_lantern()	
end

-->8
-- draw

function draw_thang(t)
	local flp = false
	if not (t.rght == nil) then
		flp = not t.rght
	end
	spr(t.s+t.fr,t.x,t.y,1,1,flp)
end

function draw_shot(t)
	-- tracer
	line(t.x, t.y, t.endx, t.endy, t.trace_color)
	--arrow
	line(t.arrowx, t.arrowy, t.endx, t.endy, t.arrow_color)
end

function draw_shooter(t)
	draw_thang(t)
	if dbg then
		if not t.shooting and t.shleft != nil then
			rectfill(
				t.x + 4 - t.shleft,
				t.y,
				t.x + 4 + t.shright,
				t.y + 8,
				14)
		end
	end
end

function draw_frog(t)
	if t.alive and t.angry then
		pal(11, 8, 0) -- main
		pal(3, 2, 0)  -- shadow
		pal(8, 10, 0) -- eyes
		draw_thang(t)
		pal()
	else
		draw_thang(t)
	end
end

function draw_knight(t)
	local flp = false
	if not (t.rght == nil) then
		flp = not t.rght
	end
	-- draw knight
	spr(t.s + t.fr,
		t.x,
		t.y,
		1,1,flp)
	-- draw sword
	if t.swrd_draw then
		local xfac = flp and -1 or 1
		spr(t.i + t.s_swrd.s + t.swrd_fr,
			t.x + (8 * xfac),
			t.y,
			1,1,flp)
		if dbg and t.swrd_hit then
			local swrd_start_x = t.rght and 8 or -t.swrd_x_off
			local x0 = t.x + swrd_start_x
			local y0 = t.y + t.swrd_y
			local x1 = x0 + t.swrd_w
			local y1 = y0 + t.swrd_h
			rectfill(x0,y0,x1,y1,8)
		end
	end
end

function draw_smol_thang(f)
	local sp = f.s + f.fr
	local sx = (f.sfr % 2) * 4
	local sy = (f.sfr \ 2) * 4
	sspr(
		(sp % 16) * 8 + sx,
		(sp \ 16) * 8 + sy,
		4,4,
  		f.x,
   		f.y,
   		4,4,
    	f.xflip,
    	f.yflip)
end

function draw_fade(s)
	fillp(s)
	rectfill(room.x,room.y,room.x+16*8 - 1,room.y+16*8 - 1,1)
end

function none()
	local rmapx = room.x \ 8
	local rmapy = room.y \ 8
	local rmapr=rmapx+15
	local rmapb=rmapy+15
	for y=rmapy,rmapb do
		for x=rmapx,rmapr do
			
			spr(s, x * 8, y * 8)
		end
	end
end

function _draw()
	cls(0)

	map(0,0,0,0,128,64)

 -- draw one layer at a time!
	for z=max_z,0,-1 do
		for t in all(thang) do
	  if t.z == z then
			 t:draw()
			end
		end
	end

	spr(p.s + p.fr,
	    p.x,
	    p.y,
	    1, 1,
	    not p.rght)

	for f in all(fireball) do
		f:draw()
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
		local x = room.x + 8
		print(dbgstr,x,room.y,7)
	end
end
-->8
--thang - entity/actor

thang = {}

-- number of layers to draw
max_z = 0

function init_thang_dat()
	local iceblock = {
		init = init_iceblock,
		update = update_iceblock,
		burn = burn_iceblock
	}
thang_dat = {
	[82] = { -- lantern
		lit = false,
		init = init_lantern_thang,
		update = update_lantern,
		burn = burn_lantern,
		replace = 82 + 3,
		z = 1,
		stops_projs = false
	},
	[14] = { -- door - close then open when enemies are dead
		update = update_door,
		draw = no_thang,
		open = true,
		w = 8,
		h = 16,
		replace = 14,
		s_open = 14,
		s_top = 15,
		s_bot = 31,
		stops_projs = false
	},
	[8] = { -- door - only close, never open
		update = update_door_only_close,
		draw = no_thang,
		open = true,
		w = 8,
		h = 16,
		replace = 8,
		s_open = 8,
		s_top = 9,
		s_bot = 25,
		stops_projs = false
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
		cx = 0,
		cy = 0,
		cw = 7,
		ch = 6,
		hx = 0,
		hy = 0,
		hw = 7,
		hh = 6,
	},
	[100] = { -- thrower
		update = update_thrower,
		burn = burn_bad,
		bad = true,
		air = true,
		g = 0.3,
		max_vy = 4,
		w = 8,
		h = 8,
		hp = 3,
		throwing = false,
		goingrght = true, -- going to go after throwing
		burning = false,
		-- coll dimensions
		-- todo same as player..
		ftw = 0.99,
		ftx = 3,
		ch = 6.99,
		cw = 5.99,
		cx = 1,
		cy = 1,
		-- hurt box - bigger than player, same as collision box
		hx = 1,
		hy = 1,
		hw = 5.99,
		hh = 6.99,
		shcount = 0, -- throw stuff at player
		range = 8*6, -- only throw at player in this range
		s_wlk = {s=0, f=2},
		s_sh = {s=2, f=1},
		s_burn = {s=3, f=1},
		s_die = {s=4, f=3},
	},
	[107] = { -- icepick
		init = init_icepick,
		update = update_icepick,
		burn = kill_icepick,
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
		hx = 0,
		hy = 0,
		hw = 4,
		hh = 4,
	},
	[112] = { -- frog
		update = update_frog,
		burn = burn_frog,
		draw = draw_frog,
		bad = true,
		air = true,
		g = 0.3,
		max_vy = 4,
		jbig_vy = -3.5,
		jbig_vx = 1.2,
		jsmol_vy = -2.5,
		jsmol_vx = 1.5,
		jtiny_vy = -1.0,
		w = 8,
		h = 8,
		hp = 2,
		burning = false,
		angry = false,
		croak = false,
		bounced = false,
		do_smol = true,
		-- coll dimensions
		ftw = 0.99,
		ftx = 3,
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
	},
	[192] = { -- knight
		update = update_knight,
		burn = burn_knight,
		draw = draw_knight,
		bad = true,
		w = 8,
		h = 8,
		hp = 5,
		burning = false,
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
		-- coll dimensions, physics
		air = true,
		g = 0.2,
		max_vy = 4,
		jump_vy = -3,
		jump_vx = 1,
		ftw = 0.99,
		ftx = 3,
		ch = 6.99,
		cw = 5.99,
		cx = 1,
		cy = 1,
		hx = 1,
		hy = 1,
		hw = 5.99,
		hh = 6.99,
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
	[117] = { -- shooter
		update = update_shooter,
		burn = burn_bad,
		draw = draw_shooter,
		bad = true,
		air = true,
		g = 0.3,
		max_vy = 4,
		w = 8,
		h = 8,
		hp = 3,
		shooting = false,
		goingrght = true, -- going to go after throwing
		burning = false,
		-- coll dimensions
		-- todo same as player..
		ftw = 0.99,
		ftx = 3,
		ch = 6.99,
		cw = 5.99,
		cx = 1,
		cy = 1,
		-- hurt box - bigger than player, same as collision box
		hx = 1,
		hy = 1,
		hw = 5.99,
		hh = 6.99,
		shcount = 0, -- shoot stuff at player
		s_wlk = {s=0, f=2},
		s_sh = {s=2, f=3},
		s_burn = {s=5, f=1},
		s_die = {s=104 - 117, f=3},
	},
	[123] = { -- shot
		update = update_shot,
		draw = draw_shot,
		stops_projs = false,
	},
	[208] = { -- archer
		update = update_archer,
		burn = burn_bad,
		draw = draw_shooter,
		bad = true,
		air = true,
		g = 0.3,
		max_vy = 4,
		w = 8,
		h = 8,
		hp = 5,
		shooting = false,
		goingrght = true, -- going to go after throwing
		burning = false,
		-- coll dimensions
		-- todo same as player..
		ftw = 0.99,
		ftx = 3,
		ch = 6.99,
		cw = 5.99,
		cx = 1,
		cy = 1,
		-- hurt box - bigger than player, same as collision box
		hx = 1,
		hy = 1,
		hw = 5.99,
		hh = 6.99,
		shcount = 0, -- shoot stuff at player
		s_idle = {s=1, f=2},
		s_wlk = {s=1, f=2},
		s_sh = {s=3, f=3},
		s_burn = {s=12, f=1},
		s_die = {s=13, f=3},
	},
}
end

function no_thang(t)
end

function init_iceblock(t)
	t.replace = t.i
end

function update_door_only_close(t)
	if (t.open) then
		if (not aabb(
			t.x,t.y,t.w,t.h,
			p.x+p.cx,p.y+p.cy,p.cw,p.ch)) then
				t.open = false
				mset(t.x/8,t.y/8,t.s_top)
				mset(t.x/8,(t.y)/8+1,t.s_bot)
		end
	end
end

function update_door(t)
	if (t.open) then
		if (room.num_bads > 0) then
			if (not aabb(
				t.x,t.y,t.w,t.h,
				p.x+p.cx,p.y+p.cy,p.cw,p.ch)) then
					t.open = false
					mset(t.x/8,t.y/8,t.s_top)
					mset(t.x/8,(t.y)/8+1,t.s_bot)
			end
		end
	else
		if (room.num_bads == 0) then
			t.open = true
			mset(t.x/8,t.y/8,t.s_open)
			mset(t.x/8,(t.y)/8+1,0)
		end
	end
end

function update_iceblock(t)
	if (not t.alive) then
		if (loop_anim(t,2,3)) then
			del(thang, t)
		end
	end
end

function burn_iceblock(t)
	if t.alive then
		sound(sfx_dat.ice_break)
		t.s = 88
		t.alive = false
		mset(t.x\8,t.y\8,0)
	end
end

function init_lantern_thang(l)
	l.lit = lantern[room.i+1].lit
	if (l.lit) then
		l.s = l.i + 1
		curr_lantern = room.i+1
	end
end

function init_icepick(t)
	if (p.x < t.x) then
		t.xflip = true
		t.vx = -t.vx
	else
		t.xflip = false
	end
end

function kill_icepick(t)
	if (t.alive) then
		sound(sfx_dat.ice_break)
		t.vx = 0
		t.vy = 0
		t.alive = false
		t.fr = 1
		t.sfr = 0
		t.fcnt = 0
	end
end

function update_icepick(t)
	if (not t.alive) then
		t.y += 0.5
		t.fcnt += 1
		if (t.fcnt & 1 == 0) then
			t.sfr += 1
		end
		if (t.fcnt == 8) then
			del(thang, t)
		end
		return
	end
	-- spin in correct direction
	local xfac = t.xflip and -1 or 1
	-- spin around 'ax'is
	if (t.fcnt > 0 and t.fcnt % 2 == 0) then
		if (t.fcnt == 2) then
			t.x += 2 * xfac
			t.y += 1
		elseif (t.fcnt == 4) then
			t.x -= 1 * xfac
			t.y += 2
		elseif (t.fcnt == 6) then
			t.x -= 2 * xfac
			t.y -= 1
		elseif (t.fcnt == 8) then
			t.x += 1 * xfac
			t.y -= 2
			t.fcnt = 0
		end
		if (t.sfr >= 3) then
			t.sfr = 0
		else
			t.sfr += 1
		end
	end
	t.fcnt += 1
	t.vy += t.g
	t.vy = clamp(t.vy,-t.max_vy,t.max_vy)
	t.x += t.vx
	t.y += t.vy

	if (
			collmap(t.x+3, t.y+2, 1) or
			collmap(t.x+1, t.y+2, 1)) then
		kill_icepick(t)
	end

	if (p.alive and hit_p(t.x,t.y,t.w,t.h)) then
		kill_p()
		kill_icepick(t)
	end
end

function update_thrower(t)
	if do_bad_die(t) then
		return
	end

	if do_bad_burning(t) then
		t.throwing = false
		return
	end

	t.vx = 0

	if t.throwing then
		if p.x < t.x then
			t.rght = false
		else
			t.rght = true
		end
		local xfac = t.rght and 1 or -1

		t.s = t.i + t.s_sh.s
		if play_anim(t, 20, t.s_sh.f) then
			t.throwing = false
			spawn_thang(107,
						t.x - 3 * xfac,
						t.y + 4)
			t.fcnt = 0
			t.fr = 0
		end

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

		if (t.shcount <= 0) then
			if (dist(p.x,p.y,t.x,t.y) <= t.range) then
				t.throwing = true
				t.fcnt = 0
				t.fr = 0
			end
			t.shcount = 30
		else
			t.shcount -= 1
		end
	end

	local phys_result = phys_thang(t)

	if not t.air then
		if phys_result.hit_wall or coll_edge_turn_around(t,t.x,t.y + t.h) != 0 then
			t.rght = not t.rght
			t.goingrght = t.rght
		end
	end

	if check_bad_coll_spikes(t) then
		return
	end
	
	if p.alive and hit_p(t.x,t.y,t.w,t.h) then
		kill_p()
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
	if dir > 0 then
		return (tiles - 1)*8 + (roundup(off,8) - off)
	else
		return (tiles - 1)*8 + (off - rounddown(off,8))
	end
end

function do_boss_die(t)
	if not t.alive then
		t.stops_projs = false
		t.s = t.i + t.s_die.s
		if not t.air then
			if play_anim(t, 10, t.s_die.f) then
				-- get shorter so fireballs don't hit air
				t.h = 3
				t.cy = 4.99
				room.num_bads = 0
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
			room.num_bads -= 1
		end
		return true
	end
	return false
end

function check_bad_coll_spikes(t)
	if coll_spikes(t) then
		sound(sfx_dat.hit)
		t.alive = false
		t.fcnt = 0
		t.fr = 0
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
		t.fr = 0
		t.fcnt = 0
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
		local left = min(t.x, t.endx)
		local top = min(t.y, t.endy)
		local width = abs(t.endx - t.x)
		local height = abs(t.endy - t.y)
		if p.alive and hit_p(left, top, width, height) then
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

function update_shooter(t)
	if do_bad_die(t) then
		return
	end

	if do_bad_burning(t) then
		return
	end

	t.vx = 0

	if t.shooting then
		t.s = t.i + t.s_sh.s
		if play_anim(t, 8, t.s_sh.f) then
			t.shooting = false
			t.fcnt = 0
			t.fr = 0
		elseif t.fr == 2 and t.fcnt == 1 then
			sound(sfx_dat.shooter_shot)
			local orig = {
				x = t.rght and t.x + 8 or t.x - 1,
				y = t.y + 3
			}
			local shot = spawn_thang(123, orig.x, orig.y)
			shot.endx = t.x + 4 + (t.rght and t.shright or -t.shleft)
			shot.endy = orig.y
			shot.arrowx = t.rght and shot.endx - 5 or shot.endx + 5
			shot.arrowy = orig.y
		end
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

		if (t.shcount <= 0) then
			t.shleft = dist_until_wall(t.x + 4, t.y + 4, -1)
			t.shright = dist_until_wall(t.x + 4, t.y + 4, 1)
			--dbgstr = tostr(left)..' '..tostr(right)..'\n'..dbgstr
			if hit_p(t.x + 4 - t.shleft, t.y, t.shleft + t.shright, 8) then
				if p.x < t.x then
					t.rght = false
				else
					t.rght = true
				end
				t.shcount = 5
				t.shooting = true
				t.fcnt = 0
				t.fr = 0
			end
		else
			t.shcount -= 1
		end
	end

	local phys_result = phys_thang(t)

	if not t.air and not t.shooting then
		if phys_result.hit_wall or coll_edge_turn_around(t,t.x,t.y + t.h) != 0 then
			t.rght = not t.rght
			t.goingrght = t.rght
		end
	end

	if check_bad_coll_spikes(t) then
		return
	end

	if p.alive and hit_p(t.x,t.y,t.w,t.h) then
		kill_p()
	end
end

function update_archer(t)

	if do_boss_die(t) then
		return
	end

	if do_bad_burning(t) then
		return
	end

	t.vx = 0

	if t.shooting then
		t.s = t.i + t.s_sh.s
		if play_anim(t, 6, t.s_sh.f) then
			t.shooting = false
			t.fcnt = 0
			t.fr = 0
		elseif t.fr == 2 and t.fcnt == 1 then
			sound(sfx_dat.shooter_shot)
			local orig = {
				x = t.rght and t.x + 8 or t.x - 1,
				y = t.y + 3
			}
			local shot = spawn_thang(123, orig.x, orig.y)
			shot.endx = t.x + 4 + (t.rght and t.shright or -t.shleft)
			shot.endy = orig.y
			shot.arrowx = t.rght and shot.endx - 5 or shot.endx + 5
			shot.arrowy = orig.y
		end
	-- else we walking
	else
		t.s = t.i + t.s_wlk.s
		-- remember which way we were going
		t.rght = t.goingrght
		if not t.air then
			if t.rght then
				t.vx = 1.2
			else
				t.vx = -1.2
			end
			loop_anim(t,4,t.s_wlk.f)
		end

		if t.shcount <= 0 then
			t.shleft = dist_until_wall(t.x + 4, t.y + 4, -1)
			t.shright = dist_until_wall(t.x + 4, t.y + 4, 1)
			if hit_p(t.x + 4 - t.shleft, t.y, t.shleft + t.shright, 8) then
				if p.x < t.x then
					t.rght = false
				else
					t.rght = true
				end
				t.shcount = 5
				t.shooting = true
				t.fcnt = 0
				t.fr = 0
			end
		else
			t.shcount -= 1
		end
	end

	local phys_result = phys_thang(t)

	if not t.air and not t.shooting then
		if phys_result.hit_wall or coll_edge_turn_around(t,t.x,t.y + t.h) != 0 then
			t.rght = not t.rght
			t.goingrght = t.rght
		end
	end

	if p.alive and hit_p(t.x,t.y,t.w,t.h) then
		kill_p()
	end
end

function burn_bad(t)
	if t.alive and not t.burning then
		sound(sfx_dat.hit)
		t.hp -= 1
		t.fcnt = 0
		t.fr = 0
		t.burning = true
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
	end

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
					sound(sfx_dat.frog_croak)
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
				sound(sfx_dat.frog_jump)
				t.vy += t.jbig_vy
				t.vx = t.jbig_vx * dir
				t.air = true
			end
		else -- angry - jump rapidly at player
			if t.jcount <= 0 then
				t.angry = false
			else
				t.jcount -= 1
				sound(sfx_dat.frog_jump)
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
	local phys_result = phys_thang(t)
	-- if hit ceiling, redo physics with tiny jump
	if phys_result.ceil_cancel then
		t.vx = oldvx
		t.vy = t.jtiny_vy + t.g
		t.x = oldx
		t.y = oldy
		t.air = true
		phys_result = phys_thang(t)
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

	if p.alive and hit_p(t.x,t.y,t.w,t.h) then
		kill_p()
	end
end

function burn_knight(t)
	if t.atking and t.fr > 0 then
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
			sound(sfx_dat.knight_die)
		end
		return
	else
		if oldburning then
			t.atking = false
		end
	end

	-- only conserve vx when airborne, otherwise reset...
	if not t.air then
		t.vx = 0
	end

	if t.alive and t.atking then
		local anim = t.s_atk
		if t.phase == 2 then
			anim = t.s_jmp
		end
		t.s = t.i + anim.s
		if play_anim(t, 10, anim.f) then
			t.atking = false
			t.fcnt = 0
			t.fr = 0
		else
			if t.fr > 0 then
				if t.phase == 1 and t.fr == 1 and t.fcnt == 1 then
					sound(sfx_dat.knight_swing)
				end
				local dir = t.rght and 1 or -1
				-- jump!
				if t.phase == 2 and not t.air and t.fr == 1 and t.fcnt == 1 then
					sound(sfx_dat.knight_jump)
					t.vy = t.jump_vy
					t.vx = t.jump_vx * dir
					t.air = true
				end
				t.swrd_draw = true
				t.swrd_fr = t.fr - 1
				-- all frames hit for now, not just first frame
				--if t.fr == 1 then
					t.swrd_hit = true
				--end
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
			t.fr = 0
			t.fcnt = 0
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
				do_attack = dist(p.x,p.y,t.x,t.y) <= t.atkrange
			end
			if t.phase == 2 then
				if t.atktimer >= t.jmptime then
					do_attack = true
				end
			end
			if do_attack then
				t.atktimer = 0
				t.atking = true
				t.fcnt = 0
				t.fr = 0
				if p.x < t.x then
					t.rght = false
				else
					t.rght = true
				end
			end
		end
	end

	local oldvx = t.vx
	local phys_result = phys_thang(t)

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
	if t.vy > 0 then
		t.s = t.i + t.s_fall.s
		t.fr = 0
		t.atking = false
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
	if t.alive and p.alive then
		local swrd_start_x = t.rght and 8 or -t.swrd_x_off
		if hit_p(t.x,t.y,t.w,t.h) then
			kill_p()
			t.phase = 0
		end
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
		sound(sfx_dat.hit)
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
		b.deadf -= 1
		if b.deadf == 0 then
			del(thang, b)
			room.num_bads -= 1
		end
		loop_anim(b,4,2)
		b.x += b.vx
		b.y += b.vy
		return
	end

	-- b.alive
	if loop_anim(b,4,2) then
		sound(sfx_dat.bat_flap)
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

	if p.alive and
	    hit_p(b.x,b.y,b.w,b.h) then
		kill_p()
	end
end

function burn_lantern(l)
	if not l.lit then
		l.lit = true
		l.s += 1
		lantern[room.i+1].lit = true
		curr_lantern = room.i+1
	end
end

function update_lantern(l)
	if l.lit then
		loop_anim(l,5,2)
	end
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
	}
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
	s_sh  =  {s=94-64, f=2},
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

function init_sfx_dat()
sfx_dat = {
	p_respawn = {
		sfx = 8
	},
	p_die = {
		sfx = 9
	},
	p_jump = {
		sfx = 10
	},
	p_shoot = {
		sfx = 11
	},
	p_land = {
		sfx = 12
	},
	hit = {
		sfx = 13
	},
	bat_flap = {
		sfx = 14
	},
	ice_break = {
		sfx = 15
	},
	frog_croak = {
		sfx = 16
	},
	frog_jump = {
		sfx = 17
	},
	knight_jump = {
		sfx = 18
	},
	knight_swing = {
		sfx = 19
	},
	knight_die = {
		sfx = 20
	},
	shooter_shot = {
		sfx = 21
	},
}
end

function sound(snd)
	sfx(snd.sfx)
end

function spawn_p(x,y)
	p = {
		x = x,
		y = y,
		rght = true,
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
	sound(sfx_dat.p_respawn)
end

function kill_p()
	sound(sfx_dat.p_die)
	p.alive = false
	p.s = p.i + p.s_die.s 
	p.fr = 0
	p.fcnt = 0
	p.sh = false
end

function hit_p(x,y,w,h)
	return aabb(x,y,w,h,
				p.x+p.hx,p.y+p.hy,
				p.hw,p.hh)
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
		elseif (p.onice) then
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
	if btnp(🅾️) and not p.air and not p.sh then
		sound(sfx_dat.p_jump)
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
	p.vy += p.g
	p.vy = clamp(p.vy, -p.max_vy, p.max_vy)

	local newx = p.x + p.vx
	local newy = p.y + p.vy

	if p.vy > 0 then
		newy = phys_fall(p,newx,newy)
		-- fall off platform only if
		-- holding direction of movement
		-- kill 2 bugs with one hack
		-- here - you slip off ice,
		-- and fall when it's destroyed
		if not p.onice and not oldair and p.air then
			if 		(btn(⬅️) and p.vx < 0) or
					(btn(➡️) and p.vx > 0) then
				-- none
			else
				p.air = false
				newx = p.x
				newy = p.y
				p.vy = 0
				p.vx = 0
			end
		end
	elseif p.vy < 0 then
		newy = phys_jump(p,newx,newy,oldair)
	end

	newx = phys_walls(p,newx,newy)

	-- close to edge?
	p.teeter = not p.air and coll_edge(p,newx,newy+p.fty)

	p.x = newx
	p.y = newy

	if oldair and not p.air then
		sound(sfx_dat.p_land)
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
			sound(sfx_dat.p_shoot)
			p.fr = 0
			p.fcnt = 0
		end
		if loop_anim(p,3,p.s_sh.f) then
			sound(sfx_dat.p_shoot)
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
			if p.fcnt == 1 and p.fr == 0 then
				--sfx(5,0,0,8)
			end
			if loop_anim(p,3,p.s_wlk.f) then
			--	sfx(5,0,0,8)
			end
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
		if play_anim(p,2,p.s_die.f) then
			-- fade out after death anim
			fade_timer = 0
			do_fade = true
		end
	elseif p.spawn then
		if play_anim(p,2,p.s_spwn.f) then
			p.fr = 0
			p.fcnt = 0
			p.s = p.i + p.s_wlk.s
			p.spawn = false
		end
	end
end
-->8
-- fireball
fireball = {}

function make_fireball(xdir, ydir)
	local f = {
		w = 4,
		h = 4,
		x = p.x + (p.w - 4)/2,
		y = p.y + (p.h - 4)/2,
		s = 80,
		alive = true,
		fcnt = 0,
		speed = 3,
		fr = 0,
		draw = draw_smol_thang,
		update = update_fireball,
	}
	if (xdir == 0 or ydir == 0) then
		f.vx = xdir * f.speed
		f.vy = ydir * f.speed
	else
		f.vx = xdir * 0.7071 * f.speed
		f.vy = ydir * 0.7071 * f.speed
	end

	f.sfr = 0 -- sub-frame
	if ydir == 0 then
		f.sfr = 1
	elseif xdir == 0 then
		f.sfr = 2
	else
		f.sfr = 3
	end
	f.xflip = false
	f.yflip = false
	if f.vy < 0 then
		f.yflip = true
	end
	if f.vx < 0 then
		f.xflip = true
	end
	add(fireball, f)
end

function kill_fireball(f)
	f.alive = false
	f.yflip = false
	f.sfr = 0
	f.fr = 1
	f.fcnt = 0
end

function update_fireball(f)
	if not f.alive then
		f.y -= 0.5
		f.fcnt += 1
		if f.fcnt & 1 == 0 then
			f.sfr += 1
		end
		if f.fcnt == 8 then
			del(fireball, f)
		end
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
			-- don't stop on lanterns
			-- or already dead stuff
			if t.stops_projs then
				kill_fireball(f)
				return
			end
		end
	end
	-- hit blocks
	-- check two points to make it harder to abuse shooting straight up/down past blocks
	if 
			collmap(f.x+3,  f.y+2, 1) or
			collmap(f.x+1,  f.y+2, 1) then
		f.vx = 0
		f.vy = 0
		kill_fireball(f)
	end
end

-->8
-- collision

function collmap(x,y,f)
	local val = mget(x\8,y\8)
	return (fget(val,f))
end

function collmapv(v,f)
	return collmap(v.x,v.y,f)
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

	local c_tl = {x=cl,y=ct}
	local c_tr = {x=cr,y=ct}
	local c_bl = {x=cl,y=cb}
	local c_br = {x=cr,y=cb}

	if 	collmapv(c_tl,1) or 
			collmapv(c_tr,1) or
			collmapv(c_bl,1) or 
			collmapv(c_br,1) then
		return true
	end
	return false
end

function coll_room_border(t)
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
	-- apply vx, vy, and
	-- return true if moving into edge of room
	local newx = t.x + t.vx
	local newy = t.y + t.vy
	local cl = newx + t.cx
	local cr = cl + t.cw
	local ct = newy + t.cy
	local cb = ct + t.ch
	-- only check left or right
	local cx = cr
	if t.vx < 0 then
		cx = cl
	end
	if 	(t.vx != 0)
			and
			(not in_room(cx,ct) or
			not in_room(cx,cb))
			 then
		return true
	end

	local cy = cb
	if t.vy < 0 then
		cy = ct
	end
	if 	(t.vy != 0)
			and
			(not in_room(cl,cy) or
			not in_room(cr,cy))
			 then
		return true
	end

	return false
end

-->8
-- physics for platformu

function phys_thang(t)
	-- physics for thangs who obey gravity
	-- apply gravity, do physics, stop them colliding with walls
	-- ground if airborne and hit the ground
	-- make airborne if not grounded or jumping
	-- return {
	--			hit_wall, 	 -- if we hit a wall
	--          ceil_cancel, -- if jump was cancelled by a ceiling
	--			landed,		 -- if t.air went from true to false (false on ceil_cancel)
    -- } 
	local oldair = t.air
	local ret = { hit_wall = false, ceil_cancel = false, landed = false }

	t.vy += t.g
	t.vy = clamp(t.vy, -t.max_vy, t.max_vy)

	local newx = t.x + t.vx
	local newy = t.y + t.vy

	if t.vy > 0 then
		newy = phys_fall(t,newx,newy)
	else
		newy = phys_jump(t,newx,newy,oldair)
		if t.vy == 0 and t.air == false then
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

	local c_tl = {x=cl,y=ct}
	local c_tr = {x=cr,y=ct}
	local c_bl = {x=cl,y=cb}
	local c_br = {x=cr,y=cb}

	local l_pen = 0
	local r_pen = 0
	if 	collmapv(c_bl,1) or 
			collmapv(c_tl,1) then
		l_pen = roundup(cl,8) - cl
	end
	if 	collmapv(c_br,1) or 
			collmapv(c_tr,1) then
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
00000000dddddddddddddddddddddddddddddddd05555550000000000555555011111111011111103101001301010110dddddddddddddddd0111111001111110
000000000dddddd00dddddddddddddddddddddd011555151000000001551515511dddd110111111031011110100110330dddddddddddddd00015510001111110
000000000111111001111110000000000111111055151555000000005555551101dddd1001111110010110101001133300000000000000000011110001111110
00000000011001100110011111111111111001101551515111111111551151510111111001dddd10010110131011131001111111111111100000000001555510
00000000010000100100001000000000010000101155511100000000155511510000000001dddd10010111131111001300000000000000000000000001555510
00000000001111000111111001100110011111101515151101100110111115550000000001dddd10010101100101001301100110011001100000000001555510
00000000000000000100001111111111110000101111151111111111151155110000000001dddd10010111103301011000111111111111000000000001555510
00000000000000000100001000000000010000100151111000000000011115100000000001dddd10110110100301011300000000000000000000000001555510
dddddddddddddddddddddddddddddddddddddddddddddddd11111111dddddddd0111111001dddd10010100100101011055555555555555555555555501555510
0dddddddddddddddddddddddddddddd00dddddd00dddddd0001000000dddddd01111111d01dddd10330100103101011005515115551555555515515001555510
01111111111111111111111111111110011111100111111000100000011111101d11d1dd01dddd10333100133301011301001110110011001100110001555510
011ddd11111111111111111111ddd110011dd1100110011000000000011dd110111ddd1d01dddd10013100010101011000000010001001010010010001555510
01ddddd1ddddd1dddd1dd1dd1ddddd1001dddd10010000101111111101dddd101ddddddd01dddd10010110010101011000101101100010101000101001555510
01111111ddddd1ddddd1d1dd11111110011111100111111000000100011111101dd1d1dd01dddd10310110100101011000100000001100001110000001111110
01d1d1d1ddddd1dddddd11dd1d1d1d1001dddd10010000100000010001dddd1011d1dddd011dd1100101111001010110000001000000010100010100011dd110
01d1d1d111111111111111111d1d1d1001dddd100100001000000000011111100dddddd000111100010111100101011000000000000001000000000000111100
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
00221120002211200222222000222220000222000022112000221120022120000022200000220200002000000002000000000000000007000000700000002200
0021112000211120222222220022222202212220022111200221112222111200022120002022222000220200002200000000000000072000009aa70000021120
022111200221112022222222022222222111222502211222022112222211122022112020022122200222200000122000000000000a02a2a0021999a007217170
02222220022222205222111202222222222222200222222202222220222222202221122002111220002120000001100000a007000a7a7a0009a2a8000a72aa20
02222220022222200222212002222222222222250222222022222220022222220222222000211200000110000000100000070a00009a9800029a9290029a2990
22222200222222005222220000222220022222222222250002222500022220500222225000021000000000000000000000a99000008988000089892000a99800
00500500000550000000000000000000002220000220500000205000002050000022500000000000000000000000000000088000000890000008890000988500
bbbb0980070a7070ddddddddddddddddddddddddddddddddc77c7ccc0cccccc00070c00000000000000000000000000000000000000000000002e200002e2000
bbbba7987a99a7a700222200002222000022220000000000cccc777cccc711cc00c070c0000000000000000000000000000000000000000002e11e0000e11e20
bbbba798099a0890021001200210012002100120000000001ccccc7c1c7cc1cc0c7ccc000c0c0c0000c0000000000000000000000000000002e71e2002e17e20
bbbb0980008000000210712002a0712002170120000000001ccccccc1ccccc1c10c7c1cc00c7000000007000000000000000000000000000029a7a2222a7a920
0aa007a0070770a0201001022017a102207aa10200000000c1cccc1cc1cccc1cccccc1c10c00c7c0070c0c000000000000000000000000002289a922229a9822
97797a98099a099020100102201891022018910200000000c11cc11cc11cc11c11cccc10cccc0c0c0c00000c00000000000000000000000002e88e2002e88e20
8998a9980080000002111120021111200211112000000000ccc11cc00ccc11cc0c1c1cc11c0c1cc1100cc710000000000000000000000000002ee200002ee200
08800880000000002222222222222222222222220000000001ccc11001ccccc000c101c00c110c100c010c000000000000000000000000000005500000055000
5500050000000000007000700700070000066600000666000006660000ee00000007000000000000000000007ccc000cc7c70c00000000000600600000000600
055055000000000008a707a009a707a0000611600006116000c611600ee7e0000000a70000707000000700000c000ccc0c70c7c7000000000600700000600700
0085800000085800009a0a80008a0a9000661160006611600c6611600ee77e00707aaaa0000aa000070a00000c00700c777c077c000000000070600600700600
00050000055555000008a9000009a80006c66160066c6160cc6661600eee7e900aa999a007a997000000900000c0000cc0c70c00000000006060600700606007
0000000055000550000098000000890006cc6660066cc66005666665088eee0000a9a900009980000000000007007000c00c000c000000000700606060606006
000000005000005000000000000000000566c66506566c6000c6666080eeeee008998900000800000000000000c0c00cc707070000000000006ddd6006dddd60
00000000000000000000000000000000c06666000c66660000666600090eeee000088000000000000000000000c0ccc000007007000000000ddd1dd00dd11dd0
0000000000000000000000000000000000500500000550000050050000890090000000000000000000000000ccccc0000c700000000000001111111111111111
0000000000000000000000b0bb00000000000e00000666000006660000066c0000066600000666c00eee080000000000dddddddddddddddd00670001d0060000
000000000000000000000b8b03b000000000e7e0006116c000611600006116c000611cc00061160ce77e00800000000001d111d001d11d10000066d1d1600000
00000b0000000b000004bbb300b0000000eeee200061160c006116c00061160c0061160c0061160ce77e008000000000061116000611116000000dd1dd166760
0000b8b00000b8b0004443b000b400b00000ee000666660c066666c0066566656656666566566665eeeeee90000ccccc060600706006060667666d11d1100000
00bbbb3000bbbb3000b400b000444b8b0008820066666665066666500066660c0066660c0066660c0eee008000000000700606067006060000000dd1d1166000
04443b0004443b300bb300000004bbb300e880005066660c056666c0006666c000666cc00066660c9eeee080000000006006070000600700007606d1dd100676
04443b0004443b00b3000000000003b0ee0020000066650c006660c000666c0000666500006665c009999800000000000007006000700600660070d1d1600000
003bb0b0003bb0b0b0000000000000b000220000005005c000055c000050050000500500005005000090090000000000000600600060000000060001d0067000
700042b370a3b350b370a3a35041704150626262626262626262626575507070707050705070705070505050705070505070507050705050705063a3b3a3b3a3
a3a3b350507063706370706370637070a3707070a350635070705070a37063a3707063637063637063707070a3707050a3b3a370b3b3b3b350b3b350b3b3b3a3
70104250b3a370a350b35070634200425062705070505081626200000065505050620000000062000000630000000050706262000000650000627070b3b3b3b3
a3b3b363626262626262626262006370706362000000000000000062700000a370620000000000000000007575505070b3a37070006375657565656370a3a3a3
700042507050b350b350a37062430043706270d7c7d7c7000000000000007570705000000000007000000000007000806200000000c1d1e1000062626350a3b3
a3507075006262626262626200000080e06200000000000000000000000000800000000000000000006200000065507070b300630000000075757575505070b3
700042706362505050626362000000800062500000000000000075000000005050000092000700000092002500006200000000000062000000000062626250a3
70706506006262626262626262000000000000000000002500000000000000000092e200250000006262620000655050a37000000000000000006575657563b3
701043506262626362626262259200000062700000750000000065000000007070657070507050a3a350705070507050700000f26200620000f2000000626350
7006000062626262626262620000c1a3500000c1d1d1d1d1d1d1d1d1e100505070d1d1d1d1e100626262626200006370b3637000000000000000000075656550
700062e0000062626262620041d1d1707050500000650000000000000000655050000000000070a3630000005070007050006200000000000062000000626250
50000000626262626262620000000050a3e100000000000000000000000000a350626200000000006262620000006550b37070000000000000000000000065a3
70e20000620062000000620042000070b350620000000065000000000075655070000000000000630000000000e000a370000000000000000000000000007070
70000000006262626262626200756570700000000062929200e20000000000a350620000000000006262620000000050b37070000000000000000000000075b3
70d1d1410000000062000000420070705062006500000075000000008165757050009200929200650000e2e200000070500000000000000000f2000000625050
50000000009262622562620065650050a30000066250a3b3a3b37062626200a370000000620000006262620000000070707000000000000000000000000075a3
700000420000000000000000420000507000000000000000000000000000655070d1d1d1d1d1d170d1d1d1d1d17000a37000000000f200000000000000000050
7000000070637070507050707500007050755050505050b3a3b3a350505065a350000062626262620000000000000050a37000000000000000000000000000b3
505000420000000000000000420070b3500000000000000000000000000075707000000000000070000000000070007050000000000000000000000000000070
50000000000000507063000000000050706262626350625050505063620000a370006262626262620000000000000050500000000000000000000000000000a3
500000420051000000005100425070a350620075000000657500000000000050700700000000007006000700007000a37000f200000000000000000000000050
50620000000000000000000000000070706262626262626262620000626262a350000062626262620000000000000080650000000000000000000000002500b3
705000430053000c00005300430050b35062628100000000000000000000007070505050507000700050707050620070700062000000000000f2000000256050
5062620007000000000000000062625070f2626200006206006262006262f2a3700000006200000000000000e2e26200e2650000000000000000000072218250
7070e2c03030303030303030d05070a370f66262000062000062620025000080636262630062506250506300500062b350620000000000000062626250d1d170
70006262620062626200626262620070506262626262626262626262626262a370620000000000000000c1d1d1d1d170a3756500000000000000007173138350
b3a350007092705070005092705050a3a370f6f662626262626262628100000062e2000062006292e2000000006270a370f662c1e16262f66262f6e670616180
e00062626262626262626200626250a3500662f26262626262626206f26250a350626200000000000062626262626270a3756500000000000000717323228350
70b3a350a350a350b3a370a3a3b3a3a3a3a3a350e6f6e6f6e6f6e6f670b3a3b37070706270925050a3506262e25070b35070f6e6e6e6f650e6e6705063616100
0062626281000062626200507050b3a3a35062626262620062626262625070a370e6f6e6f6e6f6e6f6e6f6e6f6e6f650a3706575009275657571731322128350
70a3b3a3b3a3a3b3a3b3a3a3b3a3a3a3b3b3a3b3a3a3a3a3b3a3b3a3b3a3b3a3a3a3a370a3a350a3a370a3a370a370b3a3b3a3b3a3b3a3a3b3b3a3b3a3a3b3a3
b3a3b3a3b3b3a3b3a3a3b3a3b3a3b3a3b3a3b3a3b3a3b3a3a3b3b3a3b370b3a3a3b3b3a3b3a3b3a3b3a3b3a3b3a370a3b3a3b3b3a3a3b3a3a3b3a3b3a3b3a3b3
0066dd000066dd700066dd70066d700000066dd00066dd000000000000066dd00066dd000066dd70077ee700066dd00000000000000000000000000000000000
00dffd0000dffd7000dffd700dff7000000dffd000dffd000066dd00000dffd000dffd0000dffd700eaae7000dffd0000066dd00000000000007000000000000
00d66d0022226d6022226d6022226000222d66d022d66d0000dffd70222d66d022d66d0022226d608877ee002222d00000dffd00000000000070000000000000
2222ddf02982d4442982d44429824400222dddd022dddd0022226d70222dddd022dddd002982d44488eee8802982d04022226d00000000004600000040000000
2982dd442892ddf02892ddf02892f00022fddddd2fdddddf2982dd6022fddddd2fdddddf2892ddf088eeea002892df462982dd0000000000f400000046770000
2892556029825500298255002982500022255500225550002892d44422255500225550002982550088999000298250402892dd400022226d0000000040000000
298205700225500002250500022005000205005002500500298255f0020505000250050002205050089009000220050029825f46029892dd0000000000000000
02200570000550000050050000500500005000500500050002250500005050000500050000005050009009000050050002250540528982fd0000000000000000
00000000000044400000444000444900004440000044409000000000000444900004449000444900004440000044409000222900004440000000000000000000
0044400000004ff000004ff0004ff090004ff990004ff009000444900004ff090004ff09004ff090004ff990004ff009002aa090004ff0000004440000000000
004ff00000115550100155500115500901155009011550090004ff090001550901115509011550090115500901155009099ee090011550000004ff0000000000
011550000115555011115550155f555f55f5555f55f5555f01155509011f555f111f555f155f555f55f5555f55f5555f99eeeea0115550090011550000000000
1155500019155509911555901155500911555009115550091155555f11115509111155091115500911155009111550099eeee090155550090115550000000000
11555f001199f990099f990011222090112229901122200911f522091111222901112229011222900112299001122229a98880901f2225f90155550900111100
1199f9900120020000022000112009001120020011200290111222090010209001002090011129200111202001112090999809001112029001f222f001111114
09112229020020000022000002000200020002000200020001122090000020200000202000102020001020200010202009008080010292000111222022111544
00c6600000c6600000c6600400624000221000000010000000000000000000000000000000000000000044400000444000044400000444000000444000004440
0c66f6040c66f6400c66f6040621420012620000022000000000000000000000000000000000000000004ff000004ff00004ff900004ff0000004ff000004ff0
0cfbf0040cfbf0400cfbf00f0c216421421221002102000000220110000210000000000000000000001155501001555000115509100155900011555010015550
0c6ff6040c6ff640fc6ff6c4021f6210246212100100000002101000000000000000000000000000011555501111555001155509111155900115555011115550
cc6666cffc6666f0cc666604116662101121c21200012011001002000000001000000000000000001915550991155590111555f0111555f01115550011155500
fcc66604ccc666400cc66604fcc621400214210200100201010002000200200000000000000000001199f990099f990011f22200011222901122200001122200
0ccc60040ccc60400ccc60040cc2100411c21c210000021000002000010000000000000000000000012002000002200001200200000220900120020000022000
ccccc004ccccc040ccccc000021ccc000021c1100000200000000000000000000000000000000000020020000022000002002000002209000200200000220000
00cc9c04000c6600000c6600000c6600000c66000006600000000000000660000066000007eee000000000000044400000444000000000000007007000700700
0009190400c66f6000c66f6000c66f6000c66f60006006006006600060600600660060000e07700000000000004ff900004ff09000007007000a00a0000aaa00
00c9190400cfbf0000cfbf0000cfbf0000cfbf00606dd6d06060d6d0060dd6d000ddd6007eee07000000000000155090011550090000a97a00709a9007099000
0c9111cf0cc6ff600cc6ff6f0cc6ff600cc6ff6f06d0662006d6662000d6d620dd666d200777e800000000000115509011555009007098a870a9989000a90000
c0c999040cc666600cf666600cc666600cf666600d66d2120d60d2120d6d6212000dd2127ee7898000000000011f55f011f5555f00a99895a098900000000000
f0cccc040cfc666f0cccc6600cfc666f0cccc660d0006d200d006d20d0066d20d6d06d20e00e78000000000001122090112220090a8585500a98000000000000
00cccc040cccc6000cccc6000cccc6000cccc60000660d00d066d0000060d0000066d0000e7e0000000000000112009011202009799500500000000000000000
0ccccc04cccccc00cccccc00cccccc00cccccc000000d000000d0000000d00000ddd00000007ee00000000000022090002002090085500000000000000000000
__label__
dd1ddddddd1ddddddd1d1ddddd1ddddddd1ddddddd1ddddddd1ddddddd1d1ddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1d1ddddd1ddddd
dd1ddddddd1ddddddd1dd11ddd1ddddddd1ddddddd1ddddddd1ddddddd1dd11ddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1dd11ddd1ddddd
dd1ddddddd1ddddddd1dddd1dd1ddddddd1ddddddd1ddddddd1ddddddd1dddd1dd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1dddd1dd1ddddd
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
ddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1dd
ddddd1dddddd11ddddddd1dddddd11ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1dddddd11ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1dd
ddddd11dddd1d1ddddddd1ddddd1d1ddddddd1ddddddd1ddddddd11dddddd1ddddddd1ddddddd1ddddd1d1ddddddd1ddddddd11dddddd1ddddddd1ddddddd1dd
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
dddddddd00000000000000000000000000000000000000000cccccc0c77c7ccc0cccccc0c77c7cccc77c7cccc77c7cccc77c7cccc77c7cccc77c7cccdddddddd
ddddddd00000000000000000000000000000000000000000ccc711cccccc777cccc711cccccc777ccccc777ccccc777ccccc777ccccc777ccccc777c0ddddddd
1111111000000000000000000000000000000000000000001c7cc1cc1ccccc7c1c7cc1cc1ccccc7c1ccccc7c1ccccc7c1ccccc7c1ccccc7c1ccccc7c01111111
11ddd11000000000000000000000000000000000000000001ccccc1c1ccccccc1ccccc1c1ccccccc1ccccccc1ccccccc1ccccccc1ccccccc1ccccccc011ddd11
1ddddd100000000000000000000000000000000000000000c1cccc1cc1cccc1cc1cccc1cc1cccc1cc1cccc1cc1cccc1cc1cccc1cc1cccc1cc1cccc1c01ddddd1
111111100000000000000000000000000000000000000000c11cc11cc11cc11cc11cc11cc11cc11cc11cc11cc11cc11cc11cc11cc11cc11cc11cc11c01111111
1d1d1d1000000000000000000000000000000000000000000ccc11ccccc11cc00ccc11ccccc11cc0ccc11cc0ccc11cc0ccc11cc0ccc11cc0ccc11cc001d1d1d1
1d1d1d10000000000000000000000000000000000000000001ccccc001ccc11001ccccc001ccc11001ccc11001ccc11001ccc11001ccc11001ccc11001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000cccccc00cccccc00cccccc00cccccc0c77c7cccc77c7ccc0cccccc001d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000ccc711ccccc711ccccc711ccccc711cccccc777ccccc777cccc711cc01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000001c7cc1cc1c7cc1cc1c7cc1cc1c7cc1cc1ccccc7c1ccccc7c1c7cc1cc01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000001ccccc1c1ccccc1c1ccccc1c1ccccc1c1ccccccc1ccccccc1ccccc1c01d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000c1cccc1cc1cccc1cc1cccc1cc1cccc1cc1cccc1cc1cccc1cc1cccc1c01d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000c11cc11cc11cc11cc11cc11cc11cc11cc11cc11cc11cc11cc11cc11c01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000ccc11cc0ccc11cc0ccc11cc0ccc11ccccc11cc0ccc11cc00ccc11cc01d1d1d1
1d1d1d100000000000000000000000000000000000000000000000000000000001ccccc001ccccc001ccccc001ccccc001ccc11001ccc11001ccccc001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000c77c7ccc0cccccc0c77c7ccc0cccccc0c77c7ccc01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000cccc777cccc711cccccc777cccc711cccccc777c01d1d1d1
1d1d1d100000000000000000000000000000000000000000000000000000000000000000000000001ccccc7c1c7cc1cc1ccccc7c1c7cc1cc1ccccc7c01d1d1d1
1d1d1d100000000000000000000000000000000000000000000000000000000000000000000000001ccccccc1ccccc1c1ccccccc1ccccc1c1ccccccc01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000c1cccc1cc1cccc1cc1cccc1cc1cccc1cc1cccc1c01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000c11cc11cc11cc11cc11cc11cc11cc11cc11cc11c01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000ccc11cc00ccc11ccccc11cc00ccc11ccccc11cc001d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000001ccc11001ccccc001ccc11001ccccc001ccc11001d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cccccc0c77c7cccc77c7ccc01d1d1d1
1d1d1d100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ccc711cccccc777ccccc777c01d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c7cc1cc1ccccc7c1ccccc7c01d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ccccc1c1ccccccc1ccccccc01d1d1d1
1d1d1d100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c1cccc1cc1cccc1cc1cccc1c01d1d1d1
1d1d1d100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c11cc11cc11cc11cc11cc11c01d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ccc11ccccc11cc0ccc11cc001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ccccc001ccc11001ccc11001d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c77c7ccc01d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cccc777c01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ccccc7c01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ccccccc01d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c1cccc1c01d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c11cc11c01d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ccc11cc001d1d1d1
1d1d1d100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ccc11001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cccccc001d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ccc711cc01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c7cc1cc01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ccccc1c01d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c1cccc1c01d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c11cc11c01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ccc11cc01d1d1d1
1d1d1d100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ccccc001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cccccc001d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ccc711cc01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c7cc1cc01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ccccc1c01d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c1cccc1c01d1d1d1
1d1d1d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c11cc11c01d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ccc11cc01d1d1d1
1d1d1d100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ccccc001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002220000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021122000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021112000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021112200000000001d1d1d1
11ddd110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022222200000000001d1d1d1
d11111dd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022222200000000001d1d1d1
dddddddd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002222220000000001d1d1d1
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005005000000000001d1d1d1
c77c7ccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dddddddd0000000001d1d1d1
cccc777c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002222000000000001d1d1d1
1ccccc7c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021001200000000001d1d1d1
1ccccccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a071200000000001d1d1d1
c1cccc1c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002017a1020000000001d1d1d1
c11cc11c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000201891020000000001d1d1d1
ccc11cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021111200000000001d1d1d1
01ccc110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000222222220000000001d1d1d1
0cccccc0c77c7ccc00000000000000000000000000000000000000000000000000000000000000000000000000000000dddddddddddddddddddddddd01d1d1d1
ccc711cccccc777c000000000000000000000000000000000000000000000000000000000000000000000000000000000dddddddddddddddddddddd001d1d1d1
1c7cc1cc1ccccc7c0000000000000000000000000000000000000000000000000000000000000000000000000000000001111111111111111111111001d1d1d1
1ccccc1c1ccccccc00000000000000000000000000000000000000000000000000000000000000000000000000000000011ddd111111111111ddd11001d1d1d1
c1cccc1cc1cccc1c0000000000000000000000000000000000000000000000000000000000000000000000000000000001ddddd1dd1dd1dd1ddddd1001d1d1d1
c11cc11cc11cc11c0000000000000000000000000000000000000000000000000000000000000000000000000000000001111111ddd1d1dd1111111001d1d1d1
0ccc11ccccc11cc00000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1dddd11dd1d1d1d1001d1d1d1
01ccccc001ccc1100000000000000000000000000000000000000000000000000000000000000000000000000000000001111111111111111111111001d1d1d1
dddddddd0cccccc0c77c7ccc0000000000000000000000000000000000000000000000000000000000000000dddddddd01d1dddddd1d1dddd1dddd1001d1d1d1
ddddddd0ccc711cccccc777c00000000000000000000000000000000000000000000000000000000000000000dddddd001d1dddddd1dd11dd1dddd1001d1d1d1
111111101c7cc1cc1ccccc7c00000000000000000000000000000000000000000000000000000000000000000111111001d1dddddd1dddd1d1dddd1001d1d1d1
11ddd1101ccccc1c1ccccccc0000000000000000000000000000000000000000000000000000000000000000011dd11001111111111111111111111001d1d1d1
1ddddd10c1cccc1cc1cccc1c000000000000000000000000000000000000000000000000000000000000000001dddd101ddddd1dddddd1dddddd1dd101d1d1d1
11111110c11cc11cc11cc11c0000000000000000000000000000000000000000000000000000000000000000011111101ddddd1dddddd1dddddd1dd101d1d1d1
1d1d1d100ccc11ccccc11cc0000000000000000000000000000000000000000000000000000000000000000001dddd101ddddd1dddddd1dddddd1dd101d1d1d1
1d1d1d1001ccccc001ccc11000000000000000000000000000000000000000000000000000000000000000000111111011111111111111111111111101d1d1d1
1d1d1d100cccccc0c77c7ccc0cccccc0000000000000000000000000000000000000000000000000dddddddd01d1dddddd1ddddddd1dddddd1dddd1001d1d1d1
1d1d1d10ccc711cccccc777cccc711cc0000000000000000000000000000000000000000000000000dddddd001d1dddddd1ddddddd1dddddd1dddd1001d1d1d1
1d1d1d101c7cc1cc1ccccc7c1c7cc1cc0000000000000000000000000000000000000000000000000111111001d1dddddd1ddddddd1dddddd1dddd1001d1d1d1
1d1d1d101ccccc1c1ccccccc1ccccc1c000000000000000000000000000000000000000000000000011dd1100111111111111111111111111111111001d1d1d1
1d1d1d10c1cccc1cc1cccc1cc1cccc1c00000000000000000000000000000000000000000000000001dddd101ddddd1dddddd1ddddddd1dddddd1dd101d1d1d1
1d1d1d10c11cc11cc11cc11cc11cc11c000000000000000000000000000000000000000000000000011111101ddddd1ddddd11ddddddd1dddddd1dd101d1d1d1
1d1d1d100ccc11ccccc11cc00ccc11cc00000000000000000000000000000000000000000000000001dddd101ddddd1dddd1d1ddddddd11ddddd1dd101d1d1d1
1d1d1d1001ccccc001ccc11001ccccc0000000000000000000000000000000000000000000000000011111101111111111111111111111111111111101d1d1d1
1d1d1d1000000000c77c7ccc0cccccc00cccccc0000000000cccccc0c77c7ccc0cccccc0dddddddd01d1dddddd1d1ddddd1ddddddd1dddddd1dddd1001d1d1d1
1d1d1d1000000000cccc777cccc711ccccc711cc00000000ccc711cccccc777cccc711cc0dddddd001d1dddddd1dd11ddd1ddddddd1dddddd1dddd1001d1d1d1
1d1d1d10000000001ccccc7c1c7cc1cc1c7cc1cc000000001c7cc1cc1ccccc7c1c7cc1cc0111111001d1dddddd1dddd1dd1ddddddd1dddddd1dddd1001d1d1d1
1d1d1d10000000001ccccccc1ccccc1c1ccccc1c000000001ccccc1c1ccccccc1ccccc1c011dd110011111111111111111111111111111111111111001d1d1d1
11ddd11000000000c1cccc1cc1cccc1cc1cccc1c00000000c1cccc1cc1cccc1cc1cccc1c01dddd101ddddd1dddddd1ddddddd1ddddddd1dddddd1dd1011ddd11
d11111dd00000000c11cc11cc11cc11cc11cc11c00000000c11cc11cc11cc11cc11cc11c011111101ddddd1dddddd1ddddddd1ddddddd1dddddd1dd1dd11111d
dddddddd00000000ccc11cc00ccc11cc0ccc11cc000000000ccc11ccccc11cc00ccc11cc01dddd101ddddd1dddddd1ddddddd11dddddd1dddddd1dd11ddddddd
111111110000000001ccc11001ccccc001ccccc00000000001ccccc001ccc11001ccccc001111110111111111111111111111111111111111111111111111111
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
ddddd1ddddddd1dddd1dd1ddddddd1dddd1dd1ddddddd1ddddddd1dddd1dd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1dddd1dd1ddddddd1ddddddd1dd
ddddd1ddddddd1ddddd1d1ddddddd1ddddd1d1ddddddd1ddddddd1ddddd1d1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddd1d1ddddddd1ddddddd1dd
ddddd1ddddddd1dddddd11ddddddd1dddddd11ddddddd1ddddddd1dddddd11ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1dddddd11ddddddd1ddddddd1dd
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111

__gff__
0001010101030003100300000101100303030303030100030303000001010103030303030300000303000000000300010303030303000303030303030303030300000000000000000000000000000000000011010101131300000000000000001000000010000000101010000000080810101010101000000000000008080808
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101010
__map__
2121222222222222222121212121212121312121212121212121212121322121212121212121212121212121212121212222222222223816161616161616162121323816161616161616161616372121212121212121212121212121212121211411111111111111121111111111111105050505050505050505050505050505
2116161616161616161616161616162113161616161637213816161616372110380000000000000000000000000000141300000000000000000060000000001014000000000000000000000000000014140000000000000000000000000000142400000000000000000000000000000005002121002100002200212100000005
0e161616161616161616161616161621331616161616161616161616161637200e0000000000000000000000000000242300000000000000000000000000002024000000000000000000000000000024240000000000000000000000600000242400000000560000005600000000000005002100002121002200210021000005
2116161616161616161616161616162108000000000000000000000000000020000000000000000000000000000000242300000000000000000064000000002034000000640000000000000000640034240060000000600000000000000000242400000000000000000000000000000005002121002100212200210021000005
216400000000000000000000006400210000520000006e006e6e000000000020140303030303030303030303030303242300000000000100000001000000002011113d030d0000000000000c033c1111240000000000000000000000000000242400000000000000000000000000005205002100002100002200210021000005
21565600000000640000000056560021132711111111111111111111112800202400000000000000000000000000002423000000000000000000000000006020247d7d7d7d0000006400007d7d7d7d24240000000000000000000000000000242400000000000000000000000056561405002121002100002200212100000005
21000000150056565600150000000021230000007c0018000000180000000020240100640000000000000064000000242300000000000000000000006f000020240000000000000c0d00000000000024240000000000000000000000006000242400005600000056000000560000002405000000000000000000000000000005
21000000350606060606350000000024230000000000000000000000000000202400000000000000000000000000002423000001000000000000007e187f002024000000000000000000000000000024240000000000000000000114000000242400006e6e6e6e6f6e6e6e6f6e6f6e2421210000212100210000002100002200
2100640016161616161616000000002423006e00181616161616161616161620340000005600006417000000570000340800000000000000150000007c00002024000064000000000000000000640024240000000000000014000024000000342400003721212121212121212121212421002100210000212100212100220021
2156560064000015000000006400002423001818141616166e1616166e1616202857575614565756245657561403032700000000000000002500000000000020240056565600000000000056565600242403030303140c0d240c0d24000000273400002500000025000000240000002421002100212100210021002100220021
210000005656002500640000565600242300007d3416166e186e166e186e1620380000002400000024000000240000371300005200000000250000000000002024000000000000000000000000000024240000000024000024000024001400371111111128000025000000240000002421002100210000210021002100220021
21000000000000350056560000000024231800002711111111111111111128203800000024000000240000002400003723030303000000152500000000600020240000000000003c3d000000000000242400000000240c0d240c0d24002400370e00002500000025000000240000002421210000212100210000002100002200
2106060606060615060606060606062123000000372121380000003721213830380000002400000024000000240303372300000000000025250000000000002034000000000000252500000000000034340000140024000024000024002400370000002500000025640000240000002405000000000000000000000000000005
2116161616161625161616161616160823000000000000000000000000000000380000002400000024000000240000082300000000000025256000000000000e0800000000170025250017000000000e0801002400240c0d240c0d240024000e14005625560056255600002400000024050000000000007c0000000000000005
2116521616161635161616161616160033000018000000001800000000000000386e6e6e346e6e6e346e6e6e34520000336e6e6f6e6f6e6f6e6f6e6f6e6f340000005200002500252500250000700000000052346e347000340070346e340000346e6e6e6e6e6e6e6e6e6e342712283405000000000000520000000000000005
11111111111111111111111111111111211212121212121212121221212121211111111211111211121112121112111112121212121112121212121212121212111111286e27286e6e27286e27121111111111121111121112111212111211112121212121212121212121212121212121212121212121212121212121210121
23000025001a000b00000a002500002021212121212121212121212121212121212121212121212121212121212121212121212121212121212131212132212121312121212122212121212122322121212122212121212121212121212121212121212121212121212121212121212114372138143721213814372138140014
23000025000a001a00000b002500002013161616161616161616161616161610213222322231381616161616161616372132223222313816161616161616163713162416161616161616161616161610143434341616161616161616246024141316161616005600000000000e00001024000000240000000034000000240124
23000025000b000a00001a002500002023161616161616161616161616161630213221213816161616161616161616373816161616161616161616161616163733003400000000000000000000750020246056750000000000000000345634242316161600005600007500000000563034000000240000000000000000340024
23000025002b001b00000a00250000202316161616161616161616161616160e080016001616000016161616161616373800000000000000000000000000000e080000000000000000000000003c3d20343c113d5600000000000000000000342316160000003c111112111128005656080000003400000000000000000e0124
23000025001a000b00001a00250000202300000000000000000000000000000000165200000000010000160000161637380000007500000000000000000000000000520000000000000000000000002007000000000000290000000000000011231660000000250000000037385656560000520056000000000000d000000034
23000035000b000b00002b00350000202300000000000000000000000002031028030d00000000006400000016001637386e3c11113d6e6f00000000003c1111133c1111113d00176e6e6e000000002007000000001c1e1d1d1e00000018002423000c0d000025006000003c11111211111111280000000000000c0303271111
23000014030303030303030314000020230000000000000000000000002500203800000000000000575600010000003721382121212137380000003c3d00003723271112111111111111280000000020070000000000000000000000000000242301000000002500000000250000001014000000000000000000000000000005
23000024001a001a00001b0024000020230000000017006400001700002500203800000c0d00000000000000000000372121212121212138000056000000003723000000000000000000000000000020075664000000145614002e0000007534336e6e6e6e003500000000350000002024000000000000000000000001000005
23000024000a001b00000b0024000020230000003c1111111111113d002500203800000000000000000000000000003721212121212121383c3d0000000000372300007500000000000000000000002007603c3d6e003460341c1e000000570e163c1111111112111111113d5656562024000000000000000000000000000005
23010024001a002b00000b0024000120230000002500000000000025002500203800000100000064000064000000003721212132387c7d7c00000000000000372300003c3d000c030d000c0303030d200707070707003c113d000000000000001616161400000000007c7d25600000202400000c03030d000000000c0d000005
23000024002b001a00001a002400002023000000250000000000002500250020380000000000565700005718000100373800007c7c000000000000000000003723006f6e6f6e6f6e6f6e6f6e6f6e6f20070526263600000000000000000000141316162400000000006000250000002024000000000000000000000000000005
23000024001b001a00002b00240000202311113d25000000000000250025172038160c0d00000000000000000000000e08000000000000000c0304000000003723002711111111111211111111112820050726000000000000002f00007500242316162416000000000000250015152024000000000000000000000000006f05
23000124000b002b00000a002401003033000025250000000064002500252520381616000016000000000000160000000000000000000000000024000064003723000000000034000000000000000030072600000000000000000000001400242316163416161600000064151525252024006f6f001c1d1c1e1d1e00006f0705
23000024002b000b00000b0024000000080000252500002711111128002525203816161616161616001600161616012728005200000c030d00002400565656373300001700000000000075000000000e0800000000070507000026266e346e3423161616161616160015152525252520246f05056f0000000000006f6f070705
332929342e2a2e2c292e2b293429000000005235350027212121212128353530386f6e6f6e6f6e6f6e6f6e6f6e6f6e3711111111286f6e6f6e6f346e6f6e6e371112111111111111286e3c3d6e000000002952070507050570260507050705073316521616161616166f6e6f6e6f6e3034050505056e6e6e6e6e6e0707070707
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
01020000091300d1301013012120141201512017110171101711017110171101d1001e1001710014100111000d100091000610003100001000010028100221002d10018100121000010000100001000010000100
90040000222201e2301925015250102300c21007210032101820014200122000e2000d20000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
1114000015020110300e040100400c0400b0400b0400b0400b0300b0200b010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
040300001e0341703016030110200d0200a02007010040100201000014121040e1040d10400104001040010400104001040010400104001040010400104001040010400104001040010400104001040010400104
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01180000135301353013530135301b5301b5301b5301b5301a5200a500165200750018520185201852014500185201852018520185001b5201b5201b5201b5001f5201f5201f520135001d5201d5201d5201d500
011800001353013530135301353018530185301853018530165200a500135200750014520145201452014500145201452018520185201a5201a5201b5201b5201852018500145201450016520165201652016520
29180000110201102011020110000c0200c0200c0201300011020110200c0200c0200f0200f020130201302011020110000c0200c0000f0201102014020140200c0200c0200f0200f02016020160201b0201b020
29180000110201102011020110000f0200f0200f02013000130201302014020140200f0200f0200f0200f020110201102011020110000f0200f02014020140201602216022160221602216022160221602216022
0118000024720247202472024720277202772027720277202b7202b7202b7202b7202972029720297202972027720277202772027720247202472024720247202a720267202472027720297202c7202b7202b720
0118000024720247202472024720277202772027720277201f7201f7201f7201f7201b7201b7201b7201b72020720207202072020720227202272022720227201f7201d7201f7201d7201f7201d7201f7201f720
111800001802018020180201802014020140201302013020180201b020180201802014020140201302013020110201102011020110200f0200f02014020140201302013020130201302013020130201302013020
010c000018020180201802018020180201802018020180201402014020140201402013020130201300013000135201352013000130000f5200f5200f0000f0001352013520135201352013520135201352013520
010c00001802018020180201802018020180201802018020140201402014020140201302013020130201302018020180201b0201b020180201802018020180201402014020140201402013020130201302013020
010c00001f12020100201200010014120001001f1200010020120001001f1200010014120141201b100161001f1201b10220120191001412019100131201b1051d1221d1221d1221d12220122201222012220122
010c00001f22020200202200020014220002001f2200020020220002001f22000200142200020014020160301b0421b042230001900018040180401b0001b0051a0401a0401a0401a0401a0401a0401a0401a040
011c18001c0241c0201c0201c0201c0251c0051e0241e0201e0201e0201e0251e0051f0241f0201f0201f0201f0251f0051e0241e0201e0201e0201e0251e0050000000000000000000000000000000000000000
011c18002502425020250202502025025250052602426020260202602026025260002802428020280202802028025280002602426020260202602026025260000000000000000000000000000000000000000000
011c18000b0200b0250b00012020120000d0240b0200b0250b00012022120000d0240b0200b0250b00012020120000d0240b0200b0250b00012020120000d0200000000000000000000000000000000000000000
af2800000203002030020300203002030020300203002030040300403004030040300403004030040300403007030070300703007030070300703007030070300503005030050300503005030050300503005030
a02800000e2301323016230152301523015230152301523010230132301623018230182301823018230182301a230182301623015230152301523015230152301623018230162301523015230152301523015230
__music__
01 3d4b4c44
02 3d3c3b44
01 39384344
00 3a374344
00 36354344
00 36344344
00 33424344
02 32424344

