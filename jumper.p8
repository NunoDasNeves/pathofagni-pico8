pico-8 cartridge // http://www.pico-8.com
version 38
__lua__
-- 'jumper' demo build #6
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
dbg,dbgstr = true,''

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
			music(-1)
			return true
		end
	)
end

room_old, -- for restore
room_num_bads, -- for unlock (bads door)
room_num_unlit, -- for unlock (lanterns door)
room_checkpoint -- checkpoint thang
=
nil,0,0,nil

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
			add(thang,p)
		end
	else
		p.x = -10
		is_end = true
		for f in all(fireball) do
			kill_ball(f)
		end
	end
end

function update_rain_h(t)
	t.h = dist_until_flag(t.x,t.y,1,1,true) + 7
	t.hh = t.h
end

-- spawn thangs in current room
-- save room
function spawn_room()
	local rmapx,rmapy  = room_x \ 8, room_y \ 8
	thang,max_z,room_old,room_num_bads,room_num_unlit,fireball,rain = {},0,{},0,0,{},{}
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
				update_rain_h(t)
				add(rain,t)
			end
		end
	end
end

do_fade,fade_timer = true,8 -- fade in

function spawn_p_in_curr_room()
	restore_room()
	spawn_room()
	spawn_p(room_checkpoint.x, room_checkpoint.y - 1)
end

snd_door_open,
snd_p_respawn,
snd_p_die,
snd_p_jump,
snd_p_shoot,
snd_p_land,
snd_frog_croak,
snd_bat_flap,
snd_ice_break,
snd_hit,
snd_frog_jump,
snd_knight_jump,
snd_knight_swing,
snd_knight_die,
snd_shooter_shot,
snd_archer_invis,
snd_wizard_tp
=
7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23

-- TODO this
--[[
function snd(s)
	if s < 12 then
		sfx(s)
	elseif s >=12 and s < 23 then
		local stat2,stat3 = stat(48),stat(49)
		if stat2 == -1 or stat2 > 15 then
			sfx(s,2)
		elseif stat3 == -1 or stat3 > 15 then
			sfx(s,3)
		end
	else
		-- sfx 13,14,15 are low prio; don't let them override other sounds
		if s > 15 or stat(49) == -1 then
			sfx(s)
		end
	end
end
]]
function snd(s)
	sfx(s)
end

-- TODO token reduction?
-- for state_music rooms: call start_music() when entering these rooms (i.e. we need one after a silent room to restart music)
-- play the start of the music, overlaps with start_music_rooms
silent_rooms,intro_rooms,start_music_rooms = {},{[23]=1, [8]=1, [7]=1},{[7]=1, [8]=1}
-- silent rooms includes all rooms we want regular music to fade out, and NOT play on respawn (including boss rooms)
for i in all{0,1,14,15,16,17} do
	silent_rooms[i] = 1
end

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
	-- starting room
	move_room(23)
	spawn_p_in_curr_room()	
end

-->8
-- draw

function draw_thang(t)
	for i,k in pairs(t.pal_k) do
		pal(k,t.pal_v[i],0)
	end
	spr(t.s+t.fr,t.x,t.y,1,1,not t.rght)
	pal()
end

function draw_shot(t)
	-- tracer
	line(t.x, t.y, t.endx, t.endy, t.trace_color)
	--arrow
	line(t.arrowx, t.arrowy, t.endx, t.endy, t.arrow_color)
end

function pal_mono(color)
	for i=0,15 do
		pal(i,color,0)
	end
end

function draw_wizard(t)
	if t.tping then
		pal_mono(7)
		if t.fcnt < 6 then
			draw_thang(t)
			spr(230, t.tp_to_x, t.tp_to_y)
		elseif t.fcnt < 12 then
			spr(229, t.tp_from_x, t.tp_from_y)
			spr(229, t.tp_to_x, t.tp_to_y)
		else
			draw_thang(t)
			spr(230, t.tp_from_x, t.tp_from_y)
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
	sspr(
		(f.s % 16) * 8 + (f.sfr % 2) * 4,
		(f.s \ 16) * 8 + (f.sfr \ 2) * 4,
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

rain_patterns,dither_patterns,fade_patterns =
--rain
{
	--0b1011101010101110.1,0b1110101110101010.1,0b1010111010111010.1,0b1010101011101011.1
	0b1011101110101110.1,0b1110101110111010.1,0b1010111010111011.1,0b1011101011101011.1
}
--dither
,{
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
},
--fade
{
	0b0101101001011010.1,
	0b0000101000001010.1,
	0,
	0,
	0b0000101000001010.1,
	0b0101101001011010.1
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

rainfr, rainfcnt, horiz_off, horiz_vel, end_flash = 0,0,0,12,8

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
			horiz_off += horiz_vel*0.1/1.2
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
	print_in_room(23,'demo 6', 52, 58, 11)
	print_in_room(23, '⬅️➡️ move\n🅾️ z jump\n❎ x fire', 46, 68, 6)
	print_in_room(22, 'psst!\n❎+⬆️\n❎+⬅️+⬇️', 80, 66, 1)
	print_in_room(9, 'psst!\nhold ❎', 17, 12, 1)

	camera(room_x,room_y)
	-- draw one layer at a time!
	for z=max_z,0,-1 do
		for t in all(thang) do
			if t.z == z then
				t:draw()
			end
		end
	end
	-- draw rain
	for r in all(rain) do
		for i=-1,r.h\8-1 do
			spr(123,r.x,i*8+rainfr*2)
		end
		spr(247 + (rainfr > 1 and 1 or 0),r.x,r.h-7-rainfr/2)
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
	local smol_thang = {
		w = 4,
		h = 4,
		cw = 4,
		ch = 4,
		hw = 4,
		hh = 4
	}
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
		shcount = 0, -- throw/shoot stuff at player
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
	[64]= { -- player
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
		ftw = 1, -- 1 because we just care about pixel coords
		ftx = 3,
		fty = 8,
		ch = 4,
		cw = 5,
		cx = 1,
		cy = 2,
		-- hurtbox dimensions
		hx = 1.5,
		hy = 1.5,
		hw = 4.99,
		hh = 4.99
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
		dircount = 0,
		cw = 7,
		ch = 6,
		hw = 7,
		hh = 6,
	},
	[112] = { -- frog
		init = init_frog,
		update = update_frog,
		burn = burn_frog,
		template = enemy,
		hp = 2,
		icefrog = false,
		angry = false,
		croak = false,
		bounced = false,
		do_smol = true,
		-- coll dimensions
		ch = 5.99,
		cw = 5.99,
		cx = 1,
		cy = 1,
		hx = 1,
		hy = 2,
		hw = 4.99,
		hh = 5.99,
		jcount = 0, -- jump
		s_burn_s = 4,
		s_die_s = -8 --104 - 112
	},
	[192] = { -- knight
		update = update_knight,
		burn = burn_knight,
		draw = draw_knight,
		hp = 5,
		atking = false,
		-- draw sword/sword hitbox present
		swrd_fr = 0,
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
		template = smol_thang,
		vx = 1.5,
		vy = -4,
		max_vy = 4,
		sfr = 0,
		xflip = false,
		yflip = false,
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
		s_burn_s = 12,
		s_die = {s=13, f=3}
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
		template = smol_thang,
		speed = 3,
		die_yinc = 0.5,
		s_die_s = 108
	},
	[257] = { -- rain
		update = no_thang,
		draw = no_thang
	},
	[246] = { -- ice trap
		update = update_ice_trap,
		stops_projs = false
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
		snd(snd_door_open)
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
		snd(snd_ice_break)
		t.s,t.alive = 88,false
		mset(t.x\8,t.y\8,31)
		for t in all(rain) do
			update_rain_h(t)
		end
	end
end

function kill_ice_proj(t)
	snd(snd_ice_break)
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
	t.vy += 0.3
	t.vy = clamp(t.vy,-t.max_vy,t.max_vy)
	t.x += t.vx
	t.y += t.vy

	if 
			collmap(t.x+3, t.y+2, 1) or
			collmap(t.x+1, t.y+2, 1) then
		kill_ice_proj(t)
	elseif kill_p_on_coll(t) then
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
		snd(snd_hit)
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
		snd(snd_shooter_shot)
		local orig_y = t.y + 3
		local shleft,shright,shot = 
			dist_until_flag(t.x + 4, t.y + 4, 1, -1),
			dist_until_flag(t.x + 4, t.y + 4, 1, 1),
			spawn_thang(256, t.rght and t.x + 8 or t.x - 1, orig_y)
		shot.endx,shot.endy = 
			t.x + 4 + (t.rght and shright or -shleft),
			orig_y
		shot.arrowx,shot.arrowy =
			t.rght and shot.endx - 5 or shot.endx + 5,
			orig_y
	end
end

pal_icefrog_k, pal_icefrog_v,pal_icefrog_angry_v,
-- body, legs, skin, hair, bow, (cloak)
pal_invis_k,
pals_invis_v
=
-- icefrog
{11,3,8,4}, -- main, shadow, eyes, loincloth
{12,1,7,5},
{8,2,10,5},
-- invis
{5,2,15,4,9,1},
-- ordered invisible -> visible
{
	{0, 1, 0, 1, 1, 0},
	{1, 1, 1, 1, 1, 1},
	{1, 2, 5, 2, 13, 1},
}

function update_archer(t)

	if do_boss_die(t) then
		return
	end

	local oldburning = t.burning
	if do_bad_burning(t) then
		if not t.alive then
			snd(snd_knight_die)
			music(-1,0,3)
		end
		return
	-- not burning or dead
	elseif oldburning then
		snd(snd_archer_invis)
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
				music(24, 0, 3)
				t.phase = 1
			end
			return
		end
		-- remember which way we were going
		t.rght = t.goingrght
		if not t.air then
			-- default velocity, may change if we fall
			t.s,t.vx = 209,1.2
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
					snd(snd_knight_jump)
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
			t.pal_k = pal_invis_k
			local fr = t.invistimer < 12 and 11 - t.invistimer or t.invistimer - 58
			if fr >= 0 then
				t.pal_v = pals_invis_v[fr\4+1]
			else
				for i=1,6 do
					t.pal_v[i] = 0
				end
			end
			--
			if t.invistimer == 15 then
				snd(snd_archer_invis)
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
		snd(snd_hit)
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
	snd(snd_wizard_tp)
	-- find tp plat
	local plats,minplat_d,minplat,plat = {},999
	-- start inside borders
	local rmapx,rmapy = room_x \ 8 + 2,room_y \ 8 + 4
	for y=rmapy,rmapy+9 do
		for x=rmapx,rmapx+11 do
			local val = mget(x,y)
			if fget(val,0) and not fget(val,1) then
				plat = {x = x*8, y = y*8 - t.h}
				local d = vlen{x=plat.x-p.x,y=plat.y-p.y}
				if plat.x != t.x or plat.y != t.y then
					if t.shield then
						if d < minplat_d then
							minplat,minplat_d = plat,d
						end
					elseif d > 48 then
						add(plats, plat)
					end
				end
			end
		end
	end
	plat = t.shield and minplat or rnd(plats)
	t.tp_to_x,t.tp_to_y,t.tp_from_x,t.tp_from_y = plat.x,plat.y,t.x,t.y
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
	for xy in all{{0,-6},{8,-6},{0,2}} do
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

	if kill_p_on_coll(f) then
		kill_ice_proj(f)
	-- hit blocks
	elseif collmap(f.x+2,  f.y+2, 1) then
		kill_ice_proj(f)
	end
end

function update_ice_trap(t)
	t.fcnt += 1
	if t.fcnt == 40 then
		for i=2,8,2 do
			apply_ball_prop(spawn_thang(124, t.x+2, t.y+2), ball_dirs[i])
		end
		t.fcnt = 0
	end
end

function spell_frost_nova(t)
	for i=1,8 do
		apply_ball_prop(spawn_thang(124, t.x+2, t.y+2), ball_dirs[i])
	end
end

function spell_shield(t)
	t.shield,t.shieldtimer = true,190
end

spells = {{fn = spell_summon_bats, cast_time = 50, recovery = 45, snd=24},
		{fn = spell_frost_nova, pal_k = {8,2}, pal_v = {7,12}, cast_time = 45, recovery = 30, snd=25},
		{fn = spell_shield, pal_k = {1,2,8}, pal_v = {4,9,10}, cast_time = 55, recovery = 20, snd=26}}

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
			snd(snd_knight_die)
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
		t.s,t.fr = t.i + 1,2
		t.fcnt += 1
		if t.fcnt == 9 then
			t.x,t.y = t.tp_to_x,t.tp_to_y
		elseif t.fcnt == 18 then
			reset_anim_state(t)
			t.tping,t.stops_projs = false,true
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
			snd(t.spell.snd)
		elseif t.shcount <= 0 then
			reset_anim_state(t)
			-- now use shcount for resting
			t.casting,t.shcount = false,t.shield and 20 or t.spell.recovery
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
				music(24, 0, 3)
				t.phase = 1
				t.y += t.hover_up and 2 or 1
				start_tp(t)
			end
			t.shcount = 0
			return
		end

		t.s,t.fr = t.i + 1,0

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

function init_frog(t)
	if room_i < 16 then
		t.icefrog,t.pal_k,t.pal_v = true,pal_icefrog_k,pal_icefrog_v
	end
end

function update_frog(t)
	local oldburning = t.burning
	if do_bad_die(t) or do_bad_burning(t) then
		t.pal_k = {}
		return
	elseif oldburning and t.icefrog then
		t.angry,t.jcount,t.pal_k,t.pal_v = true,3,pal_icefrog_k,pal_icefrog_angry_v
	end

	local oldair = t.air
	-- not burning and not in the air
	if not t.air then
		t.s, t.vx = t.i, 0
		face_p(t)
		local dir = t.rght and 1 or -1
		-- not angry - jump when player charges fireball
		if not t.angry then
			if t.croak then
				-- play full idle anim (croak)
				if play_anim(t, 5, 2) then
					snd(snd_frog_croak)
					t.croak = false
					reset_anim_state(t)
				end
			else
				-- just play first frame for a bit
				if play_anim(t, 120, 1) then
					t.croak = true
					reset_anim_state(t)
				end
			end
			if p.sh then
				snd(snd_frog_jump)
				t.vy,t.vx,t.air = -3.5, 1.2 * dir, true
			end
		else -- angry - jump rapidly at player
			if t.jcount <= 0 then
				t.angry, t.pal_v = false,pal_icefrog_v
			else
				t.jcount -= 1
				snd(snd_frog_jump)
				-- small jump
				if not t.bounced or t.do_smol then
					t.vy,t.do_smol = -2.5,false
				-- big jump if we bounced off a wall
				else
					-- always do a small jump after a big one
					t.vy,t.bounced,t.do_smol = -3.5,false,true
				end
				t.vx,t.air = 1.5 * dir,true
			end
		end
	end

	-- physics - always run because falling could happen e.g. due to ice breaking
	local oldvx, oldx, oldy = t.vx, t.x, t.y
	local phys_result = phys_thang(t, oldair)
	-- if hit ceiling, redo physics with tiny jump
	if phys_result.ceil_cancel then
		t.vx,t.vy,t.x,t.y,t.air = oldvx, -0.7, oldx, oldy, true
		phys_result = phys_thang(t, oldair)
	end

	-- bounce off wall
	if phys_result.hit_wall then
		t.rght,t.vx,t.bounced = not t.rght, -oldvx, true
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
		t.s,t.fr,t.fcnt = t.i,0,rnd{0,20,30}
	end

	if check_bad_coll_spikes(t) then
		return
	end

	kill_p_on_coll(t)
end

function kill_p_on_coll(t)
	if t.alive and p.alive and hit_p(t.x+t.cx,t.y+t.cy,t.cw,t.ch) then
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
	t.swrd_draw,t.swrd_hit = false, false

	if do_boss_die(t) then
		return
	end

	local oldair, oldatking, oldburning = t.air, t.atking, t.burning

	if do_bad_burning(t) then
		if not t.alive then
			snd(snd_knight_die)
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
					snd(snd_knight_swing)
				end
				-- jump!
				if t.phase == 2 and not t.air and t.fr == 1 and t.fcnt == 1 then
					snd(snd_knight_jump)
					t.vy,t.vx,t.air = -3,t.rght and 1 or -1,true
				end
				t.swrd_draw,t.swrd_hit,t.swrd_fr = true,true,t.fr-1
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
					music(24, 0, 3)
				end
			end

			if t.phase > 0 then
				t.s = t.i + 1
				-- follow player if they're on same platform
				if dir != 0 then
					t.rght = dir == 1 and true or false
				end
				t.vx = t.rght and 0.75 or -0.75

				loop_anim(t,3,2)

				t.atktimer += 1 -- time since last attack
				if 		t.phase == 1 and vlen{ x = t.x - p.x, y = t.y - p.y } <= t.atkrange or
						t.phase == 2 and t.atktimer >= t.jmptime then
					t.atktimer,t.atking = 0,true
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
			t.rght,t.vx = not t.rght,-oldvx
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
			t.phase,t.jmptime = 2,20 + rnd{0,15,30}
		else
			t.phase = 1
		end
	-- change phase if haven't attacked in a while
	elseif t.phase == 1 and t.atktimer > 60 then
		t.phase,t.jmptime = 2,10 + rnd{0,15,30}
	end
		
	-- don't kill p if we're dead! (e.g. falling)
	if t.alive and p.alive then
		if kill_p_on_coll(t) then
			t.phase = 0
		elseif t.swrd_hit and hit_p(t.x + (t.rght and 8 or -5), t.y + 1, 5, 4) then
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
			ret,t.fr = true,0
		end
	end
	t.fcnt += 1
	return ret
end

function play_anim(t,speed,frames)
	-- see loop_anim
	-- this one doesn't loop
	if loop_anim(t,speed,frames) then
		t.fr,t.fcnt = frames - 1,speed
		return true;
	end
	return false
end

function init_bat(b)
	b.fcnt = rnd{0,1,2,3}
end

function update_bat(b)
	if b.burning then
		b.burning,b.alive,b.s,b.vy,b.deadf = false,false,98,0.6,20
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
		--snd(snd_bat_flap)
	end

	-- move the bat
	local b2p = {x=p.x-b.x,y=p.y-b.y}
	local dist2p = vlen(b2p)
	local in_range = dist2p < 56 and true or false
	local go_to_p = in_range

	-- if collide with something, go in random direction
	local newx,newy = b.x + b.vx,b.y + b.vy
	local cl,ct = newx + b.cx,newy + b.cy
	local cr,cb = cl + b.cw,ct + b.ch

	if 		collmap(cl, ct, 1) or 
			collmap(cr, ct, 1) or
			collmap(cl, cb, 1) or 
			collmap(cr, cb, 1) then
		-- force pick a random direction
		b.dircount,go_to_p,b.vx,b.vy = 0,false,0,0
	else
		b.x,b.y = newx,newy
	end

	-- pick the direction for next frame
	if b.dircount <= 0 then
		-- go toward player
		if go_to_p then
			b.vx,b.vy,b.dircount = b2p.x * 0.5/dist2p,b2p.y * 0.4/dist2p,30
		-- pick random direction
		else
			local rndv = {x = rnd(2) - 1, y = rnd(2) - 1}
			local len = vlen(rndv)
			b.vx,b.vy = rndv.x * 0.5/len,rndv.y * 0.4/len
			-- reset quicker if we're in range
			b.dircount = in_range and 20 or 60
		end
	end
	b.dircount -= 1

	-- face the right way
	b.rght = b.vx > 0 and true or false

	kill_p_on_coll(b)
end

function burn_lantern(l)
	if not l.lit then
		room_num_unlit -= 1
		l.lit,l.s = true,83
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
	p.rght = room_i >= 8 and room_i <= 15
end

function kill_p()
	snd(snd_p_die)
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
	if abs(p.vx) < 0.01 then
		p.vx = 0
	end

	-- vy - jump and land
	local oldair,jumped = p.air, false
	if btnp(🅾️) and not p.air and not p.sh then
		jumped = true
		p.vy,p.air = -4,true
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
		snd(snd_p_land)
	elseif jumped and not phys_result.ceil_cancel then
		snd(snd_p_jump)
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
			if t.i == 257 and hit_p(t.x+2,t.y+2,t.w-4,t.h-4) then
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
			p.shcount, p.shbuf = 10, nil
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
			snd(snd_p_shoot)
			reset_anim_state(p)
		end
		if loop_anim(p,3,2) then
			snd(snd_p_shoot)
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
			fade_timer,do_fade,p.s = 0,true,31
			reset_anim_state(p)
		end
	elseif p.spawn then
		if play_anim(p,3,4) then
			reset_anim_state(p)
			p.s,p.spawn = 64,false
			start_music()
		elseif p.fr == 0 and p.fcnt == 1 then
			snd(snd_p_respawn, 3)
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
			collmap(f.x+1,  f.y+2, 1) or
			-- kill fireball if it leaves the map (upper levels)
			f.x < -4 or f.y < -4 then
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
	return collmap(t.x + t.w/2, t.y + t.h/2, 3)
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

	local newx,newy = t.x + t.vx,t.y + t.vy

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
	ret.hit_wall, newx = pushx != newx, pushx

	if oldair and not t.air then
		ret.landed = true
	end

	t.x,t.y = newx,newy

	return ret
end

-- t.vy > 0
function phys_fall(t,newx,newy)

	-- where our feeeeet at?
	local fty = newy + t.h
	local ftxl = newx + t.ftx
	local ftxr = ftxl + t.ftw

	local stand_left,stand_right = collmap(ftxl,fty,0),collmap(ftxr,fty,0)

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
		newy,t.vy,t.air = rounddown(newy, 8),0,false
		local lblock,rblock = mget(ftxl\8,fty\8),mget(ftxr\8,fty\8)
		-- save position of which block we're standing on
		t.lfloor,t.rfloor = stand_left and {mx = ftxl \ 8, my = fty \ 8} or nil, stand_right and {mx = ftxr \ 8, my = fty \ 8} or nil
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
			t.air,t.vy = false,0
		else
			-- just sloow down on ceiling hit
			t.vy = t.vy/10
		end
		return t.y + t.vy
	end

	return newy
end

function phys_walls(t,newx,newy)
	local cl,ct = newx + t.cx,newy + t.cy
	local cr,cb,l_pen,r_pen = cl + t.cw,ct + t.ch,0,0

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
ffffffffdddddddd01dddd10dddddddd1d11dd1005555550ffffffff05555550011111100111111011011110ffffffffdddddddddddddddd0111111001111110
ffffffff0dddddd001dddd10dddddddd11d1dd1011555151ffffffff1551515501dddd100111111000100000ffffffff0dddddddddddddd00155551001555510
ffffffff0111111001dddd10000000001dd1dd1055151555ffffffff5555551101dddd100111111000100000ffffffff00000000000000000111111001111110
ffffffff0110011001111100111111111111111115515151fffffff0551151510111111001dddd10000000001fffffff01111111111111100000000000000000
ffffffff010000101ddddd11000000001dddddd111555111fffff3f0155511510000000001dddd101fff11101fffffff00000000000000000000000000000000
ffffffff001111001dddddd1011001101dddddd115151511fff3ff3d111115550000000001dddd1011ffd1001f3ff3ff01100110011001100000000000000000
ffffffff000000001dddddd1111111111dddddd111111511ffff33d0151155110000000001dddd10001dd100033f3fff00111111111111000000000000000000
ffffffff0000000011111111000000001111111101511110fff3d000011115100000000001dddd10001d1000013333ff00000000000000000000000000000000
dddddddddddddddddddddddddddddddddddddddddddddddd11111111dddddddd0111111001dddd10000000111100000055555555555555555555555500000000
0dddddddddddddddddddddddddddddd00dddddd00dddddd0001000000dddddd01111111d01dddd10000011000011000005515115551555555515515000000000
01111111111111111111111111111110011111100111111000100000011111101d11d1dd01dddd10000100100010100001001110110011001100110000000000
011ddd11111111111111111111ddd110011dd1100110011000000000011dd110111ddd1d01dddd10001000100100010000000010001001010010010000000000
01ddddd1ddddd1dddd1dd1dd1ddddd1001dddd10010000101111111101dddd101ddddddd01dddd10010100000000101000101101100010101000101000000000
01111111ddddd1ddddd1d1dd11111110011111100111111000000100011111101dd1d1dd01dddd10010010ff1101001000100000001100001110000000000000
01d1d1d1ddddd1dddddd11dd1d1d1d1001dddd10010000100000010001dddd1011d1dddd011dd11010000ffff110000100000100000001010001010000000000
01d1d1d111111111111111111d1d1d1001dddd100100001000000000011111100dddddd0001111000000ffffff11000000000000000001000000000000000000
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd100100001000011000fffffffffffff55f0000000011111ffff1111111fffd0000000001ff0000000055555555
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd100100001000000101fff551fff55f555500000000000000ffff100000fdd000000000001f0000000005115550
01d1d1d1dd1ddddddd1ddddd1d1d1d1001dddd100100001000100000f51515fff5555515000000001110ffffff111110d0000000000000000000000001001110
01d1d1d111111111111111111d1d1d1001dddd1001000010000100001551515f5511515f000000001000ffffff11100000000000000000000000000000100010
01d1d1d1ddddd1ddddddd1dd1d1d1d1001dddd1001000010011000111155511f55551151000000001000ffffff11100010000000000000000000000001001100
01d1d1d1ddddd1ddddddd1dd1d1d1d1001dddd1001000010000000011515151111111555000000001000ffffff111000f1000000000000000303003000100000
01d1d1d1ddddd1ddddddd11d1d1d1d1001dddd1001000010100100001111151115115511003030031000111111111000fd000000000000003003303300010100
01d1d1d111111111111111111d1d1d1001dddd1001000010000100001151111111111511303300331000000000001000d0000000000000003033330300000000
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
000000000000000000000b8b03b000000000e7e0006116c000611600006116c000611cc00061160ce77e0080c0000000bbbb11c7155115511551155101d1d1d0
00000b0000000b000004bbb300b0000000eeee200061160c006116c00061160c0061160c0061160ce77e0080c0001000bbbb11c715555551155555510601d106
0000b8b00000b8b0004443b000b400b00000ee000666660c066666c0066566656656666566566665eeeeee90c000c000bbbb0c70015555100155551060060600
00bbbb3000bbbb3000b400b000444b8b0008820066666665066666500066660c0066660c0066660c0eee0080c010c01001100110015555100155551000060600
04443b0004443b300bb300000004bbb300e880005066660c056666c0006666c000666cc00066660c9eeee08010c0c0c0c11c11c7011111100111111000060060
04443b0004443b00b3000000000003b0ee0020000066650c006660c000666c0000666500006665c00999980000c010c07cc71cc7001dd100001dd10000060060
003bb0b0003bb0b0b0000000000000b000220000005005c000055c0000500500005005000050050000900900001000c007700770001111000011110000060000
70f142b370a3b350b370a3a35041704150626262626262626262626575507050707050505050505050505050705070505070637063706350705063a3b3a3b3a3
5070507050705050705070a3b3a3b3a3a3707070a3a3b3a3b3705070a370a3b370706363706363a3b3707070a3707050a3b3637063b3b3b350b3b350b3b3b3a3
70104250b3a370a350b350706342f14250626250705050816262f1f1f16550505070705050f1f1f1f1505050f1f1f15070f155f155f1556250626262f17063b3
706262f1f1752565f162705070b3a3b3706325f1f170507050707070f1f163a37062f1f1f1f1655070f1256575507070b363f1f1f16375657565656370a3a3a3
70f142507050b350b350a3706243f143706270f7f7f7f7f1f1f1f1f1f1f17570707070e0f1f1f1f1f1f150f1f1f1f180f0f125f155f155f170625070f1f1f180
f0f1f1f1f1705070f1f162627525a3b37050f2f1f1f1f163f1f17070f1f1f180f0f1f1f1f1f1f163f162f2f1f16350707050f150f1f1f1f175757575505070b3
70f142706362505050626362f1f1f180f16250f1f1f1f1f1f1f175f1f1f1f16f5070f1f1f1f1f1f1f1f150f150b562f1f1f1f1f155f125f1f1625062f1b5f1f1
f1f1f1f1f16262f1f1f1f162507050a35025f1f1f1f1f1f1f1f163f1f1b5f1f1f192f125e2f1f1f1f1f1f1f1f1655050a370f1f1f1f1f1f1f1f16575657563b3
701043506262626362626262b592f1f1f15070f1f175f1f1f1f165f1f1f150707070f15006f1f1f1f1f1f1f150a3a35070f1f1f125f1f1f1f1f17062505070a3
70f1f1f262f1f1f1f1f2f1f1f1506350507050f1f1f1f1f1f1f1f1f1f170505070d1d1d1d1e1f162f1f162f1f1f16370b36370f1f1f1f1f1f1f1f1f175656550
70f162e0f1f16262626262f141d1d170705050f1f165f1f1f1f1f1f1f1f165505070f1f150f1f1f1f1f1f1f15055f17050f1f107f1f1f1f1f1f15062626350b3
50f162f1f1f1f1f1f162f1f1f1652570a37050f1f1f1f1f1f1f1f1f1f170b3a3507062f1f1f1f192f1f162f1f1f17050b37050f1f1f1cedeeefef1f1f17565a3
70e2f1f162f162f1f1f162f142f1f1706ff162f1f1f1f165f1f1f1f1f175655070f1f1f15050f107f1f1f150f125f1a3706250507050705070507050626270a3
70f1f1f1f1f1f1f1f1f1f1f1f15070507050f0f1f1f1f1f1f1e2705070b3a3b3507050f1f1f1f1c1d1d1e1f1f1f17550b35070f1f1f1cfdfeffff1f1f1f175b3
70d1d141f1f1f1f162f1f1f142f170705050f181f1f1f175f1f1f1f18165757050f1f1f1f1a3a3a3a3a3a350f1f1f1705062f1f1f1f1f1f162626270f16270b3
50f1f1f1f1f1f1f1f1f2f1f1f1625070a3f1f1066292f181f270b3a3b3a3b3a37050709262f1f1f1f1f1f1f1f1f1f1707070f1f1f1f1f1f1f1f1f1f1f1f165a3
70f1f142f1f1f1f1f1f1f1f142f1f15070f1f1f1f1f1f1f1f1f1f1f1f1f1655070f165f1f1f1f1f1f1f1f163f1f1f1a37050e1f1f150f15070506250f1f170a3
70f1f1f1f1f2f1f1f1f1f1f1f1f1f15050f15070507050502550a3b350b3a3b350d1d1d1e1f1f1f1f1f1f1f1f1f1f150a350f1f1f1f1f1f1f1f1f1f1f1f175b3
5050f142f1f1f1f1f1f1f1f142f170b350f1f1f1f1f1f1f1f1f1f1f1f1f1757070f1f1f1f1f1f1f1f1f1f1f1f1f1f170506362f1f150f162637062f1f1f170b3
50f1f1f1f1f1f1f1f1f1f1f1f1f1f17070626262f06262705070b370625070b370f162f162f1622592f1f1f1f1f1f15050f1f1f1f1f1f1f1f1f1f1f1f1f1f1a3
50f1f142f151f1f1f1f151f1425070a37062f181f1f1756575f1f1f1f1f1f180f0f1f1f1f1f1f1f1f1f1f1f1f1f1f1a3706262f1c170f1256250f1f1f1f170a3
70f1f2f1f1f1f1f1f1f1f1f1f1f1f1505062f162f1f1626262627050626262a35025f1f1f1f1507050f1f1f1f1f1f18065f1f1f1f1f1f1f1f1f1f1f1f1b5f1b3
7050f143f153f10cf1f153f143f150b3506262f1f1f1f1f1f1f1f1f1b5f1f1f162f1f1f1f1f1f1f1f1f1f1f1f1f1f27070f1f1f16270d1d1d17007f1f1f170b3
70f162f1f1f1f1f1f1f2f1f1f1b5f1507050705070506206f16262636206f1b370f2f1f162f17050f1f1f1f1b5f162f1e265f16575f1f1f1f1f1f1f1c321d350
7070e2c03030303030303030d05070a370f66262f1f162f1f16262f171f1f15050f2f1f1f1f1f1f165f1f1f1f1f1f1b3b325f6f1f6706262f16350f125f170a3
5062f1f1f1f162f1f162626250d1d17050626262f170505050626262626262a37062f1f1f1f1f1f1f1f1f1c1d1d1d1705075f175657565f1f1f1f17173138350
b3a350f17092705070f15092705050a3a370f6f6626262626262626243f1f15050f6f1f165f1f1f170f1f1f175f1f6b3a3a350f650506207f16262625050a3b3
70f662c1e162f6626262f6f670626280e0f162f1626262f162626206f16281b3506262f1f1f1f1f1f16262626262627070657565756575f1f165717323228350
70b3a350a350a350b3a370a3a3b3a3a3a3a3a350f6f6f6f6f6f6f6f670b3a3b37050f6f6f6f6f6f6f6f6f6f6f6f650b3b3a3b3a3b3a3b3a3b3a3b3a3b3a3b3a3
5070f6f6f6f670f6f6f67050636262f1f1f15070f162627062626262815070a370f6f6f6f6f6f6f6f6f6f6f6f6f6f650a3506575659265756571731322128350
70a3b3a3b3a3a3b3a3b3a3a3b3a3a3a3b3b3a3b3a3a3a3a3b3a3b3a3b3a3b3a3a3a3a370a3a3a3a3a3a3a3a3a3a3a3b3a3b3a3b3a3b3a3a3a3a3a3b3a3a3b3a3
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
0c66000400c6600000c6600000c6600400e770000000000000000000007a70007007070000070000000000000000000000000770000077777a00770000700770
c66f60040c66f6040c66f6400c66f6040e77970000000000000000000766a70a00a5a000a005590000000000000000000000a770000aaaa77000770000aa07a0
cfbf00040cfbf0040cfbf0400cfbf00f0e9c98000007000000000000acfbfaa007ab2a0000a19100000000000000000000007770000770000000770000770770
c6ff60040c6ff6040c6ff640fc6ff6c40e7997800077700000070000ac6f96900a5a59907005159000000000000000000000a7a000aaa00000007a7000aa07a0
c6666004cc6666cffc6666f0cc6666040e7777900777770000777000ac9669907caca590010b9100000000000c000000000aaaaa00aa00000000aaa7007a0a70
cc666c04fcc66604ccc666400cc666049ee7778000777000000700000fc996c809a9898000a599000051000000000c0c000aa0aa00aa00000000aaaa00aa0aa0
ccf6fc040ccc60040ccc60400ccc600400ee7e080007000000000000989c69800088880005000100051b510010c0c0000009a09a00aa000000009aaa00aa0aa0
0cccc000ccccc004ccccc040ccccc0000eeeee08000000000000000009888800000000000051005011151150001c0100000990a9009a0000000999aa909a0a90
000000000000000000000000000000000120012000100200000000000000000000000000000660000066000007eee00000990099009900000009990999990990
00000000000000000000100000000000282102820800100800dd7d00000000000000000060600600660060000e07700000990099909900000009900999900990
0012000000008000080000000018210021100121000000000d6cc6d00000000000000000060dd6d000ddd6007eee070000899999909909aa0009900099900990
00000000002001000000002001020000100000100000002007c67c70000000000000000000d6d620dd666d200777e800089889899099099a9909800099809980
0000080000100000020000000800000000000000020000000dc66cd00c0000000000000c0d6d6212000dd2127ee7898008800008908900999908900008808890
0080010000080200000000000210001000210000000000000d6cc6d000000c0c0c00c000d0066d20d6d06d20e00e780008800008880880890008800008808800
00020000000000000010080000008220018821002010800000dd7d0010c0c000c01000c00060d0000066d0000e7e000088000008880888880008800008808800
0000000000000000000000000000000000211000000000100000000000100100000c1001000d00000ddd00000007ee0008000000800088800000800000800800
__label__
55555555555555555151551505555550515155155555555555555555555555550555555055555555555555550555555055555555555555555555555555555555
11515551155555511151515515515155115151551555555115555551155555511155515115555551155555511155515115555551155555511555555111515551
55111555551115155511555555555511551155555511151555111515551115155515155555111515551115155515155555111515551115155511151555111555
55511155555511115555555555115151555555555555111155551111555511111551515155551111555511111551515155551111555511115555111155511155
55515151555555511155111115551151115511115555555155555551555555511155511155555551555555511155511155555551555555515555555155515151
11551511115511550111151111111555011115111155115511551155115511551515151111551155115511551515151111551155115511551155115511551511
55111515115515550115110015115511011511001155155511551555115515551111151111551555115515551111151111551555115515551155155555111515
15555155151111110001110001111510000111001511111115111111151111110151111015111111151111110151111015111111151111111511111115555155
5555555551515515000000000000000000000000515155150cccccc0c77c7ccc0cccccc0c77c7cccc77c7ccc5151551505555550555555555555555555555555
155555511151515500000000000000000000000011515155ccc711cccccc777cccc711cccccc777ccccc777c1151515515515155115155511151555111515551
5511151555115555000000000000000000000000551155551c7cc1cc1ccccc7c1c7cc1cc1ccccc7c1ccccc7c5511555555555511551115555511155555111555
5555111155555555000000000000000000000000555555551ccccc1c1ccccccc1ccccc1c1ccccccc1ccccccc5555555555115151555111555551115555511155
555555511155111100000000000000000000000011551111c1cccc1cc1cccc1cc1cccc1cc1cccc1cc1cccc1c1155111115551151555151515551515155515151
115511550111151100000000000000000000000001111511c11cc11cc11cc11cc11cc11cc11cc11cc11cc11c0111151111111555115515111155151111551511
1155155501151100000000000000000000000000011511000ccc11ccccc11cc00ccc11ccccc11cc0ccc11cc00115110015115511551115155511151555111515
15111111000111000000000000000000000000000001110001ccccc001ccc11001ccccc001ccc11001ccc1100001110001111510155551551555515515555155
05555550055555500000000005555550000000000000000000000000000000000cccccc00cccccc00cccccc00cccccc005555550055555500555555055555555
1551515511555151000000001155515100000000000000000000000000000000ccc711ccccc711ccccc711ccccc711cc11555151115551511551515515555551
55555511551515550000000055151555000000000000000000000000000000001c7cc1cc1c7cc1cc1c7cc1cc1c7cc1cc55151555551515555555551155111515
55115151155151510000000015515151000000000000000000000000000000001ccccc1c1ccccc1c1ccccc1c1ccccc1c15515151155151515511515155551111
1555115111555111000000001155511100000000000000000000000000000000c1cccc1cc1cccc1cc1cccc1cc1cccc1c11555111115551111555115155555551
1111155515151511000000001515151100000000000000000000000000000000c11cc11cc11cc11cc11cc11cc11cc11c15151511151515111111155511551155
15115511111115110000000011111511000000000000000000000000000000000ccc11cc0ccc11cc0ccc11cc0ccc11cc11111511111115111511551111551555
011115100151111000000000015111100000000000000000000000000000000001ccccc001ccccc001ccccc001ccccc001511110015111100111151015111111
55555555055555500000000000000000000000000000000000000000000000000000000000000000c77c7ccc0cccccc0c77c7ccc0cccccc05151551555555555
11515551155151550000000000000000000000000000000000000000000000000000000000000000cccc777cccc711cccccc777cccc711cc1151515515555551
551115555555551100000000000000000000000000000000000000000000000000000000000000001ccccc7c1c7cc1cc1ccccc7c1c7cc1cc5511555555111515
555111555511515100000000000000000000000000000000000000000000000000000000000000001ccccccc1ccccc1c1ccccccc1ccccc1c5555555555551111
55515151155511510000000000000000000000000000000000000000000000000000000000000000c1cccc1cc1cccc1cc1cccc1cc1cccc1c1155111155555551
11551511111115550000000000000000000000000000000000000000000000000000000000000000c11cc11cc11cc11cc11cc11cc11cc11c0111151111551155
55111515151155110000000000000000000000000000000000000000000000000000000000000000ccc11cc00ccc11ccccc11cc00ccc11cc0115110011551555
1555515501111510000000000000000000000000000000000000000000000000000000000000000001ccc11001ccccc001ccc11001ccccc00001110015111111
5555555551515515055555500000000000000000000000000000000000000000000000000000000000000000000000000cccccc0c77c7cccc77c7ccc05555550
155555511151515515515155000000000000000000000000000000000000000000000000000000000000000000000000ccc711cccccc777ccccc777c11555151
5511151555115555555555110000000000000000000000000000777077707770707000000770777000000000000000001c7cc1cc1ccccc7c1ccccc7c55151555
5555111155555555551151510000000000000000000000000000717171710711717100007071711100000000000000001ccccc1c1ccccccc1ccccccc15515151
555555511155111115551151000000000000000000000000000077717771071077710000717177000000000000000000c1cccc1cc1cccc1cc1cccc1c11555111
115511550111151111111555000000000000000000000000000071117171071071710000717171100000000000000000c11cc11cc11cc11cc11cc11c15151511
1155155501151100151155110000000000000000000000000000710071710710717100007701710000000000000000000ccc11ccccc11cc0ccc11cc011111511
15111111000111000111151000000000000000000000000000000100010100100101000001100100000000000000000001ccccc001ccc11001ccc11001511110
55555555055555500555555000000000000000000000000000000770000077777a007700007007700000000000000000000000000cccccc0c77c7ccc55555555
1555555115515155115551510000000000000000000000000000a770000aaaa77000770000aa07a0000000000000000000000000ccc711cccccc777c11515551
551115155555551155151555000000000000000000000000000077700007700000007700007707700000000000000000000000001c7cc1cc1ccccc7c55111555
5555111155115151155151510000000000000000000000000000a7a000aaa00000007a7000aa07a00000000000000000000000001ccccc1c1ccccccc55511155
555555511555115111555111000000000000000000000000000aaaaa00aa00000000aaa7007a0a70000000000000000000000000c1cccc1cc1cccc1c55515151
115511551111155515151511000000000000000000000000000aa0aa00aa00000000aaaa00aa0aa0000000000000000000000000c11cc11cc11cc11c11551511
1155155515115511111115110000000000000000000000000009a09a00aa000000009aaa00aa0aa00000000000000000000000000ccc11ccccc11cc055111515
151111110111151001511110000000000000000000000000000990a9009a0000000999aa909a0a9000000000000000000000000001ccccc001ccc11015555155
55555555055555500555555000000000000000000000000000990099009900000009990999990990000000000000000000000000000000000cccccc055555555
1555555111555151155151550000000000000000000000000099009990990000000990099990099000000000000000000000000000000000ccc711cc15555551
55111515551515555555551100000000000000000000000000899999909909aa0009900099900990000000000000000000000000000000001c7cc1cc55111515
555511111551515155115151000000000000000000000000089889899099099a9909800099809980000000000000000000000000000000001ccccc1c55551111
5555555111555111155511510000000000000000000000000880000890890099990890000880889000000000000000000000000000000000c1cccc1c55555551
1155115515151511111115550000000000000000000000000880000888088089000880000880880000000000000000000000000000000000c11cc11c11551155
11551555111115111511551100000000000000000000000088000008880888880008800008808800000000000000000000000000000000000ccc11cc11551555
151111110151111001111510000000000000000000000000080000008000888000008000008008000000000000000000000000000000000001ccccc015111111
0555555005555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c77c7ccc55555555
1551515515515155000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cccc777c11515551
5555551155555511000000000000000000000000000000000000bb00bbb0bbb00bb00000b0000000000000000000000000000000000000001ccccc7c55111555
5511515155115151000000000000000000000000000000000000b0b0b000bbb0b0b00000b0000000000000000000000000000000000000001ccccccc55511155
1555115115551151000000000000000000000000000000000000b0b0bb00b0b0b0b00000bbb0000000000000000000000000000000000000c1cccc1c55515151
1111155511111555000000000000000000000000000000000000b0b0b000b0b0b0b00000b0b0000000000000000000000000000000000000c11cc11c11551511
1511551115115511000000000000000000000000000000000000bbb0bbb0b0b0bb000000bbb0000000000000000000000000000000000000ccc11cc055111515
011115100111151000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ccc11015555155
55555555055555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cccccc055555555
1151555111555151000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ccc711cc15555551
55111555551515550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c7cc1cc55111515
55511155155151510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ccccc1c55551111
5551515111555111000000000000000000000000000000066666000666660000006660066060606660000000000000000000000000000000c1cccc1c55555551
1155151115151511000000000000000000000000000000666006606600666000006660606060606000000000000000000000000000000000c11cc11c11551155
55111515111115110000000000000000000000000000006600066066000660000060606060606066000000000000000000000000000000000ccc11cc11551555
155551550151111000000000000000000000000000000066600660660066600000606060606660600000000000000000000000000000000001ccccc015111111
05555550000000000000000000000000000000000000000666660006666600000060606600060066600000000000000000000000000000000000000055555555
11555151000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011515551
55151555000000000000000000000000000000000000000666660000006660000066606060666066600000000000000000000000000000000000000055111555
15515151000000000000000000000000000000000000006600066000000060000006006060666060600000000000000000000000000000000000000055511155
11555111000000000000000000000000000000000000006606066000000600000006006060606066600000000000000000000000000000000000000055515151
15151511000000000000000000000000000000000000006600066000006000000006006060606060000000000000000000000000000000000000000011551511
11111511000000000000000000000000000000000000000666660000006660000066000660606060000000000000000000000000000000000000000055111515
01511110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015555155
c77c7ccc000000000000000000000000000000000000000666660000006060000066606660666066600000000000000000222000000700000000000055555555
cccc777c000000000000000000000000000000000000006606066000006060000060000600606060000000000000000002112200000000000000000015555551
1ccccc7c000000000000000000000000000000000000006660666000000600000066000600660066000000000000000002111200000a00000000000055111515
1ccccccc00000000000000000000000000000000000000660606600000606000006000060060606000000000000000000211122000a007000000000055551111
c1cccc1c00000000000000000000000000000000000000066666000000606000006000666060606660000000000000000222222000099a000000000055555551
c11cc11c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002222220009889000000000011551155
ccc11cc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002222220dd666d00000000011551555
01ccc110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000500500001111000000000015111111
00000000c77c7ccc00000000c77c7ccc0cccccc000000000000000000000000000000000000000000000000000000000dddddddddddddddddddddddd05555550
00000000cccc777c00000000cccc777cccc711cc000000000000000000000000000000000000000000000000000000000dddddddddddddddddddddd011555151
000000001ccccc7c000000001ccccc7c1c7cc1cc0000000000000000000000000000000000000000000000000000000001111111111111111111111055151555
000000001ccccccc000000001ccccccc1ccccc1c00000000000000000000000000000000000000000000000000000000011dd11111111111111dd11015515151
00000000c1cccc1c00000000c1cccc1cc1cccc1c0000000000000000000000000000000000000000000000000000000001dddd1ddd1dd1ddd1dddd1011555111
03030030c11cc11c00000000c11cc11cc11cc11c000000000000000000000000000000000000000000000000000000000111111dddd1d1ddd111111015151511
30033033ccc11cc000000000ccc11cc00ccc11cc00000000000000000000000000000000000000000000000000000000011dd11ddddd11ddd11dd11011111511
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
0001030103030003100300000101101003030303030100030303000001010100030303030300000303000000000000010303030303000303030003030303000000000000000000000000000000000000000010000000131300000010000000001000000010000000101010000003030810101010101000000000000000030308
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010001000000000000000000000000000100000000000000000000000000000001000000000000010101000000303030300000000000010000000000003030303
__map__
000000000000000000000000002c3722212122212121212121212121222121212132382d0000000000002c3731212121211f1f1f212121212121212121322121212138f604f6021f04f602f63721223800000000000000000000000000000000053721380037312121380037380037212221380b00003f000000002c2d002c37
000000000000000000000000002c1f081f0e2b1f0a1f1f14171f1f1f1f1f1f081f0e1f1f0b3f002c2d061f1f1f1f1f14131f1f1f1f1f1f1f1f1f1f1f1f1f1f102116161616161616161616161614f6140727000000001f2700003f00273b070505f6f618391f1f1f1f2439241f391f172231381f3732382d0000063731381f14
000000000000000000000000001f1f1f1f1f0a1f1f1f1f34341f1f1f1f175b1f1f1f1f1f1f1f391f1f1f1f1f1f1f1f24241f1f1f1f1f1f1f1f1f1f1f1f1f1f20211f1f1f1f1f1f1f1f1f1f1f1f341f24050728002800003a27003b283b3b0705241f1f1f1f1f1f1f1f241f241f1f1f080e1f1f1f1f1f1f1f37382c1f1f1f1f24
000000000000000000000000061f1f1014011f1f1f1f1f1f1f1f1f1f1f1f1714113d1f1f1f1f1f1f1f1f1f1f1f1f1f24241f1f57561f1f1f1f1f1f1f1f1f1f080f1f1a1b1f1a1b1f1a1b1f1a1b551f2405053b003b05050505003b3b07071f1f341f1f1f1f1f1f1f1f241f241f1f5b1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f24
0000003f003e003e003f00002c1f5b20241f1f1f1f1f1fe01f1f1f1f1f1f1f24111111123d1f3c113d1f3c11113d1f24241f1f561f1f1f1f601f1f1f1f1f1f1f1f1f2a2b1f2a2b1f2a2b1f2a2b521f240505051f051f571f051f0556571f1f1f0f1f1f1f1f1f1f1f1f241f241f37211414011f1f1f1f1f1f1f391f1f0a1f1f24
0000061f001f001f001f00061f051820241f1f1f1f011f171f1f1f1f1f1f1f242221347f7f1f7f7f7f1f7f7f340f1f24241f11561f601f1f1f1f1f1f1f1f1f20211f16161f16161f16161f16161f1f24051f1f1f051f051f1f1f051f1f1f1f1f1f1f1f1f1f1f1f1f52241f341f027f24241f1f0a1f1f1f1f1f1f1f1f751f1f24
00002c1f1f1f391f2d1f0b2c07181820241f1f1f1f1f1f24141f1f011f1f1f2422381f551f1f1f551f1f1f551f1f1f24241f211f1f1f1f1f1f1f1f1f1f5b2120211f561f1f1f561f561f1f1f56141f24051f052f1f1f051f1f1f051f1f1f5b3c14011f1f1f1f1f1f04241f1f1f7f1f24241f1f1f701f1f1f1f1f1f1f3c3d1f24
00001f1f1f1f1f1f1f1f1f0707181820241f1f1f6f6f6f34346f6f6f1f1f1f2422381f521f1f1f521f1f1f521f012124231f211f1f1f64211f701f1f1f212120211f1f1f1f1f1f1f1f1f1f1f1f240124051f051f1f1f0507052f1f1f1f1f2537241f1f141f37213238341f146f1f1f24241f1f1f37223801373801041f1f1f24
00001f1f1f1f1f1f1f1f1f1818181820241f011f3c1111111111113d1f011f24381f1f1f1f1f1f1f1f1f1f1f1f1ff621231f1112111111111111111111121120211f1f1f1f1f1f1f1f1f1f1f1f341f24051f051f1f1f05071f1f1f1f1f1f2537241f1f241f551f1f1f1f1f34011f1f2424011f1f1f1f1f1f1f1f1f1f1f1f1f24
002c1f1f161f0a1f1f1f0718183c1111241f1f1f1f1f1f34341f1f1f1f1f1f2438012121212121212121212121212121211f1f1f1f1f1f1f1f1f1f1f1f1f1f20211f1f1f1f1f1f1f1f1f1f1f1f1f1f24051f0503030305076f1f1f1f701f2537241f01241f521f1f1f1f1f7f1f1f1f24241f1f1f1f1f1f1f1f1f1f1f1f1f0124
001f1f1f1f1f1f1f1f18183c11111111241f1f1f1f1f1f1f1f1f1f1f1f1f1f24381f0e37212121212121381f1f1f3721211f1f1f1f1f1f1f1f1f1f1f1f1f1f20211f1f1f56561f561f56561f1f373834051f051f1f1f0507052f050505051737241f1f241f1f1f1f1f1f1f1f1f1f0124241f1f1f1f1f1f1f1f1f1f1f1f1f1f24
001f1f161f1f2e18293c111111111111241f171f1f1f1f1f1f1f1f1f1f171f24381f1f1f1f1f1f1f1f1f341f141f1f080e1f1f1f1f1f1f1f1f1f1f1f1f1f1f20211f1f1f1f1f1f1f1f1f1f1f1f1f1f080e1f051f701f0556571f051f1f1f2537241f1f241f1f1f1f1f1f1f1f1f1f1f2424030d1f1f1f1f1f1f1f1f641f1f1f24
001f1f1f2918073c1111111111111111241f241f1f1f1f1f141f1f1f01241f242238011a1b1f1a1b1f1a1b1f241f1f1f1f1f1f1f1f1f1f1f1f1f1f1f751f1f302121381f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f0505051f1f051f1f1f1f1f253724011f341f1f1f1f6f6f6f146f6f1f24241f1f1f1f1f1f1f1f1f1f3c11111124
001f1f1f053c11111111111111111111241f241f011f1f14241f1f1f1f241f2422381f2a2b1f2a2b1f2a2b1f245b1f37222121212121211f701f1f212121212121381f1f1f1f1f1f1f1f1f1f1f5b3714051f1f1f051f1f1f051f1f1f1f1f2537241f1f1f1f1f6f6f3c113d243c3d1f24241f1f1f641f1f1f1f1f1f1616161624
00071f3c111111111111111111111111346f346f6f6f6f34346f6f6f6f346f3438f61f16167016161f16161f343c111122212121212121212121212121212121212138011f1f1f011f1f011f1f37213405051f1f1f1f051f051f70561f6f1737341f1f1f1f6f37223121383437385234346f6f6f3c113d1f1f1f1f1f5b161634
3b3a3b3a3b3a3b3a3b3a3b3a3b3a3b3a1111111111111111111111111111111111111112111112111211121211121111212121212121212121212121212121212121386f6f6f6f6f6f6f6f6f6f372221213805050505070707070707053721212121312121212121212132212221212121222121212121213221212121210121
2121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212131212132212121312121212122212121212122322121212122212121212121212121212121212121212121212121212121212121212121212121322121212221213138141614
13161616161516161616151616161610381f1f1f1f1f1f1f2455241f1f1f1f372132223222313816161616161616163721322232223138161616161616161637131624161616161616161616161616101434343416161616162416161616341413161616161f561f1f1f1f1f1f1f1f5608161616161616161616161616241624
23161616162516161616251616161630381f1f1f1f1f1f1f3452241f1f1f1f372132212138161616161616161616163738161616161616161616161616161637331f341f1f1f1f1f1f1f1f1f1f751f20245256751f1f1f1f1f341f1f1f1f5224231616161f1f571f1f751f1f1f1f565700165b16161616161616161616340124
2316161616251616161625161616160e081f1f1f1f1f1f1f1f1f241f1f1f1f0f081f161f16161f1f1616161616161637381f1f1f1f1f1f1f1f1f1f1f1f1f1f0e081f1f1f1f1f1f1f1f1f1f1f1f3c3d20343c113d561f1f1f1f1f1f1f1f1f17242316161f1f1f3c11113d1f1f575657101403030d1f1f1f1f1f1f1f1f1f0e1f24
231f1f1f1f251f1f1f1f251f1f1f1f1f1f1f5b1f1f6f1f1f1f1f241f1f1f1f1f1f165b1f1f1f1f1f1f1f161f1f161637381f1f1f751f1f1f1f1f1f1f1f1f1f1f1f1f5b1f1f1f1f1f1f1f1f1f1f1f1f20051f1f1f1f1f2e291f1f1f1f1f1f1f242316601f1f1f372121383c1111113d20241f1f1f1f1f1f1f1f1f1f1f1f1f0124
231f1f1f1f251f1f1f1f251f1f0c031011113d6f6f141f1f1f1f241f1f143c113d030d1f1f1f1f1f641f1f1f161f1637386f3c11113d6f6f1f1f1f1f1f3c1111133c1111113d1f176f6f6f1f1f1f1f20071f1f1f1f1c1e1d1d1e1f1f1f181f24331f0c0d1f1f37212121212121213820241f1f1f1f1f1f1f1f1f1f1f1f011f24
231f1f1f1f251f1f1f1f251f1f1f1f203816551717341f1f1f1f24011f243721381f1f1f1f1f1f1f57561f011f1f1f3721382121212137381f1f1f3c3d1f1f37233c11121111111111113d1f1f0c0320051f1f1f1f1f1f1f1f1f1f1f1f1f1f24f6011f1f1f1f1f1f1f1f1f1f1f1f1f20241f1f1f1f1f1f16161f1f1f1f1f1f24
231f1f1f1f171f641f1f171f1f1f1f20381652161f1f1f1f1f1f241f1f243721381f1f0c0d1f1f1f1f1f1f1f1f1f1f3721212121212121381f1f561f1f1f1f37231f1f1f1f1f1f1f1f1f1f1f1f1f1f200726641f1f1f141f141f291f1f1f75343c111111111111111111113d57565720241f16161f1f1f0c0d1f1f16161f1f24
231f1f1f3c1111111111113d1f1f1f20381616161f141f1f1f14241f1f241637381f1f1f1f1f1f1f1f1f1f1f1f1f1f3721212121212121383c3d1f1f1f1f1f37231f1f751f1f1f1f1f1f1f1f1f1f1f2005523c3d6f1f3452341f2f1f1f1f570f161616141f1f1f1f1f18181f0c030d20341f0c0d1f1f1f1f1f1f1f0c0d1f1f34
231f1f1f251f1f1f1f1f1f251f1f1f20381616161f346f6f6f3424011f341637381f1f011f1f1f641f1f641f1f1f1f3721212132387f7f7f1f1f1f1f1f1f1f37231f1f3c3d1f0c030d1f0c03030303200705070507053c113d1f1f1f1f1f1f1f161616241f1f1f1f1f7f7f1f601f1f20071f1f1f1f1f1f1f1f1f1f1f1f1f1f05
231f1f1f251f1f1f1f1f1f251f1f1f20386f6f141f3721212121381f1f1f1637381f1f1f1f1f56571f1f57181f011f37381f1f7f7f1f1f1f1f1f1f1f1f1f1f37231f6f6f6f6f6f6f6f6f6f6f6f6f6f2007262626071f1f601f1f1f1f1f1f1f14131616241f1f1f1f1f601f1f1f1f1f203a261f1c1d1d1e1f26261f1f1c1e1f07
2311113d251f1f1f1f1f1f251f1f1720212121381f1f1f1f1f1f1f1f1f14163738160c0d1f1f1f1f1f1f1f1f1f1f1f0e081f1f1f1f1f1f1f0c030d1f1f1f1f37231f3c11111111111211111111113d20051f261f1f601f1f1f1f2f1f1f751f2423161624161f1f1f1f1f1f1f1f15152005262626261f1f1f1f1f261f26262605
231f1f25251f1f1f1f641f251f1f2520381616161f0c0303030303030d3416373816161f1f161f1f1f1f1f1f161f1f1f1f5b1f1f1f1f1f1f1f1f141f1f641f37231f1f1f1f1f341f1f1f1f1f1f1f1f3007261f1f1f1f1f1f1f1f1f1f1f141f24231616341616161f1f1f6415152525203b266f6f1f1f1fd01f1f1f1f1f266f07
231f1f25251f1f07050705071f1f2520385216161f1f1f1f1f1f1f1f1f1f163738161616161616161f161f161616013c113d1f1f1f0c030d1f1f241f56565637331f1f171f1f1f1f1f1f751f1f1f1f0e081f1f051f1f1f071f1f26266f346f3423161616161616161f15152525252520076f05076f261c1c1e1f1c1d1e6f0705
331f5b35351f07053b3a3b05071f073038176f6f6f6f6f6f6f6f6f6f3c3d6f37386f6f6f6f6f6f6f6f6f6f6f6f6f6f37111111113d6f6f6f6f6f346f6f6f6f3711121111111111113d6f3c3d6f1f1f1f1f295b07050705052e2605070507050733165b1616161616166f6f6f6f6f6f303b050705056f6f6f6f6f6f6f6f050707
050114053a3b3a3b3a3b3a3b3a3722222231222232212121213222312232222221212222222222222221212121212121212122222222222222212121212121212121212131212121212122322138053b3a3a3a3b3a3b3a3b053b3a3b3a3b3a3b111111111111111111121111111111123b3a3b3b3a3b3a3b3a3b3a3b3a3b3a3b
__sfx__
060400000c0000b000090000500000000000000000000000000000c0000c0000d0000d0000d0000d0000e0000e0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0001000010000
000100000a4301943025430194300f43022430254301e430134300e430124301e430284301f430174300f4301e430244301d430134300c430154302b4302443019430124301243020430234301f4301943012430
00010000204001e4001b4001a4001840016400154001540014400134001340014400144001640017400184001b4001d4001f40022400244002440024400244002440024400254002540025400264002640027400
000100001c25020250252502b2501a2502f25021250282502f2502a2502c25022250302502b250212501d2001d2001d2001c2001e2002020022200242002620027200292002b2002d2002e200312003220034200
900300000b20007200032000320503200002000020000200002000020000200002000020000200002000020034200362000020035200322000020000200332000020000200002000020000200002000020000200
960300001201112010003011300012010120101620012200003000030000300003000030000300003000030034300363000030035300323000030000300333000030000300003000030000300003000030000300
000a000015500115000c5000950005500035000350003500035000350003500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
4d0200000922009230092300423004220042200222002210012100121000200002000020000200002000020034200362000020035200322000020000200332000020000200002000020000200002000020000200
4e0a00000223004230072300c23010230122200c21007210032102d20000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
000a000015550115500c5500955005550035500355003540035300352003510005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000100000f150111501215013150141401514016130171301813019120191201a1201b1101b1101d1001d1001d1001d1001c0001e0002000022000240002600027000290002b0002d0002e000310003200034000
000200000891008910099100a9100b9200b9200c9200d9200e93010940109400f9300f9200d9100c9100c9000c900009000090000900009000090000900009000090000900009000090000900009000090000900
900300000b25007240032200321503200002000020000200002000020000200002000020000200002000020034200362000020035200322000020000200332000020000200002000020000200002000020000200
000400001e013230132702327023240131e0131901315013120130f0130d0131f0031b0031700314003110030d003090030600303003000030000328003220032d00318003120030000300003000030000300003
480400000f1130e1100b11009113021030010309103031030110300103001031f1031b1031710314103111030d103091030610303103001030010328103221032d10318103121030010300103001030010300103
140200002421329223232031b233222231a2031e213172131d203172131020316213102030a2130f2030920305203092130a20301203272032820328203222032d20318203122030020300203002030020300203
060400000c0500b050090400504000030000200000000000000000c0000c0000d0000d0000d0000d0000e0000e0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0001000010000
00020000095430d5431054312533145331553317523175231752317513175131d5031e5031750314503115030d503095030650303503005030050328503225032d50318503125030050300503005030050300503
00020000091500d1501015012140141401514017130171301713017120171201d1001e1001710014100111000d100091000610003100001000010028100221002d10018100121000010000100001000010000100
90040000222301e2501926015260102400c22007210032101820014200122000e2000d20000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
1014000015020110300e040100400c0400b0400b0400b0400b0300b0200b010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
040300001e0541704016040110300d0300a03007020040200201000014121040e1040d10400104001040010400104001040010400104001040010400104001040010400104001040010400104001040010400104
500200001e9101d9101d9201c9201b9301a930189401694014930119300f9200d9200a91009910019000c9000c900009000090000900009000090000900009000090000900009000090000900009000090000900
1004000018531125310f5310c5410b5410c5410f541145311c5212152100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501
29080000215121d5221c5221d5221a532185321a5321a5321a5321a5321a5321a5221a5220f502085020650207502095020950208502065020650207502095020a50207502075020050200502005020050200502
290900002151224522285222052223532265321d53221532245321c532205222152221522215221450207502095020950208502065020650207502095020a5020750207502005020050200502005020050200002
280800001551217522185221a5221c5321e532205322053220532205322053220522205220f502085020650207502095020950208502065020650207502095020a50207502075020050200502005020050200502
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
911c18000d0200d025000000e0200e025000001002010025000000d0200d025000000d0240d0250d0050e00014000140000d0240d02514005140050d005000000000000000000000000000000000000000000000
491c18001f0101f015180002101021015180002301023015180001f0101f015180001501415015180001500015005180001501415015180001f0001f005000000000000000000000000000000000000000000000
591c180019010190150c00015010150150c00017010170150c00012010120150c00019014190150c0001500015005180001501415015180001f0001f005000000000000000000000000000000000000000000000
491c18000d0200d025000000e0200e025000001002010025000000d0200d025000001202012025000000e0200e025000001002010025000000d0200d025000000000000000000000000000000000000000000000
491c18000d0200d025000000e0200e025000001002010025000000d0200d025000001202012025000000e0200e025000001002010025000000d0200d025000000000000000000000000000000000000000000000
591c180013010130150c00015010150150c00017010170150c00012010120150c00015010150150c00013010130150c0001201012015120050e0100e015000000000000000000000000000000000000000000000
011c1b000d0200d020000000e0200e020000001002010020000000d0200d020000001202012020000000e0200e020000001002010020000000d0200d020000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
491c18000d0200d0250d0000d00506000060200e0200e0200e0201002010020100200d0200d02510000100000d0000602009020090250900509020090250d000090000900009000090000b0000b0000b0000b000
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
411000000212002120021200212005120051200812008120021200212002120021200512005120081200812002120021200212002120051200512008120081200212002120021200212005120051200812008120
291000000b1220b10205122051020b1220b10205122051020b1220b10205122051020b1220b10205122051020b1220b10205122051020b1220b10205122051020b1220b10205122051020b1220b1020512205102
0010000024700247002470024700277002770027700277002b7002b7002b7002b7002970029700297002970027700277002770027700247002470024700247002a700267002470027700297002c7002b7002b700
0010000024700247002470024700277002770027700277001f7001f7001f7001f7001b7001b7001b7001b70020700207002070020700227002270022700227001f7001d7001f7001d7001f7001d7001f7001f700
101000001800018000180001800014000140001300013000180001b000180001800014000140001300013000110001100011000110000f0000f00014000140001300013000130001300013000130001300013000
8d1000001120011200112051d100142301423014230142201422014225110001100015230152301523015220152201522511000110001723017230172301722017220172250e2001a20015230152301523015225
8d10000023120201201d1101a11023120201201d1101a11023120201201d1101a11023120201201d1101a110211201d1201a11019110211201d1201a11019110211201d1201a11019110211201d1201a11019110
8d1000001d2001d2001d2051d1001423014230142301422014220142251d0001d0001523015230152301522015220152251d0001d000172301723017230172302622026220262202622025220252202522025225
8d10000023130201201d1101a11023130201201d1101a110211301d1201c11019110211301d1201c11019110201301d1201a110171101f1301d1201a110171101d1301a120171101a110191301d1201a11019110
451000001714017130171201711023140201301d1201a120211401d1301c12019120211401d1301c12019120201401d1301a120171201f1401d1301a120171201d1401a130171201a120191401d1301a12019110
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
00 1e5f4c44
00 20604c44
00 1e624c44
00 23614c44
02 26424344
02 5f424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 32774344
00 33424344
00 32374344
00 33384344
00 32394344
02 333a4344

