pico-8 cartridge // http://www.pico-8.com
version 38
__lua__
-- 'jumper' demo build #2
-- by nuno

function copy_into(a, b)
	for k,v in pairs(a) do
		b[k] = v
	end
end

function clamp(val, min, max)
    if val < min then
        return min
	elseif val > max then
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
    if x0 + w0 < x1 or x1 + w1 < x0 or y0 + h0 < y1 or y1 + h1 < y0 then
        return false
    end
    return true
end

function vlen(v)
    return sqrt(v.x*v.x + v.y*v.y)
end

-- 
dbg = true
dbgstr = ''

-- disable btnp repeating
poke(0x5f5c, 255)

if dbg then
	menuitem(
		1,
		"<- skip ->",
		function(b)
			move_room((room_i + 24 + (b == 1 and -1 or 1)) % 24)
			spawn_p_in_curr_room()
			_update()
			_draw()
			flip()
			return true
		end
	)
end

function init_room()
	-- starting room
	move_room(7)
	-- updated by spawn_room
	room_old, -- for restore
	room_num_bads, -- for unlock (bads door)
	room_num_unlit, -- for unlock (lanterns door)
	room_checkpoint -- checkpoint thang
	=
	nil,0,0,nil
end

function move_room(i)
	local r = get_room_xy(i)
	room_i,room_x,room_y = i,r.x,r.y
end

function restore_room()
	if room_old != nil then
		for t in all(room_old) do
			mset(t.x,t.y,t.val)
		end
	end
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

is_end = false

function update_room()
	-- update room and camera to where player currently is
	local oldi,
		  rx,ry = 
		  room_i,
		  (p.x + 4) \ 128, (p.y + 4) \ 128
	if rx >= 0 then
		local newi = rx % 8 + ry * 8
		move_room(newi)
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
				-- due to stay-on-platform-assist, the player could stand on the air if we don't do this
				p.air = true
			end
			-- fade out music and stuff
			if silent_rooms[room_i] then
				music(-1,3000,3)
			elseif start_music_rooms[room_i] then
				start_music()
			end
			restore_room()
			spawn_room()
		end
	else
		p.x = -10
		is_end = true
		for f in all(fireball) do
			kill_ball(f)
		end
	end
end

-- spawn thangs in current room
-- save room
function spawn_room()
	local rmapx,rmapy  = room_x \ 8, room_y \ 8
	thang,max_z,room_old,room_num_bads,room_num_unlit,fireball,rain = {p},0,{},0,0,{},{}
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
	-- rain
	if room_i > 0 and room_i < 8 then
		for x=rmapx,rmapx+15 do
			if not fget(mget(x,0),1) then
				local t = spawn_thang(257, x*8, 0)
				t.h = dist_until_flag(t.x,t.y,1,1,true) + 7
				t.hh = t.h
				add(rain,t)
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

snd_p_respawn,
snd_p_die,
snd_p_jump,
snd_p_shoot,
snd_p_land,
snd_hit,
snd_bat_flap,
snd_ice_break,
snd_frog_croak,
snd_frog_jump,
snd_knight_jump,
snd_knight_swing,
snd_knight_die,
snd_shooter_shot,
snd_archer_invis,
snd_wizard_tp =
8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22

-- TODO token reduction?
-- play the start of the music, overlaps with start_music_rooms
intro_rooms = {[23]=1, [8]=1}
-- silent rooms includes all rooms we want regular music to fade out, and NOT play on respawn (including boss rooms)
silent_rooms = {[4]=1, [15]=1, [16]=1, [17]=1}
-- call start_music() when entering these rooms (i.e. we need one after a silent room to restart music)
start_music_rooms = {[8]=1}

function start_music()
	if intro_rooms[room_i] then
		music(0, 0, 3)
	elseif not silent_rooms[room_i] then
		music(2, 200, 3)
	end
	-- boss music will start from boss monster's code
end

function fade_update()
	fade_timer += 1
	if fade_timer == 12 then
		spawn_p_in_curr_room()	
	elseif fade_timer > 23 then
		fade_timer = 0
		return false
	end
	return true
end

function _update()
	if not is_end then
		update_room()
		update_p()
	end
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
	for i,k in pairs(t.pal_k) do
		pal(k,t.pal_v[i],0)
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

function pal_mono(color)
	for i=1,15 do
		pal(i,color,0)
	end
end

function draw_wizard(t)
	if t.tping then
		pal_mono(7)
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
		if t.shield then
			--0b1001110010010011
			--5/200 = 0.025
			circ(t.x+3,t.y+4,6,9)
			fillp((0b1101101110011100 >>< sin(t.shieldtimer*0.025)*2.99) + 0b0.1)
			circfill(t.x+3,t.y+4,6,10)
			fillp(0)
		end
	end
end

function draw_knight(t)
	draw_thang(t)
	-- draw sword
	if t.swrd_draw then
		local xoff = t.rght and 8 or -8
		spr(206 + t.swrd_fr,
			t.x + xoff,
			t.y,
			1,1,not t.rght)
	end
end

function draw_smol_thang(f)
	local sx,sy = (f.sfr % 2) * 4, (f.sfr \ 2) * 4
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

function print_in_room(r,s,x,y,c)
	if room_i == r then
		print(s,x,y,c)
	end
end

-- background ones
rain_patterns = {0b1011101010101110.1,0b1110101110101010.1,0b1010111010111010.1,0b1010101011101011.1}
dither_patterns = {
	0b1111111111111111,
	--0b0111111111111111,
	0b0111111111011111,
	--0b0101111111011111,
	0b0101111101011111,
	--0b0101111001011011,
	--0b0101101001011011,
	0b0101101001011010, -- checker
	--0b0100101001011010,
	--0b0100101000011010,
	0b0000101000001010,
	--0b0000001000001010,
	0b0000001000001000,
	--0b0000000000001000,
	0b0000000000000000
}

function gradient(y,h,colors)
	-- TODO tokens
	--local cinc = ceil(h/grads)
	local grads = #colors-1
	local dinc = ceil(h/grads/#dither_patterns)
	for c=1,grads do
		local c1,c2 = colors[c], colors[c+1]
		for i=1,#dither_patterns do
			fillp(dither_patterns[i])
			rectfill(
				0,		y,
				128,	y + dinc,
				(c1 << 4) | c2)
			y += dinc
		end
	end
	fillp()
end

rainfr, rainfcnt = 0, 0

fade_patterns = {
	0b0101101001011010.1,
	0b0000101000001010.1,
	0,
	0,
	0b0000101000001010.1,
	0b0101101001011010.1
}
horiz_off, horiz_vel, end_flash = 0,8,8

function draw_fade(timer, color)
	fillp(fade_patterns[(timer \ 4) + 1])
	rectfill(0,0,127,127,color)
	fillp(0)
end

function end_text(xoff,yoff)
	print('path of', 50+xoff, 54+yoff,7)
	spr(236,47+xoff,60+yoff,4,2)
	print('the end', 49+xoff, 78+yoff, 11)
end

function _draw()
	cls(1)
	if room_i == 0 then
		cls(0)
		-- sky/horizon
		gradient(-8 + horiz_off,90,{0x0,0x1,0x2,0x8,0x9,0xa})
		-- landscape
		gradient(99 + horiz_off,15,{0x0,0x1,0x3})
	else
		-- grey sky
		gradient(0,30,{0x6,0xd,0x1})

		if rainfcnt > 1 then
			rainfr = (rainfr + 1) % 4
			rainfcnt = 0
		end
		rainfcnt += 1
		fillp(rain_patterns[rainfr+1])
		rectfill(0,0,128,128,0)
		fillp()
	end
	if is_end then
		if horiz_off < 31 then
			room_y -= horiz_vel
			horiz_off += horiz_vel*0.25/1.2
			horiz_vel *= 0.999
		else
			for c in all{{1,0},{1,1},{0,1},{-1,1},{-1,0},{-1,-1},{0,-1},{1,-1}} do
				pal_mono(0)
				end_text(c[1],c[2])
			end
			pal()
			end_text(0,0)
			if end_flash < 24 then
				draw_fade(end_flash,7)
				end_flash += 1
			else
			end
		end
	end

--end
--function a()

	camera(room_x,room_y)
	palt(0b0000000000000001)
	map(0,0,0,0,128,64)
	palt()
	camera()

	print_in_room(23,'path of', 53, 35, 1)
	print_in_room(23,'path of', 52, 34, 7)
	print_in_room(23,'demo 5', 52, 58, 11)
	print_in_room(23, '⬅️➡️ move\n🅾️ z jump\n❎ x fire', 46, 68, 6)
	print_in_room(22, '\npsst!\n❎+⬆️\n❎+⬅️+⬇️', 80, 58, 1)
	print_in_room(9, '\npsst!\nhold ❎', 43, 80, 1)

	camera(room_x,room_y)
	-- draw one layer at a time!
	for z=max_z,0,-1 do
		for t in all(thang) do
			if t.z == z then
				t:draw()
			end
		end
	end

	for r in all(rain) do
		for i=-1,r.h\8-1 do
			spr(123,r.x,i*8+rainfr*2)
		end
		spr(235,r.x,r.h-8+rainfr\2)
	end

	for f in all(fireball) do
		draw_smol_thang(f)
	end
	camera()

	if do_fade then
		draw_fade(fade_timer,0)
	end

	if dbg then
		print(dbgstr,8,0,7)
	end
end
-->8
--thang - entity/actor
-- thang = {} -- created in spawn_room()
-- number of layers to draw
-- max_z = 0 -- created in spawn_room()

function init_thang_dat()
	local iceblock, door, enemy = {
		init = init_replace_i,
		update = update_iceblock,
		burn = burn_iceblock
	},
	{
		init = init_replace_i,
		update = update_door,
		draw = no_thang,
		open = true,
		h = 16,
		stops_projs = false
	},
	{
		burn = burn_bad,
		burning = false,
		-- coll dimensions
		-- same as player..
		cw = 5.99,
		ch = 6.99,
		cx = 1,
		cy = 1,
		-- hurt box - bigger than player, same as collision box
		hw = 4.99,
		hh = 6.99,
		hx = 1,
		hy = 1,
		bad = true,
		air = true,
		g = 0.3,
		max_vy = 4
	}
	local thrower,shooter = {
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
		s_burn_s = 3,
		s_die_s = 4,
	},
	{}
	copy_into(thrower, shooter)
	shooter.do_shoot,
	shooter.check_shoot,
	shooter.s_burn_s,
	shooter.s_die_s =
		shoot_shot,
		check_shoot_shot,
		5,-13 -- 104 - 117
thang_dat = {
	[64]= {
		update = no_thang, -- update_p called directly
		s = 76,
		air = true, -- must start in air!
		onice = false,
		shcount = 0, -- shoot counter (cooldown)
		sh = false, -- charging fireball
		teeter = false,
		spawn = true,
		stops_projs = false,
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
		max_vx = 1.4,
		min_vx = 0.01, -- stop threshold
		g = 0.3, -- gravity
		max_vy = 4,
		j_vy = -4, -- jump accel
	},
	[91] = { -- checkpoint
		update = update_checkpoint,
		z = 2,
		stops_projs = false,
	},
	[82] = { -- lantern
		lit = false,
		update = update_lantern,
		burn = burn_lantern,
		hx = 2,
		hy = 2,
		hw = 4,
		hh = 4,
		z = 2,
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
		burn = burn_bad,
		bad = true,
		hp = 1,
		w = 7,
		h = 6,
		range = 56,
		dircount = 0,
		cw = 7,
		ch = 6,
		hw = 7,
		hh = 6,
	},
	[112] = { -- frog
		update = update_frog,
		burn = burn_frog,
		template = enemy,
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
		s_burn_s = 4,
		s_die_s = -8, --104 - 112
		pal_angry_k = {11,3,8},
		pal_v = {8,2,10} -- angry
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
		s_burn_s = 10,
		s_die  = {s=11, f=3}
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
	[256] = { -- shot
		update = update_shot,
		draw = draw_shot,
		stops_projs = false,
	},
	[208] = { -- archer
		update = update_archer,
		burn = burn_archer_wizard,
		hp = 5,
		shooting = false,
		shspeed = 6,
		goingrght = true, -- going to go after shooting 
		phase = 0,
		invis = false,
		invistimer = 0,
		template = enemy,
		shcount = 0, -- shoot stuff at player
		s_burn_s = 12,
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
		shield = false,
		shieldtimer = 0,
		s_burn_s = 4,
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
	},
	[257] = { -- rain
		update = no_thang,
		draw = no_thang
	}
}
end

function no_thang(t)
end

function init_replace_i(t)
	t.replace = t.i
end

function update_door(t)
	local num,mx,my = 1,t.x\8,t.y\8
	num = t.type == 1 and room_num_bads or num
	num = t.type == 2 and room_num_unlit or num
	if t.open then
		if num > 0 then
			if not aabb(t.x,t.y,t.w,t.h,
						p.x+p.cx,p.y+p.cy,
						p.cw,p.ch) then
					t.open = false
					mset(mx,my,t.s_top)
					mset(mx,my+1,t.s_bot)
			end
		end
	elseif num <= 0 then
		t.open = true
		mset(mx,my,t.i)
		mset(mx,my+1,31)
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
		t.s,t.alive = 88,false
		mset(t.x\8,t.y\8,31)
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

function dist_until_flag(x,y,flag,dir,vert)
	-- x, y are some position in world space
	-- dir can be -1 or 1 only
	-- set vert to true for y direction, otherwise it's x
	-- returns number of tiles until hit a wall or room border
	-- 0 if x,y are on a wall already
	if vert == nil then
		vert = false
	end

	local tiles, mx,my, xroomorig,yroomorig, xinc,yinc = 
		0,
		x\8,y\8,
		x\128,y\128,
		vert and 0 or dir,vert and dir or 0
	while true do
		local tile = mget(mx, my)
		if fget(tile, flag) then
			break
		end
		mx += xinc
		my += yinc
		tiles += 1
		if mx\16 != xroomorig or my\16 != yroomorig then
			break
		end
	end
	-- in the wall already
	if tiles == 0 then
		return 0
	end

	local off,fn = vert and y or x,dir > 0 and roundup or rounddown
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
		t.s = 104
		if play_anim(t, 5, 3) then
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
		t.s = 104
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
	t.s = t.i + t.s_burn_s
	if play_anim(t, 6, 1) then
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
		t.trace_color, t.arrow_color = 7, 7
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
		t.trace_color,t.arrow_color = 1,12
	end
	if t.fcnt > 6 then
		t.arrow_color = 1
	end
	t.fcnt += 1
end

function throw_icepick(t)
	local xfac = t.rght and 1 or -1
	if play_anim(t, 20, 1) then
		t.shooting = false
		local i = spawn_thang(
					107,
					t.x - 3 * xfac,
					t.y + 4)
		if not t.rght then
			i.xflip,i.vx = true,-i.vx
		end
		reset_anim_state(t)
	end
end

function face_p(t)
	t.rght = p.x >= t.x and true or false
end

function reset_anim_state(t)
	t.fcnt,t.fr = 0,0
end

function check_shoot_shot(t)
	local shleft,shright = dist_until_flag(t.x + 4, t.y + 4, 1, -1),dist_until_flag(t.x + 4, t.y + 4, 1, 1)
	if hit_p(t.x + 4 - shleft, t.y, shleft + shright, 8) then
		face_p(t)
		t.shcount,t.shooting = 5,true
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
		t.s = t.i + 2
		t:do_shoot()
	-- else we walking
	else
		t.s = t.i
		-- remember which way we were going
		t.rght = t.goingrght
		if not t.air then
			t.vx = t.rght and 0.75 or -0.75
			loop_anim(t,4,2)
		end

		if t.shcount <= 0 then
			t:check_shoot()
		else
			t.shcount -= 1
		end
	end

	local phys_result = phys_thang(t, t.air)

	if not t.air and not t.shooting then
		if phys_result.hit_wall or coll_edge(t,t.x) != 0 then
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
	if play_anim(t, t.shspeed, 3) then
		t.shooting = false
		reset_anim_state(t)
	elseif t.fr == 2 and t.fcnt == 1 then
		sfx(snd_shooter_shot)
		local orig = {
			x = t.rght and t.x + 8 or t.x - 1,
			y = t.y + 3
		}
		local shleft,shright,shot = dist_until_flag(t.x + 4, t.y + 4, 1, -1),dist_until_flag(t.x + 4, t.y + 4, 1, 1),spawn_thang(256, orig.x, orig.y)
		shot.endx,shot.endy = t.x + 4 + (t.rght and shright or -shleft), orig.y
		shot.arrowx,shot.arrowy = t.rght and shot.endx - 5 or shot.endx + 5, orig.y
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
		t.invis,t.stops_projs,t.invistimer,t.shooting = true, false, 70, false
		reset_anim_state(t)
	end

	local oldair = t.air
	if not oldair then
		t.vx = 0
	end

	if t.shooting then
		t.s = t.i + (t.air and 9 or 3)
		shoot_shot(t)
	-- else we walking or jumping
	else
		-- idle
		if t.phase == 0 then
			t.s = t.i
			local r = get_room_xy(room_i)
			if p.y > r.y + 16 then
				t.phase = 1
			end
			return
		end
		-- remember which way we were going
		t.rght = t.goingrght
		if not t.air then
			t.s = 209
			-- default velocity, may be change if we fall
			t.vx = 1.2
			if coll_edge(t,t.x) != 0 then
				-- is there a platform below us to fall down onto?
				local check_x,check_y = t.x + 4, t.y + 20 -- t.x + 4 + 16 - tile below the one t is standing on
				local is_plat_below = not fget(
					mget(
						check_x\8,
						check_y\8 + dist_until_flag(check_x, check_y, 0, 1, true)\8 + 1
					), 1)
				-- choices of what to do when coll_edge
				local choices = {0,1}
				-- increase chance of jump when player above
				if p.y < t.y then
					add(choices,1)
				end
				if is_plat_below then
					add(choices,2)
					-- increase chance of drop down when player below
					if p.y > t.y then
						add(choices,2)
					end
				end
				local choice = rnd(choices)
				-- turn around
				if choice == 0 then
					t.rght = not t.rght
				-- big jump
				elseif choice == 1 then
					sfx(snd_knight_jump)
					t.air,t.vy = true,-4
				-- fall down
				else
					t.air,t.vy,t.vx = true,0,0.4
				end
			end
			t.vx = t.rght and t.vx or -t.vx
			-- walk
			loop_anim(t,4,2)
		end

		-- save which way we're going (we might face a different way when shooting)
		t.goingrght = t.rght
		-- check air again
		if t.air then
			t.s = t.i + 7
			-- jump
			if t.vy < 0 then
				t.s -= 1
				reset_anim_state(t)
			-- fall
			else
				loop_anim(t,4,2)
			end
		end

		if t.invis then
			t.invistimer -= 1
			t.pal_k = t.invis_pal_k
			local fr = t.invistimer < 12 and 11 - t.invistimer or t.invistimer - 58
			if fr >= 0 then
				t.pal_v = t.invis_pal_v[fr\4+1]
			else
				for i=1,6 do
					t.pal_v[i] = 0
				end
			end
			--
			if t.invistimer == 15 then
				sfx(snd_archer_invis)
			elseif t.invistimer <= 0 then
				t.stops_projs,t.invis,t.pal_k = true,false,{}
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
		t.invis,t.pal_k = false,{}
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
	t.tping,t.stops_projs = true,false
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
				if (plat.x != t.x or plat.y != t.y) and (t.shield or vlen{x=plat.x-p.x,y=plat.y-p.y} > 48) then
					add(plats, plat)
				end
			end
		end
	end
	t.tp_to,t.tp_from = rnd(plats),{x=t.x,y=t.y}
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
		spawn_thang(96, t.x+xy[1], t.y+xy[2])	
	end
	room_num_bads += 3
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

function spell_shield(t)
	t.shield = true
	t.shieldtimer = 190
end

spells = {{fn = spell_summon_bats, cast_time = 50, recovery = 45},
		{fn = spell_frost_nova, pal_k = {8,2}, pal_v = {7,12}, cast_time = 45, recovery = 30},
		{fn = spell_shield, pal_k = {1,2,8}, pal_v = {4,9,10}, cast_time = 55, recovery = 20}}

function too_many_bats()
	local num = 0
	for t in all(thang) do
		num += t.i == 96 and 1 or 0
	end
	return num >= 7
end

function start_casting(t)
	t.casting = true
	local sub_spells = {}
	copy_into(spells,sub_spells)
	if t.shield then
		-- no re-shielding
		deli(sub_spells)
	end
	if too_many_bats() then
		-- no more bats!
		deli(sub_spells, 1)
	end
	t.spell,t.castu = rnd(sub_spells),spawn_thang(240, t.x, t.y - 6)	
	t.castu.pal_k,t.castu.pal_v = t.spell.pal_k,t.spell.pal_v
	t.shcount = t.shield and 20 or t.spell.cast_time
end

function update_wizard(t)

	if do_boss_die(t) then
		if t.castu != nil then
			t.castu.state = 2
			reset_anim_state(t.castu)
		end
		-- burn 1 bat per frame (looks better than burning all at once)
		for t in all(thang) do
			if t.i == 96 and t.alive then
				t:burn()
				break
			end
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
		t.s = t.i + 1
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
		t.s = t.i + 1
		loop_anim(t,8,3)
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
			t.shcount = t.shield and 20 or t.spell.recovery
			t.spell.fn(t)
		end

	-- else we standing or hovering around waving our arms
	else
		-- idle
		if t.phase == 0 then
			-- hover
			t.s = t.i
			if play_anim(t, 20, 1) then
				t.hover_up = not t.hover_up
				local dir = t.hover_up and -1 or 1
				t.y += dir
				reset_anim_state(t)
			end
			-- start combat - teleport away
			local r = get_room_xy(room_i)
			if p.y > r.y + 16 then
				t.phase = 1
				t.y += t.hover_up and 2 or 1
				start_tp(t)
			end
			t.shcount = 0
			return
		end

		t.s = t.i + 1
		t.fr = 0

		t.shcount -= 1
		if t.shcount <= 0 then
			start_tp(t)
		end
	end
	if t.shield then
		t.shieldtimer-=1
		if t.shieldtimer==0 then
			t.shield=false
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
		t.pal_k = t.pal_angry_k
	end

	local oldair = t.air
	-- not burning and not in the air
	if not t.air then
		t.s = t.i
		t.vx = 0
		face_p(t)
		local dir = t.rght and 1 or -1
		-- not angry - jump when player charges fireball
		if not t.angry then
			if t.croak then
				-- play full idle anim (croak)
				if play_anim(t, 5, 2) then
					sfx(snd_frog_croak)
					t.croak = false
					reset_anim_state(t)
				end
			else
				-- just play first frame for a bit
				if play_anim(t, 40, 1) then
					t.croak = true
					reset_anim_state(t)
				end
			end
			if p.sh then
				sfx(snd_frog_jump)
				t.vy = -3.5
				t.vx = 1.2 * dir
				t.air = true
			end
		else -- angry - jump rapidly at player
			if t.jcount <= 0 then
				t.angry = false
				t.pal_k = {}
			else
				t.jcount -= 1
				sfx(snd_frog_jump)
				-- small jump
				if not t.bounced or t.do_smol then
					t.vy = -2.5
					t.do_smol = false
				-- big jump if we bounced off a wall
				else
					t.vy = -3.5
					t.bounced = false
					t.do_smol = true -- always do a small jump after a big one
				end
				t.vx = 1.5 * dir
				t.air = true
			end
		end
	end

	-- physics - always run because falling could happen e.g. due to ice breaking
	local oldvx, oldx, oldy = t.vx, t.x, t.y
	local phys_result = phys_thang(t, oldair)
	-- if hit ceiling, redo physics with tiny jump
	if phys_result.ceil_cancel then
		t.vx = oldvx
		t.vy = -1 + t.g
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
		t.s = t.i + 2
		if t.vy > 0 then
			t.fr = 1 -- descend
		else
			t.fr = 0 -- ascend
		end
	end

	-- on landing, reset to idle
	if not t.air and phys_result.landed then
		t.s = t.i
		t.fr = 0
		t.fcnt = rnd{0,10,20,30}
	end

	if check_bad_coll_spikes(t) then
		return
	end

	kill_p_on_coll(t)
end

function kill_p_on_coll(t)
	if t.alive and p.alive and hit_p(t.x,t.y,t.w,t.h) then
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
	if not t.invis and not t.tping and not t.shield then
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
	local tfloor, pfloor = 	t.lfloor != nil and t.lfloor or t.rfloor,
							p.lfloor != nil and p.lfloor or p.rfloor
	-- on same level
	if pfloor.my != tfloor.my then
		return 0
	end

	local mx, pmx, topy, boty, dir = tfloor.mx, pfloor.mx, tfloor.my - 1, tfloor.my, p.x < t.x and -1 or 1
	while mx != pmx do
		if not fget(mget(mx, boty), 0) then
			return 0
		elseif fget(mget(mx, topy), 1) then
			return 0
		end
		mx += dir
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

	local oldair, oldatking, oldburning = t.air, t.atking, t.burning

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

	if t.alive then
		if t.atking then
			t.s = t.phase == 2 and 198 or 195
			if play_anim(t, 10, 3) then
				t.atking = false
				reset_anim_state(t)
			elseif t.fr > 0 then
				if t.phase == 1 and t.fr == 1 and t.fcnt == 1 then
					sfx(snd_knight_swing)
				end
				-- jump!
				if t.phase == 2 and not t.air and t.fr == 1 and t.fcnt == 1 then
					sfx(snd_knight_jump)
					t.vy = -3
					t.vx = t.rght and 1 or -1
					t.air = true
				end
				t.swrd_draw = true
				t.swrd_fr = t.fr - 1
				-- all frames hit for now, not just first frame
				t.swrd_hit = true
			end
		-- grounded state
		--  phase 0 - idle
		--  phase 1 - walk toward player if on same platform, attack
		--  phase 2 - walk until timer expires, then jump toward player
		-- if atking ended, immediately walk this frame
		elseif not t.air then
			local dir = p_on_same_plat(t)

			if t.phase == 0 then
				t.s = t.i
				reset_anim_state(t)
				-- don't advance phase if p is dead
				if p.alive and dir != 0 then
					t.phase = 1
				end
			end

			if t.phase > 0 then
				t.s = t.i + 1
				-- follow player if they're on same platform
				if dir != 0 then
					t.rght = dir == 1 and true or false
				end
				if t.rght then
					t.vx = 0.75
				else
					t.vx = -0.75
				end

				loop_anim(t,3,2)

				t.atktimer += 1 -- time since last attack
				if 		t.phase == 1 and vlen{ x = t.x - p.x, y = t.y - p.y } <= t.atkrange or
						t.phase == 2 and t.atktimer >= t.jmptime then
					t.atktimer = 0
					t.atking = true
					reset_anim_state(t)
					face_p(t)
				end
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
		-- animate falling
		if not t.atking then
			t.s = t.i + 9
			reset_anim_state(t)
		end
	elseif not t.atking and phys_result.hit_wall or coll_edge(t,t.x) != 0 then
		t.rght = not t.rght
	end

	-- change phase if attack ended for any reason
	-- switch phase after attacking
	if oldatking and not t.atking then
		if t.phase == 1 then
			t.phase = 2
			t.jmptime = 20 + rnd{0,15,30}
		else
			t.phase = 1
		end
	-- change phase if haven't attacked in a while
	elseif t.phase == 1 and t.atktimer > 60 then
		t.phase = 2
		t.jmptime = 10 + rnd{0,15,30}
	end
		
	-- don't kill p if we're dead! (e.g. falling)
	if t.alive and p.alive then
		local swrd_start_x = t.rght and 8 or -t.swrd_x_off
		if kill_p_on_coll(t) then
			t.phase = 0
		elseif t.swrd_hit and hit_p(t.x + swrd_start_x, t.y + t.swrd_y, t.swrd_w, t.swrd_h) then
			kill_p()
			t.phase = 0
		end
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
	b.fcnt = rnd{0,1,2,3}
end

function update_bat(b)
	if b.burning then
		b.burning = false
		b.alive = false
		b.s = 98
		b.vy = 0.6
		b.deadf = 20
		return
	elseif not b.alive then
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
			b.vx = b2p.x * 0.5/dist2p
			b.vy = b2p.y * 0.4/dist2p
			b.dircount = 30
		-- pick random direction
		else
			local rndv = {x = rnd(2) - 1, y = rnd(2) - 1}
			local len = vlen(rndv)
			b.vx = rndv.x * 0.5/len
			b.vy = rndv.y * 0.4/len
			-- reset quicker if we're in range
			if in_range then
				b.dircount = 20
			else
				b.dircount = 60
			end
		end
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
		l.s = 83
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
		z = 1,
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
		replace = 31,
		-- alt palette (no need for pal_v)
		pal_k = {}
	}
	-- apply template first
	local template = thang_dat[i].template
	if template != nil then
		copy_into(template, t)
	end
	-- overwrite defaults/template with specific stuff
	copy_into(thang_dat[i], t)
	if t.init != nil then
		t:init()
	end
	add(thang,t)
	return t
end

-->8
-- player

function spawn_p(x,y)
	p = spawn_thang(64,x,y)
	p.rght = not (room_i < 8 or room_i > 15)
end

function kill_p()
	sfx(snd_p_die)
	music(-1,800,3)
	p.alive,p.s = false,71
	reset_anim_state(p)
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
 
	-- grounded ax
	local ax = 1
	p.max_vx = 1.4
	-- stop moving for 4 frames after firing (grounded)
	if p.shcount >= 6 and not p.air then
		p.max_vx = 0
	elseif p.sh then
		p.max_vx = p.air and 0.7 or 0
	elseif p.air then
		ax = 0.3
	elseif p.onice then
		ax = 0.2
	end

	-- accel
	if btn(⬅️) and not p.rght then
		p.vx -= ax
	elseif btn(➡️) and p.rght then
		p.vx += ax
	end

	--decel
	if not btn(⬅️) and not btn(➡️) then
		if p.air then
			p.vx *= 0.8
		elseif p.onice then
			p.vx *= 0.9
		else
			-- ground
			p.vx *= 0.6
		end
	end

	p.vx = clamp(p.vx, -p.max_vx, p.max_vx)
	if abs(p.vx) < p.min_vx then
		p.vx = 0
	end

	-- vy - jump and land
	local oldair,jumped = p.air, false
	if btnp(🅾️) and not p.air and not p.sh then
		jumped = true
		p.vy += p.j_vy
		p.air = true
	end
	if p.sh and p.vy > 0 then
		p.max_vy,p.g = 1, 0.05
	else
		p.max_vy,p.g = 4, 0.3
	end

	local oldx,oldy = p.x,p.y
	local phys_result = phys_thang(p, oldair)

	-- fall off platform only if
	-- holding direction of movement
	-- kill 2 bugs with one hack
	-- here - you slip off ice,
	-- and fall when it's destroyed
	if phys_result.fell and not p.onice then
		if 		btn(⬅️) and p.vx < 0 or
				btn(➡️) and p.vx > 0 then
			-- none
		else
			p.air,p.x,p.y,p.vx,p.vy = false,oldx,oldy,0,0
		end
	end

	-- close to edge?
	p.teeter = not p.air and coll_edge(p,p.x,true)

	if phys_result.landed then
		sfx(snd_p_land)
	elseif jumped and not phys_result.ceil_cancel then
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
		for t in all(thang) do
			if t.i == 257 and hit_p(t.x,t.y,t.w,t.h) then
				p.sh = false
			end
		end
		if p.sh then
			local xdir,ydir = 0,0
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
				xdir = p.rght and 1 or -1
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
		p.s = 94
		if not oldsh then
			sfx(snd_p_shoot)
			p.fr = 0
			p.fcnt = 0
		end
		if loop_anim(p,3,2) then
			sfx(snd_p_shoot)
		end

	elseif not p.air then
		-- walk anim
		p.s = 64
		-- just landed, or changed dir
		if oldair or btnp(➡️) or btnp(⬅️) then
			reset_anim_state(p)
		elseif abs(p.vx) > 0.5 then
			loop_anim(p,3,2)
		elseif p.teeter then
			p.fr = 1
		else
			p.fr = 0
		end

	else --p.air
		p.s = 66
		if not oldair then
			reset_anim_state(p)
		end
		if p.vy >= 0 then
			p.s += 3
			loop_anim(p,3,2)
		else
			play_anim(p,3,4)
		end
	end
end

function respawn_update_p()
	-- do nothing while fading out/in
	if do_fade then
		return
	end
	if not p.alive then
		if play_anim(p,3,5) then
			-- fade out after death anim
			fade_timer = 0
			do_fade = true
			reset_anim_state(p)
			p.s = 31
		end
	elseif p.spawn then
		if play_anim(p,3,4) then
			reset_anim_state(p)
			p.s = 64
			p.spawn = false
			start_music()
		elseif p.fr == 0 and p.fcnt == 1 then
			sfx(snd_p_respawn, 3)
		end
	end
end
-->8
-- fireball
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
	f.sfr,f.vx,f.vy,f.xflip,f.yflip = prop[1],prop[2] * f.speed,prop[3] * f.speed,prop[4],prop[5]
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
	f.alive,f.yflip,f.sfr,f.s,f.fcnt = false,false,0,f.s_die_s,0
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

function coll_edge(t,newx,face_either_way)
	-- t = {
	--   ftx	-- foot x offset
	--   ftw	-- foot width
	--   rght	-- facing right
	-- }
	-- if face_either_way, return true if either foot is near an edge
	-- otherwise check if foot is close to edge, and facing off edge
	-- return 1 for right, -1 for left, 0 for not
	local fty = t.y + t.h
	local tftxl = newx + t.ftx
	local tftxr = tftxl + t.ftw
	local coll_r,coll_l = collmap(tftxr+1,fty,0),collmap(tftxl-1,fty,0)
	if face_either_way then
		return not (coll_r and coll_l)
	elseif t.rght then
		return not coll_r and 1 or 0
	end
	return not coll_l and -1 or 0
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
ffffffffdddddddddddddddddddddddddddddddd055555500000000005555550011111100111111011011110ffffffffdddddddddddddddd0111111001111110
ffffffff0dddddd00dddddddddddddddddddddd011555151000000001551515501dddd100111111000100000ffffffff0dddddddddddddd00155551001555510
ffffffff0111111001111110000000000111111055151555000000005555551101dddd100111111000100000ffffffff00000000000000000111111001111110
ffffffff011001100110011111111111111001101551515111111111551151510111111001dddd10000000001fffffff01111111111111100000000000000000
ffffffff010000100100001000000000010000101155511100000000155511510000000001dddd101fff11101fffffff00000000000000000000000000000000
ffffffff001111000111111001100110011111101515151101100110111115550000000001dddd1011ffd1001f3ff3ff01100110011001100000000000000000
ffffffff000000000100001111111111110000101111151111111111151155110000000001dddd10001dd100033f3fff00111111111111000000000000000000
ffffffff000000000100001000000000010000100151111000000000011115100000000001dddd10001d1000013333ff00000000000000000000000000000000
dddddddddddddddddddddddddddddddddddddddddddddddd11111111dddddddd0111111001dddd1000011000ffffffff55555555555555555555555500000000
0dddddddddddddddddddddddddddddd00dddddd00dddddd0001000000dddddd01111111d01dddd1000111100ffffffff05515115551555555515515000000000
01111111111111111111111111111110011111100111111000100000011111101d11d1dd01dddd1001100110ffffffff01001110110011001100110000000000
011ddd11111111111111111111ddd110011dd1100110011000000000011dd110111ddd1d01dddd1011000011fffffff000000010001001010010010000000000
01ddddd1ddddd1dddd1dd1dd1ddddd1001dddd10010000101111111101dddd101ddddddd01dddd1011111111fffff3f000101101100010101000101000000000
01111111ddddd1ddddd1d1dd11111110011111100111111000000100011111101dd1d1dd01dddd1010000001fff3ff3d00100000001100001110000000000000
01d1d1d1ddddd1dddddd11dd1d1d1d1001dddd10010000100000010001dddd1011d1dddd011dd11001111110ffff33d000000100000001010001010000000000
01d1d1d111111111111111111d1d1d1001dddd100100001000000000011111100dddddd00011110001fffd10fff3d00000000000000001000000000000000000
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd100100001000011000dddddddddddddddd0000000001fffd1000011000fffd0000000001ff0000000055555555
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd1001000010000001010dddddddddddddd00000000001fffd1000111100fdd000000000001f0000000005115550
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd10010000100010000001111111111111100000000001fffd101ffffd10d0000000000000000000000001001110
01d1d1d111111111111111111d1d1d1001dddd100100001000010000011ddd1111ddd1100000000001dddd10fffffd1100000000000000000000000000100010
01d1d1d1ddddd1ddddddd1dd1d1d1d1001dddd10010000100110001101ddddd11ddddd100000000011111111fffffd1110000000000000000000000001001100
01d1d1d1ddddd1ddddddd1dd1d1d1d1001dddd100100001000000001011111111111111000000000100000011fffd100f1000000000000000303003000100000
01d1d1d1ddddd1ddddddd11d1d1d1d1001dddd10010000101001000001d1d1d11d1d1d10003030030111111011ffd101fd000000000000003003303300010100
01d1d1d111111111111111111d1d1d1001dddd1001000010000100000111111111111110303300330000000001fffd10d0000000000000003033330300000000
01d1d1d1dd1d1ddddd1ddddd1d1d1d1001dddd10010000105151551501d1ddddd1dddd100ff3fd005555555555555555dddddddddddddddd11111111ffffffff
01d1d1d1dd1dd11ddd1ddddd1d1d1d1001dddd10010000101151515501d1ddddd1dddd10013f3d0011515551155555510dddddddddddddd0f111111fffffffdf
01d1d1d1dd1dddd1dd1ddddd1d1d1d1001dddd10011001105511555501d1ddddd1dddd100013300055111555551115150111111111111110f110011ffffffd1f
01d1d1d111111111111111111d1d1d1001dddd1001011010555555550111111111111110000010005551115555551111011dd111111dd110f000000ff1ffd00f
011ddd11ddddd1ddddddd1dd11ddd110011dd11001000010115511111ddddd1ddddd1dd100001000555151515555555101dddd1dd1dddd10f111111ff01dd11f
dd11111dddddd1dddddd11ddd11111dd01d11d1010111101011115111ddddd1ddddd1dd10000100011551511115511550111111dd1111110f000000ff001000f
1dddddddddddd1ddddd1d1dddddddddd1dddddd110000001011511001ddddd1ddddd1dd1000000005511151511551555011dd11dd11dd110f000000ff110000f
1111111111111111111111111111111111111111111111110001110011111111111111110000000015555155151111110111111111111110f000000ff000000f
00022200000222000000000000505200000000000022220000222200002220000002000000200020000000000000000000000000000000000000000000000000
002211200022112002222220002222200002220000221120002211200221200000222000002202000020000000020000000000000000000007007000007022a0
0021112000211120222222220022222202212220022111200221112222111200022120002022222000220200002200000000000000072000009a2707700a1127
02211120022111202222222202222222211122250221122202211222221112202211202002212220022220000012200000070a00070292a072199aa0002971a0
02222220022222205222111202222222222222200222222202222220222222202221122002111220002120000001100000a9900000a9899009a889000a922920
02222220022222200222212002222222222222250222222022222220022222220222222000211200000110000000100009989990098888a002988890a922229a
222222002222220052222200002222200222222222222500022225000222205002222250000210000000000000000000000000000098820000a99a2009829890
0050050000055000000000000000000000222000022050000020500000205000002250000000000000000000000000000000000000000000000a000000900500
bbbb0980070a707000022000000220000002200000001000c77c7ccc0cccccc00070c00000000000000000000000000000000000000700000002e200002e2000
bbbb7a987a99a7a700222200002222000022220000010000cccc777cccc711cc00c070c0000000000000000000000000000007000000000002e11e0000e11e20
bbbb7a98099a0890021001200210012002100120000010001ccccc7c1c7cc1cc0c7ccc000c0c0c0000c000000000070000700000000a000002e71e2002e17e20
bbbb0980008000000210712002a0712002170120000100001ccccccc1ccccc1c10c7c1cc00c700000000700000700a000090aa0000a00700029a7a2222a7a920
077007a0070770a0201001022017a102207aa10200001000c1cccc1cc1cccc1cccccc1c10c00c7c0070c0c0000a990000009900000099a002289a922229a9822
9aa97a98099a099020100102201891022018910200010000c11cc11cc11cc11c11cccc10cccc0c0c0c00000c00988900009889000098890002e88e2002e88e20
8998a9980080000002011020020110200201102000001000ccc11cc00ccc11cc0c1c1cc11c0c1cc1100cc7100d66ddd00dd66dd00dd666d0002ee200002ee200
08800880000000000222222002222220022222200001000001ccc11001ccccc000c101c00c110c100c010c000011110000111100001111000005500000055000
5500050000000000007000700700070000066600000666000006660000ee00000007000000000000000000007ccc000cc7c70c00011111100111111000006000
055055000000000008a707a009a707a0000611600006116000c611600ee7e0000000a70000707000000700000c000ccc0c70c7c7011111100111111006007000
0085800000085800009a0a80008a0a9000661160006611600c6611600ee77e00707aaaa0000aa000070a00000c00700c777c077c015555100155551007007000
00050000055555000008a9000009a80006c66160066c6160cc6661600eee7e900aa999a007a997000000900000c0000cc0c70c00015555100155551000706000
0000000055000550000098000000890006cc6660066cc66005666665088eee0000a9a900009980000000000007007000c00c000c155555511555155100606007
000000005000005000000000000000000566c66506566c6000c6666080eeeee008998900000800000000000000c0c00cc70707001511115115151551601d1060
00000000000000000000000000000000c06666000c66660000666600090eeee000088000000000000000000000c0ccc00000700715111151151dd1510d1d1d10
0000000000000000000000000000000000500500000550000050050000890090000000000000000000000000ccccc0000c700000151d1d511551d15111111111
0000000000000000000000b0bb00000000000e00000666000006660000066c0000066600000666c00eee0800100000c0bbbb0c7015111151151d155111111111
000000000000000000000b8b03b000000000e7e0006116c000611600006116c000611cc00061160ce77e0080c0000000bbbb11c7155115511551155101515150
00000b0000000b000004bbb300b0000000eeee200061160c006116c00061160c0061160c0061160ce77e0080c0001000bbbb11c7155555511555555106015106
0000b8b00000b8b0004443b000b400b00000ee000666660c066666c0066566656656666566566665eeeeee90c000c000bbbb0c70015555100155551060060600
00bbbb3000bbbb3000b400b000444b8b0008820066666665066666500066660c0066660c0066660c0eee0080c010c01001100110015555100155551000060600
04443b0004443b300bb300000004bbb300e880005066660c056666c0006666c000666cc00066660c9eeee08010c0c0c0c11c11c7011111100111111000060060
04443b0004443b00b3000000000003b0ee0020000066650c006660c000666c0000666500006665c00999980000c010c07cc71cc7001dd100001dd10000060060
003bb0b0003bb0b0b0000000000000b000220000005005c000055c0000500500005005000050050000900900001000c007700770001111000011110000060000
70f142b370a3b350b370a3a35041704150626262626262626262626575507050707050705070705070505050705070505070637063706350705063a3b3a3b3a3
5070507050705050705070a3b3a3b3a3a3707070a3a3b3a3b3705070a370a3b370706363706363a3b3707070a3707050a3b3637063b3b3b350b3b350b3b3b3a3
70104250b3a370a350b350706342f14250626250705050816262f1f1f1655050507070f1f1f162f1f1f163f1f1f1f15070f155f155f1556250626262f17063b3
706262f1f1752565f162705070b3a3b3706325f1f170507050707070f1f163a37062f1f1f1f1655070f1256575507070b363f1f1f16375657565656370a3a3a3
70f142507050b350b350a3706243f143706270f7f7f7f7f1f1f1f1f1f1f175707050f1f1f1f1f170f1f1f1f1f170f180f0f125f155f155f170625070f1f1f180
f0f1f1f1f1705070f1f162627525a3b37050f2f1f1f1f163f1f17070f1f1f180f0f1f1f1f1f1f163f162f2f1f16350707050f150f1f1f1f175757575505070b3
70f142706362505050626362f1f1f180f16250f1f1f1f1f1f1f175f1f1f1f15050f1f192f107f1f1f192f1b5f1f162f1f1f1f1f155f125f1f1625062f1b5f1f1
f1f1f1f1f16262f1f1f1f162507050a35025f1f1f1f1f1f1f1f163f1f1b5f1f1f192f125e2f1f1f1f1f1f1f1f1655050a370f1f1f1f1f1f1f1f16575657563b3
701043506262626362626262b592f1f1f15070f1f175f1f1f1f165f1f1f1f170706570705070b3b3a35070507050705070f1f1f125f1f1f1f1f17062505070a3
70f1f1f262f1f1f1f1f2f1f1f1506350507050f1f1f1f1f1f1f1f1f1f170505070d1d1d1d1e1f162f1f162f1f1f16370b36370f1f1f1f1f1f1f1f1f175656550
70f162e0f1f16262626262f141d1d170705050f1f165f1f1f1f1f1f1f1f1655050f1f1f1f1f170a363f1f1f15070f17050f107f1f1f1f150f1f15062626350b3
50f162f1f1f1f1f1f162f1f1f1652570a37050f1f1f1f1f1f1f1f1f1f170b3a3507062f1f1f1f192f1f162f1f1f17050b37050f1f1f1cedeeefef1f1f17565a3
70e2f1f162f162f1f1f162f142f1f170b35062f1f1f1f165f1f1f1f1f175655070f1f1f1f1f1f163f1f1f1f1f1e0f1a3706250507050705070507050626270a3
70f1f1f1f1f1f1f1f1f1f1f1f15070507050f1f1f1f1f1f1f1e2705070b3a3b3507050f1f1f1f1c1d1d1e1f1f1f17550b35070f1f1f1cfdfeffff1f1f1f175b3
70d1d141f1f1f1f162f1f1f142f170705062f165f1f1f175f1f1f1f18165757050f192f19292f165f1f1e2e2f1f1f1705062f1f1f1f1f1f162626270f16270b3
50f1f1f1f1f1f1f1f1f2f1f1f1625070a3f1f1066292f181f270b3a3b3a3b3a37050709262f1f1f1f1f1f1f1f1f1f1707070f1f1f1f1f1f1f1f1f1f1f1f165a3
70f1f142f1f1f1f1f1f1f1f142f1f15070f1f1f1f1f1f1f1f1f1f1f1f1f1655070d1d1d1d1d1d150d1d1d1d1d170f1a37050e1f1f150f15070506250f1f170a3
70f1f1f1f1f2f1f1f1f1f1f1f1f1f15050f15070507050502550a3b350b3a3b350d1d1d1e1f1f1f1f1f1f1f1f1f1f150a350f1f1f1f1f1f1f1f1f1f1f1f175b3
5050f142f1f1f1f1f1f1f1f142f170b350f1f1f1f1f1f1f1f1f1f1f1f1f1757050f1f1f1f1f1f170f1f1f1f1f150f170506362f1f150f162637062f1f1f170b3
50f1f1f1f1f1f1f1f1f1f1f1f1f1f17070626262f06262705070b370625070b370f162f162f1622592f1f1f1f1f1f15050f1f1f1f1f1f1f1f1f1f1f1f1f1f1a3
50f1f142f151f1f1f1f151f1425070a37062f175f1f1f16575f1f1f1f1f1f1507007f1f1f1f1f15006f107f1f170f1a3706262f1c170f1256250f1f1f1f170a3
70f1f2f1f1f1f1f1f1f1f1f1f1f1f1505062f162f1f1626262627050626262a35025f1f1f1f1507050f1f1f1f1f1f18065f1f1f1f1f1f1f1f1f1f1f1f1b5f1b3
7050f143f153f10cf1f153f143f150b350626281f1f1f1f1f1f1f1f1b5f1f170705050705070f170f15070705062f17070f1f1f16270d1d1d17007f1f1f170b3
70f162f1f1f1f1f1f1f2f1f1f1b5f1507050705070506206f16262636206f1b370f2f1f162f17050f1f1f1f1b5f162f1e265f16575f1f1f1f1f1f1f172218250
7070e2c03030303030303030d05070a370f66262f1f162f1f16262f171f1f18063626263f1625062505063f150f162b3b325f6f1f6706262f16350f125f170a3
5062f1f1f1f162f1f162626250d1d17050626262f170505050626262626262a37062f1f1f1f1f1f1f1f1f1c1d1d1d1705075f175657565f1f1f1f17173138350
b3a350f17092705070f15092705050a3a370f6f6626262626262626243f1f1f162e2f1f162f16292e2f1f1f1f16270b3a3a350f650506207f16262625050a3b3
70f662c1e162f6626262f6f670626280e0f162f1626262f162626206f16281b3506262f1f1f1f1f1f16262626262627070657565756575f1f165717323228350
70b3a350a350a350b3a370a3a3b3a3a3a3a3a350f6f6f6f6f6f6f6f670b3a3b37050706270925050a3506262e25070b3b3a3b3a3b3a3b3a3b3a3b3a3b3a3b3a3
5070f6f6f6f670f6f6f67050636262f1f1f15070f162627062626262815070a370f6f6f6f6f6f6f6f6f6f6f6f6f6f650a3506575659265756571731322128350
70a3b3a3b3a3a3b3a3b3a3a3b3a3a3a3b3b3a3b3a3a3a3a3b3a3b3a3b3a3b3a3a3a3a370a3a350a3a370a3a370a370b3a3b3a3b3a3b3a3a3a3a3a3b3a3a3b3a3
a3b3a3b3a3b3a3a3b3b3a3b3a3a3b3a3b3a3b3a3b3a3b3a3a3b3b3a3b370b3a3a3b3b3a3b3a3b3a3b3a3b3a3b3a370a3b3a3b3b3a3a3b3a3a3b3a3b3a3b3a3b3
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
c6666004cc6666cffc6666f0cc6666040e7777900777770000777000ac9669907caca590010b9100000000000c000000001aaaaa00aa11101100aaa7107a1a71
cc666c04fcc66604ccc666400cc666049ee7778000777000000700000fc996c809a9898000a599000051000000000c0c001aa1aa00aa11111000aaaa11aa1aa1
ccf6fc040ccc60040ccc60400ccc600400ee7e080007000000000000989c69800088880005000100051b510010c0c0001019a09a00aa101000109aaa10aa1aa1
0cccc000ccccc004ccccc040ccccc0000eeeee08000000000000000009888800000000000051005011151150001c0100100990a9109a1000010999aa919a1a91
000000000000000000000000000000000120012000100200100010c00006600000000000000660000066000007eee00000991099119910001109991999991991
000000000000000000001000000000002821028208001008c000c000006006006006600060600600660060000e07700000991099919911111109911999911991
001200000000800008000000001821002110012100000000c000c000606dd6d06060d6d0060dd6d000ddd6007eee070000899999919919aa1009910199910991
000000000020010000000020010200001000001000000020c000c00006d0662006d6662000d6d620dd666d200777e800089889899199199a9919810199819981
000008000010000002000000080000000000000002000000c00010100d66d2120d60d2120d6d6212000dd2127ee7898008811118918911999918911118818891
008001000008020000000000021000100021000000000000100000c0d0006d200d006d20d0066d20d6d06d20e00e780008810008881881891008811018818810
000200000000000000100800000082200188210020108000000000c000660d00d066d0000060d0000066d0000e7e000088101008881888881008810018818810
000000000000000000000000000000000021100000000010000000c00000d000000d0000000d00000ddd00000007ee0008100000800188810000810000810801
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
0001010101030003100300000101101003030303030100030303000001010100030303030300000303000000000000010303030303000303030003030303000000000000000000000000000000000000000010000000131300000010000000001000000010000000101010000003030810101010101000000000000000030308
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010001000000000000000000000000000100000000000000000000000000000001000000000000010101000080303030300000000000000000000000003030303
__map__
000000000000000000000000002c372221212121212121212121212121212121212121212121212121212121212121212131212121212121212121212132212105050505050505050505050505050505212121212121212121212121212121211411211100110011111100111100111111113d2d00003f000000002c3c111111
000000000000000000000000002c1f081f0e2b1f0a1f1f17171f1f1f1f1f1f1438000000000000000000000000000014131616161616372138161616163721100500212100210000220021210000000514000000000000000000000000000014241f1f1f391f391f1f2439241f391f17171f1f1f001b1f2d00001b1f1f1f1f14
000000000000000000000000001f1f1f1f1f0a1f1f1f1f1f341f1f1f1f175b240e000000000000000000000000000024331616161616161616161616161637200500210000212100220021002100000524000000000000000000000060000024241f1f1f1f1f1f601f241f241f1f1f080e1f1f1f391f0a1f00002c1f1f3c1124
0000000000000000000000001b1f1f1014011f1f1f1f1f1f1f1f1f1f1f1f1724000000000000000000000000000000240800000000000000000000000000002005002121002100212200210021000005240060000000600000000000000000240e1f1f1f1f1f1f1f1f241f241f1f5b1f1f1f1f1f3c113d1f0b001f1f1f1f1f24
0000003f003e003e003f00002c1f5b20241f1f1f1f1f1fe01f1f1f1f1f1f1f241403030303030303030303030303032400005b0000006f006f6f00000000002005002100002100002200210021000005240000000000000000000000000000241f1f1f1f1f1f1f1f1f241f241f030314141f1f1f1f1f1f1f1f391f1f0a1f1f24
00001b1f001f001f001f001b1f051820241f1f1f1f1f1f17141f1f1f1f1f1f242400000000000000000000000000002413271111111111111111111111280020050021210021000022002121000000052400000000000000000000000000002414011f1f1f1f1f1f1f241f241f1f6f24241f1f0a1f1f1f1f1f1f1f1f1f1f1f24
00002c1f1f1f391f2d1f0b2c07181820241f1f1f011f1f24241f1f011f1f1f2424010064000000000000006400000024230000007f00180000001800000000200500000000000000000000000000000524000000000000000000000000600024241f1f1f1f1f1f751f241f1f1f6f032424011f1f1a1f2b1f1f1f1f1f3c3d1f24
00001f1f1f1f1f1f1f1f1f0707181820241f1f6f6f6f6f34346f6f6f1f1f1f2424000000000000000000000000000024230000000000000000000000000000202121000021210021000000210000220024000000000000000000011400000024241f1f221f11111111241f146f031f24241f1f1f2a1f2a1f1f0100001f1f1f24
00001f1f1f1f1f1f1f1f1f1818181820241f012711111111111111281f011f243400000056000064170000005700003423006f001816161616161616161616202100210021000021210021210022002124000000000000001400002400000034241f1f241f551f1f1f1f1f24031f1f24241f1f1f1f641f1f1f1f00001f1f1f24
002c1f1f161f0a1f1f1f071818271111241f1f1f1f1f1f14171f1f1f1f1f1f242857575614565756245657561403032723001818141616166f1616166f161620210021002121002100210021002200212403030303140c0d240c0d2400000027241f01241f521f1f1f1f1f7f1f1f1f24241f1f3c1111113d1f1f1f1f1f1f1f24
001f1f1f1f1f1f1f1f18182711111111241f1f1f1f1f1f24341f1f1f1f1f1f24380000002400000024000000240000372300007f3416166f186f166f186f16202100210021000021002100210022002124000000002400002400002400140037241f1f241f1f1f1f1f1f1f1f1f1f0124241f1f251f1f1f251f1f1f641f1f1f24
001f1f161f1f2e182927111111111111243c3d1f1f1f1f341f1f1f1f1f3c3d243800000024000000240000002400003723180000271111111111111111112820212100002121002100000021000022002400000000240c0d240c0d2400240037241f1f241f1f1f1f1f1f1f1f1f1f1f24241f1f251f1f1f251f1f3c1111111124
001f1f1f291807271111111111111111241f1f1f011f1f1f1f1f1f011f1f1f243800000024000000240000002403033723000000372121380000003721213830050000000000000000000000000000053400001400240000240000240024003724011f241f1f1f1f6f6f6f146f6f1f24241f162516160c0d1616251616161624
001f1f1f052711111111111111111111241f1f1f1f1f1f1f1f1f1f1f1f1f1f243800000024000000240000002400000823000000000000000000000000000000050000000000005b00000000000000050801002400240c0d240c0d240024000e241f1f0f1f1f6f6f2121212411111f2424161625161616251616251616161624
00071f27111111111111111111111111346f6f6f6f6f3c11113d6f6f6f6f6f34386f6f6f346f6f6f346f6f6f345b000033000018000000001800000000000000050000000000006f000000000000000500005b346f347000340070346f340000341f1f1f1f6f21212121212421215234346f6f6f6f6f6f6f6f6f35165b161634
3b3a3b3a3b3a3b3a3b3a3b3a3b3a3b3a11111111111111111111111111111111111111121111121112111212111211112112121212121212121212212121212121222121212121212121212121210121111111121111121112111212111211112121212121212121212121212121212121222121212121212121212121210121
2121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212131212132212121312121212122212121212122322121212122212121212121212121212121212121212121212121212121212121212121212121322121212221213138141614
1316161616151616161615161616161038161616241616241624162416161637213222322231381616161616161616372132223222313816161616161616163713162416161616161616161616161610143434341616161616161616241f1f1413161616161f561f1f1f1f1f1f1f1f5608161616161616161616161616241624
23161616162516161616251616161630381616162416162416241f241f1f1f372132212138161616161616161616163738161616161616161616161616161637331f341f1f1f1f1f1f1f1f1f1f751f20245256751f1f1f1f1f1f1f1f341f5224231616161f1f561f1f751f1f1f1f565600165b16161616161616161616340124
2316161616251616161625161616160e081f1f1f241f1f341f241f341f1f1f0f081f161f16161f1f1616161616161637381f1f1f1f1f1f1f1f1f1f1f1f1f1f0e081f1f1f1f1f1f1f1f1f1f1f1f3c3d20343c113d561f1f1f1f1f1f1f1f1f17242316161f1f1f3c1111121111281f56141403030d1f1f1f1f1f1f1f1f1f0e1f24
231f1f1f1f251f1f1f1f251f1f1f1f1f1f1f5b1f241f1f551f241f1f1f1f1f1f1f165b1f1f1f1f011f1f161f1f161637381f1f1f751f1f1f1f1f1f1f1f1f1f1f1f1f5b1f1f1f1f1f1f1f1f1f1f1f1f20071f1f1f1f1f1f291f1f1f1f1f1f1f242316601f1f1f251f1f1f1f3738565634241f1f1f1f1f1f1f1f1f1f1f1f1f0124
231f1f1f1f251f1f1f1f251f1f02031011113d1f241f1f521f241f1f1f14033c28030d1f1f1f1f1f641f1f1f161f1637386f3c11113d6f6f1f1f1f1f1f3c1111133c1111113d1f176f6f6f1f1f1f1f20071f1f1f1f1c1e1d1d1e1f1f1f181f24231f0c0d1f1f251f601f1f3c11111211241f1f1f1f1f1f1f1f1f1f1f1f011f24
231f1f1f1f251f1f1f1f251f1f251f20381f551f241f1f1f1f241f1f1f241f37381f1f1f1f1f1f1f57561f011f1f1f3721382121212137381f1f1f3c3d1f1f3723271112111111111111281f1f020320071f1f1f1f1f1f1f1f1f1f1f1f1f1f2423016f6f6f1f251f1f1f1f251f1f1f10241f1f1f1f1f1f16161f1f1f1f1f1f24
231f1f1f1f171f641f1f171f1f251f20381f521f341f1f1f1f241f1f1f341f37381f1f0c0d1f1f1f1f1f1f1f1f1f1f3721212121212121381f1f561f1f1f1f37231f1f1f1f1f1f1f1f1f1f1f1f2516200726641f1f1f141f141f2e1f1f1f753433271111281f351f1f1f1f351f1f1f20241f16161f1f1f0c0d1f1f16161f1f24
231f1f1f3c1111111111113d1f251f20381f1f1f1f1f1f011f34011f1f1f1f37381f1f1f1f1f1f1f1f1f1f1f1f1f1f3721212121212121383c3d1f1f1f1f1f37231f1f751f1f1f1f1f1f1f1f1f25162007523c3d6f1f3452341c1e1f1f1f570f16161614271112111111113d56565620341f0c0d1f1f1f1f1f1f1f0c0d1f1f34
231f1f1f251f1f1f1f1f1f251f251f20381f1f1f1f1f1f1f1f1f1f1f1f141f37381f1f011f1f1f641f1f641f1f1f1f3721212132387f7f7f1f1f1f1f1f1f1f37231f1f3c3d1f0c030d1f0c030303032007070707071f3c113d1f1f1f1f1f1f1f161616241f1f1f1f1f7f7f25601f1f20071f1f1f1f1f1f1f1f1f1f1f1f1f1f05
231f1f1f251f1f1f1f1f1f251f251f20386f6f6f171f1f1f1f171f1f1f241f37381f1f1f1f1f56571f1f57181f011f37381f1f7f7f1f1f1f1f1f1f1f1f1f1f37231f6f6f6f6f6f6f6f6f6f6f6f6f6f2007262626361f1f1f1f1f1f1f1f1f1f14131616241f1f1f1f1f601f251f1f1f203a261f1c1d1d1e1f26261f1f1c1e1f07
2311113d251f1f1f1f1f1f251f25172021212138251f1f1f1f251f1701341f3738160c0d1f1f1f1f1f1f1f1f1f1f1f0e081f1f1f1f1f1f1f0c03041f1f1f1f37231f27111111111112111111111128200507261f1f1f1f1f1f1f2f1f1f751f2423161624161f1f1f1f1f1f251f15152005262626261f1f1f1f1f261f26262605
231f1f25251f1f1f1f641f251f25252038521f1f251f1f1f1f251f251f1f1f373816161f1f161f1f1f1f1f1f161f1f1f1f5b1f1f1f1f1f1f1f1f241f1f641f37231f1f1f1f1f341f1f1f1f1f1f1f1f3007261f1f1f1f1f1f1f1f1f1f1f141f24231616341616161f1f1f6415152525203b266f6f1f1f1fd01f1f1f1f1f266f07
231f1f25251f1f07050705071f25252038141f1f251f1f1f1f251f250c0d1f3738161616161616161f161f161616012711281f1f1f0c030d1f1f241f56565637331f1f171f1f1f1f1f1f751f1f1f1f0e081f1f1f1f0705071f1f26266f346f3423161616161616161f15152525252520076f05076f261c1c1e1f1c1d1e6f0705
331f5b35351f07053b3a3b050735073038346f6f6f6f6f6f6f6f6f6f6f6f6f37386f6f6f6f6f6f6f6f6f6f6f6f6f6f3711111111286f6f6f6f6f346f6f6f6f371112111111111111286f3c3d6f1f1f1f1f295b0705070505702605070507050733165b1616161616166f6f6f6f6f6f303b050705056f6f6f6f6f6f6f6f050707
050114053a3b3a3b3a3b3a3b3a3722222231222232212121213222312232222221212222222222222221212121212121212122222222222222212121212121212121212131212121212122322138053b3a3a3a3b3a3b3a3b053b3a3b3a3b3a3b111111111111111111121111111111123b3a3b3b3a3b3a3b3a3b3a3b3a3b3a3b
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

