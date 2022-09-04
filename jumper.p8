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
curr_lantern = 12

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
				if (val == 82) then
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
	if (x<room.x or x>room.x+room.sz) then
		return false
	end
	if (y<room.y or y>room.y+room.sz) then
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
	if (oldi != room.i) then
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
			if (fget(val,4)) then
				local t = spawn_thang(val,x*8,y*8)
				max_z = max(t.z, max_z)
				mset(x,y,t.replace)
				if (t.bad) then
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
	if (fade_timer == 12) then
		spawn_p_at_curr_lantern()	
	elseif (fade_timer > 23) then
		fade_timer = 0
		return false
	end
	fade_timer += 1
	return true
end

function _update()
	--dbgstr = ''
	--dbgstr = room.num_bads
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
	if (not (t.rght == nil)) then
		flp = not t.rght
	end
	spr(t.s+t.fr,t.x,t.y,1,1,flp)
end

function draw_frog(t)
	if t.angry then
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
	if (not (t.rght == nil)) then
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
	  if (t.z == z) then
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
		if (fade_timer < 4) then
			draw_fade(28)
		elseif (fade_timer < 8) then
			draw_fade(29)
		elseif (fade_timer < 16) then
			draw_fade(30)
		elseif (fade_timer < 20) then
			draw_fade(29)
		elseif (fade_timer < 24) then
			draw_fade(28)
		end
	end

	if (dbg) then
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
		burn = burn_thrower,
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
		s_die = {s=3, f=4},
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
		s_die = {s=4, f=4},
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
	}
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

function burn_thrower(t)
	if (not t.burning) then
		sound(sfx_dat.hit)
		t.hp -= 1
		t.fr = 0
		t.fcnt = 0
		t.burning = true
		if (t.hp <= 0) then
			t.alive = false
		end
	end
end

function update_thrower(t)
	if not t.alive then
		t.stops_projs = false
		t.s = t.i + t.s_die.s
		if play_anim(t, 6, t.s_die.f) then
			del(thang, t)
			room.num_bads -= 1
		end
		return
	end

	if t.burning then
		t.throwing = false
		t.s = t.i + t.s_burn.s
		if play_anim(t, 6, t.s_burn.f) then
			t.burning = false
			t.fcnt = 0
			t.fr = 0
			t.s = t.i
		else
			return
		end
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
		-- remember which way we were going
		t.rght = t.goingrght
		if t.rght then
			t.vx = 0.75
		else
			t.vx = -0.75
		end

		t.s = t.i + t.s_wlk.s
		loop_anim(t,4,t.s_wlk.f)

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

	local oldair = t.air

	t.vy += t.g
	t.vy = clamp(t.vy, -t.max_vy, t.max_vy)

	local newx = t.x + t.vx
	local newy = t.y + t.vy

	newy = phys_fall(t,newx,newy)

	local turned = false
	if t.air then
		t.vx = 0
		newx = t.x
	else
		local pushx = phys_walls(t,newx,newy)
		if pushx != newx then
			turned = true
			t.rght = not t.rght
			newx = pushx
		elseif coll_room_border(t) then
			turned = true
			t.rght = not t.rght
		elseif coll_edge_turn_around(t,newx,t.y+t.h) then
			turned = true
			newx = t.x
		end
	end
	if turned then
		t.goingrght = t.rght
	end

	t.x = newx
	t.y = newy

	if coll_spikes(t) then
		sound(sfx_dat.hit)
		t.alive = false
		t.fcnt = 0
		t.fr = 0
		t.s = t.i + t.s_die.s
		return
	end
	if p.alive and hit_p(t.x,t.y,t.w,t.h) then
		kill_p()
	end
end

function burn_frog(t)
	if t.alive and not t.burning and not t.angry then
		sound(sfx_dat.hit)
		t.hp -= 1
		t.fcnt = 0
		t.fr = 0
		if (t.hp <= 0) then
			t.alive = false
		else
			t.burning = true
		end
	end
end

function update_frog(t)
	if not t.alive then
		t.stops_projs = false
		t.s = t.i + t.s_die.s
		if play_anim(t, 6, t.s_die.f) then
			del(thang, t)
			room.num_bads -= 1
		end
		return
	end

	local oldair = t.air

	if t.burning then
		t.s = t.i + t.s_burn.s
		if play_anim(t, 8, t.s_burn.f) then
			t.burning = false
			t.angry = true
			t.jcount = 3
		else
			return
		end
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
				dbgstr = 'croak\n'..dbgstr
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
	t.vy += t.g
	t.vy = clamp(t.vy, -t.max_vy, t.max_vy)

	local newx = t.x + t.vx
	local newy = t.y + t.vy

	if (t.vy > 0) then
		newy = phys_fall(t,newx,newy)
	else
		newy = phys_jump(t,newx,newy,oldair)
		-- tile directly above preventing jump - jump tiny instead
		if t.vy == 0 and t.air == false then
			-- gotta redo everything here - keep vx the same
			t.air = true
			t.vy = t.jtiny_vy + t.g
			newy = t.y + t.vy
			newy = phys_jump(t,newx,newy,oldair)
		end
	end

	-- bounce off wall
	local oldvx = t.vx
	local pushx = phys_walls(t,newx,newy)
	if pushx != newx then
		t.rght = not t.rght
		t.vx = -oldvx
		t.bounced = true
	end
	newx = pushx

	t.x = newx
	t.y = newy

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
	if not t.air and oldair then
		t.s = t.i + t.s_idle.s
		t.fr = 0
		t.fcnt = rnd({0,10,20,30})
	end

	if coll_spikes(t) then
		sound(sfx_dat.hit)
		t.alive = false
		t.fr = 0
		t.fcnt = 0
		t.s = t.i + t.s_die.s
	end

	if p.alive and hit_p(t.x,t.y,t.w,t.h) then
		kill_p()
	end
end

function burn_knight(t)
	if t.hp <= 0 then
		return
	end
	if t.atking and t.fr > 0 and not t.burning then
		sound(sfx_dat.hit)
		t.hp -= 1
		t.fr = 0
		t.fcnt = 0
		t.burning = true
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

	if not t.alive then
		t.stops_projs = false
		t.s = t.i + t.s_die.s
		if not t.air then
			if (play_anim(t, 10, t.s_die.f)) then
				-- get shorter so fireballs don't hit air
				t.h = 3
				t.cy = 4.99
				room.num_bads = 0
			end
			-- don't want to keep doing physics when dead
			-- this would break if he was on an ice block and you broke it
			return
		end
	end

	local oldatking = t.atking

	if t.burning then
		t.s = t.i + t.s_burn.s
		if t.fcnt >= 10 then
			t.atking = false
			t.burning = false
			t.fcnt = 0
			t.fr = 0
			if t.hp <= 0 then
				t.alive = false
			end
		else
			t.fcnt += 1
			return -- 'freeze' when hit in the air
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

	local oldair = t.air

	t.vy += t.g
	t.vy = clamp(t.vy, -t.max_vy, t.max_vy)

	local newx = t.x + t.vx
	local newy = t.y + t.vy

	if t.vy > 0 then
		newy = phys_fall(t,newx,newy)
	else
		newy = phys_jump(t,newx,newy,oldair)
	end

	local oldvx = t.vx
	local pushx = phys_walls(t,newx,newy)
	local hit_screen_edge = coll_room_border(t)
	local turned = false
	if pushx != newx or hit_screen_edge then
		turned = true
		-- bounce off wall in air
		if t.air then
			t.rght = not t.rght
			t.vx = -oldvx
		-- otherwise just turn around
		else
			t.rght = not t.rght
		end
	end
	newx = pushx

	t.x = newx
	t.y = newy

	-- turn around if walking off edge of platform
	-- note can still fall off if moving fast enough
	if not turned and not t.air then
		if coll_edge_turn_around(t,newx,t.y+t.h) then
			turned = true
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
			--dbgstr = 'checking swrd_hit\n'..dbgstr
			if hit_p(t.x + swrd_start_x, t.y + t.swrd_y, t.swrd_w, t.swrd_h) then
				kill_p()
				t.phase = 0
			end
		else
			--dbgstr = 'NOT swrd_hit\n'..dbgstr
		end
	end
end

function burn_bat(b)
	if (b.alive) then
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
	if (t.fcnt >= speed) then
		t.fcnt = 0
		t.fr += 1
		if (t.fr >= frames) then
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
	if (loop_anim(t,speed,frames)) then
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
	if (not b.alive) then
		b.deadf -= 1
		if (b.deadf == 0) then
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
	if move_hit_wall(b) or coll_room_border(b) then
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
	if (b.vx > 0) then
		b.rght = true
	else
		b.rght = false
	end

	if (p.alive and
	    hit_p(b.x,b.y,b.w,b.h)) then
		kill_p()
	end
end

function burn_lantern(l)
	if (not l.lit) then
		l.lit = true
		l.s += 1
		lantern[room.i+1].lit = true
		curr_lantern = room.i+1
	end
end

function update_lantern(l)
	if (l.lit) then
		loop_anim(l,5,2)
	end
end

function spawn_thang(i,x,y)
	local t = {}
	t.i = i
	t.x = x
	t.y = y
	t.cx = 0
	t.cy = 0
	t.hx = 0
	t.hy = 0
	t.vx = 0
	t.vy = 0
	t.s = i
	t.fr = 0
	t.fcnt = 0
	t.draw = draw_thang
	t.burn = no_thang
	t.stops_projs = true
	t.replace = 0
	t.w = 8
	t.h = 8
	t.cw = 8
	t.ch = 8
	t.hw = 8
	t.hh = 8
	t.z = 0
	t.rght = true
	t.alive = true
	for k,v in pairs(thang_dat[i]) do
		t[k] = v
	end
	if (t.init != nil) then
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
}
end

function sound(snd)
	sfx(snd.sfx)
end

function spawn_p(x,y)
	p = {}
	p.x = x
	p.y = y
	p.rght = true -- facing
	p.vx = 0
	p.vy = 0
	p.air = true -- must start in air!
	p.onice = false
	p.fr = 0 -- displayed frame offset
	p.fcnt = 0 -- counter for advancing frame
	p.shcount = 0 -- shoot counter
	p.sh = false -- charging fireball
	p.teeter = false
	p.alive = true
	p.spawn = true
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
	return aabb(
				x,y,w,h,
				p.x+p.hx,p.y+p.hy,
				p.hw,p.hh)
end

function update_p()
	if (p.spawn or not p.alive) then
		respawn_update_p()
		return
	end

	-- change direction
	if (btnp(⬅️) or
		btn(⬅️) and not btn(➡️)) then
		p.rght = false
	elseif (btnp(➡️) or
		btn(➡️) and not btn(⬅️)) then
		p.rght = true
	end
 
	if (not p.sh) then
		local ax = 0
		if (p.air) then
			ax = p.aax
		elseif (p.onice) then
			ax = p.iax
		else
			ax = p.gax
		end
		if (btn(⬅️) and not p.rght) then
			-- accel left
			p.vx -= ax
		elseif (btn(➡️) and p.rght) then
			p.vx += ax
		end
	end
	if (p.sh or (not btn(⬅️) and not btn(➡️))) then
		if (p.air) then
			p.vx *= p.adax
		elseif (p.onice) then
			p.vx *= p.idax
		else
			p.vx *= p.gdax
		end
	end
	p.vx = clamp(p.vx, -p.max_vx, p.max_vx)
	if (abs(p.vx) < p.min_vx) then
		p.vx = 0
	end

	-- vy - jump and land
	local oldair = p.air
	if (btnp(🅾️) and not p.air and not p.sh) then
		sound(sfx_dat.p_jump)
		p.vy += p.j_vy
		p.air = true
	end
	if (p.sh and p.vy > 0) then
		p.vy += p.g_sh
	else
		p.vy += p.g_norm
	end
	p.vy = clamp(p.vy, -p.max_vy, p.max_vy)

	local newx = p.x + p.vx
	local newy = p.y + p.vy

	if (p.vy > 0) then
		newy = phys_fall(p,newx,newy)
		-- fall off platform only if
		-- holding direction of movement
		-- kill 2 bugs with one hack
		-- here - you slip off ice,
		-- and fall when it's destroyed
		if (not p.onice and not oldair and p.air) then
			if ((btn(⬅️) and p.vx < 0) or
				(btn(➡️) and p.vx > 0)) then
			else
				p.air = false
				newx = p.x
				newy = p.y
				p.vy = 0
				p.vx = 0
			end
		end
		if oldair and not p.air then
			sound(sfx_dat.p_land)
		end
	elseif (p.vy < 0) then
		newy = phys_jump(p,newx,newy,oldair)
	end

	newx = phys_walls(p,newx,newy)

	-- close to edge?
	p.teeter = not p.air and coll_edge(p,newx,newy+p.fty)

	p.x = newx
	p.y = newy

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
			if (btn(⬆️)) then
				ydir = -1
			elseif (btn(⬇️)) then
				ydir = 1
			end
			if (btn(⬅️)) then
				xdir = -1
			elseif (btn(➡️)) then
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
	if (p.shcount > 0) then
		p.shcount -= 1
	end

	-- animate
	if (p.sh) then
		p.s = p.i + p.s_sh.s
		if (not oldsh) then
			sound(sfx_dat.p_shoot)
			p.fr = 0
			p.fcnt = 0
		end
		if loop_anim(p,3,p.s_sh.f) then
			sound(sfx_dat.p_shoot)
		end

	elseif (not p.air) then
		-- walk anim
		p.s = p.i + p.s_wlk.s
		-- just landed, or changed dir
		if (oldair or btnp(➡️) or btnp(⬅️)) then
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
		elseif (p.teeter) then
			p.fr = 1
		else
			p.fr = 0
		end

	else --p.air
		p.s = p.i + p.s_jmp.s
		if (not oldair) then	 
			p.fr = 0
			p.fcnt = 0
			-- fell, not jumped
			if (not btn(🅾️)) then
				p.fr = 5
			end
		end
	-- jump anim
		if (p.fcnt > 2) then
			p.fr += 1
			-- loop last 2 frames
			if (p.fr >= p.s_jmp.f) then
				p.fr -= 2
			end
			p.fcnt = 0
		end
		p.fcnt += 1
	end
end

function respawn_update_p()
	if do_fade then
		return
	end
	if (not p.alive) then
		if (play_anim(p,2,p.s_die.f)) then
			fade_timer = 0
			do_fade = true
		end
	elseif (p.spawn) then
		if (play_anim(p,2,p.s_spwn.f)) then
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
	local f = {}
	f.w = 4
	f.h = 4
	f.x = p.x + (p.w - f.w)/2
	f.y = p.y + (p.h - f.h)/2
	f.s = 80
	f.alive = true
	f.fcnt = 0
	f.speed = 3
	f.fr = 0
	f.draw = draw_smol_thang
	f.update = update_fireball
	if (xdir == 0 or ydir == 0) then
		f.vx = xdir * f.speed
		f.vy = ydir * f.speed
	else
		f.vx = xdir * 0.7071 * f.speed
		f.vy = ydir * 0.7071 * f.speed
	end

	f.sfr = 0 -- sub-frame
	if (ydir == 0) then
		f.sfr = 1
	elseif (xdir == 0) then
		f.sfr = 2
	else
		f.sfr = 3
	end
	f.xflip = false
	f.yflip = false
	if (f.vy < 0) then
		f.yflip = true
	end
	if (f.vx < 0) then
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
	if (not f.alive) then
		f.y -= 0.5
		f.fcnt += 1
		if (f.fcnt & 1 == 0) then
			f.sfr += 1
		end
		if (f.fcnt == 8) then
			del(fireball, f)
		end
		return
	end
	f.x += f.vx
	f.y += f.vy
	-- hit stuff
	for t in all(thang) do
		-- use hurt box if t has one
		if (aabb(
				t.x + t.hx, t.y + t.hy, t.hw, t.hh,
				f.x,f.y,4,4)) then
			-- todo - is alive the right check?
			if (t.burn != nil) then
				t:burn()
			end
			-- don't stop on lanterns
			-- or already dead stuff
			if (t.stops_projs) then
				kill_fireball(f)
				return
			end
		end
	end
	-- hit blocks
	-- check two points to make it harder to abuse shooting straight up/down past blocks
	if (
			collmap(f.x+3,  f.y+2, 1) or
			collmap(f.x+1,  f.y+2, 1)) then
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
	-- turn around if foot is close to edge, and facing off edge
	-- and return true if we turned it around
	local tftxl = newx + t.ftx
	local tftxr = tftxl + t.ftw
	if t.rght then
		if not collmap(tftxr+1,fty,0) then
			t.rght = false
			return true
		end
	else
		if not collmap(tftxl-1,fty,0) then
			t.rght = true
			return true
		end
	end
	return false
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
	if (not (collmap(tftxl-1,fty,0) and
			collmap(tftxr+1,fty,0))) then
		return true
	end
	return false
end

function coll_spikes(t)
	local hl = t.x + t.hx
	local hr = hl + t.hw
	local ht = t.y + t.hy
	local hb = ht + t.hh
	if (	collmap(hl,ht,3) or
			collmap(hr,ht,3) or
			collmap(hl,hb,3) or
			collmap(hr,hb,3)) then
		return true
	end
	return false
end

function coll_walls(t,newx)
	-- t = {
	--   y  -- coord
	--   cx -- coll x offset
	--   cw -- coll width
	--   cy -- coll y offset
	--   ch -- coll height
	--   vx -- x vel
	-- return newx pushed out of wall
	local cl = newx + t.cx
	local cr = cl + t.cw
	local ct = t.y + t.cy
	local cb = ct + t.ch
	-- only check left or right
	local cx = cr
	if (t.vx < 0) then
		cx = cl
	end
	if (	(t.vx != 0)
			and
			(collmap(cx,ct,1) or
			collmap(cx,cb,1))
			) then
		-- push out of wall
		if (cx == cl) then
			newx = roundup(cx, 8) - t.cx-- - 1
		else
			newx = rounddown(cx, 8) - t.cw - t.cx + 1
		end
	end
	return newx
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

	if (	collmapv(c_tl,1) or 
			collmapv(c_tr,1) or
			collmapv(c_bl,1) or 
			collmapv(c_br,1)) then
		return true
	end
	return false
end

-- TODO currently NOT USED
function move_coll(t)
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
	-- return {x, y} pushed out of wall

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

	local x_pen = 0
	if (t.vx < 0) then
		if (	collmapv(c_bl,1) or 
				collmapv(c_tl,1)) then
			x_pen = cl - roundup(cl,8) -- < 0
		end
	elseif t.vx > 0 then
		if (	collmapv(c_br,1) or 
				collmapv(c_tr,1)) then
			x_pen = cr - rounddown(cr,8) -- > 0
		end
	end

	local y_pen = 0
	if (t.vy < 0) then
		if (	collmapv(c_tl,1) or 
				collmapv(c_tr,1)) then
			y_pen = ct - roundup(ct,8) -- < 0
		end
	elseif t.vy > 0 then
		if (	collmapv(c_bl,1) or 
				collmapv(c_br,1)) then
			y_pen = cb - rounddown(cb,8) -- > 0
		end
	end

	return {x = newx - xpen, y = newy - ypen}
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
	if (t.vx < 0) then
		cx = cl
	end
	if (	(t.vx != 0)
			and
			(not in_room(cx,ct) or
			not in_room(cx,cb))
			) then
		return true
	end

	local cy = cb
	if (t.vy < 0) then
		cy = ct
	end
	if (	(t.vy != 0)
			and
			(not in_room(cl,cy) or
			not in_room(cr,cy))
			) then
		return true
	end

	return false
end

-->8
-- physics for platformu

-- t.vy > 0
function phys_fall(t,newx,newy)

	-- where our feeeeet at?
	local fty = newy + t.h
	local ftxl = newx + t.ftx
	local ftxr = ftxl + t.ftw

	local stand_left = collmap(ftxl,fty,0)
	local stand_right = collmap(ftxr,fty,0)

	-- hit or stay on the ground
	if (	(stand_left or
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
			) then
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
	if (	t.air and (
				collmap(hdxl,hdy,1) or
				collmap(hdxr,hdy,1))) then
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
	if (	collmapv(c_bl,1) or 
			collmapv(c_tl,1)) then
		l_pen = roundup(cl,8) - cl
	end
	if (	collmapv(c_br,1) or 
			collmapv(c_tr,1)) then
		r_pen = cr - rounddown(cr,8)
	end
	
	local oldnewx = newx
	if (t.vx < 0) then
		newx += l_pen
	elseif (t.vx > 0) then
		newx -= r_pen
	else
		if (l_pen > 0) then
			newx += l_pen
		elseif (r_pen > 0) then
			newx -= r_pen
		end
	end

	if (oldnewx != newx) then
		t.vx = 0
	end

	return newx
end

__gfx__
00000000dddddddddddddddddddddddddddddddd05555550000000000555555011111111111111113101001301010110dddddddddddddddd0111111001111110
000000000dddddd00dddddddddddddddddddddd0115551510000000015515155111dd1111111111131011110100110330dddddddddddddd00015510001111110
000000000111111001111110000000000111111055151555000000005555551101dddd10111dd111010110101001133300000000000000000011110001111110
00000000011001100110011111111111111001101551515111111111551151510111111001dddd10010110131011131001111111111111100000000001555510
00000000010000100100001000000000010000101155511100000000155511510000000001111110010111131111001300000000000000000000000001555510
00000000001111000111111001100110011111101515151101100110111115550000000001dddd10010101100101001301100110011001100000000001555510
00000000000000000100001111111111110000101111151111111111151155110000000001dddd10010111103301011000111111111111000000000001555510
00000000000000000100001000000000010000100151111000000000011115100000000001dddd10110110100301011300000000000000000000000001555510
dddddddddddddddddddddddddddddddddddddddddddddddd11111111dddddddd0111111001dddd10010100100101011010101010111111111111111101555510
0dddddddddddddddddddddddddddddd00dddddd00dddddd0001000000dddddd01111111d01dddd10330100103101011001010101010101011111111101555510
01111111111111111111111111111110011111100111111000100000011111101d11d1dd01dddd10333100133301011310101010111111111111111101555510
011ddd11111111111111111111ddd110011dd1100110011000000000011dd110111ddd1d01dddd10013100010101011001010101010101011111111101555510
01ddddd1ddddd1dddd1dd1dd1ddddd1001dddd10010000101111111101dddd101ddddddd011dd110010110010101011010101010111111111111111101555510
01111111ddddd1ddddd1d1dd11111110011111100111111000000100011111101dd1d1dd01d11d10310110100101011001010101010101011111111101111110
01d1d1d1ddddd1dddddd11dd1d1d1d1001dddd10010000100000010001dddd1011d1dddd1dddddd10101111001010110101010101111111111111111011dd110
01d1d1d111111111111111111d1d1d1001dddd100100001000000000011111100dddddd011111111010111100101011001010101010101011111111100111100
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd100100001000000000dddddddddddddddd00000000010101100101011001010110dddddddd0000000000000000
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd1001000010111111110dddddddddddddd0000000003101011031010110310101100dddddd00000000000000000
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd100100001011111111011111111111111000000000310101133101011331010113011111100000000000000000
01d1d1d111111111111111111d1d1d1001dddd100100001000000000011ddd1111ddd11000000000010101100111011101010111011dd1100000000000000000
01d1d1d1ddddd1ddddddd1dd1d1d1d1001dddd10010000100110011001ddddd11ddddd100000000001010110011101110101011101dddd100000000000000000
01d1d1d1ddddd1ddddddd1dd1d1d1d1001dddd100100001000000000011111111111111000000000013131303101011031013113011111100303003003030030
01d1d1d1ddddd1ddddddd11d1d1d1d1001dddd10010000101111111101d1d1d11d1d1d100030300303310110013131300131331331dd3d133003303330033033
01d1d1d111111111111111111d1d1d1001dddd100100001000000000011111111111111030330033333313133331331333333333331333333033330333333333
01d1d1d1dd1d1ddddd1ddddd1d1d1d1001dddd10010000100003000001d1ddddd1dddd10155555555555555555555555dddddddddddddddd55555551dd1d1ddd
01d1d1d1dd1dd11ddd1ddddd1d1d1d1001dddd10010000100033300001d1ddddd1dddd10d155555111111111155555510dddddddddddddd01555551ddd1dd11d
01d1d1d1dd1dddd1dd1ddddd1d1d1d10011dd110011001100333330001d1ddddd1dddd10d1111515551115555511151501111111111111105511151ddd1dddd1
01d1d1d111111111111111111d1d1d1001d11d1001011010333333300111111111111110155511115551115555551111011dd111111dd1105555111111111111
011ddd11ddddd1ddddddd1dd11ddd11001dddd1001000010003330001ddddd1ddddd1dd1d1555551555511115555555101dddd1dd1dddd1055555551ddddd1dd
dd11111dddddd1dddddd11ddd11111dd1d1111d110111101003330001ddddd1ddddd1dd1d111115511111511111111550111111dd11111101111111dddddd1dd
1dddddddddddd1ddddd1d1dddddddddd1dddddd110000001003330001ddddd1ddddd1dd1111115555511151511111555011dd11dd11dd1101111151dddddd1dd
11111111111111111111111111111111111111111111111100333000111111111111111111111111555555551111111101111111111111101111111111111111
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
0000000000000000000000b0bb00000000000e0000000000000700700070070000666e00000666e0000666e000ee0080dddddddddddddddd00670001d0060000
000000000000000000000b8b03b000000000e7e000007007000a00a0000aaa0000611ee0006611ee006611ee0ee7e08801d111d001d11d10000066d1d1600000
00000b0000000b000004bbb300b0000000eeee200000a97a00709a9007099000066112e00666112e0666112e0ee77e88061116000611116000000dd1dd166760
0000b8b00000b8b0004443b000b400b00000ee00007098a870a9989000a900000666122006666122066661220eee7588060600706006060667666d11d1100000
00bbbb3000bbbb3000b400b000444b8b0008820000a99895a09890000000000006665220666665226666652200eee588700606067006060000000dd1d1166000
04443b0004443b300bb300000004bbb300e880000a8585500a9800000000000066665220666665226666652200eeeee86006070000600700007606d1dd100676
04443b0004443b00b3000000000003b0ee002000799500500000000000000000666662206666602266666022000eeee80007006000700600660070d1d1600000
003bb0b0003bb0b0b0000000000000b00022000008550000000000000000000000550200500500200550002000050050000600600060000000060001d0067000
410042b370a3b350b370a3a350417041836161616161616161616165757312121213221223122212131222121223121212121312122212231213121212131222
12121323221222132322221223221222832213232212221323222212232212221212231312222312121222121213232222231323121222131212231222121312
42104250b3a370a350b3507070420042836172111111828100000000006575733100000000000000000000000000007383000000000065000000000000000001
82756500516060606060605100000073830051000000000000000000005100738300000000000000000000007565750131000000000075657565656565656501
420042507050b350b3a3507000430043836141d7c7d7c7000000000000007573328100008100008100008100008100800000000000c030d00000000000000002
83650000526161616161615200000080e00052000000000000000000005200800000000000000000006100000065650232000000000000007575757565657502
42004270700050505000500000000080006142000000000000007500000000733200000000070000000000250000000000000000000000000000000000000002
83000006526161616161615200000000000052000000002500000000005200000000000025000000616161000000750232000000000000000000657565756502
42104350000000700000000000250000006142000075000000006500000000733265721111111111112111111111820131000010000000000010000000000002
83060000526161616161615200001072820052c03030303030303030d05200723130303030d00061616161610000000232000000000000000000000075656502
420000e0000000000000000041413041828143000065000000000000000065733200000000000041000000000071000232000000000000000000000000000002
83000000526161616161615200000073831052000000000000000000005210123200000000000000616161000000000232000000000000000000000000006502
420000000000000000000000424200428300000000000065000000000075657332000000000000430000000000e0000232000000000000000000000000000002
83000000526161616161615200756573830052000000000000000000005200733200000000000000616161000000000232000000000000000000000000007502
42104141000000000000000042420042830000650000007500000000816575733200000000000065000000000000000232000000000000000010000000000002
83000000536161612561615365650073830053060000000000000000005300733200000061000000616161000000000232000000000000000000000000007502
42004242000000000000000042420042830000000000000000000000000065733230303030303041303030303041600232000000005100000000000000000002
83000000c3112111111111d375000073837572111111111111111111118265733200006161616161000000000000000232000000000000000000000000000002
42004242000000000000000042420042830000000000000000000000000075733200000000000042000000000042610232000000005200000000000000000002
83000000000000000000000000000073836161616161616161616161610000733200616161616161000000000000000333000000000000000000000000000002
42004242005100000000510042420042830000750000006575000000000000833207000000000043060007000043610232005100005200000000000000000002
83000000000000000000000000000073836161616161616161610000616161733200006161616161000000000000008065000000000000000000000000250002
420043430053000c00005300434300428300008100000000000000000000007333c31111111111111111111111d3610232625262625262626251626262256202
83000000070000000000000000000073831061610000610600616100616110733200000061000000000000000000000075650000000000000000000072218202
4200c030303030303030303030d00042830000000000000000000000250000800052616161616161616161616152610232615261615261616152616141303003
836161616161616161616161616161738361616161616161616161616161617332000000000000000000c0303030300131756500000000000000007173138302
42000000000000000000000000000042830000000000000000000000710000000053616161616161616161616153610232615220405261616152616142616180
e0616161616161616161616161616173830661106161616161616106106161733261616161616161616161616161610232756575000000000000717323228302
43e6f6e6f6e6f6e6f6e6e6f6e6f6e64383f6e6f6e6f6e6f6e6f6e6f6818181817211211111111111112111111111820333e6f6e6e6e6f6f6e6e6e6f643616100
006161617161616161616172111182738361616161616100616161616161617333e6f6e6f6e6f6e6f6e6f6e6f6e6f60333006575750075657571731322128303
12121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121211111111111111111111111111111111
11111121111111111111211111111121111111211111111111112111111111211111111111211111111111112111111111112111211111211111111111211111
0066dd000066dd700066dd70066d700000066dd00066dd000000000000066dd00066dd000066dd70077ee700066dd00000000000000000000000000000000000
00dffd0000dffd7000dffd700dff7000000dffd000dffd000066dd00000dffd000dffd0000dffd700eaae7000dffd0000066dd00000000000007000000000000
00d66d0022226d6022226d6022226000222d66d022d66d0000dffd70222d66d022d66d0022226d608877ee002222d00000dffd00000000000070000000000000
2222ddf02982d4442982d44429824400222dddd022dddd0022226d70222dddd022dddd002982d44488eee8802982d04022226d00000000004600000040000000
2982dd442892ddf02892ddf02892f00022fddddd2fdddddf2982dd6022fddddd2fdddddf2892ddf088eeea002892df462982dd0000000000f400000046770000
2892556029825500298255002982500022255500225550002892d44422255500225550002982550088999000298250402892dd400022226d0000000040000000
298205700225500002250500022005000205005002500500298255f0020505000250050002205050089009000220050029825f46029892dd0000000000000000
02200570000550000050050000500500005000500500050002250500005050000500050000005050009009000050050002250540528982fd0000000000000000
00444000004440000044400000444900004440000044409000000000000444900004449000444900004440000044409000222900004440000000000000000000
004ff090004ff900004ff090004ff090004ff990004ff009000444900004ff090004ff09004ff090004ff990004ff009002aa090004ff0000004440000000000
0015500900155090011550090115500901155009011550090004ff090001550901115509011550090115500901155009099ee090011550000004ff0000000000
011550090115509011555009155f555f55f5555f55f5555f01155509011f555f111f555f155f555f55f5555f55f5555f99eeeea0115550090011550000000000
0115555f011f55f011f5555f1155500911555009115550091155555f11115509111155091115500911155009111550099eeee090155550090115550000000000
01122009011220901122200911222090112229901122200911f522091111222901112229011222900112299001122229a98880901f2225f90155550000111100
011020090112009011202009112009001120020011200290111222090010209001002090011129200111202001112090999809001112029001f2222901111114
00202090002209000200209002000200020002000200020001122090000020200000202000102020001020200010202009008080010292000111222022111544
00c6600000c6600000c6600400624000221000000010000000000000000000000000000000000000000666000006660000066c0000066600000666c00ee00800
0c66f6040c66f6400c66f60406214200126200000220000000000000000000000000000000000000006116c000611600006116c000611cc00061160ce77e0080
0cfbf0040cfbf0400cfbf00f0c2164214212210021020000002201100002100000000000000000000061160c006116c00061160c0061160c0061160ce77e0080
0c6ff6040c6ff640fc6ff6c4021f62102462121001000000021010000000000000000000000000000066660c006666c0066266626626666266266662eeeeee90
cc6666cffc6666f0cc666604116662101121c212000120110010020000000010000000000000000006666662066666200066660c0066660c0066660c0eee0080
fcc66604ccc666400cc66604fcc621400214210200100201010002000200200000000000000000000266660c062666c0006666c000666cc00066660c9eeee080
0ccc60040ccc60400ccc60040cc2100411c21c2100000210000020000100000000000000000000000055550c005555c000555c0000555500005555c009999800
ccccc004ccccc040ccccc000021ccc000021c1100000200000000000000000000000000000000000005005c000055c0000500500005005000050050000900900
00cc9c04000c6600000c6600000000000006600000000000000660000000000000000000000c6600000c66000000000000666000000060000011111000222200
0009190400c66f6000c66f6000000000006006006006600060600600666660000000000000c66f6000c66f6000000000061166000696c666000119f100223040
00c9190400cfbf0000cfbf0000000000606dd6606060d660060dd660000dd6000000000000cfbf0000cfbf000000000009916600666cc55600099ff900233304
0c9111cf0cc6ff600cc6ff6f0000000006d0662006d6662000d6d620dd666620000000000cc6ff600cc6ff6f000000009aa966600ccccc560099119003333004
c0c999040cc666600cf66660000000000d66d2120d60d2120d6d6212000dd212000000000cc666600cf66660000000009aa966c665cccc554011111030999334
f0cccc040cfc666f0cccc66000000000d0006d200d006d20d0066d2006666d20000000000cfc666f0cccc660000000009accccc555cccc05441111f430999004
00cccc040cccc6000cccc6000000000000660d00d066d0000060d00000dddd00000000000cccc6000cccc60000000000099666c0505c55004001010000903004
0ccccc04cccccc00cccccc00000000000000d000000d0000000d00000000000000000000cccccc00cccccc000000000000500500000505000010100000303040
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
0001010101030003100300000101100303030303030100030303000000000003030303030300000303000000000300000303030303000003030303030303030300000000000000000000000000000000000011010101131300000000000000001000000010000000101010000000080810101010101010100000000008080808
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000002121212121212121212121212121212121212121212131212121212121212121212121212121212121212121212222222222223816161616161616162121312221322122213121222121322121213122213221222131212221213221211411111111111111121111111111111121212222222222222221212121212121
0052000000000000000000000000001013000000000000000000000000000000380000000000000000000000000000141300000000000000000060000000001013000000000000000000000000000013130000000000000000000000000000372400000000000000000000000000000021161616161616161616161616161621
23000000000000000000210000000020230000000000000000000000000000000e000000000000000000000000000024230000000000000000000000000000202300000000700000000000000000003323000000000000000000000000000008240000000056000000560000000000000e161616161616161616161616161621
2303040000000000000021001506062023000000000000000000000000000000000000000000000000000000000000242300000000000000000064000000002023000000000000000000000000520057230000000000000000000000000000002400000000000000000000000000000021161616161616161616161616161621
2316250000000000000000002516162023000000000000000000000000000000140303030303030303030303030303242300000000000100000001000000002023562711111111111111111111111156230000000000000000000000000000102400000000000000000000000000005221640000000000000000000000640021
231625000000020303040000251616202300000060000000000000000000000024000000000000000000000000000024230000000000000000000000000060202300007d000000007d000000007d0013230000000000000000000000520000202400000000000000000000000056561421565600000000640000000056560021
2316250000002516162500003526262023000000000000000000006000007e27240100640000000000000064000000242300000000000000000000006f000020230000000000000000000060000000232300000000000000000000003c113d202400005600000056000000560000002421000000150056565600150000000021
23162500000125161625000203030320237f0000000000000000000000007e202400000000000000000000000000002423000001000000000000007e187f002023000000000000000000000000000023235600000056005600000056252625202400006e6e6e6e6f6e6e6e6f6e6f6e2421000000350606060606350000000024
2316252100002516162500251616162023060606060606060606271228000030340000005600006417000000570000340800000000000000150000007c00002023000000000000000000000000000023230000000000000000000000250025202400003721212121212121212121212421006400262626262626260000000024
2316250100002516162500251616163033161616161616161616372238020304285757561456575624565756140303270000000000000000250000000000002023111111116e6e1111116e6e11115623230064000000000000640000356435203400002500000025000000240000002421565600640000150000000064000024
23263500000025161625002501161616161616161652161616167c7d25252500380000002400000024000000240000371300005200000000250000000000002023000000000c0d0000000c0d0000002323000203046e6f0203046e6f020304201111111128000025000000240000002421000000565600250064000056560024
230203030304251616250025161616161616161616151616161625253535350038000000240000002400000024000037230303030000001525000000006000202300000000000000000000000000002323162516250c0d2516250c0d251625200e00002500000025000000240000002421000000000000350056560000000024
232516161625251616250125101212131316161616251616161625352712281038000000240000002400000024030337230000000000002525000000000000200e000000000000000000000000000023331625162516162516251616251625200000002500000025640000240000002421060606060606150606060606060621
2325161602042516162500252021212323161616163516161614252721213820380000002400000024000000240000082300000000000025256000000000000e000000000000000070000000000000200e1625162516162516251616251625201400562556005625560000240000002421161616161616251616161616161608
33352626353535266e35003530212133336f6e6f142712281634353721213830386e6e6e346e6e6e346e6e6e34520000336e6e6f6e6f6e6f6e6f6e6f6e6f34001111111111111127112811112711113000000000000000000000000000000000346e6e6e6e6e6e6e6e6e6e342712283421265226262626352626262626262600
2121212121212121212121212121212121121212121212121212122121212121111111121111121112111212111211111212121212111212121212121212121221212121212121212121212121212121121212121212121212121212121212122121212121212121212121212121212111111111111111111111111111111111
23000025001a000b00000a002500002021212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121312121212121212121212121322121213238161616161616161616163721212121212121212121212121212121212100000000000000000000000000000000
23000025000a001a00000b002500002013161616161616161616161616161610213222322231381616161616161616371316161616005600000000000e00001013161616161637213816161616372110140000000000000000000000000000141400000000000000000000000000001400002121002100002200212100000000
23000025000b000a00001a002500002023161616161616161616161616161630213221213816161616161616161616372316161600005670000000000000563033161616161616161616161616163720240000000000000000000000000000242400000000000000000000006000002400002100002121002200210021000000
23000025002b001b00000a00250000202316161616161616161616161616160e080016001616000016161616161616372316160000003c11111211112800565608000000000000000000000000000020340000006400000000000000006400342400600000006000000000000000002400002121002100212200210021000000
23000025001a000b00001a00250000202300000000000000000000000000000000165200000000010000160000161637231660000000250000000037385656560000520000006e006e6e00000000002011113d030d0000000000000c033c11112400000000000000000000000000002400002100002100002200210021000000
23000035000b000b00002b00350000202300000000000000000000000002031028030d0000000000640000001600163723000c0d000025006000003c1111121113271111111111111111111111280020247d7d7d7d0000006400007d7d7d7d242400000000000000000000000000002400002121002100002200212100000000
23000014030303030303030314000020230000000000000000000000002500203800000000000000575600010000003723000000000025000000002500000010230000007c0018000000180000000020240000000000000c0d000000000000242400000000000000000000000060002400000000000000000000000000000000
23000024001a001a00001b0024000020230000000017006400001700002500203800000c0d0000000000000000160037336e6e6e6e003500000000350000002023000000000000000000000000000020240000000000000000000000000000242400000000000000000001140000002421210000212100210000002100002200
23000024000a001b00000b0024000020230000003c1111111111113d002500203800000000000000000000000000160e11111111111112111111113d5656562023006e00181616161616161616161620240000640000000000000000006400242400000000000000140000240000003421002100210000212100212100220021
23010024001a002b00000b002400012023000000250000000000002500250020380000010000006400006400001616000016161400000000007c7d256000002023001818141616166e1616166e161620240056565600000000000056565600242403030303140c0d240c0d240000002721002100212100210021002100220021
23000024002b001a00001a002400002023000000250000000000002500250020380000000000565700005718000c0d27131616240000000000600025000000202300007d3416166e186e166e186e1620240000000000000000000000000000242400000000240000240000240014003721002100210000210021002100220021
23000024001b001a00002b00240000202311113d25000000000000250025172038160c0d0000000000000000001616372316162416000000000000250015152023180000271111111111111111112820240000000000003c3d000000000000242400000000240c0d240c0d240024003721210000212100210000002100002200
23000124000b002b00000a002401003033000025250000000064002500252520381616000016000000000000161616372316163416161600000064151525252023000000372121380000003721213830340000000000002525000000000000343400001400240000240000240024003700000000000000000000000000000000
23000024002b000b00000b0024000000080000252500002711111128002525203816161616161616001600161616163723160016161616160015152525252520230000000000000000000000000000000800000000170025250017000000000e0801002400240c0d240c0d240024000e000000000000007c0000000000000000
332929342e2a2e2c292e2b293429000000005235350027212121212128353530386f6e6f6e6f6e6f6e6f6e6f6e6f6e373300520016161616166f6e6f6e6f6e303300001800000000180000000000000000005200002500252500250000700000000052346e347000340070346e34000000000000000000520000000000000000
310137213907073b3a073a3e21212121111111111111111111111111111111212121222222222222222121212121212111111111111111111112111111111112286e27286e27286e27286e27286e2711111111286e27286e6e27286e271211111111111211111211121112121112111121212121212121212121212121212121
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
00040000231201e13018150111500d1300811006110051101810014100121000e1000d10000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
000300002a120231301d14017140121300e1300a120061100511004110121000e1000d10000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
000300002a220232301d24017240122300e2300a220062100521004210122000e2000d20000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
90040000222201e2301925015250102300c21007210032101820014200122000e2000d20000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
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
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011c18001c0241c0201c0201c0201c0251c0051e0241e0201e0201e0201e0251e0051f0241f0201f0201f0201f0251f0051e0241e0201e0201e0201e0251e0050000000000000000000000000000000000000000
011c18002502425020250202502025025250052602426020260202602026025260002802428020280202802028025280002602426020260202602026025260000000000000000000000000000000000000000000
011c18000b0200b0250b00012020120000d0240b0200b0250b00012022120000d0240b0200b0250b00012020120000d0240b0200b0250b00012020120000d0200000000000000000000000000000000000000000
af2800000203002030020300203002030020300203002030040300403004030040300403004030040300403007030070300703007030070300703007030070300503005030050300503005030050300503005030
a02800000e2301323016230152301523015230152301523010230132301623018230182301823018230182301a230182301623015230152301523015230152301623018230162301523015230152301523015230
__music__
00 3d4b4c44
02 3d3c3b44

