pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- wolf z-catcher
-- catch z's before they reach the top

-- enemy prototype (used for creating new enemies)
enemy_proto = {
  width = 16,
  height = 16,
  sprite = 5, -- use sprite #5 as the top-left of a 2x2 grid (5,6,21,22)
  base_speed = 0.8,
  speed = 0.8,
  move_timer = 0,
  move_duration = 60,
  dx = 0,
  dy = 0
}

-- enemy sprite designs to alternate between
enemy_sprites = {
  5,  -- design 1: sprites 5,6,21,22 
  13  -- design 2: sprites 13,14,29,30
}

-- game state
wolf = {
  x = 64,
  y = 16,
  width = 8,
  height = 8,
  sprite = 1,
  speed = 2.0,
  lives = 3,
  score = 0,
  z_caught = 0, -- counter for z's caught
  prev_x = 64,
  prev_y = 16
}

coyote = {
  x = 64, -- stationary in the middle
  y = 120,
  width = 16,
  height = 16, -- increased height for 16x16 sprite
  sprite = 2, -- top-left sprite of the 2x2 coyote sprite area
  fire_timer = 0,
  fire_rate = 60, -- frames between z shots (will decrease over time)
  z_speed = 0.7, -- initial z speed (will increase over time)
  bonus_speed = 1.2, -- speed during bonus round
  bonus_dir = 1, -- direction of movement during bonus round (1 = right, -1 = left)
  bonus_rounds = 0 -- counter for number of bonus rounds played
}

-- enemies that roam the screen
enemies = {}
max_enemies = 5

-- player's projectile during bonus round
heart = {
  x = 0,
  y = 0,
  width = 16,
  height = 16,
  sprite = 11, -- use sprite #11 as the top-left of a 2x2 grid (11,12,27,28)
  speed = 3.0,
  active = false
}

-- declare global game variables at the top
zs = {}
game_over = false
victory = false -- victory state variable
victory_timer = 0 -- for victory animation
bonus_round = false
bonus_timer = 0
wave_amplitude = 2.0 -- increased for more noticeable side-to-side movement
wave_frequency = 0.03 -- adjusted for smoother waves
difficulty_timer = 0
difficulty_level = 0
max_level = 8 -- maximum level before victory (changed to 8)
z_bonus_count = 10 -- number of z's needed for bonus round
title_screen = true -- start at the title screen
title_timer = 0 -- for title screen animation
leaving_bonus_round = false  -- for anything special post-bonus

-- for debugging 
-- set to true and change test_score to test bonus round quickly
debug_bonus = false
test_score = 90 -- test score for quick bonus round testing
debug_skip_title = false -- set to true to skip title screen

-- initialize the game
function _init()
  -- start with title screen
  title_screen = not debug_skip_title
  title_timer = 0
  
  init_game_state()
  
  -- start playing the lullaby music (track 0)
  music(0)
end

-- initialize or reset the game state
function init_game_state()
  -- set up initial state
  wolf.x = 64
  wolf.y = 16
  wolf.prev_x = 64
  wolf.prev_y = 16
  wolf.lives = 3
  wolf.score = debug_bonus and test_score or 0
  wolf.z_caught = 0 -- reset z counter
  
  wolf.bonus_x = 0
  wolf.bonus_y = 0

  coyote.x = 64 -- center position
  coyote.fire_timer = 0
  coyote.fire_rate = 60 -- reset to initial fire rate
  coyote.z_speed = 0.7 -- reset to initial z speed
  coyote.bonus_dir = 1
  coyote.bonus_speed = 1.2 -- reset bonus speed
  coyote.bonus_rounds = 0 -- reset bonus round counter
  
  -- initialize enemies
  enemies = {}
  add_enemy() -- start with one enemy
  
  -- reset heart
  heart.active = false
  
  zs = {}
  game_over = false
  victory = false -- reset victory state
  victory_timer = 0 -- reset victory animation timer
  bonus_round = false
  bonus_timer = 0
  wave_amplitude = 2.0
  wave_frequency = 0.03
  difficulty_timer = 0
  difficulty_level = 0
end

-- create a new enemy at a random position
function add_enemy()
  -- don't add more than max_enemies
  if #enemies >= max_enemies then return end
  
  -- create a new enemy based on the prototype
  local e = {}
  for k,v in pairs(enemy_proto) do
    e[k] = v
  end
  
  -- alternate between different sprite designs based on enemy count
  local sprite_index = (#enemies % #enemy_sprites) + 1
  e.sprite = enemy_sprites[sprite_index]
  
  -- ensure speed is set
  e.speed = e.speed or enemy_proto.base_speed
  
  -- set random position (avoid immediate collisions with wolf)
  repeat
    e.x = flr(rnd(110)) + 10
    e.y = flr(rnd(70)) + 25
  until abs(e.x - wolf.x) > 20 and abs(e.y - wolf.y) > 20
  
  -- set random direction
  local angle = rnd(1)
  e.dx = cos(angle) * e.speed
  e.dy = sin(angle) * e.speed
  
  -- add to enemies table
  add(enemies, e)
  
  printh("added enemy #"..#enemies.." at "..e.x..","..e.y.." with speed "..e.speed.." sprite:"..e.sprite)
end

-- helper function to set random enemy direction
function set_random_enemy_direction(e)
  -- choose a random angle
  local angle = rnd(1)
  e.dx = cos(angle) * e.speed
  e.dy = sin(angle) * e.speed
end

-- update game state
function _update()
  if title_screen then
    update_title_screen()
    return
  end
  
  if game_over then
    if btnp(5) then -- x button to restart
      _init()
    end
    return
  end
  
  if victory then
    update_victory_scene()
    if btnp(5) then -- x button to restart
      _init()
    end
    return
  end
  
  -- check if we need to start a bonus round (based on z count now)
  if not bonus_round and wolf.z_caught >= z_bonus_count then
    start_bonus_round()
    return -- important to exit the function after starting bonus round
  end
  
  -- different update cycle for bonus round
  if bonus_round then
    update_bonus_round()
  else
    update_normal_game()
  end
end

-- update victory scene animation
function update_victory_scene()
  victory_timer += 1
end

-- update title screen
function update_title_screen()
  title_timer += 1
  
  -- press x to start the game
  if btnp(5) then
    title_screen = false
    init_game_state()
  end
end

-- update normal gameplay
function update_normal_game()
  update_wolf()
  update_enemies()
  update_coyote()
  update_zs()
  
  -- increase difficulty over time
  difficulty_timer += 1
  if difficulty_timer > 600 then -- every 10 seconds (600 frames at 60fps)
    -- increase difficulty level
    difficulty_level += 1
    
    -- check if player completed all levels
    if difficulty_level >= max_level then
      victory = true
      return
    end
    
    -- make z's spawn more frequently
    coyote.fire_rate = max(20, coyote.fire_rate - 5) -- decrease time between shots
    
    -- make z's move faster
    coyote.z_speed = min(1.4, coyote.z_speed + 0.1) -- increase z speed
    
    -- other difficulty increases
    wave_amplitude = min(3, wave_amplitude + 0.1) -- wider waves
    
    -- speed up existing enemies
    for e in all(enemies) do
      if e.speed then -- check if speed is defined
        e.speed = min(1.5, e.speed + 0.05) -- faster enemies
        -- update velocity to match new speed while keeping direction
        local angle = atan2(e.dy, e.dx)
        e.dx = cos(angle) * e.speed
        e.dy = sin(angle) * e.speed
      end
    end
    
    -- add a new enemy every second level (2, 4, 6, etc.)
    if difficulty_level % 2 == 0 and #enemies < max_enemies then
      add_enemy()
      sfx(4) -- enemy appear sound
    end
    
    difficulty_timer = 0
  end
end

-- update bonus round
function update_bonus_round()
  update_wolf_bonus() -- special wolf controls for bonus round
  update_coyote_bonus() -- coyote moves during bonus round
  update_heart() -- handle heart movement
  
  -- bonus round timer (max time to shoot)
  bonus_timer += 1
  if bonus_timer > 300 then -- 5 seconds (300 frames)
    end_bonus_round(false) -- failed to shoot in time
  end
end

function update_wolf()
  -- store previous position for smooth movement
  wolf.prev_x = wolf.x
  wolf.prev_y = wolf.y
  
  -- wolf movement with 8-directional controls
  local moved = false
  
  -- horizontal movement
  if btn(0) then 
    wolf.x -= wolf.speed
    moved = true
  end
  if btn(1) then 
    wolf.x += wolf.speed
    moved = true
  end
  
  -- vertical movement
  if btn(2) then 
    wolf.y -= wolf.speed
    moved = true
  end
  if btn(3) then 
    wolf.y += wolf.speed
    moved = true
  end
  
  -- normalize diagonal movement (optional, makes diagonal movement same speed as cardinal)
  if (btn(0) or btn(1)) and (btn(2) or btn(3)) then
    -- if moving diagonally, adjust for proper speed
    wolf.x = wolf.x * 0.7071 + wolf.prev_x * 0.2929
    wolf.y = wolf.y * 0.7071 + wolf.prev_y * 0.2929
  end
  
  -- keep wolf on screen (with some restricted upper and lower limits)
  wolf.x = mid(wolf.width/2, wolf.x, 128-wolf.width/2)
  wolf.y = mid(8, wolf.y, 100) -- restrict vertical movement range
end

function update_wolf_bonus()
  -- wolf only moves horizontally during bonus
  if btn(0) then wolf.x -= wolf.speed end
  if btn(1) then wolf.x += wolf.speed end
  
  -- keep wolf on screen
  wolf.x = mid(wolf.width/2, wolf.x, 128-wolf.width/2)
  
  -- wolf sends heart when x is pressed
  if btnp(5) and not heart.active then
    heart.x = wolf.x
    heart.y = wolf.y + 8
    heart.active = true
    sfx(4) -- play smooch sound
  end
end

function update_heart()
  if not heart.active then return end
  
  -- move heart down
  heart.y += heart.speed
  
  -- check if heart hit coyote
  if check_collision(heart, coyote) then
    end_bonus_round(true) -- success!
  end
  
  -- check if heart went off screen
  if heart.y > 128 then
    heart.active = false
    end_bonus_round(false) -- failed
  end
end

function update_enemies()
  for e in all(enemies) do
    -- ensure speed is defined
    e.speed = e.speed or enemy_proto.base_speed
    
    -- move enemy according to current direction
    e.x += e.dx
    e.y += e.dy
    
    -- bounce off screen edges
    if e.x < 8 then
      e.x = 8
      e.dx = -e.dx
    elseif e.x > 120 then
      e.x = 120
      e.dx = -e.dx
    end
    
    if e.y < 8 then
      e.y = 8
      e.dy = -e.dy
    elseif e.y > 100 then -- stay above the coyote
      e.y = 100
      e.dy = -e.dy
    end
    
    -- randomly change direction occasionally
    e.move_timer += 1
    if e.move_timer > e.move_duration then
      -- choose a random angle
      local angle = rnd(1)
      e.dx = cos(angle) * e.speed
      e.dy = sin(angle) * e.speed
      
      e.move_timer = 0
      e.move_duration = 30 + flr(rnd(60)) -- random duration between 30-90 frames
    end
    
    -- check collision with wolf
    if check_collision(e, wolf) then
      wolf.lives -= 1
      sfx(1) -- play fail sound
      
      -- reset wolf to starting position
      wolf.x = 64
      wolf.y = 16
      wolf.prev_x = 64
      wolf.prev_y = 16
      
      if wolf.lives <= 0 then
        game_over = true
      end
    end
  end
end

function update_coyote()
  -- coyote stays stationary in the center
  coyote.x = 64
  
  -- fire z's
  coyote.fire_timer += 1
  if coyote.fire_timer >= coyote.fire_rate then
    add_z()
    coyote.fire_timer = 0
  end
end

function update_coyote_bonus()
  -- move coyote left/right
  coyote.x += coyote.bonus_speed * coyote.bonus_dir
  
  -- bounce off screen edges
  if coyote.x < 16 then
    coyote.x = 16
    coyote.bonus_dir = 1 -- switch to moving right
  elseif coyote.x > 112 then
    coyote.x = 112
    coyote.bonus_dir = -1 -- switch to moving left
  end
end

function add_z()
  -- random position at the bottom of the screen
  local rand_x = flr(rnd(110)) + 10 -- between 10 and 118
  
  local z = {
    x = rand_x, -- random x position
    y = 116, -- start slightly above the coyote's head
    width = 8,
    height = 8,
    sprite = 4,
    speed = coyote.z_speed, -- use the current z speed (increases over time)
    time = rnd(1), -- random starting phase for wave pattern
    wave_dir = flr(rnd(2)), -- 0 or 1 for initial wave direction (left or right)
    rotation = 0,
    dx = nil -- for ricochet effect
  }
  
  -- if wave_dir is 0, adjust time to start moving right
  -- if wave_dir is 1, adjust time to start moving left
  if z.wave_dir == 0 then
    z.time = 0.25 + rnd(0.25) -- start moving right
  else
    z.time = 0.75 + rnd(0.25) -- start moving left
  end
  
  add(zs, z)
end

function update_zs()
  for i=#zs,1,-1 do
    local z = zs[i]
    
    -- move z up with improved side-to-side wave pattern
    z.y -= z.speed
    z.time += 0.01
    -- use sine wave for smooth side-to-side movement
    local old_x = z.x
    z.x += sin(z.time * wave_frequency) * wave_amplitude
    
    -- improved bounce off screen edges with ricochet
    if z.x < 4 then
      z.x = 4
      -- calculate ricochet angle by reversing x movement
      z.dx = abs(z.x - old_x) * 1.5
      -- keep vertical movement
      z.time = 0.25 -- force movement to the right
    elseif z.x > 124 then
      z.x = 124
      -- calculate ricochet angle
      z.dx = -abs(z.x - old_x) * 1.5
      -- keep vertical movement
      z.time = 0.75 -- force movement to the left
    end
    
    -- if we have a ricochet effect, apply it
    if z.dx then
      z.x += z.dx
      z.dx *= 0.95 -- gradually reduce the ricochet effect
      if abs(z.dx) < 0.1 then z.dx = nil end -- stop when small enough
    end
    
    -- rotate between frames
    z.rotation = (z.rotation + 0.02) % 1
    
    -- check if wolf caught the z
    if check_collision(z, wolf) then
      wolf.score += 10
      wolf.z_caught += 1 -- increment z counter
      sfx(0) -- play catch sound
      del(zs, z)
      
      -- check if we reached z bonus count
      if wolf.z_caught >= z_bonus_count and not bonus_round then
        start_bonus_round()
        return
      end
    
    -- check if z reached the top (lose points instead of life)
    elseif z.y <= 0 then
      -- subtract 50 points (but don't go below 0)
      wolf.score = max(0, wolf.score - 50)
      sfx(1) -- play fail sound
      del(zs, z)
      
      -- game over only if score drops to 0
      if wolf.score <= 0 then
        game_over = true
      end
    end
  end
end

-- start bonus round
function start_bonus_round()
  bonus_round = true
  bonus_timer = 0
  
  -- increment bonus round counter
  coyote.bonus_rounds += 1
  
  -- save wolf pre-bonus position
  wolf.bonus_x = wolf.x
  wolf.bonus_y = wolf.y

  -- reposition wolf at the top center of screen, further below the timer
  wolf.x = 64
  wolf.y = 45 -- moved lower on screen, well below the countdown timer
  wolf.prev_x = 64
  wolf.prev_y = 45
  
  -- increase coyote speed with each bonus round
  coyote.bonus_speed = 1.2 + (coyote.bonus_rounds * 0.2) -- 0.2 faster each round
  
  -- set coyote position for bonus round
  coyote.x = 32 -- start at left side
  coyote.bonus_dir = 1 -- start moving right
  
  -- reset heart
  heart.active = false
  
  -- clear all z's from the screen
  zs = {}
  
  -- reset z counter after starting bonus round
  wolf.z_caught = 0
  
  -- change music to bonus round music (track 1)
  -- music(1)
  
  -- print debug message to console
  printh("bonus round #"..coyote.bonus_rounds.." started! z_caught: "..wolf.z_caught.." target: "..z_bonus_count.." coyote speed: "..coyote.bonus_speed)
end

-- end bonus round
function end_bonus_round(success)
  bonus_round = false
  
  if success then
    -- give an extra life instead of points
    wolf.lives += 1
    sfx(5) -- play success sound
  else
    -- lose a life if they missed
    wolf.lives -= 1
    sfx(1) -- play fail sound
    
    if wolf.lives <= 0 then
      game_over = true
    end
  end
  
  -- reset coyote to center
  coyote.x = 64
  
  -- reset wolf to pre-bonus position
  wolf.x = wolf.bonus_x
  wolf.y = wolf.bonus_y

  -- flag we're leaving
  leaving_bonus_round = true

  -- return to main game music
  -- music(0)
end

-- draw everything
function _draw()
  cls(1) -- dark blue background
  
  if title_screen then
    draw_title_screen()
    return
  end
  
  -- draw ground
  rectfill(0, 124, 127, 127, 3)
  
  if bonus_round then
    draw_bonus_round()
  else
    draw_normal_game()
  end
  
  -- draw game over
  if game_over then
    rectfill(24, 48, 104, 80, 0)
    rect(24, 48, 104, 80, 7)
    print("he's gonna yarr!", 35, 56, 8)
    print("score: "..wolf.score, 40, 64, 7)
    print("press ❎ to restart", 28, 72, 6)
  end
  
  -- draw victory screen as its own scene
  if victory then
    draw_victory_scene()
  end
end

-- draw victory scene with bouncing characters
function draw_victory_scene()
  cls(1) -- dark blue background
  
  -- animated stars (similar to title screen)
  for i=1,20 do
    local x = (i * 13 + (time() * 20)) % 128
    local y = (i * 9 + (time() * 10)) % 128
    pset(x, y, 7)
  end
  
  -- draw large heart at the top (using sprites 11,12,27,28)
  spr(11, 48, 12, 2, 2)
  
  -- draw "you win!" text
  print("you win!", 44, 44, 10)
  
  -- draw score info
  print("final score: "..wolf.score, 30, 54, 7)
  -- print("z's caught: "..flr(wolf.score/10), 34, 62, 7)
  
  -- calculate bounce position for characters
  local bounce_offset1 = sin(time()*2) * 4
  local bounce_offset2 = sin(time()*2 + 0.5) * 4
  
  -- draw bouncing wolf and coyote
  spr(1, 40, 80 + bounce_offset1, 1, 1) -- wolf on left, bouncing
  spr(2, 72, 80 + bounce_offset2, 2, 2) -- coyote on right, bouncing
  
  -- press button to restart
  if (victory_timer\30) % 2 == 0 then
    print("press ❎ for new game", 20, 110, 6)
  end
end

-- draw title screen
function draw_title_screen()
  -- animated background (stars)
  for i=1,20 do
    local x = (i * 13 + (time() * 20)) % 128
    local y = (i * 9 + (time() * 10)) % 128
    pset(x, y, 7)
  end
  
  -- draw title logo (2x4 sprite area)
  spr(7, 32, 32, 4, 2) -- use sprites 7,8,9,10,23,24,25,26 for logo
  
  -- draw wolf and coyote
  spr(1, 40, 64, 1, 1) -- wolf on left
  spr(2, 80, 64, 2, 2) -- coyote on right
  
  -- draw some z's
  for i=0,3 do
    local y_offset = sin(time() + i/4) * 6
    spr(4, 60 + i*8, 60 + y_offset, 1, 1)
  end
  
  -- press start text (flashing)
  if (title_timer\30) % 2 == 0 then
    print("press ❎ to start", 28, 90, 7)
  end
  
  -- credits
  print("wolf z-catcher", 34, 110, 6)
end

function draw_normal_game()
  -- draw wolf
  spr(wolf.sprite, wolf.x-4, wolf.y-4)
  
  -- draw enemies (using 4 sprite slots in a 2x2 grid for each)
  for e in all(enemies) do
    spr(e.sprite, e.x-8, e.y-8, 2, 2)
  end
  
  -- draw coyote (using 4 sprite slots in a 2x2 grid)
  spr(coyote.sprite, coyote.x-8, coyote.y-8, 2, 2)
  
  -- draw zs
  for z in all(zs) do
    -- choose sprite frame based on rotation
    local spr_frame = 4
    spr(spr_frame, z.x-4, z.y-4)
  end
  
  -- draw sleep status
  print("score: "..wolf.score, 2, 2, 7)
  print("lives: "..wolf.lives, 80, 2, 7)
  
  -- display z counter
  -- print("z: "..wolf.z_caught.."/"..z_bonus_count, 40, 2, 7)
  
  -- draw level indicator at the left side of the screen
  print("level "..(difficulty_level + 1).." of "..max_level, 2, 120, 7)

  -- if we're exiting the bonus round, give the player some breathing
  if (leaving_bonus_round == true) then
  
    leaving_bonus_round = false
  end
end

function draw_bonus_round()
  -- draw wolf
  spr(wolf.sprite, wolf.x-4, wolf.y-4)
  
  -- draw coyote (using 4 sprite slots in a 2x2 grid)
  spr(coyote.sprite, coyote.x-8, coyote.y-8, 2, 2)
  
  -- draw heart (2x2 sprite)
  if heart.active then
    spr(heart.sprite, heart.x-8, heart.y-8, 2, 2)
  end
  
  -- draw bonus round status
  print("bonus round!", 35, 2, 8)
  print("smooch the coyote", 25, 10, 7)
  print("for an extra life!", 25, 18, 7)
  print("press ❎ to send heart", 17, 26, 6)
  print("lives: "..wolf.lives, 80, 2, 7)
  
  -- draw timer bar
  local timer_width = 60 - (bonus_timer / 300 * 60)
  rectfill(34, 32, 94, 34, 5) -- background
  rectfill(34, 32, 34 + timer_width, 34, 8) -- timer
end

-- collision detection function
function check_collision(a, b)
  return abs(a.x - b.x) < (a.width + b.width)/2 and
         abs(a.y - b.y) < (a.height + b.height)/2
end
__gfx__
0000000000700700000000000000000000000000000000fddf000000000000000000000000000000000000000006660000066600000060000000000000000000
0000000000777700000000000000000000c00c000000dffffffd0000040000044000000000000000000000000666666006666660000600060000000000000000
00700700007c7c0004004000000000000c7777c0000ffff5fffff000040000044000000000000000000000000644446666444460000060006000000000000000
000770000077070004004000000000400000070000dffff5fffffd00044000044000000000000000444444406644444664444446000000060000000000000000
000770000007770004444000000004400000700000fffff5ffffff000444004440000000004440004444444064444446644444460ff0000000ff000000000000
00700700077777000949444000004440000700000ffffff5fffffff00044444400044440044044004400004064444444444444460ff4444444fffff000000000
000000007776670004044444444444000c7777c00dfffff5ffffffd00000444000444440440004000400004064444444444444460ff4444444ff00ff00000000
00000000000000000444444444444000000000000fffffff5ffffff00000444000440440400004000400004066444444444444660ff4444444ff000f00000000
00000000000000000004ffffff4440000000000000fffffff5ffff000000044004400440400044000400044006444444444444660ff4444444ff000f00000000
000000000000000000044ffffff440000000000000dfffffff5ffd000000044004444440400440000400440006644444444446600ff4444444ff00ff00000000
0000000000000000000044000004400000000000000ffffffffff0000000044004400440444440000444440000664444444446000ff4444444fffff000000000
00000000000000000004400000440000000000000000dffffffd00000000044000400440444400000444440000066444444466000fff44444fff000000000000
0000000000000000000000000000000000000000000000fddf0000000000000000000000044444000440044000006644444660000fffffffffff000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000444440004400440000006644466000000fffffffff0000000000000
00000000000000000000000000000000000000000000000000000000000000000000000004400444004000400000006646600000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000004400044004000440000000666000000000000000000000000000000
__sfx__
00010000030500405005050080500a0500e0501105014050170501a0501d05020050230502505027050280502a0502a0502805025050210501b0501705014050110500e0500c0500b05009050000000000000000
000500002b0502d0502f0503205034050340503305032050300502e0502c0502a0502805025050230501e05019050120500e0500b050090500705006050040500205001050000500005000000000000005000000
000b00001505015050000001505015050050001805018050180501805018050180500000000000000000000000000150501505000000150501505000000180501805018050180501805018050190000000000000
000b00001505015050000001505015050000001d0501d0501d0501d0501d000000001c0501c0501c0501c0501c0001a0501a0501a0501a0501a0001a0501a0501a0501a050180001805018050180501805000000
000400001e0502105024050270502d050003000030001300013000130001300013000130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800000000014050180501c0501f050210502205022050225002350014050170501b0501c0501d0501c0501b0501905016050130500f0500c0000c0000e5001c50018500155001250011500105000f5000f500
__music__
00 02424344
00 03424344
00 42434344

