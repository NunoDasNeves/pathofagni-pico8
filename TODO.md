### Misc
- Refactor code to reduce lines
    - lanterns can be replaced by checkpoints at start of each room
        - remove most of lantern code
        - maybe have lanterns that will open a door (light all lanterns in room = open door)
            - maybe requires another sprite
            - maybe requires same amount of code
            - some level designs are nicer, chill platforming levels are easier to design?
            - color lantern/door combos?? (need more sprites)
    - shooter/thrower have almost same logic
        - should parameterize some stuff - maybe have a few enemy 'types'
        - all code can be almost same between these two except what projectile is spawned
        - and some parameters - move speed, reaction time etc
    - bat code can probably be reduced
    - player code can probably be reduced
    - fireball code can probably be reduced

### Levels
- How to effectively teach player to shoot diagonally?
- How to teach/use fireball slowdown (mainly useful for combat rn, not platforming)?
- Probably don't have space for another enemy type unless almost identical to an existing one
- cavern levels still have some dungeon stuff left
- doors can maybe be drawn with palette swap
- for DEMOs - maybe have a door to skip floors?
- text for boss levels

### Sounds!
- fireball explode?
- light lantern?
- enemy die?
- archer LEAVE invis

### Music
- Come up with a structure that lasts a decent time, using existing ideas
- Chill music for start/regular levels
- Epic music for boss battles

### Enemies
- Underside crawler - spider? 1x1
- Ghost/phantom 1x1
- Moving spikes or something
- bat spawning enemy

### Boss ideas
- knight 1x1
    - walk around (toward player)
    - attack when close
    - phase 2 - jump at you periodically
    - immune to fireballs unless he's in attack lag
- archer / rogue 1x1
    - shoots arrows
    - jumps around platforms
    - goes stealth after you hit them, repositions and sneak attacks you
- mage 1x1 or 1x2
    - teleports before attacking or after getting hit
    - casts protection spell which reflects fireballs ?
    - shoots stuff at you ?
    - targeted area, or laser - you see indicator and have to move out of the  way ?
    - spawns bats ?


### Playtest notes
