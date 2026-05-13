# Maze Using Wave Function Collapse in Godot
Created by Liam Bouwman, Jaidyn Carroll, and Ashtyn Gagner<br/><br/>

### Overview
This program uses the wave function collapse algorithm to generate a large maze from a smaller sample image. The program works by breaking the sample image into pieces, and adding rotations and reflections, therefore creating rules for the larger randomly generated maze to follow. 

### How it Works
- **Takes in the sample maze image**
  - ` read_grid_from_tilemap() `
  - ` build_tile_type_lookup() `
- **Splits the map into 2x2 overlapping segments (stores each segment as a 2D array to be matched later)**
  - ` split_grid() `
- **Generates rotations and reflections**
  - ` add_reflections() `
  - ` add_rotations() `
  - ` rotate_90() `
  - ` reflect() `
- **Uses backtracking to keep going back and forth until it generates valid tile matches**
  - ` generate_map() `
  - ` generate_grid() `
  - ` backtrack() `

### Implementation
To implement this program into this program you must first attach the script to a TileMapLayer. Then import a Tileset of your choice into this TileMapLayer. Add a custom data layer {Tile_Type:Int} Then assign unique values to each of the tiles in your TileSet. Draw a sample for the program to generate from onto the scene editor and hit go. If you want infinite generation, assign a node to the exported value “player”. If you desire to seed your generation assign which tile you would like to use as the exported value “Seed”



### Wave Function Collapse: Limitations and Hurdles:
We tried many methods when working with WFC. Our first attempt was doing a simple sliding window with a set of tiles. We used a 2x2 grid that would simply iterate across the area. This worked but was unstable and didn’t contain any form of backtracking. Next we added a simple form of backtracking simply retrying the last step if we failed, but this still didn't work very well. 

So we looked into better methods of performing WFC. There were two main issues we wanted to solve. First instead of using a sliding window we wanted to select the tile with the least entropy. Then second we wanted to replace the 2x2 tiles we were using. 

The way we decided to track entropy was by using a grid we called the guide. This grid functioned like a building map for the main function. Each time we generated a tile it would add +1 to all adjacent tiles on the guide. This meant that by looking at a position on the guide we could tell how many neighbors it had generated. We could simply look for the highest non 8 value. Each time we queried this guide we would get a selection of tiles and we just randomly chose one to go with. 

This adds a wrinkle with our original backtracking. So we stored the decisions we made and the possible other decisions we could’ve made. That way if we were to backtrack we would avoid repeating moves we’ve already made. This closely mirrors a depth first search. But this approach demanded incredible amounts of memory especially when generating large grids. If we had used traditional programming languages we could’ve used a real node tree for much greater efficiency and lesser memory usage. 

Once we’ve selected our candidate tile we check to see how many valid tiles could fit in that spot. This task could’ve been handled better. Looking at other interactions of WFC there are many better ways to store and check adjacencies. Our approach uses all the undecided tiles as wildcards then randomly selects one of the valid candidates to place in our candidate position.  This approach is also very memory intensive and compounds with the above problems to drag the program to a halt. 

This repeats until either a max attempt is reached or a full grid is generated. The algorithm can produce decently proper outputs but it will often grind the system to a halt causing a crash or reach max attempts before doing so. 










