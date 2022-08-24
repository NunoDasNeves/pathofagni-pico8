pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- jumper

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
curr_lantern = 9

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
	dbgstr = ''
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
	if t.burning then
		pal(11, 10, 0)
		pal(3, 9, 0)
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
	if (	t.s == (t.i + t.s_atk.s) and
			(t.fr == 1 or t.fr == 2)
			) then
		local sw_fr = t.fr - 1
		local xfac = flp and -1 or 1
		spr(t.i + t.s_swrd.s + sw_fr,
			t.x + (8 * xfac),
			t.y,
			1,1,flp)
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
		--dbgstr = dbgstr..tostr(p.x\8)..''..tostr(p.y\8)..'\n'
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
		shcount = 0, -- throw stuff at player
		range = 8*6, -- only throw at player in this range
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
		w = 8,
		h = 8,
		hp = 2,
		goingrght = true,
		burning = false,
		croak = false,
		bounced = false,
		-- coll dimensions
		ftw = 0.99,
		ftx = 3,
		ch = 4.99,
		cw = 5.99,
		cx = 1,
		cy = 2,
		jcount = 0, -- jump
	},
	[192] = { -- knight
		update = update_knight,
		burn = burn_knight,
		draw = draw_knight,
		bad = true,
		w = 8,
		h = 8,
		hp = 5,
		goingrght = true, -- going to go after attacking?
		burning = false,
		air = true,
		atking = false,
		g = 0.2,
		max_vy = 4,
		-- coll dimensions
		-- todo same as player..
		ftw = 0.99,
		ftx = 3,
		ch = 6.99,
		cw = 5.99,
		cx = 1,
		cy = 1,
		atkrange = 11, -- only attack player in this range
		s_idle = {s=0, f=0},
		s_wlk  = {s=1, f=2},
		s_atk  = {s=3, f=3},
		s_jmp  = {s=6, f=2},
		s_def  = {s=8, f=2},
		s_burn = {s=10, f=1},
		s_die  = {s=10, f=4},
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
	t.s = 88
	t.alive = false
	mset(t.x\8,t.y\8,0)
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

	if (collmap(t.x+2,t.y,1)) then
		kill_icepick(t)
	end

	if (p.alive and hit_p(t.x,t.y,t.w,t.h)) then
		kill_p()
		kill_icepick(t)
	end
end

function burn_thrower(t)
	if (not t.burning) then
		t.hp -= 1
		t.s = t.i + 3
		t.fr = 0
		t.fcnt = 0
		t.burning = true
		if (t.hp <= 0) then
			t.alive = false
		end
	end
end

function update_thrower(t)
	if (not t.alive) then
		if (loop_anim(t,2,4)) then
			del(thang, t)
			room.num_bads -= 1
		end
		return
	end

	if (t.burning) then
		t.throwing = false
		if (t.fcnt >= 4) then
			t.burning = false
			t.fcnt = 0
			t.fr = 0
			t.s = t.i
		else
			t.fcnt += 1
			return
		end
	end

	t.vx = 0

	if (t.throwing) then
		if (p.x < t.x) then
			t.rght = false
		else
			t.rght = true
		end
		local xfac = t.rght and 1 or -1
		t.fr = 2
		if (t.fcnt >= 20) then
			t.throwing = false
			spawn_thang(107,
						t.x - 3 * xfac,
						t.y + 4)
			t.fcnt = 0
			t.fr = 0
		else
			t.fcnt += 1
		end
	else
		-- remember which way we were going
		t.rght = t.goingrght
		if (t.rght) then
			t.vx = 0.75
		else
			t.vx = -0.75
		end

		loop_anim(t,3,2)

		if (t.shcount <= 0) then
			if (dist(p.x,p.y,t.x,t.y) <= t.range) then
				t.throwing = true
				t.fcnt = 0
			end
			t.shcount = 30
		else
			t.shcount -= 1
		end
	end

	t.vy += t.g
	t.vy = clamp(t.vy, -t.max_vy, t.max_vy)

	local newx = t.x + t.vx
	local newy = t.y + t.vy

	newy = phys_fall(t,newx,newy)

	if (t.air) then
		t.vx = 0
		newx = t.x
	else
		-- todo use phys_walls here
		local pushx = coll_walls(t,newx)
		if (pushx != newx) then
			t.rght = not t.rght
		end
		newx = pushx
		if (	coll_edge(t,newx,t.y+t.h) or
				coll_room_border(t)) then
			t.rght = not t.rght
			newx = t.x
		end
		t.goingrght = t.rght
	end

	t.x = newx
	t.y = newy

	if (p.alive and hit_p(t.x,t.y,t.w,t.h)) then
		kill_p()
	end
end

function burn_frog(t)
	if t.alive and not t.burning then
		t.hp -= 1
		if (t.hp <= 0) then
			t.alive = false
			t.s = t.i + 4
			t.fr = 0
			t.fcnt = 0
		else
			t.burning = true
			t.jcount = 3
		end
	end
end

function update_frog(t)
	if (not t.alive) then
		if (loop_anim(t, 4, 3)) then
			del(thang, t)
			room.num_bads -= 1
		end
		return
	end

	local oldair = t.air
	if not t.air then
		t.vx = 0
		t.rght = p.x > t.x and true or false
		local dir = t.rght and 1 or -1
		if not t.burning then -- not burning - jump when player charges fireball
			t.s = t.i + 0
			if t.croak == false then
				if play_anim(t, 30, 1) then
					t.croak = true
					t.fr = 0
					t.fcount = 0
				end
			else
				if play_anim(t, 5, 2) then
					t.croak = false
					t.fr = 0
					t.fcount = 0
				end
			end
			if p.sh then
				t.vy += t.jbig_vy
				t.vx = t.jbig_vx * dir
				t.air = true
			end
		else -- burning - jump rapidly at player
			if t.jcount <= 0 then
				t.burning = false
			else
				t.jcount -= 1
				-- small jump
				if not t.bounced then
					t.vy += t.jsmol_vy
				-- big jump if we bounced off a wall
				else
					t.vy += t.jbig_vy
					t.bounced = false
				end
				t.vx = t.jsmol_vx * dir
				t.air = true
			end
		end
	else -- jumping/falling
		t.s = t.i + 2

		t.vy += t.g
		t.vy = clamp(t.vy, -t.max_vy, t.max_vy)

		local newx = t.x + t.vx
		local newy = t.y + t.vy

		if (t.vy > 0) then
			t.fr = 1
			newy = phys_fall(t,newx,newy)
		else
			t.fr = 0
			newy = phys_jump(t,newx,newy,oldair)
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
		if not t.air then
			t.fr = 0
			t.fcnt = 0
		end
	end

	if (p.alive and hit_p(t.x,t.y,t.w,t.h)) then
		kill_p()
	end
end

function burn_knight(t)
	if (not t.alive) then
		return
	end
	if (t.atking and t.fr > 0 and not t.burning) then
		t.hp -= 1
		t.s = t.i + t.s_burn.s
		t.fr = 0
		t.fcnt = 0
		t.burning = true
		if (t.hp <= 0) then
			t.s = t.i + t.s_die.s
			t.alive = false
			room.num_bads -= 1
		end
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

	dbgstr = dbgstr..'mx '..tostr(mx)..' topy '..tostr(topy)..' boty '..tostr(boty)..'\n'
	dbgstr = dbgstr..'pmx '..tostr(pmx)..'\n'

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
	if (not t.alive) then
		if (play_anim(t, 10, t.s_die.f)) then
			-- get shorter so fireballs don't hit air
			t.h = 3
			t.cy = 4.99
		end
		return
	end

	if (t.burning) then
		t.atking = false
		if (t.fcnt >= 10) then
			t.burning = false
			t.fcnt = 0
			t.fr = 0
			t.s = t.i
		else
			t.fcnt += 1
			return
		end
	end

	t.vx = 0

	if (t.atking) then
		t.s = t.i + t.s_atk.s
		if (play_anim(t, 10, t.s_atk.f)) then
			t.atking = false
			t.fcnt = 0
			t.fr = 0
		end
	else
		t.s = t.i + t.s_wlk.s
		-- follow player if they're on same platform
		local dir = p_on_same_plat(t)
		if dir != 0 then
			t.goingrght = dir == 1 and true or false
		end
		-- remember which way we were going (after turning around from edge)
		t.rght = t.goingrght
		if (t.rght) then
			t.vx = 0.75
		else
			t.vx = -0.75
		end

		loop_anim(t,3,t.s_wlk.f)

		if (dist(p.x,p.y,t.x,t.y) <= t.atkrange) then
			t.atking = true
			t.fcnt = 0
			t.fr = 0
			if (p.x < t.x) then
				t.rght = false
			else
				t.rght = true
			end
		end
	end

	t.vy += t.g
	t.vy = clamp(t.vy, -t.max_vy, t.max_vy)

	local newx = t.x + t.vx
	local newy = t.y + t.vy

	newy = phys_fall(t,newx,newy)

	if (t.air) then
		t.vx = 0
		newx = t.x
	else
		-- todo use phys_walls here
		local pushx = coll_walls(t,newx)
		if (pushx != newx) then
			t.rght = not t.rght
		end
		newx = pushx
		if (	coll_edge(t,newx,t.y+t.h) or
				coll_room_border(t)) then
			t.rght = not t.rght
			newx = t.x
		end
		t.goingrght = t.rght
	end

	t.x = newx
	t.y = newy

	if (p.alive) then
		local swordpos = t.rght and 8 or -5
		if hit_p(t.x,t.y,t.w,t.h) then
			kill_p()
		elseif (
				t.atking and
				t.fr == 1 and
				hit_p(t.x + swordpos, t.y + 1, 5, 4)) then
			kill_p()
		end
	end
end

function burn_bat(b)
	if (b.alive) then
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
	loop_anim(b,4,2)

	-- move the bat
	local b2p = {x=p.x-b.x,y=p.y-b.y}
	local dist2p = vlen(b2p)

	-- if collide with something, go in random direction
	if move_hit_wall(b) or coll_room_border(b) then
		b.dircount = 0
		-- force pick a random direction - pretend the player is too far away
		dist2p = b.range + 1
		b.vx = 0
		b.vy = 0
	else
		b.x += b.vx
		b.y += b.vy
	end

	-- pick the direction for next frame
	if b.dircount <= 0 then
		-- out of range - pick random direction
		if dist2p > b.range then
			local rndv = {x = rnd(2) - 1, y = rnd(2) - 1}
			local len = vlen(rndv)
			b.vx = rndv.x * b.xspeed/len
			b.vy = rndv.y * b.yspeed/len
			b.dircount = 60
		-- in range - go toward player
		else
			b.vx = b2p.x * b.xspeed/dist2p
			b.vy = b2p.y * b.yspeed/dist2p
			b.dircount = 30
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

	-- bounce up and down while flying
	-- todo un-jank
	if (b.fr == 0) then
		b.vy += 0.2
	else
		b.vy -= 0.2
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
	s_sh  =  {s=93-64, f=2},
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
end

function kill_p()
	p.alive = false
	p.s = p.i + p.s_die.s 
	p.fr = 0
	p.fcnt = 0
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
	elseif (p.vy < 0) then
		newy = phys_jump(p,newx,newy,oldair)
	end

	newx = phys_walls(p,newx,newy)

	-- close to edge?
	p.teeter = not p.air and coll_edge(p,newx,newy+p.fty)

	p.x = newx
	p.y = newy

	-- hit spikes
	local hl = p.x + p.hx
	local hr = hl + p.hw
	local ht = p.y + p.hy
	local hb = ht + p.hh
	if (	collmap(hl,ht,3) or
			collmap(hr,ht,3) or
			collmap(hl,hb,3) or
			collmap(hr,hb,3)) then
		kill_p()
		return
	end

	local oldsh = p.sh
	if (btn(❎)) then
		if (p.shcount == 0) then
			p.sh = true
		end
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
	else -- release - fire
		if (p.sh) then
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
			p.fr = 0
			p.fcnt = 0
		end
		loop_anim(p,3,p.s_sh.f)

	elseif (not p.air) then
		-- walk anim
		p.s = p.i + p.s_wlk.s
		-- just landed, or changed dir
		if (oldair or btnp(➡️) or btnp(⬅️)) then
			p.fr = 0
			p.fcnt = 0
		end
		if (btn(➡️) or btn(⬅️)) then
			loop_anim(p,3,p.s_wlk.f)
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
		-- use collision box if t has one
		if (aabb(
				t.x + t.cx, t.y + t.cy, t.cw, t.ch,
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
	if (collmap(f.x+2,f.y+2,1)) then
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
	-- where our feeeeet at?
	local fty = newy + t.h
	local ftxl = newx + t.ftx
	local ftxr = ftxl + t.ftw

	-- ceiling
	if (	t.air and (
				collmap(ftxl,newy,1) or
				collmap(ftxr,newy,1))) then
		if (not oldair) then
			t.air = false
			t.vy = 0
		else
			-- just sloow down on ceiling hit
			t.vy = t.vy/3
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
00000000dddddddddddddddddddddddddddddddd00111100000000000000000011111111111111113101001301010110dddddddddddddddd0111111001111110
000000000dddddd00dddddddddddddddddddddd0011001100000000000000000111111111111111131011110100110330dddddddddddddd00111111001111110
0000000001111110011111100000000001111110010000100000000000111100111dd111111dd111010110101001133300000000000000000111111001111110
000000000110011001100111111111111110011001111110111111110110011001dddd1001dddd100101101310111310011111111111111001dddd1001dddd10
00000000010000100100001000000000010000100100001000000000010000100111111001111110010111131111001300000000000000000111111001dddd10
00000000001111000111111001100110011111100100001001100110011111100000000001dddd10010101100101001301100110011001100000000001d11d10
00000000000000000100001111111111110000100100001011111111010000100000000001dddd10010111103301011000111111111111000000000001d16d10
00000000000000000100001000000000010000100100001000000000010000100000000001dddd10110110100301011300000000000000000000000001d16d10
dddddddddddddddddddddddddddddddddddddddddddddddd11111111dddddddd0111111001dddd10010100100101011010101010111111111111111101d16d10
0dddddddddddddddddddddddddddddd00dddddd00dddddd0001000000dddddd01111111d01dddd10330100103101011001010101010101011111111101d16d10
01111111111111111111111111111110011111100111111000100000011111101d11d1dd01dddd10333100133301011310101010111111111111111101d16d10
011ddd11111111111111111111ddd110011dd1100110011000000000011dd110111ddd1d01dddd10013100010101011001010101010101011111111101d16d10
01ddddd1ddddd1dddd1dd1dd1ddddd1001dddd10010000101111111101dddd101ddddddd011dd110010110010101011010101010111111111111111101d66d10
01111111ddddd1ddddd1d1dd11111110011111100111111000000100011111101dd1d1dd01d11d10310110100101011001010101010101011111111101dddd10
01d1d1d1ddddd1dddddd11dd1d1d1d1001dddd10010000100000010001dddd1011d1dddd1dddddd1010111100101011010101010111111111111111101dddd10
01d1d1d111111111111111111d1d1d1001dddd100100001000000000011111100dddddd011111111010111100101011001010101010101011111111101111110
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd100100001000000000dddddddddddddddd00000000010101100101011001010110dddddddd0000000000000000
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd1001000010111111110dddddddddddddd0000000003101011031010110310101100dddddd00000000000000000
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd100100001011111111011111111111111000000000310101133101011331010113011111100000000000000000
01d1d1d111111111111111111d1d1d1001dddd100100001000000000011ddd1111ddd11000000000010101100111011101010111011dd1100000000000000000
01d1d1d1ddddd1ddddddd1dd1d1d1d1001dddd10010000100110011001ddddd11ddddd100000000001010110011101110101011101dddd100000000000000000
01d1d1d1ddddd1ddddddd1dd1d1d1d1001dddd100100001000000000011111111111111000000000013131303101011031013113011111100303003003030030
01d1d1d1ddddd1ddddddd11d1d1d1d1001dddd10010000101111111101d1d1d11d1d1d100030300303310110013131300131331331dd3d133003303330033033
01d1d1d111111111111111111d1d1d1001dddd100100001000000000011111111111111030330033333313133331331333333333331333333033330333333333
01d1d1d1dd1d1ddddd1ddddd1d1d1d1001dddd10010000100000000001d1ddddd1dddd10155555555555555555555555dddddddddddddddd55555551dd1d1ddd
01d1d1d1dd1dd11ddd1ddddd1d1d1d1001dddd10010000101101111101d1ddddd1dddd10d155555111111111155555510dddddddddddddd01555551ddd1dd11d
01d1d1d1dd1dddd1dd1ddddd1d1d1d10011dd110011001101101111101d1ddddd1dddd10d1111515551115555511151501111111111111105511151ddd1dddd1
01d1d1d111111111111111111d1d1d1001d11d1001011010111111110111111111111110155511115551115555551111011dd111111dd1105555111111111111
011ddd11ddddd1ddddddd1dd11ddd11001dddd1001000010000000001ddddd1ddddd1dd1d1555551555511115555555101dddd1dd1dddd1055555551ddddd1dd
dd11111dddddd1dddddd11ddd11111dd1d1111d110111101111110111ddddd1ddddd1dd1d111115511111511111111550111111dd11111101111111dddddd1dd
1dddddddddddd1ddddd1d1dddddddddd1dddddd110000001111110111ddddd1ddddd1dd1111115555511151511111555011dd11dd11dd1101111151dddddd1dd
11111111111111111111111111111111111111111111111111111111111111111111111111111111555555551111111101111111111111101111111111111111
00022200000222000000000000505200000000000022220000222200002220000002000000200020000000000000000000000000000000000000000000000000
00221120002211200222222000222220000222000022112000221120022120000022200000220200002000000002000000000000000007000000700000002200
0021112000211120222222220022222202212220022111200221112222111200022120002022222000220200002200000000000000072000009aa70000021120
022111200221112022222222022222222111222502211222022112222211122022112020022122200222200000122000000000000a02a2a0021999a007217170
02222220022222205222111202222222222222200222222202222220222222202221122002111220002120000001100000a007000a7a7a0009a2a8000a72aa20
02222220022222200222212002222222222222250222222022222220022222220222222000211200000110000000100000070a00009a9800029a9290029a2990
22222200222222005222220000222220022222222222250002222500022220500222225000021000000000000000000000a99000008988000089892000a99800
00500500000550000000000000000000002220000220500000205000002050000022500000000000000000000000000000088000000890000008890000988500
bbbb0980070a7070ddddddddddddddddddddddddddddddddc77c7ccc0cccccc00070c000000000000000000000000000000000000002e200002e200000000000
bbbba7987a99a7a700222200002222000022220000000000cccc777cccc711cc00c070c00000000000000000000000000000000002e11e0000e11e2000000000
bbbba798099a0890021001200210012002100120000000001ccccc7c1c7cc1cc0c7ccc000c0c0c0000c00000000000000000000002e71e2002e17e2000000000
bbbb0980008000000210712002a0712002170120000000001ccccccc1ccccc1c10c7c1cc00c70000000070000000000000000000029a7a2222a7a92000000000
0aa007a0070770a0201001022017a102207aa10200000000c1cccc1cc1cccc1cccccc1c10c00c7c0070c0c0000000000000000002289a922229a982200000000
97797a98099a099020100102201891022018910200000000c11cc11cc11cc11c11cccc10cccc0c0c0c00000c000000000000000002e88e2002e88e2000000000
8998a9980080000002111120021111200211112000000000ccc11cc00ccc11cc0c1c1cc11c0c1cc1100cc7100000000000000000002ee200002ee20000000000
08800880000000002222222222222222222222220000000001ccc11001ccccc000c101c00c110c100c010c000000000000000000000550000005500000000000
5500050000000000007000700700070000066600000666000006660000ee00000007000000000000000000007ccc000cc7c70c00000000000600600000000600
055055000000000008a707a009a707a0000611600006116000c611600ee7e0000000a70000000700000070000c000ccc0c70c7c7000000000600700000600700
0085800000085800009a0a80008a0a9000661160006611600c6611600ee77e00707aaaa000707a00000a70000c00700c777c077c000000000070600600700600
00050000055555000008a9000009a80006c66160066c6160cc6661600eee7e500aa999a0000aa9700009000000c0000cc0c70c00000000006060600700606007
0000000055000550000098000000890006cc6660066cc660056666650cceee0000a9a90000a990000000000007007000c00c000c000000000700606060606006
000000005000005000000000000000000566c66506566c6000c66660c0eeeee008998900000800000000000000c0c00cc707070000000000006ddd6006dddd60
00000000000000000000000000000000c06666000c66660000666600050eeee000088000000000000000000000c0ccc000007007000000000ddd1dd00dd11dd0
0000000000000000000000000000000000500500000550000050050000c50050000000000000000000000000ccccc0000c700000000000001111111111111111
0000000000000000000000b0bb000000000000000007007000700700006660e000666e00000666e0000666e000ee0080dddddddddddddddd00670001d0060000
000000000000000000000b8b03b0000000007007000a00a0000aaa00006116ee00611ee0006611ee006611ee0ee7e08801d111d001d11d10000066d1d1600000
00000b0000000b000004bbb300b000000000a97a00709a90070998000661162e066112e00666112e0666112e0ee77e88061116000611116000000dd1dd166760
0000b8b00000b8b0004443b000b400b0007098a870a9989000a90000066616220666122006666122066661220eee7588060600706006060667666d11d1100000
00bbbb3000bbbb3000b400b000444b8b00a99895a0989000000000000666652206665220666665226666652200eee588700606067006060000000dd1d1166000
04443b0004443b300bb300000004bbb30a8585500a980000000000006666652266665220666665226666652200eeeee86006070000600700007606d1dd100676
04443b0004443b00b3000000000003b079950050000000000000000066666022666662206666602266666022000eeee80007006000700600660070d1d1600000
003bb0b0003bb0b0b0000000000000b00855000000000000000000000500502000550200500500200550002000050050000600600060000000060001d0067000
41106161616161616161616161616141121212121212121212121212121212128361616161616161616173121212121212132212231222121312221212231212
12121312122212231213121212131222832213232212221323222212232212221212231312222312121222121213232222231323121222131212231222121312
4200a3000000a300a300a3a3a3000043830000000000000000000000000000413100000000060000000000000000000131000000000000000000000000000073
83000000000065000000000000000001830000000000000000000000000000738300000000000000000000007565750131000000000075657565656565656501
4200a3000000a300a300a300a3000080e00000000000000000000000000000423200000000000000000000000000000232000000000000000000000000000080
0000000000c030d0000000000000000283000000000000000000000000000080e000000000000000000061000065650232000000000000007575757565657502
4210a300a300a300a300a3a3a3000000000000000000000000000000000000423200000000000000000000000000000232000000000000000000000025000000
00000000000000000000000000000002830000060000000000000000000000000000000025000000006161610000750232000000000000000000657565756502
4200e0a300a30000a300a300000000414130303030303030303030303030304232000000100000000010000000000002320000000000000000000000c311d301
31000010000000000010000000000002830600000000000000000000000072113130303030d00000616161616100000232000000000000000000000075656502
42000000000000000000000000250042420000000000000000000000000000423206000000000000000000000000000232650000006500650000006552625202
32000000000000000000000000000002830000000000000000000000000073123200000000000000006161610000000232000000000000000000000000006502
42100000000000000000000000c0304242100046000000000000004600000042320000f600000000000000000000000232000000000000000000000052005202
32000000000000000000000000000002830000000000000000000000006500733200000000000000006161610000000232000000000000000000000000007502
42000000000000000000000000000042420000000000000000000000000000423200e781f7000000000000001000000332000000000000000000000052005202
32000000000000000010000000000002830000000000000025000000650600733200000061000000006161610000000232000000000000000000000000007502
4200000000000000000000000000004243000000650000467100000075000043320000c700000051000000000000008032000000000000000000000052005202
32000000005100000000000000000002830000007211211111111182000006733200006161616161610000000000000232000000000000000000000000000002
42000000c0d000000000c0d000000042827575654165756542657565413030723200000000000052000000000000000032004600000000000046000053465302
32000000005200000000000000000002830000000000000000000000650600733206616161616161610000000000000333000000000000000000000000000002
4200000000000000000000000000004283000000420000004200000042000073320000000000005200000000250000013200203040e6f6203040e6f620304002
32005100005200000000000000000002830000000000000000000000006565733200006161616161610000000000008065000000000000000000000000250002
42000000000000000000000c0000004283000000420000004200000042000073320000000000005251000000203030023261526152c0d0526152c0d052615202
32625262625262626251626262256202830000000000000000000000000000733200000061000000000000000000000075650000000000000000000072218202
420000c03030303030303030d0000042830000004200000042000000423030733300000000060052520000005261610233615261526161526152616152615202
326152616152616161526161413030038300000000000000000000000000007332000000000000000000c0303030300131756500000000000000007173138302
4200000000000000000000000000004283000000420000004200000042000080e0000000000000525206000052616102e0615261526161526152616152615202
32615220405261616152616142616180e00000000000000000000000000000733261616161616161616161616161610232756575000000000000717323228302
43e6f6e6f6e6f6e6f6e6e6f6e6f6e64383e6e6e643e6e6e643e6e6e6432500000000e6f6e6f6e6f6e6f6e6f6e6f6e60300615361536161536153616153615303
33e6f6e6e6e6f6f6e6e6e6f6436161000000000000004600007211111111827333e6f6e6f6e6f6e6f6e6f6e6f6e6f60333006575750075657571731322128303
1212121212121212121212121212121211111121111121112111212111211111111111211111211121112121112111111111211182e6f6721182e6f672111111
12121212121212121212121212121212111111211111111111112111111111211111111111211111111111112111111111112111211111211111111111211111
0066dd700066dd700066dd70066d700000066dd00066dd00000000000066dd700000000000002222077ee700066dd00000000000000000000000000000000000
00dffd7000dffd7000dffd700dff7000000dffd000dffd000066dd0000dffd700066dd00006629820eaae7000dffd0000066dd00000000000007000000000000
22226d6022226d6022226d6022226000222d66d022d66d0000dffd7022226d6000dffd7000df28928888ee002222d00000dffd00000000000070000000000000
2982d4442982d4442982d44429824400222dddd022dddd0022226d702982d44402222d7000d629828ae8e8802982d04022226d00000000004600000040000000
2892ddf02892ddf02892ddf02892f00022fddddd2fdddddf2982dd602892ddf002982d6006ddd2208ea8ea002892df462982dd0000000000f40000004d660000
2982550029825500298255002982500022255500225550002892d4442982550002892d440dd455008ae8e000298250402892dd400022226d0000000040000000
022005000225500002250500022005000205005002500500298255f002250050029825f000f4677008800e000220050029825f46029892dd0000000000000000
0050050000055000005005000050050000500050050005000225050000500050002205000054050000e00e000050050002250540528982fd0000000000000000
00444000004440000044400000444900004440000044409000000000000444900004449000444900004440000044409000222000004440000000000000000000
004ff090004ff900004ff090004ff090004ff990004ff009000444900004ff090004ff09004ff090004ff990004ff009002aa070004ff0000004440000000000
0015500900155090011550090115500901155009011550090004ff090001550901115509011550090115500901155009099ee007011550000004ff0000000000
011550090115509011555009155f555f55f5555f55f5555f01155509011f555f111f555f155f555f55f5555f55f5555f99eee007115550090011550000000000
0115555f011f55f011f5555f1155500911555009115550091155555f111155091111550911155009111550091115500999aeeeea155550090115550000000000
01122009011220901122200911222090112229901122200911f522091111220901122209011222900112299001122229998880071f2225f90155550000111100
011020090112009011202009112009001120020011200290111222090012009001120090011129200111202001112090999808071112029001f2222901111114
00202090002209000200209002000200020002000200020001122090002000200020002000102020001020200010202009080870010292000111222022111544
000c6600000c6600000c6600000c6600000c660400c6600000c6600400c6600000c6600000000000000000000000000000000000000000000000000000000000
00c66f6000c66f6000c66f6000c66f6400c66f640c66f6040c66f6040c66f6040c66f64000000000000000000000000000000000000000000000000000000000
00cfbf0000cfbf0000cfbf0000cfbf0400cfbf0f0cfbf0040cfbf00f0cfbf0040cfbf04000000000000000000000000000000000000000000000000000000000
0cc6fff00cc6ff600cc6ff6f0cc6ff6f0cc6ff640c6ff6cffc6ff6c40c6ff60f0c6ff6f000000000000000000000000000000000000000000000000000000000
0cc666000cc666600cf666600cc666640cf66664cc666604cc666604cc6666c4cc66664000000000000000000000000000000000000000000000000000000000
0cfc66cf0cfc666f0cccc6600cfc66640ccc6664fcc666040cc66604fcc66604ccc6664000000000000000000000000000000000000000000000000000000000
ccccc6000cccc6000cccc6000cccc6040cccc6040ccc60040ccc60040ccc60040fcc604000000000000000000000000000000000000000000000000000000000
00200200cccccc00cccccc00cccccc04cccccc00ccccc004ccccc000ccccc004ccccc04000000000000000000000000000000000000000000000000000000000
00cc9c04000000000000000000000000000000000000000000000000000000000000000000000000000660000006600000666000000060000011111000222200
000919040000000000000000000000000000000000000000000000000000000000000000000000000060060000600600061166000696c666000119f100223040
00c91904000000000000000000000000000000000000000000000000000000000000000000000000006dd660006dd66009916600666cc55600099ff900233304
0c9111cf00000000000000000000000000000000000000000000000000000000000000000000000006dd6d2006dd6d629aa966600ccccc560099119003333004
c0c999040000000000000000000000000000000000000000000000000000000000000000000000006d06d2126d06dd219aa966c665cccc554011111030999334
f0cccc040000000000000000000000000000000000000000000000000000000000000000000000000d006d200d006dd29accccc555cccc05441111f430999004
00cccc04000000000000000000000000000000000000000000000000000000000000000000000000d066dd00d066dd00099666c0505c55004001010000903004
0ccccc04000000000000000000000000000000000000000000000000000000000000000000000000000dd000000dd00000500500000505000010100000303040
__label__
dddddddd77dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
ddddddddd7dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
11111111171111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111171111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
dd1dd1dd777dd1dddd1dd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1dddd1dd1ddddddd1dddd1dd1ddddddd1ddddddd1dd
ddd1d1ddddddd1ddddd1d1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddd1d1ddddddd1ddddd1d1ddddddd1ddddddd1dd
dddd11ddddddd1dddddd11ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1dddddd11ddddddd1dddddd11ddddddd1ddddddd1dd
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
dddddddd7700777077707770000077707770777000000000000000000000000000000000000000000000000000000000000000000000000000000000dddddddd
ddddddd007007070707070700000007000707070000000000000000000000000000000000000000000000000000000000000000000000000000000000ddddddd
11111110070070707070707000000770777077700000000000000000000000000000000000000000000000000000000000000000000000000000000001111111
11ddd1100700707070707070000000707000707000000000000000000000000000000000000000000000000000000000000000000000000000000000011ddd11
1ddddd10777077707770777000007770777077700000000000000000000000000000000000000000000000000000000000000000000000000000000001ddddd1
11111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10707000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10707000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10707000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000222000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002211200000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002111200000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022111200000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022222200000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022222200000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000222222000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005005000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dddddddd0000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002222000000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021001200000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021701200000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000207aa1020000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000201891020000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021111200000000001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000222222220000000001d1d1d1
1d1d1d1000000000000000000000000000000000dddddddd000000000000000000000000000000000000000000000000dddddddddddddddddddddddd01d1d1d1
1d1d1d10000000000000000000000000000000000dddddd00000000000000000000000000000000000000000000000000dddddddddddddddddddddd001d1d1d1
1d1d1d10000000000000000000000000000000000111111000000000000000000000000000000000000000000000000001111111111111111111111001d1d1d1
1d1d1d100000000000000000000000000000000001100110000000000000000000000000000000000000000000000000011ddd111111111111ddd11001d1d1d1
1d1d1d10000000000000000000000000000000000100001000000000000000000000000000000000000000000000000001ddddd1dd1dd1dd1ddddd1001d1d1d1
1d1d1d10000000000000000000000000000000000011110000000000000000000000000000000000000000000000000001111111ddd1d1dd1111111001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1d1d1dddd11dd1d1d1d1001d1d1d1
1d1d1d10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111111111111111111001d1d1d1
1d1d1d1000000000dddddddd00000000000000000000000000000000dddddddd000000000000000000000000dddddddd01d1dddddd1d1dddd1dddd1001d1d1d1
1d1d1d10000000000dddddd0000000000000000000000000000000000dddddd00000000000000000000000000dddddd001d1dddddd1dd11dd1dddd1001d1d1d1
1d1d1d10000000000111111000000000000000000000000000000000011111100000000000000000000000000111111001d1dddddd1dddd1d1dddd1001d1d1d1
1d1d1d1000000000011001100000000000000000000000000000000001100110000000000000000000000000011dd11001111111111111111111111001d1d1d1
11ddd1100000000001000010000000000000000000000000000000000100001000000000000000000000000001dddd101ddddd1dddddd1dddddd1dd101d1d1d1
d11111dd00000000001111000000000000000000000000000000000000111100000000000000000000000000011111101ddddd1dddddd1dddddd1dd101d1d1d1
dddddddd0000000000000000000000000000000000000000000000000000000000000000000000000000000001dddd101ddddd1dddddd1dddddd1dd101d1d1d1
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000111111011111111111111111111111101d1d1d1
01111110000000000000000000000000000000000000000000000000000000000000000000000000dddddddd01d1dddddd1ddddddd1dddddd1dddd1001d1d1d1
011111100000000000000000000000000000000000000000000000000000000000000000000000000dddddd001d1dddddd1ddddddd1dddddd1dddd1001d1d1d1
011111100000000000000000000000000000000000000000000000000000000000000000000000000111111001d1dddddd1ddddddd1dddddd1dddd1001d1d1d1
01dddd10000000000000000000000000000000000000000000000000000000000000000000000000011dd1100111111111111111111111111111111001d1d1d1
01dddd1000000000000000000000000000000000000000000000000000000000000000000000000001dddd101ddddd1dddddd1ddddddd1dddddd1dd101d1d1d1
01d11d10000000000000000000000000000000000000000000000000000000000000000000000000011111101ddddd1ddddd11ddddddd1dddddd1dd101d1d1d1
01d16d1000000000000000000000000000000000000000000000000000000000000000000000000001dddd101ddddd1dddd1d1ddddddd11ddddd1dd101d1d1d1
01d16d10000000000000000000000000000000000000000000000000000000000000000000000000011111101111111111111111111111111111111101d1d1d1
01d16d100000000000000000000000000000000000000000006660000000000000000000dddddddd01d1dddddd1d1ddddd1ddddddd1dddddd1dddd1001d1d1d1
01d16d1000000000000000000000000000000000000000000611600000000000000000000dddddd001d1dddddd1dd11ddd1ddddddd1dddddd1dddd1001d1d1d1
01d16d1000000000000000000000000000000000000000000611660000000000000000000111111001d1dddddd1dddd1dd1ddddddd1dddddd1dddd1001d1d1d1
01d16d10000000000000000000000000000000000000000006166c600000000000000000011dd110011111111111111111111111111111111111111001d1d1d1
01d66d1000000000000000000000000000000000000000000666cc60000000000000000001dddd101ddddd1dddddd1ddddddd1ddddddd1dddddd1dd1011ddd11
01dddd100000000000000000000000000000000000000000566c66500000000000000000011111101ddddd1dddddd1ddddddd1ddddddd1dddddd1dd1dd11111d
01dddd1000000000000000000000000000000000000000000066660c000000000000000001dddd101ddddd1dddddd1ddddddd11dddddd1dddddd1dd11ddddddd
01111110000000000000000000000000000000000000000000500500000000000000000001111110111111111111111111111111111111111111111111111111
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
ddddd1ddddddd1dddd1dd1ddddddd1dddd1dd1ddddddd1ddddddd1dddd1dd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1dddd1dd1ddddddd1ddddddd1dd
ddddd1ddddddd1ddddd1d1ddddddd1ddddd1d1ddddddd1ddddddd1ddddd1d1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddd1d1ddddddd1ddddddd1dd
ddddd1ddddddd1dddddd11ddddddd1dddddd11ddddddd1ddddddd1dddddd11ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1dddddd11ddddddd1ddddddd1dd
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111

__gff__
0001010101000000100300000101100303030303030100030303000000000003030303030300000303000000000300000303030303000003030303030303030300000000000000000000000000000000000011010101171700000000000000001000000010000000101010000000080810101010101010000000000008080808
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
00000021212121212121212121212121212121212121212121312121212121211a1b1b0b000b001b1a1b001a0b0021212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121211411111111111111121111111111111121212121212121212121000000000000
00520000000000000000000000000010130000000000000000000000000000001b1a1a1b001b001b1a1a001a1b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002400000000000000000000000000000000000000000000000000000000000000
23000000000000000000210000000020230000000000000000000000000000001a0a0a1b001b001a1b0b000b0a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002400000000560000005600000000000000000000000000000000000000000000
23030400000000000000210015060620230000000000000000000000000000000b1a0b1b000b001a1b1b000a1b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002400000000000000000000000000000000000000000000000000000000000000
23162500000000000000000025161620230000000000000000000000000000001a0b1a1a000a001b1b0a001a1b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002400000000000000000000000000005200000000000000000000000000000000
23162500000002030304000025161620230000006000000000000000000000001b0a0b1a001b000a1b0a000b1b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002400000000000000000000000056561400000000000000000000000000000000
2316250000002516162500003526262023000000000000000000006000007e271b1a1b1a001b000a1b1b001a0a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002400005600000056000000560000002400000000000000000000000000000000
23162500000125161625000203030320237f0000000000000000000000007e201a1b0b0a000a000a0a1b001a0a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002400006e6e6e6e6f6e6e6e6f6e6f6e2400000000000000000000000000000000
23162521000025161625002516161620230606060606060606062712280000301b1a1a1b001b001b1b1b001b1a0000202200000000000000000000000000002022000000000000000000000000000020220000000000000000000000000000202400003721212121212121212121212422000000000000000000000000000020
23162501000025161625002516161630331616161616161616163722380203040a1b0a0b001b000a1b1b000a1a0000203200000000000000000000000000002032000000000000000000000000000020320000000000000000000000000000203400002500000025000000240000002432000000000000000000000000000020
23263500000025161625002501161616161616161652161616167c7d252525001a0a1a1b000b000b1b0a000a1b0000300000000000000000006400000000000000000000000000000000000000000000000000000000000000000000000000001111111128000025000000240000002400000000000000000000000000000000
23020303030425161625002516161616161616161615161616162525353535001b1b1b0a001b001b1b1b001a0b0000000000000000000027111111280000000000000000000000000000000000000000000000000000000000000000000000000e00002500000025000000240000002400000000000000000000000000000000
2325161616252516162501251012121313161616162516161616253527122810280b0a0a001a001b1a1a000a1b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002500000025640000240000002400000000000000000000000000000000
232516160204251616250025202121232316161616351616161425272121382012281b0b000a520a1a1b001a0b0000000000000000000000640000000000000000000000000000000000000000000000000000000000000000000000000000001400562556005625560000240000002400000000000000000000000000000000
33352626353535266e35003530212133336f6e6f14271228163435372121383022382b2a642b2d2b2b2a2e2a2b000000000052001700640017000000000000000000000000000000000000000000000000000000000000000000000000000000346e6e6e6e6e6e6e6e6e6e342712283400000000000000000000000000000000
21212222222222222221212121212121212121212121212121212121212121212131393b3a3b3a3b3a3b3a3b3e1111111212121212111212121212121212121212121212121212121212121212121212121212121212121212121212121212122121212121212121212121212121212112121212121212121212000000000000
2400000000000000000000000000001423000025001a000b00000a0025000020212122222222222222212121212121212131222132212221312122212132212114111111111111111211111111111111212121212121212121212121212121212121223221223221322122212131212200000000000000000000000000000000
2400000000000000000000000000002423000025000a001a00000b0025000020211616161616161616161616161616211316161616161616161616161616161024000000000000000000000000000000380000000000000000000000000000140e00000000000000000000000000001000000000000000000000000000000000
2400000000000000000000000000002423000025000b000a00001a00250000200016161616161616161616161616162123161616161616161616161616161620240000000056000000560000000000000e0000000000000000000000000000240000570000000000000000000000002000000000000000000000000000000000
2400000000000000000000000000002423000025002b001b00000a0025000020001616161616161616161616161616212300161616000000000000161616002024000000000000000000000000000000000000000000000000000000000000241303040060000000000000000000002000002121210021000022002121000000
2400000000000000000000000000002423000025001a000b00001a0025000020226400000000000000000000006400212300000000000000000000000000002024000000000000000000000000000052140303030303030303030303030303242316250000000000000000000000002000002100000021210022002100210000
2400000000000000000000000000002423000035000b000b00002b0035000020225656000000006400000000565600212300640000000000000000006400002024000000000000000000000000565614240000000000000000000000000000242316250000000000000000000000002000002121210021002122002100210000
2400000000000000000000000000002423000014030303030303030314030320220000001500565656001500000000212300565656000000000000565656002024000056000000560000005600000024240100640000000000000064000000242316250000010000000001000000012000002100000021000022002100210000
2400000000006000000000000000002423000024001a001a00001b002400002014000000350606060606350000000024330000000000000000000000000000202400006e6e6e6e6f6e6e6e6f6e6f6e24240000000000000000000000000000242316250000000000000000000000572000002121210021000022002121000000
3400000000000000000000000000003423000024000a001b00000b0024000020240064002626262626262600000000240e0000000000000000000000000000202400003721212121212121212121212434000000560000641700000057000034231625000000000000000000005657300000000000007c000000000000000000
2800000000000000000000000000002723000024001a002b00000b0024030320245656006400001500000000640000240000000000000000000000000000002034000025000000250000002400000024285757561456575624565756140303272316250000000000000000000027121100000000000052000000000000000000
3800000000000000000022000000003723000024002b001a00001a0024000020240000005656002500640000565600242711122815000000001527111128002011111111280000250000002400000024380000002400000024000000240000372316250000000000000000000000000800000000000c030d00000000000c0303
3800000000000070000012000000003723000024001b001a00002b0024000020240000000000003500565600000000247f0000002500000000250000000000200e000025000000250000002400000024380000002400000024000000240000372316250000000203030304000000000000000000000000000000000000000000
3800000000000303030312030303003733000024000b002b00000a0024030330210506060706061506060706060706217f00000025000000002500000000013000000025000000256400002400000024380000002400000024000000240303372316250000002500000025000000272800000000000000000000000000000000
3801000000000000000000000000000800000024002b000b00000b00240000002125161625161625161625161625160e7f00000025000000002500000000000814005625560056255600002400000024380000002400000024000000240000082303030304002500000025000000373800000000000000000000000000000000
38000000000000000000000000520029295229342e2a2e2c292e2b2934290000213552263526263526263526263526006f6f6f6f176400000017000052000000346e6e6e6e6e6e6e6e6e6e3427122834386e6e6e346e6e6e346e6e6e34520000331616162500350052003500005637386e6e6e6e6e6e6e6e6e6e6e6e6e6e6e6e
3800271211111211121112121112111131213121393b3a3b3a3b3a3e21212121212122222222222222212121212121212121212121212121212121212121212121212121212121212121212121212121111111121111121112111212111211111111111111121111111111111211111121212121212121212121212121212121
__sfx__
a1280000182301a2301f2301c2301d230182301a2301523010230132301623018230182301823018230182301a230182301623015230152301523015230152301623018230162301523015230152301523015230
af2800000203002030020300203002030020300203002030040300403004030040300403004030040300403007030070300703007030070300703007030070300503005030050300503005030050300503005030
650100001c6201b6201a620196201861018610166101461013610126101261015600146000961009610126001160004610046100e6000d6000c6000b6000a6000a60009600086000860008600076000760006600
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a12800000e2301323016230152301523015230152301523010230132301623018230182301823018230182301a230182301623015230152301523015230152301623018230162301523015230152301523015230
af2800000203002030020300203002030020300203002030040300403004030040300403004030040300403007030070300703007030070300703007030070300503005030050300503005030050300503005030
011c18000b0200b0250b00012020120000d0240b0200b0250b00012022120000d0240b0200b0250b00012020120000d0240b0200b0250b00012020120000d0200000000000000000000000000000000000000000
011c18002502425020250202502025025250052602426020260202602026025260002802428020280202802028025280002602426020260202602026025260000000000000000000000000000000000000000000
011c18001c0241c0201c0201c0201c0251c0051e0241e0201e0201e0201e0251e0051f0241f0201f0201f0201f0251f0051e0241e0201e0201e0201e0251e0050000000000000000000000000000000000000000
__music__
00 0a4b4c44
02 0a0b0c44

